## O que muda
<!-- Resumo objetivo da mudança. -->

## Por quê

## Checklist
- [ ] `node tools/run_lua_tests.js` passa (todos verdes)
- [ ] `luacheck lua tools outputs_chk.lua` sem avisos
- [ ] Smokes da área tocada (`npm run host-smoke` / `viz-smoke` / `sera-viz-smoke` / `persist-smoke`)
- [ ] Comportamento novo registrado em `lua/src/registry.lua` **e** incluído em `lua/bootstrap.lua`
- [ ] Params declarados no meta da folha (para o editor validar)
- [ ] Nenhuma chamada à API nativa fora de `ro_api.lua` / camada de ação
- [ ] Se corrige um bug visto no jogo: cenário de regressão salvo em `scenarios/`

## Como testei
