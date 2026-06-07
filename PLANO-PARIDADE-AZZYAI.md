# Plano de paridade com a AzzyAI

Comparação entre a AzzyAI (`USER_AI/`, máquina de estados clássica) e a nossa
reimplementação em árvore de comportamento (`lua/src/`). O objetivo é trazer as
funções da AzzyAI que ainda faltam, **mantendo nossa arquitetura**: cada
comportamento vira nó(s) de BT (condição/ação/decorator) + campos de percepção +
config + suporte no simulador. Nada de máquina de estados — o que na AzzyAI é um
"estado" aqui vira um ramo da árvore.

Legenda de status: ✅ temos · 🟡 parcial · ❌ falta

---

## Já implementado (referência)

- ✅ Percepção: self, owner (incl. **HP% do dono** — recém-adicionado), monstros, alvo.
- ✅ Aquisição de alvo, perseguição (`ChaseTarget` com `dist`), ataque normal.
- ✅ Skills: `UseSkill` (alvo único + área), `UseSkillBuff`, heal self/owner, summon, castling, owner buff, buffs ofensivo/defensivo por perfil.
- ✅ Cooldown do jogo + intervalo customizado por nó (com reset ao trocar de alvo).
- ✅ Condições: HP/SP self, HP dono, sob ataque, alvo válido, no alcance, longe do dono, pode engajar, deve fugir.
- ✅ Fuga (`Flee`), seguir o dono (`MoveToOwner`), ocioso, comandos básicos do dono.
- ✅ Tipo base do Homunculus S (config `BaseHomunType`).

---

## Fase A — Combate essencial (maior impacto)

### A1. Proteção anti-Kill Steal (KS)
**AzzyAI:** `IsNotKS()` (AzzyUtil ~798), modos `KS_ALWAYS`/`KS_POLITE`/`KS_NEVER`, isenção de mobs em movimento e de amigos.
**Plano:**
- Percepção: para cada monstro, marcar `claimedBy` (quem ele mira / quem mira nele que não seja eu/dono).
- Condição `TargetIsFree` (params: `mode` = always/polite/never) usada antes de `AcquireTarget`.
- Config: `KSMode`.
- Simulador: já temos `target` por entidade; adicionar "dono" de um monstro é simples.

### A2. Seleção de skills durante a perseguição
**AzzyAI:** usa skills já no `CHASE_ST`, não só no ataque.
**Plano:** isso **já é natural** na nossa BT — basta posicionar os nós de skill no ramo de combate antes de `ChaseTarget` (a `UseSkill` checa alcance sozinha). Documentar o padrão; nenhum código novo. 🟡→✅ via árvore.

### A3. Resgate do dono (rescue)
**AzzyAI:** `IsRescueTarget()` (AzzyUtil ~219) — engaja quem ataca o dono, com prioridade.
**Plano:**
- Condição `OwnerUnderAttack` (já existe ✅) + nova ação `AcquireOwnerAttacker` (mira no monstro que ataca o dono).
- Config: `RescueOwner`, `RescueOwnerLowHP`.

### A4. Troca oportunista de alvo
**AzzyAI:** `OpportunisticTargeting` — troca para um alvo melhor no meio da perseguição.
**Plano:** ação `ReacquireIfBetter` (params: critério: mais próximo / menor HP), opcional no ramo de combate. Requer prioridade de alvo (ver A5).

### A5. Prioridade de alvo (Tactics)
**AzzyAI:** `convpriority()` (~2158), tabelas de táticas por mob.
**Plano:**
- `AcquireTarget` ganha param `by` = nearest | lowestHp | highestThreat.
- Estrutura de dados opcional de prioridade por tipo de mob (futuro).

---

## Fase B — Posicionamento e sobrevivência

### B1. Kiting
**AzzyAI:** `DoKiteAdjust()` (~3011) — afasta-se do inimigo mantendo-se perto do dono. Configs `KiteMonsters/KiteBounds/KiteStep/KiteParanoid`.
**Plano:** ação `Kite` (params: `bounds`, `step`) que emite intent de movimento para a célula que maximiza distância do alvo respeitando `MoveBounds` do dono. Condição auxiliar `ShouldKite`.

### B2. Dance attack (atacar movendo)
**AzzyAI:** reposiciona e ataca sem usar skill (`UseDanceAttack`, `DanceMinSP`).
**Plano:** ação `DanceAttack` — alterna passo + ataque. Útil para melee evitar dano parado.

### B3. Recuo escalonado ao seguir (follow panic)
**AzzyAI:** `FollowTryPanic` — tenta segurar posição, depois recua, depois desiste.
**Plano:** enriquecer `MoveToOwner`/adicionar `FollowOrPanic` com tentativas e marcação de inalcançável (já temos `persist.unreachable`).

### B4. Desistência de perseguição / inalcançável
**AzzyAI:** `ChaseGiveUpCount`, marca alvo inalcançável.
**Plano:** decorator `Limiter`/contador no `ChaseTarget`; ao estourar, `markUnreachable(target)`. Parte da infra já existe (`bb:markUnreachable`).

### B5. Pausa de perseguição por SP baixo
**AzzyAI:** `ChaseSPPause`.
**Plano:** condição `SpAbove` (já existe ✅) no ramo de perseguição — resolvível por árvore. Documentar.

---

## Fase C — Modos de combate

### C1. Berserk
**AzzyAI:** dispara com aggro alto; libera `Berserk_SkillAlways`, `Berserk_Dance`, ignora SP mínimo.
**Plano:** condição `Mobbed` (params: `count`) baseada em `GetAggroCount`; ramo "berserk" na árvore (usa skills sempre / dance). Flag `bb.flags.berserk` já existe — passar a setá-la.

### C2. Tank / TankChase
**AzzyAI:** agrega mais mobs até um limite.
**Plano:** ação `TauntExtraMobs` / condição `AggroCountBelow` (params: `limit`). Requer contagem de mobs no dono (`GetAggroCount` → novo helper de percepção).

### C3. Standby
**AzzyAI:** `DefendStandby`/`StickyStandby` — segura posição sem engajar.
**Plano:** flag `bb.flags.standby` já existe; adicionar condição `InStandby` e comando do dono para alternar.

---

## Fase D — Específicos de Homunculus S

### D1. Filtro de skills por classe / combos
**AzzyAI:** `CLASS_S/COMBO/MINION`, `AutoComboMode` (Tinder Breaker, Xeno Slasher, Eraser Cutter, Sonic Claw → Silvervein → Midnight Frenzy).
**Plano:** ação `UseCombo` (sequência de combo com janela de tempo) + metadados de combo em `skill_meta`. Média complexidade.

### D2. Style Change (Eleanor)
**AzzyAI:** alterna Power/Defense (`MH_STYLE_CHANGE`) conforme o combo desejado.
**Plano:** condição `StyleIs` + ação `SetStyle`. Requer rastrear o "modo" atual (novo campo de percepção, se disponível via GetV).

### D3. Detecção automática do tipo base
**AzzyAI:** varre `V_SKILLATTACKRANGE` para deduzir a forma base.
**Plano:** no `AI.lua` do cliente, auto-detectar e preencher `BaseHomunType` se não configurado. Só vale no jogo (no simulador escolhemos manualmente). Baixa prioridade.

---

## Fase E — Buffs, cura e suporte avançado

### E1. Canais de buff separados com timeout
**AzzyAI:** ofensivo/defensivo/dono com timeouts independentes; `buffmode`.
**Plano:** já temos `buffUntil` por skill. Adicionar ações `MaintainOwnerBuff` (Provoke/Bless/Agi) e config por canal.

### E2. Sacrifice / Devotion no dono
**Plano:** ação `UseSacrificeOwner` + timeout. Análogo ao owner buff atual.

### E3. Heal com reserva de SP e condição de mob
**AzzyAI:** `HealSelfHP`/`HealOwnerHP` + reserva de SP + `DefensiveBuffOwnerMobbed`.
**Plano:** `UseHealSelf`/`UseHealOwner` ganham checagem de reserva de SP; condição `OwnerMobbed`.

### E4. Lista de amigos / party / Painkiller friends
**AzzyAI:** `MyFriends[]` persistente, `GetFriendTargets`, Painkiller adiciona amigos.
**Plano:** maior esforço (persistência + I/O). Só faz sentido no jogo. Baixa prioridade para o simulador.

---

## Fase F — Ocioso e rotinas

### F1. Idle walk (rotas)
**AzzyAI:** `UseIdleWalk` 0–6 (circular, relativa, castelo).
**Plano:** ação `IdleWalk` (params: `pattern`, `radius`). Média prioridade (qualidade de vida).

### F2. Rest quando o dono senta
**Plano:** condição `OwnerSitting` (via `V_MOTION` do dono = sit) + ramo de descanso. Baixo esforço.

### F3. Bounds/Aggro dinâmicos (parado vs em movimento)
**AzzyAI:** `Stationary*` vs `Mobile*`.
**Plano:** percepção rastreia movimento do dono; `effectiveRange`/aquisição usam o valor dinâmico. Baixa prioridade.

---

## Comandos do dono (completar)
**AzzyAI:** MOVE, ATTACK_OBJECT, FOLLOW, HOLD, PATROL, SKILL_OBJECT, SKILL_AREA, STOP, sticky move.
**Nós:** já temos MOVE/ATTACK_OBJECT/FOLLOW. Faltam HOLD, STOP, SKILL_OBJECT, SKILL_AREA, sticky. Adicionar em `commands.lua` + percepção do comando.

---

## Ordem sugerida (custo × impacto)

1. **A1 (anti-KS)** e **A3 (resgate do dono)** — alto impacto em campo, custo médio.
2. **B1 (kiting)** e **C1 (berserk)** — diferenciais grandes de comportamento.
3. **A5 (prioridade de alvo)** + **A4 (oportunista)** — refinam o combate.
4. **E3/E1 (cura+buffs avançados)** e **D1 (combos S)** — profundidade por classe.
5. **F* (idle/rest/bounds)**, **comandos restantes**, **E4 (amigos)** — polimento.

Cada item entra com: nó(s) de BT + campos de percepção/config + **teste texlua** + suporte no simulador quando observável. Itens que só existem no cliente (D3, E4, alguns comandos) terão teste de unidade da decisão, não do efeito.

---

## Suporte de percepção a criar (transversal)
- `GetAggroCount(ownerId)` → nº de mobs mirando o dono (usado por C1/C2/E3).
- `claimedBy` por monstro (A1/A4).
- Movimento do dono (histórico curto) para bounds dinâmicos (F3).
- Modo atual do Eleanor, se exposto via GetV (D2).
