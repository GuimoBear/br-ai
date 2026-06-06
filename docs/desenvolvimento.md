# Guia de Desenvolvimento

Como mexer no código do BR-AI: rodar os testes, adicionar comportamentos, trabalhar com dados de skill, entender a ponte do simulador e levar a árvore ao jogo.

## Rodar os testes

Os harnesses em `tools/*.lua` rodam **fora do jogo**, contra um blackboard/mundo falso. Precisam de um interpretador Lua. Se você tiver `lua` (5.1+) no PATH, use-o; senão, o `texlua` (do TeX Live) serve:

```bash
lua tools/bt_test.lua
# ou
texlua tools/bt_test.lua
```

Saída esperada do principal: `RESULTADO: 30 ok, 0 falhas`.

Cada arquivo de teste cobre uma área:

| Arquivo | Cobre |
|---|---|
| `bt_test.lua` | Motor de BT + decisão básica (seguir, fugir, comando). |
| `homun_test.lua` | A árvore adaptando-se aos 9 tipos de homúnculo. |
| `base_test.lua` | Tipo base do Homunculus S (OldHomunType). |
| `chase_test.lua` / `kite_berserk_test.lua` | Perseguição, kiting, berserk. |
| `priority_test.lua` / `rescue_ks_test.lua` | Seleção de alvo, resgate, proteção anti-KS. |
| `skillinfo_test.lua` / `skill_meta_test.lua` / `skillactions_test.lua` | Metadados e ações de skill. |
| `combo_test.lua` / `ground_test.lua` / `interval_test.lua` | Combos, FX de área, timers. |
| `monsters_test.lua` / `phaseb_test.lua` / `check_test.lua` / `sim_test.lua` | Mundo simulado, IA de monstros, runtime. |

Rode o conjunto inteiro antes de qualquer mudança que toque o motor ou os behaviors.

## Carregamento de módulos

`lua/bootstrap.lua` é a fonte da ordem de carregamento — reutilizada pelo cliente (`AI.lua`), pelos testes e pelo simulador. Ele carrega tudo sob o namespace global `BRAI`. A ordem importa: `compat` e `core` primeiro, depois `data`, depois o motor de BT (`bt/*`), depois `blackboard`/`perception`/`registry`, depois os `behaviors/*` (que se registram), e por fim `tree.lua` e a spec `tree_homun.lua`.

Se você criar um arquivo de behavior novo, **adicione-o ao `bootstrap.lua`** (na seção de behaviors), senão ele não será carregado nem registrado.

## Adicionar uma condição ou ação

Comportamentos vivem em `lua/src/behaviors/`. Cada folha é registrada no registry com nome, função e metadados (descrição + schema de parâmetros). O registry é a **fonte única** que jogo, simulador e editor compartilham — registrar uma folha já a faz aparecer na paleta do editor e ficar disponível no jogo.

Padrão de uma condição:

```lua
reg.condition("MinhaCondicao", function(bb, p)
    -- bb = blackboard; p = params (ex.: p.pct)
    return bb.self.hpPct < (p.pct or 50)
end, { desc = "Descrição curta para o editor.", params = { pct = "number" } })
```

Padrão de uma ação:

```lua
reg.action("MinhaAcao", function(bb, p)
    -- decida e escreva UMA intenção no blackboard; não chame a API nativa aqui
    bb.intent = { kind = "move", x = bb.owner.x, y = bb.owner.y, reason = "minha-acao" }
    return BRAI.status.RUNNING   -- ou SUCCESS / FAILURE
end, { desc = "Descrição curta.", params = { dist = "number" } })
```

Regras importantes:

- **Ações decidem, não agem.** Uma ação escreve a intenção no blackboard (`bb.intent`); os efeitos reais (`Move`/`Attack`/`Skill`) são emitidos pela camada de ação via `ro_api`, nunca diretamente — é o que mantém a decisão pura e testável, e a mesma árvore rodando no jogo e no simulador.
- **Retorne o status certo.** `RUNNING` enquanto a ação continua entre ticks; `SUCCESS`/`FAILURE` quando conclui ou não se aplica.
- **Declare os params** no meta para o editor validar e oferecer os campos.
- **Adicione um teste** em `tools/` cobrindo o novo comportamento.

Depois de registrar, inclua o arquivo (se for novo) no `bootstrap.lua` e adicione um caso de teste.

## Dados de skill e perfis

A adaptação por tipo de homúnculo vem dos dados em `lua/src/data/`:

- `skills.lua` — `SkillInfo`: alcance, SP, cast fixo/variável, recarga, modo de alvo (self/objeto/chão), AoE. Portado de `H_SkillList.lua`.
- `profiles.lua` — classifica as skills de cada tipo em papéis: `mainAtk`, `aoeAtk`, `offBuff[]`, `defBuff[]`, `heal`, `ownerBuff`, `summon`, `combo[]`, `styleChange`, etc.
- `profile_resolve.lua` — `BRAI.profileFor(bb)` devolve o perfil **efetivo**, mesclando Homunculus S com o tipo base (`BaseHomunType`).
- `core/skillsys.lua` — alcance/SP/cooldown/duração, contagem de mobs no AoE, timers de buff/recast, e a emissão da intenção de skill.
- `core/skill_range.lua` — alcance efetivo (melee ou da skill) para a perseguição parar na distância certa.
- `data/monsters.lua` — `BRAI.monsterGroups`: catálogo de monstros/grupos (cadastro do usuário) consultado pelos nós `monsterCheck`. Carregado no simulador via `setMonsters` e no jogo via o `monsters.lua` gerado.

Para dar suporte a uma skill nova de um tipo, adicione-a em `skills.lua` e classifique-a no papel certo em `profiles.lua`; as ações automáticas (`UseMainSkill`, `UseAoESkill`, etc.) passam a usá-la sem mudar a árvore.

## A ponte do simulador (SIM_DISPATCH)

O app desktop embute Lua via Fengari (`desktop/lua_host.js`) e expõe a global Lua `SIM_DISPATCH(method, argJson)` (implementada em `lua/src/sim/runtime.lua`). O JavaScript só transporta strings JSON; toda a simulação é Lua. O renderer chama via `window.brai.dispatch(method, argJson)` (exposto por `preload.js`).

Comandos principais do `SIM_DISPATCH`:

| Comando | Função |
|---|---|
| `registry` | Exporta a paleta (condições/ações) para o editor. |
| `skillCatalog(homunType, baseType)` | Lista as skills do tipo (para o seletor do editor). |
| `treeSpec` | A árvore padrão. |
| `setTree(spec)` / `clearTree` | Carrega uma árvore customizada / volta à padrão. |
| `load(scenario)` | Inicializa mundo, blackboard e árvore. |
| `reset` | Reinicia com o mesmo cenário. |
| `step` | Executa 1 tick. |
| `snapshot` | Estado atual sem avançar. |
| `setOwner(x,y)`, `moveEntity(id,x,y)` | Reposicionam entidades. |
| `addMonster(...)`, `addAlly(...)`, `removeMonster(id)` | Editam o mundo. |
| `updateMonster(...)`, `updateEntity(...)` | Ajustam stats. |
| `command(cmd,a,b)` | Envia comando do dono ao mundo. |
| `setMonsters(catalog)` | Carrega o catálogo de monstros/grupos (cadastro) para os nós monsterCheck. |

O mock (`runtime.lua`) implementa os sensores (`GetV`/`GetActors`/`GetTick`/`GetMsg`) lendo o estado do mundo e os atuadores (`Move`/`Attack`/`SkillObject`/`SkillGround`) como no-ops cujo efeito é aplicado a partir de `bb.intent` no passo do mundo — reproduzindo a assincronicidade do jogo. Inclui uma IA simples de monstros (aggro, perseguir, atacar) e um relógio determinístico.

## Persistência (caminhos)

- **Árvores** — `trees/<nome>/tree.json` (estrutura + contexto). "Gerar Lua" produz `trees/<nome>/tree_homun.lua` e `config.lua`. I/O em `desktop/trees_io.js`.
- **Cenários** — `scenarios/<nome>.json`. I/O em `desktop/scenarios_io.js`.
- **Árvore compartilhada do app** — `desktop/shared/tree_homun.json`.
- **Catálogo de monstros/grupos** — `monsters.json` na raiz (global). I/O em `desktop/monsters_io.js`. "Gerar Lua" emite também `trees/<nome>/monsters.lua` (codegen `buildTree.generateMonsters`).
- **Pacote de instalação** — "Gerar Lua" monta uma pasta auto-suficiente `trees/<nome>/dist/` (entry `AI.lua` + `brai/lua/**` com o runtime completo + gerados) e um `trees/<nome>/<nome>.zip`. Montagem em `desktop/installer.js`; o `.zip` é escrito por `desktop/zip.js` (DEFLATE puro, sem dependências). O runtime é copiado de `lua/` excluindo `src/sim/` e `sim_boot.lua` (só do simulador).

Nomes de arquivo são saneados (remoção de caracteres inválidos) por `safeName()` nos módulos de I/O.

## Levar a árvore ao jogo

1. No editor, **Gerar Lua** → produz `tree_homun.lua` + `config.lua`.
2. O cliente carrega `lua/AI.lua` (shell fino): ele faz `bootstrap`, liga o backend nativo (`ro.bind(ro.nativeBackend)`), aplica `src/config.lua` (que define, por exemplo, `BaseHomunType`), constrói a árvore com `tree.build(BRAI.treeSpec)` e define a global `AI(myid)`.
3. Ajuste `BRAI_BASE` em `AI.lua` se a pasta da instalação for diferente do padrão (`./AI/USER_AI/brai/lua`).

O cliente do RO roda **Lua 5.0 com extensões 5.1**, então o código que vai para o jogo deve ficar no subconjunto portável (sem `string.gfind` dependente de versão, etc.). O simulador roda numa VM Lua moderna (Fengari), por isso a regra de portabilidade existe: garantir que a mesma árvore se comporte igual nos dois. Detalhes e mitigações na seção 10.2 do [`DESIGN.md`](../DESIGN.md).

## Checklist antes de commitar

1. `texlua tools/bt_test.lua` passa (e os testes da área que você tocou).
2. Behavior novo registrado **e** incluído no `bootstrap.lua`.
3. Params declarados no meta da folha (para o editor validar).
4. Nenhuma chamada à API nativa fora de `ro_api.lua` / camada de ação.
5. Se corrigiu um bug visto no jogo, salve um **cenário de regressão** em `scenarios/`.
