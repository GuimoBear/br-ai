# Arquitetura

Este documento descreve como o BR-AI é organizado e por que cada camada existe. Para o design conceitual completo (incluindo a API real do cliente do RO e o mapeamento a partir do AzzyAI), veja [`DESIGN.md`](../DESIGN.md) na raiz.

## Princípio central: "mesma BT, cliente trocável"

O cliente do RO carrega `AI.lua` e chama a função global `AI(myid)` a cada ciclo de IA. Nosso código só pode **perceber** (via `GetV`/`GetActors`/`GetMsg`), **decidir** e **agir** (via `Move`/`Attack`/`SkillObject`/`SkillGround`). Não há laço próprio — somos reinvocados a cada tick.

A decisão (a árvore de comportamento) é escrita em Lua puro e portável, sem nunca chamar a API nativa diretamente. Toda a comunicação com o cliente passa por uma interface fina, `lua/src/core/ro_api.lua`. No jogo essa interface aponta para as globais nativas; no simulador, para um mock implementado em `lua/src/sim/runtime.lua`. É isso que permite a **mesma árvore** rodar no jogo e no simulador sem nenhuma alteração.

## Camadas

```
AI(myid)  — loop do cliente (1 chamada por ciclo)
   │
   ▼
Percepção / Blackboard      (core/perception.lua, core/blackboard.lua)
   • lê a API 1× por tick → self, owner, monsters, target
   • contadores, intenção, flags (berserk/standby), timers persistentes
   │ passado como contexto
   ▼
Árvore de Comportamento     (bt/*, registry, behaviors/*)
   • decisão PURA: lê o blackboard e escreve UMA intenção
   │ intenção (ex.: UseSkill | AttackTarget | MoveToOwner)
   ▼
Camada de Ação / ro_api     (core/ro_api.lua)
   • efeitos: Move / Attack / SkillObject / SkillGround
   ▼
Dados                       (data/skills, data/profiles, data/skill_meta)
   • metadados de skill, perfis por tipo de homúnculo
```

A vantagem de separar **decisão** de **ação**: a decisão vira uma função pura do blackboard, **testável fora do jogo**. A camada de ação concentra o que depende de versão/servidor e onde moram os bugs históricos, isolando a fragilidade.

## Estrutura de pastas

```
br-ai/
├── lua/                         Tudo que roda no cliente do RO (e no simulador)
│   ├── AI.lua                   Entrada no cliente: define AI(myid)
│   ├── bootstrap.lua            Carrega todos os módulos sob o namespace global BRAI
│   ├── sim_boot.lua             Boot do simulador (carrega BRAI + runtime do mock)
│   └── src/
│       ├── compat.lua           Helpers portáveis Lua 5.0/5.1/5.3
│       ├── core/
│       │   ├── const.lua        Constantes V_*/MOTION_*/*_CMD (espelham o AzzyAI)
│       │   ├── util.lua         Geometria de grid (distância Chebyshev, passos)
│       │   ├── ro_api.lua       INTERFACE única com o cliente (nativo no jogo / mock no sim)
│       │   ├── blackboard.lua   Contexto por tick + contadores + intenção + persistência
│       │   ├── perception.lua   Lê a API 1×/tick → self / owner / monsters
│       │   ├── skillsys.lua     Alcance/SP/cooldown/duração, mobcount, timers de buff
│       │   └── skill_range.lua  Alcance efetivo (melee ou da skill) para a perseguição
│       ├── bt/
│       │   ├── status.lua       SUCCESS / FAILURE / RUNNING
│       │   ├── node.lua         Nó base (guarda lastStatus p/ o depurador)
│       │   ├── composites.lua   selector / sequence / parallel
│       │   ├── decorators.lua   inverter / succeeder / cooldown / limiter / check
│       │   └── tree.lua         build(spec) → árvore executável; walk; snapshot
│       ├── data/
│       │   ├── skills.lua       SkillInfo: alcance, SP, cast, cooldown, modo de alvo, AoE
│       │   ├── profiles.lua     Classifica skills de cada tipo em papéis (mainAtk, heal...)
│       │   ├── profile_resolve.lua  Perfil efetivo (Homunculus S + tipo base)
│       │   └── skill_meta.lua   Metadados auxiliares de skill
│       ├── registry.lua         Registro nome → folha (condição/ação) + schema de params
│       ├── behaviors/           conditions, combat, idle, survival, commands, skills
│       ├── tree_homun.lua       SPEC da árvore padrão (mesma forma do JSON do editor)
│       └── sim/
│           ├── runtime.lua      Mock do cliente + mundo simulado + SIM_DISPATCH
│           └── json.lua         Encode/decode JSON portável (5.0/5.1/5.3)
│
├── desktop/                     Aplicação Electron (simulador + editor)
│   ├── main.js                  Processo principal: janela + handlers IPC + I/O de arquivos
│   ├── lua_host.js              Embute Fengari, carrega os módulos Lua, expõe SIM_DISPATCH
│   ├── preload.js               Ponte segura (contextBridge) renderer ↔ main
│   ├── trees_io.js              Persistência de árvores (trees/<nome>/)
│   ├── scenarios_io.js          Persistência de cenários (scenarios/*.json)
│   ├── editor/                  Editor visual de árvores (index.html, editor.js, editor.css)
│   ├── renderer/                Simulador/depurador (index.html, renderer.js, style.css)
│   └── shared/tree_homun.json   Cópia da árvore padrão usada pelo app
│
├── tools/                       Harnesses de teste em Lua (rodam com lua/texlua) + build_tree.js
├── trees/                       Árvores salvas pelo editor (1 pasta por árvore)
├── scenarios/                   Cenários salvos pelo simulador (.json)
└── docs/                        Esta documentação
```

## O motor de behavior tree

A árvore é reavaliada **inteira a cada tick** a partir da raiz. "Prioridade" é simplesmente a ordem dos filhos de um `selector`. Não há transições manuais de estado — sair de um comportamento é apenas outro ramo passar a ter sucesso. Isso elimina a classe de bugs de "estado preso" da máquina de estados original.

### Status

Todo nó retorna um de três status (`lua/src/bt/status.lua`):

- **SUCCESS** — o nó cumpriu seu objetivo neste tick.
- **FAILURE** — o nó não se aplica / não conseguiu agir.
- **RUNNING** — a ação está em andamento e deve continuar no próximo tick.

Cada nó grava seu `lastStatus`, que é o que o painel do simulador colore ao vivo.

### Composites (sem memória, reativos)

- **selector** — OR de prioridade: tica os filhos em ordem; o primeiro que retorna SUCCESS ou RUNNING vence; falha só se todos falharem.
- **sequence** — AND: tica em ordem; para no primeiro FAILURE ou RUNNING; sucesso só se todos passarem.
- **parallel** — tica todos os filhos; `policy = "all"` (sucesso se todos) ou `"any"` (sucesso se ao menos um).

Os composites são **reativos** (sem estado): a árvore reavalia tudo a cada tick, o que mantém a prioridade sempre atual.

### Decorators

- **inverter** — troca SUCCESS↔FAILURE; RUNNING passa.
- **succeeder** — força SUCCESS (exceto quando RUNNING). Útil para tornar um ramo opcional.
- **cooldown(ms)** — bloqueia (FAILURE) durante `ms` após o filho ter tido SUCCESS. Mantém estado (`readyAt`).
- **limiter(max, key)** — permite no máximo `max` sucessos do filho; depois falha. Reseta via `bb:resetCounters()`. Mantém estado (contador).
- **check(name, params)** — nó condicional com **um filho opcional**: avalia a condição `name`; se verdadeira, executa o filho e devolve o status dele; se falsa, devolve FAILURE. Sem filho, funciona como uma condição pura.

### Da spec à árvore executável

`lua/src/bt/tree.lua` converte uma **spec** (tabela Lua ou JSON) em árvore executável:

- `tree.build(spec)` — lê a spec recursivamente e instancia os nós. Tipos suportados: `selector`, `sequence`, `parallel`, `inverter`, `succeeder`, `cooldown`, `limiter`, `check`, `condition`, `action`. Os campos lidos por nó incluem `children`, `child`, `policy`, `ms`, `max`, `key`, `name`, `params` e `label`.
- `tree.walk(node, fn)` — visita todos os nós em profundidade.
- `tree.snapshot(node)` — retorna uma lista `{ label, kind, status, depth }` por nó, que alimenta o painel da árvore ao vivo no simulador.

A **spec é o contrato compartilhado** entre editor, simulador e jogo: o editor a produz como JSON, o simulador a carrega direto e um passo de codegen (`tools/build_tree.js`) a converte em `tree_homun.lua` para o cliente, que não tem parser JSON nativo.

## O registry: fonte única de verdade dos nós

`lua/src/registry.lua` registra cada **condição** e cada **ação** disponível, com nome, descrição e schema de parâmetros. Os três consumidores compartilham esse registro:

- O **motor** resolve `name` → implementação Lua ao construir a árvore.
- O **editor** lê o registro (via comando `registry` do simulador) para montar a paleta e validar parâmetros — só oferece nós que existem de fato.
- O **simulador** usa o mesmo registro ao executar.

Adicionar um comportamento novo é, portanto, uma operação única: implementar a folha e registrá-la (veja [desenvolvimento.md](desenvolvimento.md)).

## A árvore padrão do homúnculo

A spec padrão (`lua/src/tree_homun.lua`, espelhada em `desktop/shared/tree_homun.json`) é um `selector` na raiz com esta ordem de prioridade:

1. **comando** — se há comando do dono pendente, executa-o (interrompe tudo).
2. **sobrevivência** — se HP baixo e sob ataque, foge.
3. **cura-urgente** — cura a si (`UseHealSelf`) ou o dono (`UseHealOwner`).
4. **UseCastling** — Amistr troca de lugar com o dono cercado.
5. **UseOwnerBuff** — mantém buff no dono.
6. **Engajar** — sequência: primeiro define o alvo (resgatar o dono › manter alvo atual › adquirir novo), depois age em combate (summon › AoE › skill single › ataque normal › perseguir).
7. **ocioso** — volta para o dono se longe; senão recasta buffs ofensivos/defensivos; senão fica ocioso.

A **mesma árvore** atende os 9 tipos de homúnculo; o que muda é o *perfil de skills* resolvido por `V_HOMUNTYPE` (e, para Homunculus S, pelo tipo base). Veja a seção 15 do [`DESIGN.md`](../DESIGN.md) e [referencia-nos.md](referencia-nos.md).

## A ponte Electron ↔ Lua

O app desktop não reimplementa a IA em JavaScript — ele **embute o Lua** via [Fengari](https://fengari.io/) e roda a árvore real:

```
renderer/ (UI, sem Node)  ──IPC──▶  main.js  ──▶  lua_host.js (Fengari)
                                                    └─ carrega lua/** e chama SIM_DISPATCH
```

- `lua_host.js` cria um estado Lua, carrega os módulos na ordem de `bootstrap.lua` mais `sim/json.lua` e `sim/runtime.lua`, e expõe a global Lua `SIM_DISPATCH(method, argJson)`.
- `preload.js` expõe ao renderer um conjunto seguro de funções (`window.brai.dispatch`, `window.trees.*`, `window.scenarios.*`) que viram chamadas IPC.
- Toda a lógica de simulação (mock + aplicação de intenção + IA dos monstros + JSON) é **Lua**, em `lua/src/sim/`. O JavaScript é só transporte e desenho.

Os detalhes do protocolo `SIM_DISPATCH` e do mock estão em [guia-simulador.md](guia-simulador.md) e [desenvolvimento.md](desenvolvimento.md).
