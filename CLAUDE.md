# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

BR-AI é uma IA de homúnculos do Ragnarok Online construída sobre uma **árvore de comportamento** (BT) em Lua, reimplementando o AzzyAI 1.56 de forma incremental. A mesma árvore roda em três lugares sem alteração: dentro do cliente do RO, dentro de um simulador/depurador desktop (Electron) e no navegador (`npm run web`, que abre direto no simulador). Documentação detalhada em `docs/` e visão completa de design em `DESIGN.md`.

## Comandos

**Testes** (harnesses offline em `tools/*.lua`, rodam fora do jogo contra um mundo falso). Requerem um interpretador Lua; use `lua` (5.1+) se estiver no PATH, senão `texlua` (do TeX Live). Rode **da raiz do repo**:

```bash
node tools/run_lua_tests.js   # roda TODA a suíte (autodetecta lua/texlua) e falha se algum quebrar
texlua tools/bt_test.lua      # ou um teste só; principal, saída: "RESULTADO: 30 ok, 0 falhas"
```

Cada arquivo `tools/<área>_test.lua` é um teste independente — rodar um arquivo é "rodar um teste". Antes de mexer no motor ou nos behaviors, rode os relevantes (ex.: `homun_test.lua`, `chase_test.lua`, `priority_test.lua`, `skillinfo_test.lua`, `monsters_test.lua`, e os da Eleanor `eleanor_{sphere,combo,grapple,editor,scenarios}_test.lua`, `rescue_ks_test.lua`). `texlua outputs_chk.lua` faz um `loadfile` rápido dos módulos-chave para checar sintaxe.

**App desktop** (simulador + editor):

```bash
cd desktop && npm install
npm start              # app Electron (electron .)
npm run web            # versão web — http://localhost:8000/ abre direto no simulador
npm run host-smoke     # smoke do host Lua via Fengari, sem UI
npm run viz-smoke      # smoke da visualização da Eleanor
npm run sera-viz-smoke # smoke da visualização da legião da Sera
npm run persist-smoke  # smoke da persistência de estado do simulador
```

**Codegen da árvore** (JSON → Lua para o cliente):

```bash
node tools/build_tree.js [entrada.json] [saida.lua]
# padrão: desktop/shared/tree_homun.json -> lua/src/tree_homun.lua
```

**Lint:** `luacheck lua tools outputs_chk.lua` (config em `.luacheckrc`, que declara os globais `BRAI`, a API nativa do RO, `SIM_DISPATCH`/`AI`).

**Pacotes (todas as árvores):**

```bash
node tools/build_all_dists.js   # gera dist/ + .zip de cada árvore em trees/ (headless, igual ao "Gerar Lua")
```

**CI** (`.github/workflows/ci.yml`, GitHub Actions): a cada push/PR roda os testes Lua numa matriz **5.1/5.3/5.4**, os smokes do desktop, o lint (luacheck) e publica os pacotes `dist/` como artefatos. Guia de contribuição em `CONTRIBUTING.md`.

## Arquitetura

### Princípio central: "mesma BT, cliente trocável"

O cliente do RO carrega `lua/AI.lua` e chama a global `AI(myid)` a cada ciclo. Não há laço próprio — somos reinvocados a cada tick. **`lua/src/core/ro_api.lua` é a única interface com o cliente**: no jogo aponta para as globais nativas (`GetV`/`Move`/`SkillObject`/...), no simulador para o mock em `lua/src/sim/runtime.lua`. **Nenhum módulo da árvore chama a API nativa diretamente** — é isso que permite a mesma árvore rodar nos dois lados.

### Decisão pura vs. ação (a separação mais importante)

A árvore é **decisão pura**: lê o blackboard e escreve UMA intenção em `bb.intent` (ex.: `{ kind = "move"/"attack"/"skill", ... }`), retornando um status. Os **efeitos reais** (`Move`/`Attack`/`SkillObject`/`SkillGround`) são emitidos **só em `lua/AI.lua` (`applyIntent`)**. Uma "ação" da BT decide, nunca age. Isso torna a decisão testável fora do jogo e isola a fragilidade (versão/servidor) na camada de ação.

Fluxo de um tick (`AI(myid)` em `lua/AI.lua`): `readCommand` → `perception.update` (lê a API 1×/tick → self/owner/monsters/target no blackboard) → `tree:tick(bb)` (decide, escreve `bb.intent`) → `applyIntent` (efeitos + `skillsys.markUsed` para cooldown/buff só ao aplicar).

### Motor de BT

A árvore é reavaliada **inteira a cada tick** a partir da raiz. "Prioridade" é apenas a ordem dos filhos de um `selector`; não há transições manuais de estado (elimina bugs de "estado preso" da HSM original do AzzyAI). Status: `SUCCESS`/`FAILURE`/`RUNNING` (`lua/src/bt/status.lua`); cada nó grava `lastStatus`, que o painel do simulador colore ao vivo. Composites (`selector`/`sequence`/`parallel`) são reativos/sem memória; decorators mantêm estado (`cooldown`, `limiter`). `check(name, params, child?)` é o condicional usado para amarrar "se X então Y". Tipos de nó e parâmetros: ver `docs/referencia-nos.md`.

### A spec é o contrato compartilhado (não edite o Lua gerado à mão)

A **fonte da verdade** de uma árvore é o **JSON** (editado no editor visual). A mesma spec é consumida por três lados: o editor a produz, o simulador a carrega direto (`tree.build`), e um passo de codegen (`tools/build_tree.js`) a converte em `lua/src/tree_homun.lua` para o cliente — que não tem parser JSON nativo. `tree_homun.lua` é **gerado**; para mudar a árvore padrão, edite o JSON e rode o codegen. `lua/src/bt/tree.lua` faz `build(spec)`, `walk`, `snapshot` (alimenta o painel ao vivo).

### Registry + bootstrap (adicionar um comportamento)

`lua/src/registry.lua` é a **fonte única** de condições e ações (nome → implementação + descrição + schema de params). O motor resolve `name`→folha ao construir a árvore; o editor lê o registry para montar a paleta e validar; o simulador usa o mesmo. Adicionar um comportamento é uma operação única:

1. Implemente a folha em `lua/src/behaviors/` via `reg.condition(...)` / `reg.action(...)` com `desc` + `params` no meta (a ação escreve `bb.intent` e retorna status — **não chama a API nativa**).
2. **Adicione o arquivo (se novo) ao `lua/bootstrap.lua`** na seção de behaviors, senão ele não é carregado nem registrado. `bootstrap.lua` é a fonte da ordem de carregamento, reusada por cliente, testes e simulador — a ordem importa.
3. Adicione um teste em `tools/`.

### Adaptação por tipo de homúnculo

A **mesma árvore** atende os 9 tipos. As ações automáticas (`UseMainSkill`, `UseAoESkill`, `UseHealOwner`, `UseCastling`, ...) resolvem a skill concreta pelo **perfil** do tipo (`lua/src/data/profiles.lua`), obtido de `V_HOMUNTYPE` e, para Homunculus S, do tipo base (`lua/src/data/profile_resolve.lua` → `BRAI.profileFor(bb)`; `BaseHomunType` vem de `src/config.lua`). Para suportar uma skill nova: adicione-a em `data/skills.lua` (SkillInfo: alcance/SP/cast/cooldown/modo de alvo/AoE) e classifique-a no papel certo em `data/profiles.lua` — as ações automáticas passam a usá-la sem mudar a árvore.

**Escolha de skill por papel (override).** Alguns Homunculus S têm 2+ skills no mesmo papel (Dieter: Lava Slide/Blast Forge em AoE; Pyroclastic/Tempering como buff ofensivo). `homun_skills.json` (catálogo global na raiz, igual ao `monsters.json`) escolhe **qual** skill cada ação usa por tipo: `{ choices = { ["<tipo>"] = { mainAtk, aoeAtk, offBuff, defBuff } } }` (papel ausente = padrão do perfil). O override é aplicado num **único ponto** — `BRAI.applySkillChoice` no fim de `BRAI.profileFor` (módulo `lua/src/data/skill_choice.lua`) — então vale igual no jogo, no simulador e no dist. Cada skill tem um campo `role` em `data/skill_meta.lua` que alimenta os candidatos. Edição na tela **"Skills"** do editor (botão na toolbar → `roleConfig(tipo)` lista candidatos+padrão+escolha). Carregamento: dispatch `setSkillChoice` no simulador; `AI.lua` faz `dofile src/skill_choice.lua` no jogo (gerado por `generateSkillChoice` em `build_tree.js`).

### Combos da Eleanor (Homunculus S de alvo único)

A Eleanor tem dois estilos exclusivos (Combate: Sonic Claw→Silvervein Rush→Midnight Frenzy; Agarrão: Tinder Breaker→C.B.C.→E.Q.C.), alternados por Style Change. Tudo é encapsulado no **nó guarda-chuva** `UseEleanorOffense` (decisão pura; helpers internos em `BRAI.eleanor` p/ teste). As **Esferas Espirituais** não são expostas pela API → são **estimadas** em `bb.self.spheres` (+0.5 por ataque e por dano, clamp 0–10; contabilidade em `core/skillsys.lua`, custos por elo em `data/combos.lua` — corrige o bug do EQC da AzzyAI, que custa 2). A **barragem** (`comboSpheres`/`AutoComboSpheres`) só inicia o combo se há esferas pro finalizador. O Agarrão zera o Flee → só libera se isolado (`perception.threatCount` / condição `SafeToGrapple`); o E.Q.C. é podado em Boss/MVP (condição `TargetIsBoss`, via flag `ro.isBoss` ou grupo `config.BossGroup`). O combo reinicia ao trocar/perder o alvo (anti-stutter) e na expiração da janela. Edição na tela **"Combos"** do editor (dispatch `comboInfo`). O simulador tem visualização dedicada (o snapshot expõe um bloco `eleanor` só p/ homunType 52; `renderer.js` desenha orbs + sequência no painel lateral e sobre o sprite). Plano e mapa de testes em `PLANO-COMBOS-ELEANOR.md`; testes em `tools/eleanor_*_test.lua` + `desktop/eleanor_viz_smoke.js`.

### Ponte Electron ↔ Lua

O app desktop **não reimplementa a IA em JS** — embute Lua via [Fengari](https://fengari.io/) (`desktop/lua_host.js`) e roda a árvore real. Expõe a global Lua `SIM_DISPATCH(method, argJson)` (implementada em `lua/src/sim/runtime.lua`); o JS é só transporte (strings JSON) e desenho. `desktop/preload.js` expõe ao renderer `window.brai.dispatch` / `window.trees.*` / `window.scenarios.*` via IPC. Toda a simulação (mock dos sensores/atuadores, IA dos monstros, aplicação de intenção, relógio determinístico) é Lua em `lua/src/sim/`. Comandos do `SIM_DISPATCH` e detalhes do mock: `docs/guia-simulador.md` e `docs/desenvolvimento.md`.

**Versão web (navegador).** A MESMA UI roda no navegador: `desktop/web/lua_host_web.js` embute o Fengari e carrega a BT por `fetch` (na ordem do `bootstrap.lua`); `desktop/web/fs_bridge.js` reimplementa `window.brai/trees/scenarios/...` falando com o `serve.js` (servidor local que lê/grava as pastas reais). O `serve.js` serve `sim.html` como default da pasta web (abre direto no simulador); o `index.html` redireciona p/ `sim.html` (fallback p/ hospedagem estática). **`desktop/web/sim.html` e `editor.html` precisam ter os MESMOS ids do `renderer/index.html` e `editor/index.html`** do Electron — eles carregam o mesmo `renderer.js`/`editor.js`; um elemento ausente quebra a web com `innerHTML` em `null` (confira com um diff de `id="..."`).

**Cuidado (nomes da ponte):** `renderer.js`/`editor.js` são `<script>` clássicos; um `let X` no topo **colide** com a global não-configurável criada por `contextBridge.exposeInMainWorld('X', ...)` no `preload.js` → `SyntaxError` que quebra **só no Electron** (no site, `fs_bridge.js` usa `window.X = {}`, configurável, sem colidir). Por isso a ponte de skill choice é `skillChoiceIO` (não `skillChoice`, que é a variável local). Nunca nomeie um `let`/`const` de topo igual a uma global de ponte (`brai`, `files`, `trees`, `scenarios`, `monsters`, `skillChoiceIO`).

### Portabilidade Lua (restrição que vai para o jogo)

O cliente do RO roda **Lua 5.0 com extensões 5.1**; o simulador roda uma VM moderna (Fengari). Código que vai para o jogo deve ficar no **subconjunto portável** (sem `string.gfind` dependente de versão, etc.) para que a mesma árvore se comporte igual nos dois. Helpers portáveis em `lua/src/compat.lua`. Detalhes na seção 10.2 do `DESIGN.md`.

## Checklist antes de commitar

1. `node tools/run_lua_tests.js` passa (todos verdes) e `luacheck lua tools outputs_chk.lua` sem avisos.
2. Behavior novo registrado **e** incluído em `lua/bootstrap.lua`.
3. Params declarados no meta da folha (para o editor validar).
4. Nenhuma chamada à API nativa fora de `ro_api.lua` / camada de ação.
5. Se corrigiu um bug visto no jogo, salve um cenário de regressão em `scenarios/`.

## Persistência

Árvores em `trees/<nome>/tree.json` (fonte) → "Gerar Lua" produz `tree_homun.lua` + `config.lua` + `monsters.lua` + `skill_choice.lua` e um pacote auto-suficiente `trees/<nome>/dist/` (+ `.zip`). Cenários em `scenarios/*.json`. Catálogo global de monstros/grupos em `monsters.json` (usado pelos nós `monsterCheck`) e escolha global de skills por papel/homúnculo em `homun_skills.json` (aplicada em `BRAI.profileFor`). I/O em `desktop/{trees,scenarios,monsters,skillchoice}_io.js`; montagem do pacote em `desktop/installer.js`.
