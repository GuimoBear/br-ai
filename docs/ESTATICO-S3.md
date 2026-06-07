# Versão estática (S3 + CloudFront)

Publica a MESMA BT/IA como site **estático** (sem back-end): duas páginas que reusam o
`renderer.js`/`editor.js` **sem modificação**, com **defaults vindos do S3** e
**carregar = upload / salvar = download** (nada de conteúdo do usuário no navegador).
Plano completo em `PLANO-ESTATICO-S3.md`.

## Como funciona (desacoplamento)
- **`desktop/shared/bridge_core.js`** — núcleo COMUM da ponte (`window.brai/trees/scenarios/
  monsters/skillChoiceIO/summonIO/files`). A web (`fs_bridge.js`) e a estática
  (`s3_backend.js`) só implementam o "backend"; o contrato é idêntico.
- **`desktop/shared/lua_host_core.js`** — núcleo COMUM do host Lua (Fengari). A web
  (`lua_host_web.js`) busca os módulos por `fetch`; a estática (`static_host.js`) lê do
  **bundle** `window.BRAI_LUA_FILES`.
- **`desktop/static/s3_backend.js`** — defaults do S3 (`data/manifest.json` + `data/*.json`,
  com cache) ∪ **overlay de upload em sessão**; `save` dispara **download**.
- **`desktop/static/static_ui.js`** — botão "Importar" (upload) + `classify()`.
- **`desktop/static/static.css`** — largura máxima **960px** (não toca o CSS compartilhado).

## Build
```
node tools/build_static.js            # gera dist-static/ (index.html, editor.html, assets/, data/)
# ou: cd desktop && npm run build:static
```
- Assets com **hash** no nome (cache imutável), Lua num único bundle, Fengari via CDN (jsDelivr).

## Testes (tudo verde antes de publicar)
```
cd desktop
npm run test:node          # bridge_core, lua_host_core, s3_backend, + smokes Fengari
npm run smoke:statichost   # bundle Lua roda no Fengari
npm run test:buildstatic   # valida a saída do build (completude, auto-contenção, ordem)
npm run smoke:web          # Playwright: web (rede de segurança do refactor)
npm run smoke:static-browser   # Playwright: estática (inclui "nada em localStorage")
```
Regressão (inalterados): `node tools/run_lua_tests.js`, `npm run host-smoke|persist-smoke|viz-smoke|sera-viz-smoke`.

## Deploy
- GitHub Action `.github/workflows/deploy-s3.yml` (push na `main` + manual) → S3 + invalidação CloudFront, via **OIDC**.
- Configuração da infra (bucket, CloudFront/OAC, role OIDC, variáveis/segredos): **`infra/README.md`**.
