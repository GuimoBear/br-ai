# PLANO — Versão estática (S3 + CloudFront, duas páginas)

Publica o BR-AI como site **estático** em **S3 + CloudFront**, com **defaults vindos do S3** (somente leitura, com cache), **dados do usuário só por upload/download** (nunca persistidos no navegador), **largura máxima 960px**, **sem alterar o comportamento** de web/desktop, e **deploy automatizado** por GitHub Action (OIDC, sem chaves).

> Regra de storage (esclarecida): o navegador **não** é sistema de registro dos **dados do usuário** (cenários, monstros, skills, árvores) — para guardar, **baixa**; para usar, **sobe** (ou escolhe um default do S3). O **estado da ferramenta** (handoff editor↔simulador, preferências de UI) **pode** usar `sessionStorage`/`localStorage` normalmente. Por isso o handoff usa `sessionStorage` real, **igual à web atual** — sem shell/iframe/shim.

---

## 1. Objetivo e restrições

| # | Requisito | Como o plano atende |
|---|-----------|---------------------|
| R1 | Hospedar num **bucket S3** | S3 (origem) **+ CloudFront** (borda/cache); bucket privado atrás de OAC |
| R2 | **Economizar ao máximo** | Free tier perpétuo do CloudFront (1 TB egress + 10 M req/mês), assets *content-hashed* `immutable`, Fengari via CDN grátis, dados sob demanda |
| R3 | **Cache** onde der | `Cache-Control: immutable` nos assets versionados; compressão gzip/brotli do CloudFront; invalidação só de `*.html`+`manifest.json` |
| R4 | **Dados do usuário** não ficam no navegador | `save = download`, `load = upload` (ou default do S3); nada de `localStorage` para conteúdo do usuário |
| R5 | **Estado da ferramenta** pode usar storage | Handoff editor↔sim via `sessionStorage` real (igual à web); overlay de upload em escopo de sessão |
| R6 | **Padrões vêm do S3** | `manifest.json` + `data/*.json` buscados sob demanda (com cache), populam as listas |
| R7 | Experiência **idêntica** às atuais | **Duas páginas** (`index.html`=sim, `editor.html`=editor) com `renderer.js`/`editor.js` **sem modificação** |
| R8 | **Não quebrar** web/desktop | Núcleo extraído + testes de contrato e *smokes* (Playwright) que provam paridade |
| R9 | Comum **compartilhado entre todas** | `bridge_core.js` + `lua_host_core.js` usados por web **e** estática |
| R10 | Deploy **automatizado** | GitHub Action: `push` na `main` + manual, via **OIDC** (sem chaves AWS) |

### Decisões travadas (suas respostas)

1. **Padrões vindos do S3** (read-only, com cache) populam as listas; **upload** traz arquivos do usuário; **save = download**.
2. **Estrutura de duas páginas** (`index.html` + `editor.html`), navegação normal + `sessionStorage` real — **idêntico à web atual**, mínimo de código novo. (Sem SPA/shell/iframe.)
3. **CloudFront + S3**.
4. **Storage liberado para estado da ferramenta**; proibido só para persistir dados do usuário.
5. (Mantidas) **Extrair núcleo + refatorar web**; **deploy no push da `main` + manual**.

---

## 2. Hospedagem S3+CloudFront e custo

- **S3 tem pastas** → estrutura normal: `index.html`, `editor.html`, `assets/…`, `data/…`.
- **CloudFront**: cache de borda, **compressão automática** (gzip/brotli) e **free tier perpétuo** (1 TB/mês egress + 10 M req + 2 M function inv.). App pequeno ⇒ custo ≈ **US$0**.
- **Custo mínimo, na prática:**
  - Assets versionados por *hash* → `Cache-Control: public, max-age=31536000, immutable` (egress repetido ≈ 0).
  - **Fengari via CDN público** (`jsDelivr`, versão fixada) → **zero egress** nosso na maior dependência.
  - **Lua em 1 bundle** → menos requests (S3 cobra por request).
  - **Dados sob demanda** → paga só o que é usado.
  - **Invalidação barata**: só `index.html`, `editor.html`, `data/manifest.json` por deploy (≤ 1000 paths/mês grátis).
  - **Storage** do bucket: poucos MB → desprezível.
- **Segurança:** recomendado **bucket privado + CloudFront OAC** (acessível pela URL do CloudFront; bucket não fica aberto). ACL pública também funciona, mas menos seguro.

URLs (exemplo): `https://<dist>.cloudfront.net/` (sim) e `…/editor.html` (editor).

---

## 3. Arquitetura atual (resumo + handoff)

- **Contrato de globais** (consumido por `renderer.js`/`editor.js`, igual em web e desktop): `window.brai.dispatch`, `trees.{list,load,save,build}`, `scenarios.{list,load,save}`, `monsters.{load,save}`, `skillChoiceIO.{load,save}`, `summonIO.{load,save}`, `files.{loadTree,saveTree,buildLua}`.
- **`fs_bridge.js`**: implementa o contrato por HTTP (`serve.js`); só o I/O de baixo nível é acoplado → **ponto de corte** do núcleo comum.
- **`lua_host_web.js`**: roda a BT via **Fengari**, `fetch` dos módulos na ordem do `bootstrap.lua` (+ `sim/json`,`sim/runtime`), e reaplica `sessionStorage['brai.simTree']`.
- **Handoff editor↔sim (verificado):** via `sessionStorage` — `editor.js#simulateTree` (l.961-966) grava `brai.simTree` (efeito do `setTree` na ponte) + `brai.simContext` + `brai.editorState`, e faz `location.href = BRAI_SIM_URL`; `renderer.js` lê `brai.simSetup`/`simContext` no boot. **Na estática mantemos esse fluxo idêntico** (é estado da ferramenta ⇒ storage permitido); `BRAI_SIM_URL = './index.html'`.

---

## 4. Arquitetura nova (desacoplamento)

### 4.1 Ponte (bridge)

```
        renderer.js / editor.js  (NÃO mudam)  → consomem window.brai/trees/...
                               │  mesmo contrato
                    bridge_core.js (NOVO)  → BRAI_BRIDGE.install(backend)
                    ┌──────────┴───────────┐
            http_backend (web)        s3_backend (estática, NOVO)
            fetch + /__brai/*         fetch S3 (defaults+manifest, cache)
            = fs_bridge.js REFAT.     + overlay de upload (sessão)
                                       + save = DOWNLOAD
```

**Interface do backend** (consumida pelo `bridge_core`): `ready`, `canWrite()`, `readText(rel)`, `readBytes(rel)`, `listDir(rel)`/`listKind(kind)`, `writeData(rel,data)`, `readLuaTree()`, `download(name,bytes)`.

- `fs_bridge.js` (web) → `httpBackend` + `install`. **Comportamento idêntico.**
- `s3_backend.js` (estática) → ver §4.3. `preload.js` (desktop) **fica como está** (Node/Electron; conforme ao contrato, coberto por teste).

### 4.2 Host Lua

```
 lua_host_core.js (NOVO) → create({ getText })
   ├─ lua_host_web.js : getText = fetch(LUA_BASE+rel)   (web, REFAT.)
   └─ static_host.js  : getText = BRAI_LUA_FILES[rel]    (bundle em memória)
```

`lua-bundle.<hash>.js` = `window.BRAI_LUA_FILES = { "<rel em lua/>": "<fonte>" }` com **toda** a `lua/` (roda a BT **e** alimenta o "Gerar Lua"/zip sem requests extras).

### 4.3 `s3_backend` — defaults do S3 + upload/download

- **Listas:** `GET data/manifest.json` (cache) → nomes **∪** overlay de upload (sessão).
- **Load:** overlay → senão `GET data/trees/<n>.json` / `data/scenarios/<n>.json` (cache). `monsters`/`skills`/`summons` → `GET data/*.json` (cache) ou overlay.
- **Save:** dispara **download** do `.json` **e** adiciona ao overlay (continua selecionável na sessão). **Nunca** grava conteúdo do usuário em `localStorage`.
- **Upload (tela):** `static_ui` abre file picker → `parse` → grava no **overlay (sessão, em `sessionStorage`)** → atualiza a lista → seleciona (dispara o caminho normal de load). Reusa a UX de seleção existente; o conteúdo subido sobrevive ao handoff editor→sim na mesma aba e some ao fechar (para guardar, baixar).
- **Build ("Gerar Lua"):** reusa `BRAI_BUILD` + `BRAI_ZIP` sobre o `BRAI_LUA_FILES` e **baixa o `.zip`**.

### 4.4 As duas páginas estáticas

`index.html` (sim) e `editor.html` (editor) espelham as `desktop/web/{sim,editor}.html`, trocando ponte/host e adicionando upload/download + 960px. Ordem de scripts:

```
Fengari (jsDelivr) → build_tree_web → zip_web →
lua_host_core → static_host → lua-bundle →
bridge_core → s3_backend → static_ui → renderer.js (index) | editor.js (editor)
```

Handoff: `sessionStorage` real (`brai.simTree/simContext/editorState/simSetup`), `BRAI_SIM_URL='./index.html'`. Sem shim, sem iframe.

### 4.5 Mapa do contrato → modo estático

| Método | Web (HTTP) | Estática (S3) |
|--------|-----------|----------------|
| `trees.list` / `scenarios.list` | `GET /__brai/list` | `GET data/manifest.json` (cache) ∪ overlay |
| `*.load(name)` | `GET <arquivo>` | overlay → `GET data/...` (cache) |
| `*.save(name,json)` | `POST /__brai/write` | **download .json** (+ overlay sessão) |
| `trees.build` | grava + baixa zip | gera do `BRAI_LUA_FILES` e **baixa zip** |
| `monsters/skill/summon.load` | `GET *.json` | `GET data/*.json` (cache) ou overlay |
| `monsters/skill/summon.save` | `POST` | **download .json** |
| `brai.dispatch` | BRAIHost + persist `simTree` (`sessionStorage`) | **igual** (`sessionStorage` real) |
| importar / exportar | — | **novo na UI** (`static_ui`) |

---

## 5. Inventário de arquivos

**Novos (compartilhados — web + estática):** `desktop/shared/bridge_core.js`, `desktop/shared/lua_host_core.js`.

**Novos (só estática — `desktop/static/`):** `s3_backend.js`, `static_host.js`, `static_ui.js`, `static.css` (960px + overrides), e *templates* `index.tmpl.html`, `editor.tmpl.html`.

**Novos (build/automação/testes):** `tools/build_static.js` (gera as 2 páginas + `manifest.json` + assets *hashed* em `dist-static/`), `tools/bridge_core_test.js`, `tools/s3_backend_test.js`, `tools/static_host_smoke.js`, `tools/build_static_test.js`, `desktop/web_browser_smoke.js`, `desktop/static_browser_smoke.js` (Playwright), `.github/workflows/deploy-s3.yml`, `infra/README.md` (OIDC/bucket/CloudFront).

**Alterados (comportamento preservado):** `desktop/web/fs_bridge.js` (→ httpBackend+install), `desktop/web/lua_host_web.js` (→ fetch provider+create), `desktop/web/sim.html`+`editor.html` (adicionam `<script>` de `bridge_core.js`/`lua_host_core.js`), `.github/workflows/ci.yml`, `desktop/package.json` (scripts `build:static`,`smoke:web`,`smoke:static`), `.gitignore` (`dist-static/`).

**Intocados (garantido):** `renderer/renderer.js`, `renderer/style.css`, `editor/editor.js`, `editor/editor.css`, `web/serve.js`, `preload.js`, `main.js`, **toda a `lua/`**, **todos os `tools/*_test.lua`**, `lib/*`.

---

## 6. Build — `tools/build_static.js` (saída em `dist-static/`)

1. **Lua bundle:** ler toda `lua/` → `assets/lua-bundle.<hash>.js` (`window.BRAI_LUA_FILES`).
2. **Dados:** `trees/*/tree.json` → `data/trees/<nome>.json`; `scenarios/*.json` → `data/scenarios/<nome>.json`; `monsters.json`/`homun_skills.json`/`homun_summons.json` → `data/`. Gerar `data/manifest.json` (listas de nomes).
3. **Assets (hashed):** `renderer.js`, `editor.js`, `style.css`, `editor.css`, `lib/build_tree_web.js`, `lib/zip_web.js`, `bridge_core.js`, `lua_host_core.js`, `static_host.js`, `s3_backend.js`, `static_ui.js`, `static.css` → `assets/<nome>.<hash>.<ext>`.
4. **HTMLs:** montar `index.html` e `editor.html` dos *templates*, injetando URLs *hashed* e Fengari via **`https://cdn.jsdelivr.net/npm/fengari-web@0.1.4/dist/fengari-web.js`** (opção: self-host em `assets/`). Ordem de §4.4.
5. **Verificações (falham o build):** todo módulo do `bootstrap.lua` (+ `sim/*`) no bundle; todas as árvores/cenários no `manifest`; sem referência externa além do CDN do Fengari e dos assets; plano de `Cache-Control` coerente.

`npm run build:static`.

---

## 7. GitHub Action — deploy S3+CloudFront (OIDC, sem chaves)

**Infra (uma vez, `infra/README.md`):** bucket S3 privado + CloudFront (OAC, compressão ligada); **provedor OIDC do GitHub** + **IAM role** com confiança restrita ao repo e permissões `s3:PutObject/DeleteObject/ListBucket` + `cloudfront:CreateInvalidation`. *Variables*: `AWS_REGION`, `S3_BUCKET`, `CLOUDFRONT_ID`; *secret*: `AWS_DEPLOY_ROLE_ARN`.

```yaml
name: Deploy estático (S3+CloudFront)
on:
  push: { branches: [main] }
  workflow_dispatch: {}
permissions: { id-token: write, contents: read }
jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with: { node-version: '20' }
      - run: cd desktop && npm ci
      - run: node tools/build_static.js
      - run: node tools/static_host_smoke.js       # trava: bundle boota no Fengari
      - run: node tools/build_static_test.js        # trava: completude/auto-contenção
      - uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.AWS_DEPLOY_ROLE_ARN }}
          aws-region: ${{ vars.AWS_REGION }}
      - name: Assets imutáveis
        run: aws s3 sync dist-static/assets s3://${{ vars.S3_BUCKET }}/assets --delete --cache-control "public,max-age=31536000,immutable"
      - name: Dados imutáveis (exceto manifest)
        run: aws s3 sync dist-static/data s3://${{ vars.S3_BUCKET }}/data --delete --cache-control "public,max-age=31536000,immutable" --exclude manifest.json
      - name: HTML + manifest (cache curto)
        run: |
          aws s3 cp dist-static/index.html  s3://${{ vars.S3_BUCKET }}/index.html  --cache-control "public,max-age=60,must-revalidate"
          aws s3 cp dist-static/editor.html s3://${{ vars.S3_BUCKET }}/editor.html --cache-control "public,max-age=60,must-revalidate"
          aws s3 cp dist-static/data/manifest.json s3://${{ vars.S3_BUCKET }}/data/manifest.json --cache-control "public,max-age=60,must-revalidate"
      - name: Invalidar CloudFront
        run: aws cloudfront create-invalidation --distribution-id ${{ vars.CLOUDFRONT_ID }} --paths "/index.html" "/editor.html" "/data/manifest.json"
```

**Segurança:** sem segredos no bundle; credenciais AWS **efêmeras via OIDC**.

---

## 8. Layout 960px (sem tocar no CSS compartilhado)

As páginas envolvem o conteúdo num container `max-width:960px; margin:0 auto;`. `static.css` (carregado **depois** do CSS compartilhado) aplica overrides 960px e responsivos (mapa default menor; *sidebar* quebra abaixo do simulador; cap do `#graphwrap` no editor). `renderer.js`/`editor.js` selecionam por **id**, então o wrapper é seguro.

---

## 9. Testes (provar paridade e a regra de storage)

**Regressão (continuam verdes):** `node tools/run_lua_tests.js` (31), `luacheck`, e os smokes `host-smoke`/`persist-smoke`/`viz-smoke`/`sera-viz-smoke` (usam `renderer.js`/`lua_host.js`, intocados).

**Novos:**
- `bridge_core_test.js` — `install()` com **dois mocks** (HTTP e S3) → mesmas formas de retorno. **Paridade do contrato.**
- `s3_backend_test.js` — `manifest` + load com cache (fetch mockado), overlay de upload (sessão), `save = download`, e **asserção de que conteúdo do usuário não vai p/ `localStorage`**.
- `static_host_smoke.js` — carrega `BRAI_LUA_FILES` (do bundle) no **Fengari** e roda `load` + N `step`.
- `build_static_test.js` — build p/ tmp: valida saídas, *hashing*, completude do `manifest`, auto-contenção e plano de cache.
- **`desktop/web_browser_smoke.js` (Playwright)** — sobe `serve.js`, abre `sim.html`, roda *steps*: **rede de segurança da refatoração `fs_bridge.js`/`lua_host_web.js`**.
- **`desktop/static_browser_smoke.js` (Playwright)** — abre `index.html` (dropdowns carregam do `data/`), abre `editor.html`, monta árvore, clica **Simular** → navega p/ `index.html` e roda a árvore editada (handoff por `sessionStorage`); **afirma que dados do usuário não foram persistidos em `localStorage`** e que `save` baixa arquivo; zero erros no console.

**CI:** novo job em `ci.yml` (`npm ci` → testes Node → 2 smokes Playwright). Matriz Lua 5.1/5.3/5.4 e luacheck permanecem. Deploy fica no workflow separado.

---

## 10. Fases (ordem + "pronto quando")

| Fase | Entrega | Pronto quando |
|------|---------|---------------|
| 0 | Andaime: `desktop/shared/`, `desktop/static/`, `.gitignore dist-static/`, contrato documentado | repo intacto |
| 1 | `bridge_core.js` + refatorar `fs_bridge.js` | `bridge_core_test` + `web_browser_smoke` + smokes existentes verdes |
| 2 | `lua_host_core.js` + refatorar `lua_host_web.js` | `web_browser_smoke` verde de novo |
| 3 | `s3_backend.js` + `static_host.js` + `static_ui.js` + `static.css` | `s3_backend_test` verde |
| 4 | `build_static.js` + templates (2 páginas) | `build_static_test` + `static_host_smoke` + `static_browser_smoke` verdes; site roda local |
| 5 | Infra AWS (bucket+CloudFront+OIDC) + `deploy-s3.yml` | deploy manual publica; URL abre; cache/headers conferidos |
| 6 | CI + docs (`README`/`CLAUDE.md`/`infra/README.md`) | CI roda tudo; docs atualizados |

> Fases 1–2 entregam o desacoplamento **antes** de qualquer novidade; se um smoke falhar, paramos e corrigimos.

---

## 11. Riscos e mitigações

- **Refatorar `fs_bridge.js`/`lua_host_web.js` sem teste hoje** → adicionar `web_browser_smoke` **antes** de refatorar.
- **Sem listagem de diretório no S3** → `manifest.json` gerado no build (não depende de `ListBucket`).
- **CORS** → mesma origem (CloudFront serve tudo); Fengari via CDN com CORS liberado.
- **Confundir estado da ferramenta com dado do usuário** → `localStorage` nunca guarda conteúdo do usuário (só, se útil, prefs de UI); conteúdo do usuário = `sessionStorage` (sessão) + upload/download. Coberto por `s3_backend_test`/`static_browser_smoke`.
- **Custo inesperado** → assets *immutable* + CDN grátis + Fengari fora do egress; billing alarm.
- **Segredos em repo/bucket** → **OIDC**; bucket privado atrás de OAC; build sem segredos.
- **Portabilidade Lua do cliente do RO** → **inalterada** (não tocamos `lua/`); "Gerar Lua" produz o mesmo `.zip`.

---

## 12. Checklist antes do deploy

1. `node tools/run_lua_tests.js` verde e `luacheck` sem avisos.
2. `host-smoke`, `persist-smoke`, `viz-smoke`, `sera-viz-smoke` verdes (web/desktop preservados).
3. `bridge_core_test`, `s3_backend_test`, `static_host_smoke`, `build_static_test` verdes.
4. `web_browser_smoke` **e** `static_browser_smoke` (Playwright) verdes — incluindo a regra de storage (conteúdo do usuário não persistido; `save` baixa).
5. Local: dropdowns carregam defaults do `data/`, upload abre tela e injeta, save baixa arquivo, Editor→Simular roda a árvore editada — tudo a 960px.
6. Infra AWS: OIDC/role/bucket/CloudFront ok; `deploy-s3.yml` publica no push da `main` + manual; cache/invalidação conferidos.
