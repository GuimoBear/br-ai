# Contribuindo com o BR-AI

Obrigado pelo interesse! Este guia cobre como rodar o projeto, a suíte de testes e o
fluxo de contribuição. A visão de arquitetura está em [`DESIGN.md`](DESIGN.md) e os
guias detalhados em [`docs/`](docs/).

## Pré-requisitos

- **Node.js 18+** — para o app desktop/web e o codegen (`tools/build_tree.js`).
- **Um interpretador Lua** para os testes: `lua` 5.1+ (recomendado) ou, na falta dele,
  `texlua` (do TeX Live). O código roda igual em 5.1, 5.3 e 5.4.

## Rodando

```bash
cd desktop
npm install
npm run web      # editor + simulador no navegador: http://localhost:8000/desktop/web/
npm start        # ou como app Electron
```

Detalhes da versão web em [`desktop/web/README.md`](desktop/web/README.md).

## Testes

A suíte são harnesses offline que rodam a IA fora do jogo contra um mundo falso.
Da **raiz do repositório**:

```bash
# roda TODOS os tools/*_test.lua + outputs_chk.lua e falha se algum quebrar
node tools/run_lua_tests.js

# ou um teste específico, direto no interpretador
lua tools/bt_test.lua          # principal — esperado: "RESULTADO: 30 ok, 0 falhas"
texlua tools/bt_test.lua       # idem, se você não tem o lua no PATH
```

Smokes da ponte Lua↔JS (Fengari) e das visualizações, em `desktop/`:

```bash
cd desktop
npm run host-smoke        # a árvore real rodando via Fengari, sem UI
npm run viz-smoke         # visualização da Eleanor
npm run sera-viz-smoke    # visualização da legião da Sera
npm run persist-smoke     # persistência de estado do simulador
```

O **CI** (GitHub Actions, `.github/workflows/ci.yml`) roda tudo isso a cada push/PR,
com a suíte Lua numa matriz **5.1 / 5.3 / 5.4**.

## Princípios de arquitetura (leia antes de mexer no motor)

- **Decisão pura vs. ação.** A árvore só lê o blackboard e escreve UMA intenção em
  `bb.intent`; os efeitos reais (`Move`/`Attack`/`Skill`) saem só na camada de ação
  (`lua/AI.lua` / `applyIntent`). Uma "ação" da BT decide, nunca age.
- **`ro_api.lua` é a única interface com o cliente.** Nenhum módulo da árvore chama a
  API nativa direto — é isso que permite a mesma árvore rodar no jogo e no simulador.
- **A spec (JSON) é o contrato.** A fonte da verdade de uma árvore é
  `trees/<nome>/tree.json`; o `tree_homun.lua` é **gerado** (`tools/build_tree.js`) —
  não edite o Lua gerado à mão.
- **Registry + bootstrap.** Um comportamento novo é registrado em
  `lua/src/registry.lua` (via `reg.condition`/`reg.action`, com `desc` + `params`) e
  **precisa** ser incluído em `lua/bootstrap.lua`, senão não é carregado.
- **Portabilidade Lua.** Código que vai para o jogo fica no subconjunto portável
  (Lua 5.0/5.1): sem `//`, `goto`, operadores bitwise, `table.unpack`, etc. Helpers em
  `lua/src/compat.lua`.

## Checklist antes de abrir um PR

1. `node tools/run_lua_tests.js` passa (todos verdes), mais os smokes da área tocada.
2. Comportamento novo registrado **e** incluído em `lua/bootstrap.lua`.
3. Params declarados no meta da folha (para o editor validar).
4. Nenhuma chamada à API nativa fora de `ro_api.lua` / camada de ação.
5. Se corrigiu um bug visto no jogo, salve um cenário de regressão em `scenarios/`.

## Estilo

Sem linter configurado. Siga o estilo do código vizinho: indentação com TAB nos
arquivos Lua, comentários curtos explicando o "porquê", nomes em português quando
fizer sentido com o domínio (homúnculo, esfera, agarrão...).
