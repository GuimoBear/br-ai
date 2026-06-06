# BR-AI — Controle de Homúnculos do Ragnarok Online com Árvores de Comportamento

Documento de design / arquitetura. **v2** — revisado após análise do código-fonte do AzzyAI 1.56 (referência original; não incluída neste repositório).

Alvo: **Lua 5.0 com extensões 5.1** (é o que o AzzyAI assume — usa `string.gfind`, que é 5.0, e faz *feature detection* de `_VERSION=="Lua 5.1"` para APIs novas).
Norte de longo prazo: **paridade ampla de funcionalidades com o AzzyAI 1.56**, porém construída sobre uma **árvore de comportamento** em vez da máquina de estados hierárquica original.

> Esta versão substitui a v1: a seção de API agora é baseada nas **assinaturas reais** extraídas de `AzzyUtil.lua` / `Const_.lua` / `AI_main.lua`, não em suposições.

---

## 1. Objetivo e princípios

O cliente do RO carrega `AI.lua` (homúnculo) que faz `dofile` de todos os módulos e define a função global `AI(myid)`, chamada a cada ciclo de IA. Nosso código só pode: **perceber** via `GetV`/`GetActors`/`GetMsg`, **decidir**, e **agir** via `Move`/`Attack`/`SkillObject`/`SkillGround`. Não há laço próprio — somos reinvocados e precisamos ser rápidos e sem bloqueio.

Princípios:

- **Decisão declarativa.** O AzzyAI é uma *máquina de estados hierárquica* (HSM) com ~20 estados e transições espalhadas por assignment direto de `MyState`. Vamos trocar isso por uma árvore reavaliada a cada tick, onde prioridade é a ordem dos filhos de um Selector.
- **Percepção centralizada por tick.** O AzzyAI já faz isso (fase de *info gathering* da `AI()`, linhas ~3288–3421, que classifica `GetActors()` em `Monsters/Players/Targets/Summons/...`). Mantemos a ideia num *blackboard*.
- **Ações são assíncronas e a detecção de conclusão é heurística.** Este é o ponto mais delicado e onde mora a maior parte da complexidade do AzzyAI (o *skill-fail watcher*, ~110 linhas, infere sucesso/falha de cast por *delay* de `AI()`, `V_MOTION==MOTION_CASTING` e queda de SP). Vamos **encapsular essa lógica intacta** numa camada de ação — não reinventar.
- **Dados separados de lógica.** O AzzyAI separa `H_Config` (opções), `H_Tactics` (`MyTact[id]`), `H_SkillList` (IDs + `SkillInfo[]`), `Const_` (constantes). Preservamos exatamente esse modelo — a árvore consome esses dados.
- **Reaproveitar os helpers de baixo nível do AzzyAI.** `Closest`, `GetStandPoint`, `AdjustStandPoint`, `AttackRange`, `GetMobCount`, `DoSkill`, família `GetDistance*` são código maduro e dependente de quirks do servidor. A reescrita é da **camada de decisão**, não desses utilitários.

---

## 2. A API real do cliente (confirmada no código-fonte)

### 2.1 Ponto de entrada e ciclo

`AI(myid)` (em `AI_main.lua`, ~linha 3163) executa, em ordem, a cada tick:

1. **Proteção/identidade** — guarda `MyID`, detecta dupla-chamada e ciclos perdidos; atualiza histórico de 10 posições do inimigo (previsão de movimento).
2. **Bookkeeping** — valida timeouts contra `GetTick()` bugado, recalcula custo de buffs, zera contadores do tick.
3. **Info gathering** — lê posição/owner/inimigo; atualiza *ring buffers* de 10 ciclos (`MyPosX/Y`, `OwnerPosX/Y`, `EnemyPosX/Y`, `MyMotions`, `MyStates`); itera `GetActors()` para `Monsters/Players/Targets/Summons/Retainers` e monta `TakenCells` (células ocupadas).
4. **Emergências** — *skill-fail watcher*; atualização do tick de regen de SP; se distância do owner > bounds, força `FOLLOW_ST`.
5. **Comandos** — desenfileira `ResCmdList` e despacha por `ProcessCommand()`.
6. **Dispatch de estado** — `if MyState == IDLE_ST then OnIDLE_ST() elseif ...` (~linhas 3849–3892), com *gate* de `LagReduction` antes.

Callbacks de extensão expostos em `Stubs.lua`: `OnInit`, `OnAIstart`, `OnAImiddle`, `OnAIEnd`, `OnIdleTasks`, `OnAttackStart`, `OnChaseStart`, `OnAutoBuffs(buffmode)`, `DoSkillHandleMode(...)`, `OnFailUnknownMode(mode)`, e `NewState(state)`. **Esses hooks são o ponto de entrada oficial para plugar comportamento custom sem editar o core** — provavelmente o vetor de integração mais limpo para a nossa BT (ver §9, estratégia de migração).

### 2.2 Funções nativas do cliente (assinaturas reais)

| Função | Assinatura | Retorno |
|---|---|---|
| `GetV(V_x, id [,skill,level])` | índice + ator (+ skill/level p/ alguns) | número, `{x,y}`, ou `-1` p/ posição inválida |
| `GetActors()` | — | lista iterável de IDs visíveis |
| `GetTick()` | — | ms inteiros desde o boot |
| `GetMsg(myid)` | — | `{cmd, arg1, arg2, ...}` |
| `GetResMsg(myid)` | — | `{cmd, ...}` (comando reservado/fila) |
| `IsMonster(id)` | id | `1` monstro / `0` player-NPC |
| `Move(myid, x, y)` | — | efeito colateral |
| `Attack(myid, target)` | — | efeito colateral |
| `SkillObject(myid, level, skill, target)` | — | skill single-target |
| `SkillGround(myid, level, skill, x, y)` | — | skill em chão/AoE |
| `TraceAI(msg)` | string | log |

> `GetDistance(...)` **não é nativa** — é helper Lua interno (ver §2.5).

### 2.3 Constantes `V_*` (índices de `GetV`)

`V_OWNER`(0)→id do dono · `V_POSITION`(1)→`{x,y}` · `V_TYPE`(2) · `V_MOTION`(3)→`MOTION_*` · `V_ATTACKRANGE`(4) · `V_TARGET`(5)→id do alvo do ator (0=nenhum) · `V_SKILLATTACKRANGE`(6) · `V_HOMUNTYPE`(7) · `V_HP`(8) · `V_SP`(9) · `V_MAXHP`(10) · `V_MAXSP`(11) · `V_MERTYPE`(12) · `V_POSITION_APPLY_SKILLATTACKRANGE`(13, só 5.1) · `V_SKILLATTACKRANGE_LEVEL`(14, só 5.1).

> Em Lua 5.1 o alcance de skill é por nível (`V_SKILLATTACKRANGE_LEVEL`, com `skill,level`); em 5.0 há *fallback* para `V_SKILLATTACKRANGE`. **Sempre checar `x==-1`** antes de usar coordenadas.

### 2.4 Comandos e motions

**Comandos** (1º elemento de `GetMsg`): `NONE_CMD`(0) · `MOVE_CMD`(1,`x,y`) · `STOP_CMD`(2) · `ATTACK_OBJECT_CMD`(3,`target`) · `ATTACK_AREA_CMD`(4,`x,y`) · `PATROL_CMD`(5,`x,y`) · `HOLD_CMD`(6) · `SKILL_OBJECT_CMD`(7,`skill,level,target`) · `SKILL_AREA_CMD`(8,`skill,level,x,y`) · `FOLLOW_CMD`(9).

**Motions** (`V_MOTION`): `MOTION_STAND`(0) · `MOTION_MOVE`(1) · `MOTION_ATTACK`(2) · `MOTION_DEAD`(3) · `MOTION_DAMAGE`(4) · `MOTION_BENDDOWN`(5) · `MOTION_SIT`(6) · `MOTION_SKILL`(7) · `MOTION_CASTING`(8) · `MOTION_ATTACK2`(9) … (e vários de classes especiais). Os que importam para nós: `STAND/MOVE/ATTACK/DEAD/SIT/CASTING`.

### 2.5 Helpers internos críticos (em `AzzyUtil.lua`)

- `AttackRange(myid, skill, level)` → alcance em células (ataque normal se `skill==0`, senão `SkillInfo`/`V_SKILLATTACKRANGE_LEVEL`).
- `Closer(id, ox, oy)` → célula 1 passo na direção de `(ox,oy)`.
- `Closest(myid, ox, oy, range, alt)` → melhor célula a `range` células do alvo (trig p/ ranged; adjacência p/ melee; `alt` = CW/CCW/oposto).
- `GetStandPoint(myid, target, skill, level, alt)` → posição ideal p/ usar a skill; tenta `V_POSITION_APPLY_SKILLATTACKRANGE` e cai para `Closest`+`AdjustStandPoint`.
- `AdjustStandPoint(...)` → evita `TakenCells` e respeita bounds (até 7 tentativas).
- `DoSkill(skill, level, target, mode, targx, targy)` → escolhe `SkillObject`/`SkillGround` por `SkillInfo[skill][7]` (0=self,1=obj,2=ground), e **configura cooldown/timeout e o tracking p/ skill-fail**.
- `GetMobCount(skill, level, target [,aggro])` → contagem **ponderada** (usa `TACT_WEIGHT`) de monstros no AoE — base do `AutoMobCount`/AoE.
- Família de distância: `GetDistance(x1,y1,x2,y2)` euclidiana; `GetDistanceA(id1,id2)` (999 se inválido); `GetDistanceAPR(id,x,y)` **Chebyshev** (grid do RO); `GetDistanceRect(id1,id2)` Chebyshev entre atores.

### 2.6 `SkillInfo[]` — metadados de skill (em `H_SkillList.lua`)

`SkillInfo[id] = { nome, range[], spCost[], fixedCast[], varCast[], delay[], targetMode, duration[], reuseDelay[] }` — todos os campos exceto `targetMode`(7) e `nome`(1) são **arrays por nível**. Acesso via `GetSkillInfo(skill, campo, level)`. Custo de SP = campo 3; alcance = 2; cooldown = 9; `targetMode` = 7 (0 self / 1 objeto / 2 chão).

---

## 3. A HSM do AzzyAI (o que vamos substituir)

Estados em `Const_.lua` (~365–385), estado atual na global **`MyState`** (sem getter/setter — assignment direto, com `return On<Estado>_ST()` para transição imediata no mesmo tick). Há *ring buffer* `MyStates[1..10]` usado para **detectar loops** (ex.: CHASE→ATTACK→CHASE sem progresso ⇒ marca alvo `Unreachable`).

| Estado | Handler | Papel |
|---|---|---|
| `IDLE_ST` | `OnIDLE_ST` | Hub: idle-tasks (buff/heal) → seleciona alvo (friend-targets, depois aggro por HP/SP, depois tank) → follow/idlewalk/rest |
| `FOLLOW_ST` | `OnFOLLOW_ST` | Volta para o owner; reage a ataque → CHASE |
| `CHASE_ST` | `OnCHASE_ST` | Persegue; usa skill em chase se em range; detecta KS/out-of-sight/unreachable; → ATTACK |
| `ATTACK_ST` | `OnATTACK_ST` | Ataca; snipe; seleciona skill vs ataque normal; timeouts → FOLLOW/CHASE/IDLE |
| `MOVE_CMD_ST` | `OnMOVE_CMD_ST` | Comando de mover; reage a ataque → CHASE |
| `TANKCHASE_ST`/`TANK_ST` | … | Perseguir/segurar alvo de tank |
| `PROVOKE_ST` | `OnPROVOKE_ST` | Buffs/reações ASAP; retorna a `MyPState` |
| `IDLEWALK_ST` | `OnIDLEWALK_ST` | Passeio ocioso (gated por HP/SP) |
| `REST_ST` | … | Owner sentado |
| `*_CMD_ST` | … | `SKILL_OBJECT`/`SKILL_AREA`/`PATROL`/`FOLLOW`/`FRIEND_*` |

**Seleção de alvo** (`SelectEnemy(enemys, curenemy)` + `GetEnemyList(myid, aggro)` + `convpriority(base, agr)`): `GetEnemyList` filtra candidatos por tática (vs nível de aggro), proteção de KS (`IsNotKS`) e alcance (depende de `aggro`: bounds / `AggroDist` / range de skill p/ snipe). `convpriority` converte `TACT_BASIC` em prioridade numérica (ATTACK_TOP=15 no topo; ATTACK_LAST=0), com reação elevada quando o monstro está atacando/castando. `SelectEnemy` escolhe maior prioridade, desempatando por menor distância, ignorando `Unreachable[]`. **Isto é exatamente um Selector com função de pontuação** — mapeia direto para BT.

---

## 4. Por que árvore de comportamento (e os tipos de nó)

A "Monster priority list" do manual e a `convpriority` já são um Selector de prioridade. A vantagem da BT sobre a HSM atual:

- **Prioridade reavaliada a cada tick, sem transições manuais.** Hoje, esquecer um `MyState = X` causa estados presos (o changelog tem vários bugs assim: "homun travado em move state", loops de ASAP, etc.). Numa BT, a raiz reavalia tudo todo tick; "sair" de um comportamento é só outro ramo passar a ter sucesso.
- **Composição/reuso.** O subtree "usar skill de ataque" aparece em CHASE e ATTACK no AzzyAI (código duplicado ~795–877 e ~1085–1205). Na BT é um nó referenciado uma vez.
- **Extensão barata rumo à paridade.** Kiting, rescue, sniping, buffs viram ramos adicionais.

**Status de nó:** `SUCCESS`, `FAILURE`, `RUNNING`.

- **Composites:** `Selector` (prioridade), `Sequence` (AND), `Parallel` (fase avançada — "manter buff enquanto ataca"). Versões **com memória** retomam o filho que estava `RUNNING`.
- **Decorators:** `Inverter`, `Succeeder`, `Condition`, `Cooldown` (mapeia `AutoSkillDelay`/`AutoSkillCooldown[]`/recast de buff), `Limiter` (mapeia `TACT_SKILL`/`AutoSkillLimit`), `RunningUntil`.
- **Leaves de condição:** `HasTarget`, `OwnerUnderAttack`, `HpBelow(%)`, `SpAbove(%)`, `InRange(target, range)`, `MobCount>=n`, `OwnerSitting`, `TooFarFromOwner`.
- **Leaves de ação:** `MoveToOwner`, `ChaseTarget`, `AttackTarget`, `UseSkill`, `Kite`, `IdleWalk`, `Rest`, `HandleCommand`. Retornam `RUNNING` enquanto o cliente executa.

---

## 5. Arquitetura em camadas

```
AI(myid)  — loop do cliente (1 chamada/ciclo)
   │ atualiza
   ▼
Blackboard / Percepção   ← (espelha o "info gathering" da AzzyAI)
   • self{hp,sp,pos,type,motion}, owner{pos,hp,target}
   • monsters[], targets[], attackers_of_owner[], takenCells, current_target
   • comandos (GetMsg/GetResMsg → fila), flags de contexto (berserk, standby)
   • ring buffers de 10 ciclos (posições/motions) p/ predição e anti-poslag
   • timers/cooldowns persistentes entre ticks
   │ passado como contexto
   ▼
Árvore de Comportamento (decisão PURA — sem efeitos)
   • lê blackboard, emite UMA intenção
   │ intenção (ex.: UseSkill(s,t) | AttackTarget(t) | MoveToOwner)
   ▼
Camada de Ação (efeitos + a parte "suja")
   • Move/Attack/SkillObject/SkillGround
   • REAPROVEITA: Closest/GetStandPoint/AdjustStandPoint/AttackRange/DoSkill
   • skill-fail watcher, anti double-cast, lag-reduction gate
   ▼
Dados: H_Config · H_Tactics(MyTact[]) · H_SkillList(SkillInfo[]) · Const_
```

**Por que separar decisão de ação:** a decisão vira função pura do blackboard, **testável fora do jogo** (`tools/bt_test.lua` com blackboard falso). A camada de ação concentra o que depende de versão/servidor e é onde estão os bugs históricos — isolando a fragilidade.

---

## 6. Motor de BT — decisões específicas de RO

1. **Memória entre ticks.** `AI()` é reentrante; um nó de ação que pediu "mover até o alvo" precisa lembrar no próximo tick que está `RUNNING`. Cada nó com estado guarda status no blackboard por id estável; Selector/Sequence com memória retomam o filho `RUNNING`.
2. **Detecção de conclusão de ação = encapsular o skill-fail watcher.** Não há callback de "skill concluída". Portamos a heurística do AzzyAI (delay de `AI()` ≥ ~50ms p/ instacast; `MOTION_CASTING` + timeout p/ cast longo; queda de SP como confirmação) para dentro de `actions.lua`, como uma mini-FSM por ação (enviado → aguardando → ok/falhou). A árvore só vê `RUNNING/SUCCESS/FAILURE`. Mantemos `SkillFailCount[mode]`/`SkillRetryLimit[mode]`.
3. **Anti double-cast / delays.** `AutoSkillDelay`, `SpawnDelay`, `AutoSkillCooldown[skill]` → decorators `Cooldown` na camada de ação.
4. **Lag reduction.** `LagReduction>=1` (segura comandos por N ciclos) = *gate* na camada de ação que pode adiar a emissão mesmo com a árvore decidida.
5. **Anti-loop / unreachable.** Reproduzir a heurística de `MyStates[]`: se a árvore alterna perseguir/atacar o mesmo alvo sem reduzir distância por N ticks, marca `Unreachable[target]` (decorator de "circuit breaker" no ramo de combate).
6. **Custo O(n).** Percepção varre todos os atores por tick; cachear e limitar logging (o changelog registra crashes por volume em mapas cheios).

---

## 7. Árvore proposta (raiz do homúnculo)

```
Selector (raiz)
├── Sequence — Comando explícito pendente
│     ├── Cond: HasOwnerCommand            (GetMsg/ResCmdList ≠ NONE)
│     └── HandleOwnerCommand               (move/attack/skill/standby/sit; seta berserk se UseBerserk*)
│
├── Sequence — Sobrevivência
│     ├── Cond: HpBelow(FleeHP) AND BeingAttacked
│     └── Selector: [ UseDefensiveBuff, Kite/Flee, MoveToOwner ]
│
├── Sequence — Resgate (filtra por TACT_RESCUE do agressor)
│     ├── Cond: OwnerOrFriendUnderAttack
│     └── EngageRescueTarget
│
├── Sequence — Reação a cast (TACT_CAST: CAST_REACT_*)
│     ├── Cond: EnemyCastingOnUsOrOwner
│     └── ReactToCast                      (skill/debuff/breeze conforme tática)
│
├── Sequence — Combate (já engajado)
│     ├── Cond: HasValidTarget (não Unreachable, em vista, vivo)
│     └── Selector:
│           ├── Sequence: [ ShouldKite(target), KiteStep ]            (TACT_KITE)
│           ├── Sequence: [ PickAttackSkill, EnoughSP(TACT_SP), InSkillRange, UseSkill ]
│           │        └─ PickAttackSkill respeita TACT_SKILLCLASS, TACT_SKILL(limite), AutoMobCount+GetMobCount
│           ├── Sequence: [ InMeleeRange, AttackTarget ]              (se UseSkillOnly≠1)
│           └── ChaseTarget                                          (TACT_CHASE / DoNotChase)
│
├── Sequence — Aquisição de alvo
│     ├── Cond: HpAbove(AggroHP) AND SpAbove(AggroSP) AND NOT SuperPassive AND NOT Standby
│     ├── SelectTargetByPriority           (porta de convpriority: friend-targets → aggro → tank; TACT_KS, TACT_WEIGHT)
│     └── (alvo setado ⇒ próximo tick cai no ramo Combate)
│
├── Sequence — Buffs / manutenção
│     ├── Cond: ShouldBuffNow(buffmode)    (buffmode -2..3 por skill)
│     └── Selector: [ UseSelfBuff(off/def), BuffOwner(painkiller/blessing/kyrie/...), AutoHeal ]
│
└── Selector — Ocioso
      ├── Sequence: [ OwnerSitting, RestNearOwner ]
      ├── Sequence: [ TooFarFromOwner(MoveBounds), MoveToOwner ]
      ├── Sequence: [ UseIdleWalk>0 AND SpAbove(IdleWalkSP), IdleWalk(pattern/route) ]
      └── FollowStayBack
```

Notas:
- **Berserk** e **Standby** são *flags de contexto* no blackboard (não ramos): berserk afeta condições (ignora `AttackSkillReserveSP`, força skill, dança); standby poda aquisição/idle agressivo. Espelha `BerserkMode` e o tratamento de standby do AzzyAI.
- Os subtrees `UseSkill`/`AttackTarget`/`ChaseTarget` são **definidos uma vez** e referenciados nos ramos de Combate e Aquisição.
- O ramo **Buffs** consome o esquema de `buffmode` do AzzyAI (-2 idle-se-nada, -1 chase, 0 off, 1 idle, 2 berserk, 3 ASAP).

---

## 8. Sistema de Tactics — tupla real e mapeamento

Confirmado em `H_Tactics.lua`: `MyTact[id]` é uma tupla de **13 campos**, nesta ordem exata:

```
{ TACT_BASIC, TACT_SKILL, TACT_KITE, TACT_CAST, TACT_PUSHBACK,
  TACT_DEBUFF, TACT_SKILLCLASS, TACT_RESCUE, TACT_SP, TACT_SNIPE,
  TACT_KS, TACT_WEIGHT, TACT_CHASE }
```

Exemplos reais:
`MyTact[0] = {TACT_ATTACK_H, SKILL_ALWAYS, KITE_NEVER, CAST_REACT, PUSH_NEVER, DEBUFF_NEVER, CLASS_BOTH, RESCUE_NEVER, -1, SNIPE_DISABLE, KS_ALWAYS, 1, CHASE_ALWAYS}` (default).
`MyTact[1189] = {TACT_REACT_H, SKILL_ALWAYS, ... , 2, CHASE_ALWAYS}` (Orc Archer — peso 2). Entradas especiais: `[0]` default, `[10]` summoned, `[11]` plants (merc).

| # | Campo | Onde entra na BT |
|---|---|---|
| 1 | `TACT_BASIC` | `SelectTargetByPriority` (via `convpriority`) |
| 2 | `TACT_SKILL` (NEVER/ALWAYS/n/negativo=nível) | decorator `Limiter` no subtree de skill + nível |
| 3 | `TACT_KITE` | condição `ShouldKite` |
| 4 | `TACT_CAST` (CAST_REACT_*) | ramo "Reação a cast" |
| 5 | `TACT_PUSHBACK` | ramo de pushback (merc) |
| 6 | `TACT_DEBUFF` (incl. `DEBUFF_ASH_*`) | subtree de debuff |
| 7 | `TACT_SKILLCLASS` (CLASS_*) | seleção de qual skill em `PickAttackSkill` |
| 8 | `TACT_RESCUE` (RESCUE_*) | filtro do ramo Resgate |
| 9 | `TACT_SP` | override de `AttackSkillReserveSP` em `EnoughSP` |
| 10 | `TACT_SNIPE` | habilita/poda subtree de sniping |
| 11 | `TACT_KS` (NEVER/POLITE/ALWAYS) | filtro em `SelectTargetByPriority` |
| 12 | `TACT_WEIGHT` | peso em `GetMobCount`/contagem de mob |
| 13 | `TACT_CHASE` (CHASE_*) | condição no nó `ChaseTarget` |

Mantemos o **formato de arquivo idêntico** ao AzzyAI, para reaproveitar as tabelas existentes (incl. `Mob_ID.lua`, PVP tactics) e a familiaridade do usuário.

---

## 9. Estratégia de integração e migração

Há duas formas de plugar a BT no AzzyAI, e elas definem o risco do projeto:

**Opção A — Substituição total da `AI()`.** Reescrever o loop e todos os `On*_ST`. Máximo controle, máximo risco; perde-se o valor maduro dos handlers de comando, friending, PVP, etc.

**Opção B (recomendada) — BT por cima dos hooks de `Stubs.lua`, substituindo a HSM incrementalmente.** O AzzyAI já expõe `OnAIstart`, `OnIdleTasks` (retornar 1 *pula* o resto de `OnIDLE_ST`), `OnAttackStart`, `OnChaseStart`, `OnAutoBuffs`, `NewState`. Podemos:

1. Construir o motor de BT + blackboard como módulos novos, **sem tocar no core**.
2. Começar a BT governando só o estado **IDLE** (via `OnIdleTasks` retornando 1 quando a BT assume), reusando `SelectEnemy`/`DoSkill`/`Closest` existentes como folhas de ação.
3. Migrar ramo a ramo (combate, depois aquisição, depois buffs), trocando cada `On*_ST` por um subtree, validando paridade em jogo a cada passo.
4. Quando a árvore cobrir tudo, a `AI()` vira um shell fino: percepção → `tree:tick(bb)` → ação.

Isso transforma um *rewrite* arriscado numa **refatoração incremental verificável** — cada fase roda no jogo e é comparável ao comportamento original.

---

## 10. Ferramentas gráficas: simulador/depurador + editor de árvores

Duas ferramentas desktop (uma só aplicação Electron, dois modos) para acelerar o desenvolvimento sem depender do cliente do RO a cada iteração: um **simulador/depurador** que roda a IA contra um mundo falso e visualiza tudo, e um **editor visual de árvores**. Stack: **Electron + JavaScript/Node** (conforme sua preferência).

### 10.1 O princípio que torna isso possível: "mesma BT, cliente trocável"

A arquitetura da §5 já separa **decisão (Lua puro)** de **API do cliente**. Isso é o que viabiliza o simulador: a *mesma* árvore em Lua roda em dois ambientes, mudando apenas quem implementa `GetV`/`GetActors`/`Move`/`Attack`/`SkillObject`/`GetTick`:

```
                ┌─────────────────────────┐
                │   BT em Lua (idêntica)  │   src/bt + src/core + behaviors
                └───────────┬─────────────┘
        ┌───────────────────┴───────────────────┐
        ▼                                        ▼
  Cliente REAL do RO                      Cliente MOCK (JS)
  (GetV/Move/... nativos)         (GetV/Move/... implementados no simulador)
        ▼                                        ▼
   jogo de verdade                    grid + sprites + debug visual
```

Consequência de design: **nenhum módulo da BT pode chamar a API nativa diretamente** — tudo passa por uma interface fina (`core/ro_api.lua`) que no jogo aponta para as globais nativas e no simulador aponta para o mock. Isso já estava implícito; aqui vira regra dura.

### 10.2 Rodando Lua dentro do Electron

Para o simulador executar a BT real (e não uma reimplementação em JS, que divergiria), embutimos um interpretador Lua no processo Node/Electron:

- **Recomendado: [Fengari](https://fengari.io/)** — Lua puro em JavaScript, interop Lua↔JS excelente (expor o mock como funções JS é trivial). Roda no renderer e no main process.
- Alternativa: **wasmoon** (Lua via WASM, mais rápido) — bom se performance virar gargalo em cenários grandes.

**Tensão importante (Lua 5.0 vs VM moderna):** Fengari/wasmoon são Lua 5.3/5.4; o cliente do RO é 5.0. Mitigações, já alinhadas com a regra "evitar 5.0-only no código novo" (§12):
1. **A BT em si é escrita em subconjunto portável** (sem `string.gfind`, sem `setfenv` dependente de versão) — roda igual em 5.0 e na VM.
2. Os **helpers do AzzyAI que dependem de 5.0** (ex.: parsing com `string.gfind`) **não entram no simulador**; suas funções equivalentes (`Closest`, `GetStandPoint`, `GetMobCount`, distâncias) são reescritas de forma portável em `compat/azzy_shims.lua` (que precisamos portar de qualquer modo na Opção B). O simulador usa esses shims; o jogo pode usar shims ou os originais.
3. Um pequeno *teste de conformidade* compara a saída dos shims portáveis com os originais do AzzyAI rodados num Lua 5.0 standalone, garantindo que não divergiram.

> Em outras palavras: o simulador testa **lógica de árvore e de decisão** com altíssima fidelidade. Comportamentos que dependem de quirks do servidor real (poslag, alocação de IDs, timing fino de cast) continuam exigindo validação final no jogo — o simulador reduz, mas não elimina, esse passo.

### 10.3 O mock do cliente RO (em JS)

`sim/ro_mock.js` implementa a superfície da §2 sobre o estado do mundo simulado:

- **Sensores:** `GetV(V_*, id [,skill,lvl])` lê do estado (posição, HP/SP, motion, target, homuntype…); `GetActors()` devolve os IDs no mundo; `GetTick()` é um **relógio determinístico** controlado pelo simulador (essencial para reprodutibilidade e para testar timeouts/cooldowns).
- **Atuadores:** `Move/Attack/SkillObject/SkillGround` **não** têm efeito imediato — enfileiram intenções que o motor do mundo resolve no próximo passo, **reproduzindo a assincronicidade do jogo** (movimento célula a célula, cast time, delays). É isso que permite depurar de verdade o skill-fail watcher.
- **Comandos:** `GetMsg/GetResMsg` alimentados pela UI (você clica "atacar este monstro", "mover aqui", "standby").
- **Modelo de mundo:** grid retangular com obstáculos/células ocupadas, atores `{owner, homun, monsters[], players[]}` com IA simples para os monstros (aggro/perseguir/atacar/casting), HP/SP, e skills resolvidas via `SkillInfo[]` (mesmos dados do jogo).

### 10.4 Simulador / depurador (modo 1)

Tela dividida:

- **Mapa (canvas grid):** dono, homúnculo, monstros como sprites; alcances, AoE, `TakenCells`, linhas de "quem mira em quem". Ferramentas para **pintar o cenário**: colocar/remover monstros (com ID → puxa `MyTact`), mover o dono, desenhar obstáculos.
- **Controles de tempo:** *step* (1 tick), *play/pause*, velocidade (0.25×–8×), e **timeline com replay** — grava o histórico de estado por tick para você voltar e inspecionar.
- **Painel da árvore (depuração viva):** a árvore renderizada com cada nó colorido pelo status do último tick — verde `SUCCESS`, vermelho `FAILURE`, azul `RUNNING`, cinza não-avaliado. Mostra **o caminho ativo** e por que a raiz escolheu o ramo X. Este é o maior ganho de produtividade do projeto.
- **Inspetor de blackboard:** todas as variáveis (alvo atual, HP/SP, timers, flags berserk/standby, listas de atores) ao vivo, com diff entre ticks.
- **Console de log:** captura de `TraceAI` redirecionada para a UI.
- **Cenários:** salvar/carregar mundos `.json` (mapa + atores + comandos roteirizados) como **casos de teste** — viram regressão automatizável (ver §10.7) e reproduzem bugs específicos.

### 10.5 Editor de árvores (modo 2)

- **Node-graph** (recomendo [Rete.js](https://rete.js.org/) ou React Flow): arraste nós de uma **paleta** (Selector, Sequence, Parallel, decorators, condições e ações registradas), conecte filhos, reordene prioridade visualmente.
- **Paleta dirigida por registro:** cada folha de condição/ação que existe na BT em Lua é registrada com nome, descrição e **schema de parâmetros**; o editor lê esse registro para oferecer só nós válidos e validar parâmetros (ex.: `HpBelow(%)` exige número 0–100). Evita árvores que referenciam nós inexistentes.
- **Parâmetros vindos dos dados reais:** dropdowns populados de `H_SkillList` (skills), `Const_` (constantes de tática) e `H_Config` (opções) — você monta a árvore falando a linguagem do jogo.
- **Validação:** ciclos, nós órfãos, filhos faltando, tipos de parâmetro; avisos de "ramo inalcançável".
- **Ponte com o simulador:** botão "Simular esta árvore" carrega a árvore editada direto no modo 1, sem exportar manualmente.

### 10.7 Formato compartilhado da árvore (o contrato)

O ponto de integração entre editor, simulador e jogo. **Fonte da verdade = JSON**, porque é trivial para a UI ler/escrever:

```jsonc
// tree_homun.json (exemplo abreviado)
{ "type": "selector", "id": "root", "children": [
  { "type": "sequence", "children": [
      { "type": "condition", "name": "HasOwnerCommand" },
      { "type": "action", "name": "HandleOwnerCommand" } ] },
  { "type": "sequence", "children": [
      { "type": "condition", "name": "HpBelow", "params": { "pct": 30 } },
      { "type": "action", "name": "Kite" } ] }
] }
```

Como o JSON vira árvore executável nos dois lados:

- **No simulador (JS/Lua via Fengari):** carrega o JSON e instancia a árvore chamando as folhas registradas. Imediato, sem build.
- **No jogo (Lua 5.0, sem parser JSON nativo):** um passo de **codegen** (`tools/build_tree.js`) converte `tree_homun.json` → `tree_homun.lua` (tabela Lua literal que o `dofile` carrega). Evita embarcar parser JSON e custo de parsing em runtime no cliente.

Assim: você edita no graph → salva JSON → simula na hora → roda `build_tree` → joga no cliente. O **registro de nós** (nome→implementação Lua + schema) é a única fonte que os três compartilham, garantindo que editor, simulador e jogo concordem sobre o que cada nó significa.

---

## 11. Estrutura de arquivos proposta (monorepo)

```
br-ai/
├── lua/                         -- tudo que roda no cliente do RO (Lua 5.0)
│   ├── AI.lua                   -- entrada: dofile dos módulos + define AI(myid) (shell fino)
│   ├── src/
│   │   ├── bt/                  -- node, composites, decorators, tree (builder + loader)
│   │   ├── core/
│   │   │   ├── ro_api.lua       -- INTERFACE: no jogo → globais nativas; no sim → mock
│   │   │   ├── blackboard.lua   -- percepção/tick + estado persistente + ring buffers
│   │   │   ├── perception.lua   -- GetActors/GetV → monsters/targets/attackers/takenCells
│   │   │   ├── actions.lua      -- Move/Attack/Skill + skill-fail watcher + lag gate
│   │   │   └── targeting.lua    -- SelectTargetByPriority/convpriority/GetMobCount (port)
│   │   ├── behaviors/           -- combat, survival, support, idle, commands
│   │   ├── registry.lua         -- nome → folha (condição/ação) + schema de params
│   │   └── tree_homun.lua       -- GERADO por build_tree.js a partir do JSON
│   ├── compat/azzy_shims.lua    -- Closest/GetStandPoint/DoSkill/AttackRange portáveis
│   └── data/                    -- H_Config / H_Tactics / H_SkillList / Const_ (formato AzzyAI)
├── desktop/                     -- aplicação Electron (JS/Node)
│   ├── main/                    -- processo principal Electron
│   ├── renderer/
│   │   ├── simulator/           -- canvas grid, controles de tempo, painel de árvore, inspetor
│   │   └── editor/              -- node-graph (Rete.js/React Flow), paleta, validação
│   ├── sim/
│   │   ├── ro_mock.js           -- implementa GetV/GetActors/Move/... sobre o mundo
│   │   ├── world.js             -- estado do mundo, resolução de movimento/cast/dano
│   │   └── lua_host.js          -- embute Fengari, carrega a BT Lua, expõe o mock
│   └── shared/tree_schema.json  -- schema do formato de árvore (§10.7)
├── tools/
│   ├── build_tree.js            -- tree_homun.json → tree_homun.lua (codegen)
│   ├── bt_test.lua              -- harness offline mínimo (CI sem UI)
│   └── shim_conformance.lua     -- compara shims portáveis vs originais 5.0
├── scenarios/                   -- casos de teste .json (mundos + comandos roteirizados)
├── reference/azzyai/            -- AzzyAI 1.56 original (referência externa, não versionada)
└── DESIGN.md
```

---

## 12. Roadmap por fases

Duas trilhas que se reforçam: o **motor/IA (Lua)** e a **toolchain gráfica (Electron)**. A toolchain entra cedo de propósito — depurar a árvore visualmente acelera todas as fases seguintes.

**Trilha IA (Lua)**

- **Fase 0 — Andaime + prova de vida.** `AI.lua` mínimo + `ro_api.lua` (interface), monta blackboard e faz só `MoveToOwner`. *Critério: segue o dono no jogo.*
- **Fase 1 — Motor de BT + percepção.** `node/composites/decorators` + `registry.lua` + blackboard completo, com `bt_test.lua` (CI). *Critério: testes da árvore passam offline.*
- **Fase 2 — Combate básico (MVP) via hook IDLE.** Aquisição + perseguir + atacar normal + 1 skill, reusando `SelectEnemy`/`DoSkill`/`Closest` via shims portáveis. *Critério: mata monstro e volta ao dono.*
- **Fase 3 — Tactics completas.** `MyTact[]` parametrizando prioridade, KS, chase, limite/nível de skill, peso.
- **Fase 4 — Sobrevivência e suporte.** Flee/kite, rescue, reação a cast, buffs self/owner, heal, painkiller, berserk/standby como contexto.
- **Fase 5 — Avançado / paridade.** Sniping, AoE com `GetMobCount`, Homunculus S (skills por tipo/`OldHomunType`), idlewalk/route, sticky standby, lag reduction.
- **Fase 6 — Robustez + migração final.** Afinação do skill-fail watcher, logging configurável (espelho de `LogEnable`), obstáculos, e colapso da `AI()` para shell fino (fim da HSM).

**Trilha Ferramentas (Electron) — em paralelo**

- **Fase T0 — Host Lua + mock mínimo.** Electron embute Fengari (`lua_host.js`), carrega a BT da Fase 1 e roda contra um `ro_mock.js` mínimo num mundo estático. *Critério: a árvore tica no app e produz intenções.*
- **Fase T1 — Simulador visual.** Mapa em grid, sprites, controles de tempo (step/play), inspetor de blackboard, log de `TraceAI`. *Critério: dá pra ver o homún seguir/atacar no mundo falso.*
- **Fase T2 — Depuração viva da árvore.** Highlight de nós por status (RUNNING/SUCCESS/FAILURE) + timeline/replay + cenários `.json` como regressão.
- **Fase T3 — Editor de árvores.** Node-graph dirigido pelo `registry`, validação, parâmetros vindos de `H_SkillList`/`Const_`/`H_Config`, e `build_tree.js` (JSON→Lua) + botão "Simular".

Sincronização sugerida: T0 logo após a Fase 1; T1/T2 acompanham as Fases 2–3 (depurar combate visualmente); T3 quando a árvore estiver grande o bastante para a edição manual em JSON incomodar.

---

## 13. Decisões travadas e riscos

**Decisões travadas (nesta conversa):**

- **Lua 5.0** como alvo do código que roda no cliente (igual ao AzzyAI).
- **Sem suporte a servidores privados** — foco no servidor oficial, como o AzzyAI.
- **Integração Opção B** — BT incremental sobre os hooks de `Stubs.lua`, substituindo a HSM ramo a ramo.
- **Toolchain gráfica em Electron + JS/Node**, com a BT Lua rodando via Fengari sobre um mock do cliente.
- **Fonte da verdade da árvore = JSON**, com codegen para Lua (`build_tree.js`).

**Riscos e mitigações:**

- **Detecção de conclusão de ação** (skill-fail) é heurística e dependente de timing real — maior risco técnico. Mitigação: portar o watcher verbatim, isolá-lo em `actions.lua`, e exercitá-lo no simulador com cast times/delays modelados.
- **Lua 5.0 no cliente vs VM moderna no simulador.** A BT é escrita em subconjunto portável; shims do AzzyAI são reescritos portáveis em `azzy_shims.lua`; `shim_conformance.lua` compara contra os originais 5.0. Resíduo: quirks de servidor (poslag, IDs, timing fino) só validáveis no jogo.
- **Divergência simulador↔jogo.** O simulador é um modelo, não o servidor. Mitigação: manter o mock fiel à §2, e todo bug reproduzido no jogo vira um `scenario` de regressão.
- **Escopo merc.** Mesmo motor atende mercenário com outra árvore + dados `M_*`; fora do MVP, previsto na arquitetura.

---

## 14. Próximos passos sugeridos

1. Eu codo **Fase 0 + Fase 1** (andaime Lua: `AI.lua` shell, `ro_api.lua`, motor de BT, blackboard, `registry`, `bt_test.lua`).
2. Em seguida **Fase T0** (Electron + Fengari rodando a BT contra um mock mínimo) — para já termos onde depurar.
3. Validamos "segue o dono" no jogo e seguimos para o combate via hook IDLE (Fase 2), com o simulador acompanhando (Fases T1/T2).


---

## 15. Skills por homúnculo (Fase 5 — árvore adaptativa)

Implementado: a **mesma árvore** atende os 9 homúnculos; o que muda é o *perfil* de skills resolvido por `V_HOMUNTYPE`. Espelha o AzzyAI (uma IA; o comportamento varia pelo `SkillList` do tipo).

**Dados** (`lua/src/data/`): `skills.lua` porta `SkillInfo`/`SkillList`/`SkillAOEInfo` do `H_SkillList.lua` (ID, alcance, SP, cast, cooldown, modo de alvo, AoE). `profiles.lua` classifica as skills de cada tipo em papéis: `mainAtk`, `aoeAtk`, `offBuff[]`, `defBuff[]`, `heal`(+`healOwner`/`healSelf`), `ownerBuff`, `summon`, `combo[]`, `styleChange`, `debuffAoE`, `castling`.

**Sistema** (`lua/src/core/skillsys.lua`): alcance/SP/cooldown/duração, contagem de mobs no AoE (`mobCount`), timers de buff/recast (`buffActive`/`markUsed`) e emissão da intenção de skill. `skill_range.lua` calcula o **alcance efetivo** (melee ou alcance da skill) para a perseguição parar na distância certa (Caprice 9, Lava Slide 7…).

**Comportamentos** (`lua/src/behaviors/skills.lua`): `UseMainSkill`, `UseAoESkill` (gated por `AutoMobCount`), `UseOffensiveBuff`/`UseDefensiveBuff` (recast por expiração), `UseHealSelf`/`UseHealOwner`, `UseOwnerBuff` (Painkiller), `UseSummon`, `UseCastling`. Tudo dirigido por config (`UseAttackSkill`, `HealOwnerHP`, `AutoMobCount`, …) no blackboard.

**Árvore** (`tree_homun.json`): ordem de prioridade — comando › fuga › cura urgente › castling › painkiller no dono › combate (summon › AoE › skill single › ataque normal › perseguir) › aquisição › voltar ao dono › buffs ociosos › idle.

**Cobertura validada** (`tools/homun_test.lua`, 10/10): Vanilmirth→Caprice, Filir→Moonlight, Sera→Summon Legion, Eira→Erase Cutter / Xeno Slasher (mob), Dieter→Lava Slide (mob), Bayeri→Stahl Horn, Eleanor→Sonic Claw, Lif→cura o dono, Amistr→Castling com dono cercado.

**Long-tail (simplificações desta fase):** combos da Eleanor (Tinder→CBC→EQC e Sonic→Silvervein→Midnight) usam só o golpe principal por ora; Style Change, ciclo de vida da Legião, SBR44/Self Destruct e timing de cast (skill-fail watcher) ficam como refinamentos. Os 9 nós de skill entram automaticamente na paleta do editor (registry).


### 15.1 Tipo base do Homunculus S (OldHomunType)

O cliente informa a **forma evoluída** via `V_HOMUNTYPE` (ex.: Dieter), mas não a **forma base** de origem — e um Homunculus S mantém as skills da base. Espelha o `OldHomunType` do AzzyAI.

- Config `BaseHomunType` (no blackboard; `0` = N/A) define a base de um S.
- `profile_resolve.lua` → `BRAI.profileFor(bb)` devolve o **perfil efetivo** mesclando S + base: `mainAtk`/`aoeAtk` preferem o S e caem para a base; `offBuff`/`defBuff` concatenam; cura normaliza em `healOwnerSkill`/`healSelfSkill`. `skillsys.knownLevel` também consulta a lista de skills da base.
- Escolha: dropdown **base** no simulador (ativo só para tipos S); no cliente, viria de um arquivo de config.
- Validado (`tools/base_test.lua`, 5/5): Dieter base Vanilmirth usa Caprice em alvo único; Dieter base Amistr usa Castling; Sera base Vanilmirth cura a si (Chaotic); sem base, nada disso ocorre.
