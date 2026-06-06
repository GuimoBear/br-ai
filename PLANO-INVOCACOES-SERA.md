# Plano de implementação — Invocações / Summon Legion (Sera, Homunculus S)

Migração das invocações da Sera da AzzyAI (`USER_AI/`) para a nossa árvore de
comportamento. Mesma filosofia do [`PLANO-COMBOS-ELEANOR.md`](PLANO-COMBOS-ELEANOR.md):
documento de trabalho, iteramos antes de codar. Companion do
[`PLANO-PARIDADE-AZZYAI.md`](PLANO-PARIDADE-AZZYAI.md).

> **Status: IMPLEMENTADO ✅ (6 fases)** — estimador de legião, nó `UseSeraLegion`
> (política `resummon` configurável), atores no simulador (spawn / IA própria /
> TTL / revide), visualização do enxame, editor (sub-painel na tela "Skills" +
> dist) e a árvore `Sera - Vanilmirth` + 6 cenários de demonstração/regressão.
> Testes: `tools/summon_{estimator,decision,sim,editor,scenarios}_test.lua` (85
> asserts de invocação; suíte global **370 ok, 0 falhas**) + smokes node
> `eleanor_viz`/`sera_viz` + `host_smoke`. Os bugs da AzzyAI da §7 têm guard de
> regressão verde. Números conferidos contra a AzzyAI 1.56 em `USER_AI/` e
> contra divine-pride / rAthena.

## Como este plano cobre os 7 pedidos

| Pedido | Onde no plano |
|---|---|
| 1. Skill de summon aparece na tela "Skills"; clicar carrega params da skill | §6 (editor: role `summon` + sub-painel de params por skill) |
| 2. Configurações de summon em algum lugar (AzzyAI dá o norte) | §1 (modelo), §3 + **§3.1 (campos documentados)**, §6 (`data/summons.lua` + params do nó) |
| 3. Invocações no simulador + visualização diferenciada (criativa) | §4 (atores no sim) + §5 (snapshot + viz da Legião) |
| 4. Mapear e automatizar cenários de teste (cobertura vasta) | §9 (cenários) + §11 (catálogo de testes) |
| 5. Checar bugs da AzzyAI | §7 (tabela de regressão dos bugs) |
| 6. Ações disponíveis para as invocações | §8 (inventário de ações/condições) |
| 7. Árvores e cenários para o vídeo | §9 (árvore Sera + cenários de demo) |

---

## Estado atual (o que já existe vs. o que falta)

A invocação **já está parcialmente plumbada** na camada de decisão, mas como
*placeholder*: hoje a Summon Legion é tratada como uma skill de dano em alvo
único com um "buff" longo fingindo cooldown — ela **não invoca nada** no
simulador.

| Já existe | Arquivo | Observação |
|---|---|---|
| ID `MH_SUMMON_LEGION = 8018` | `data/skills.lua:13` | ok |
| SkillInfo (range 9, SP 60–140, cast, **dur/reuse 20–60s**, **targetMode=1**) | `data/skills.lua:40` | `targetMode=1` (enemy) = cópia da AzzyAI; servidor é **Self** (ver §1) |
| `list[SERA]` com Summon Legion lv5 | `data/skills.lua:87` | ok |
| Perfil `summon = MH_SUMMON_LEGION` | `data/profiles.lua:45` | resolvido em `profile_resolve.lua:37` |
| Meta `role="summon"`, `cat="special"` | `data/skill_meta.lua:29` | ok |
| Efeito `kind="summon"` + desc por nível | `data/skill_effects.lua:69-70` | "Hornet/Giant Hornet/Luciola" |
| Ação `UseSummon` | `behaviors/skills.lua:94-102` | **gate por `buffActive` (hack)** na linha 97 |
| Config `UseSummon=true` | `core/blackboard.lua:100` | liga/desliga global |
| `UseSummon` já na árvore padrão gerada | `tree_homun.lua:93` | dispara hoje, sem efeito real no sim |

| Falta (este plano) | Onde |
|---|---|
| **Estimador de legião viva** (count + timer) na percepção — substitui o hack `buffActive` | §2 |
| Nó guarda-chuva **`UseSeraLegion`** (decisão pura, política de re-summon) | §3 |
| **Spawn de atores invocados** no simulador (TTL + IA própria) | §4 |
| Bloco de **snapshot** `sera`/`legion` + **visualização** dedicada | §5 |
| Exposição no **editor** (role `summon` na tela "Skills" + params por skill) | §6 |
| **Catálogo `data/summons.lua`** (mob/qtd/duração por nível) | §4/§6 |
| **Testes** (estimador, decisão, sim, editor, cenários) | §11 |
| **Árvore + cenários** de demonstração | §9 |

---

## Princípio (por que fica melhor que na AzzyAI)

A API do cliente **não expõe o dono/mestre de um ator** — não há `GetV` de
"quem invocou este mob" (confirmado em `core/ro_api.lua`; a relação
`master_id`/`AI_LEGION` mora só no `mob.cpp` do servidor). A AzzyAI contorna
**varrendo a tela** e contando atores cujo tipo está em 2158–2160, com um
detector de "bicho bugado" e um histórico de 5 ticks (`AI_main.lua:3334-3367`,
`:3448-3467`). Esse esquema dependente de visão é a maior fonte de **re-summon
desperdiçando SP** (o próprio autor já amorteceu o detector uma vez —
`Changelog.txt:16`).

Nossa saída é a **mesma da Eleanor com as Esferas**: um **estimador no
blackboard** (`bb.self.legion`), alimentado por (a) contagem por tipo de mob e
(b) um **timer de duração** registrado quando a intenção de summon é aplicada.
"Legião viva" passa a ser decidida por *timer*, não por *visão* — então perder
os bichos de vista por um tick não dispara re-cast. Mantemos a regra da casa: a
árvore é **decisão pura** (escreve `bb.intent`); efeitos e contabilidade só no
`applyIntent` / `skillsys.markUsed`.

---

## 1. Modelo mecânico (fonte da verdade)

Conferido na AzzyAI (`USER_AI/H_SkillList.lua:177`, `Const_.lua`,
`AzzyUtil.lua`) + divine-pride/rAthena (Renewal). **Sera = V_HOMUNTYPE 50.**

| Nv | Mob invocado | Tipo (V_HOMUNTYPE do ator) | Qtd | Duração | SP | Cast (fixo+var) | Cooldown (servidor) |
|----|--------------|----------------------------|-----|---------|----|-----------------|---------------------|
| 1 | Hornet | 2158 | 3 | 20 s | 60 | 0.4 + 1.6 s | **0** |
| 2 | Giant Hornet | 2159 | 3 | 30 s | 80 | 0.6 + 1.4 s | **0** |
| 3 | Giant Hornet | 2159 | 4 | 40 s | 100 | 0.8 + 1.2 s | **0** |
| 4 | Luciola Vespa | 2160 | 4 | 50 s | 120 | 1.0 + 1.0 s | **0** |
| 5 | Luciola Vespa | 2160 | 5 | 60 s | 140 | 1.2 + 0.8 s | **0** |

**Comportamento dos invocados (servidor, `mob.cpp`):**
- São mobs **agressivos** com `master_id = Sera` e `special_state.ai = AI_LEGION`.
- **Copiam o alvo do mestre:** quando o invocado não tem alvo, `mob_ai_sub_hard_slavemob` copia `target/target_to/skilltarget` da Sera. Se o alvo some e a Sera não ataca nada, os bichos atacam a própria Sera até a skill acabar (wikis).
- **Morrem com o mestre** (`status_kill` do slave se o mestre morre) e **expiram** ao fim da `Duration1` (20–60 s).

**Cooldown = 0 no servidor.** A única "janela" é a vida dos bichos. A AzzyAI
**inventa** um cooldown = duração (`DoSkill`, `AzzyUtil.lua:2560-2561`:
`AutoSkillCooldown[skill]=t+GetSkillInfo(skill,9,level)+delay`). Vamos modelar
igual, mas via estimador (§2) em vez de um único timer cego.

**Divergência de `targetMode`.** O servidor marca a skill como **Self**; a AzzyAI
(e o nosso `skills.lua:40`) marca **enemy (1)** para "anexar" a swarm a um
inimigo e usar a lógica de alcance. **Decisão:** manter `targetMode=1` na
decisão (resolve alcance/alvo), mas no `applyIntent` do simulador a skill
**não causa dano no alvo** — ela **spawna** a legião (§4). Documentar que, no
jogo, a camada de ação emite `SkillObject` no alvo (comportamento da AzzyAI),
não `SkillGround`/`Self`.

---

## 2. Fase 1 — Estimador de legião (percepção)

A base de tudo. Sem isto, a decisão de re-summon vira o hack atual
(`buffActive`) e herda os bugs de SP da AzzyAI.

**Onde mora:** estado em `bb.persist.legion` (sobrevive aos ticks; a percepção é
reconstruída a cada tick), espelhado em `bb.self.legion` para leitura da árvore e
do snapshot:

```lua
bb.self.legion = {
  count     = <int>,    -- bichos detectados agora (por tipo)
  alive     = <bool>,   -- count>0  OU  now < expiresAt
  expiresAt = <ms>,     -- registrado no markUsed ao aplicar o summon
  level     = <1..5>,   -- nível do último summon
  ids       = { ... },  -- AIDs dos membros (para a viz)
}
```

**Identificação por tipo (mesma BT, cliente trocável).** No cliente, a Legião é
reconhecida por `GetV(V_HOMUNTYPE, ator) ∈ {2158,2159,2160}` (é assim que a
AzzyAI faz — `AI_main.lua:3357`). Hoje a percepção lê só `V_TYPE` para
`m.type` (`perception.lua` ~46-73). **Mudança:** ler também o "mob class" de cada
monstro e marcar:
- `m.mobClass = ro.getv(V_HOMUNTYPE, id)` (no sim, o backend devolve `e.homunType`).
- `m.isSummon = SUMMON_TYPES[m.mobClass]` (conjunto `{2158,2159,2160}` em `data/summons.lua`).
- **Excluir a própria legião da aquisição de alvo** (a Sera não deve atacar os
  próprios insetos) — corrige a classe de bug "magic number" da AzzyAI (§7, A5).

**Regras por tick (`perception.update`, só quando `homunType == SERA`):**
- `count = #(monstros com isSummon)`; suavizar com `math.max` de uma pequena
  janela (2–3 ticks) contra flicker de visão.
- `alive = count > 0 or bb:now() < (bb.persist.legion.expiresAt or 0)`.
- **Sem** a heurística "STAND + dist>3 = bugado" da AzzyAI (foi a maior fonte de
  re-summon à toa — `Changelog.txt:16`).

**Registro do timer (`skillsys.markUsed`):** ao aplicar uma skill com
`fx.kind=="summon"`, setar `bb.persist.legion.expiresAt = now + duration(level)`
e `legion.level = level`. (Análogo a como `markUsed` já liga `buffUntil` para
buffs — `skillsys.lua:158`.)

**Fail-safe (cast falho):** se o cast foi despachado mas falhou (cliente: hook de
falha; simulador: `failNextCast`, já existe no `SIM_DISPATCH`), **não** estender
`expiresAt` — assim a próxima avaliação re-summona corretamente.

**Config nova (`blackboard.lua`):** `SummonMobTypes={2158,2159,2160}`,
`LegionSmoothTicks=3`. (Mantém `UseSummon=true` que já existe na linha 100.)

**Testes (`tools/summon_estimator_test.lua`):** contagem por tipo; `alive` por
timer mesmo com `count==0`; expiração; reset ao re-summonar; **perda de visão de
1 tick não derruba `alive`** (regressão do bug A3); homún não-Sera não cria
`legion` (isolamento).

---

## 3. Fase 2 — Nó `UseSeraLegion` (decisão)

Evolui o atual `UseSummon`. Decisão pura: escreve um `bb.intent` de skill por
tick e devolve `SUCCESS` (emitiu) ou `FAILURE` (deixa o ramo seguir p/
ataque/chase). Mantemos `UseSummon` como **alias** para compatibilidade da
árvore gerada (`tree_homun.lua:93`).

**Params (expostos ao editor — §6; cada campo documentado em §3.1):**
- `enable`: liga/desliga (espelha `config.UseSummon`).
- `level`: nível usado (1–5; default 5; valida contra a `list`). *Substitui o
  `SeraCallLegionLevel` da AzzyAI.*
- `resummon`: **política de re-invocação** — `onExpire` (default) | `keepFull` |
  `minCount` (ver §3.1).
- `minCount`: piso de insetos vivos quando `resummon=minCount` (default 3).
- `minMobCount`: nº mínimo de inimigos no alcance para valer a pena (default 1).
- `vsBossOnly` (bool, default false): a swarm rende muito em MVP/Boss; opção de
  só invocar contra chefe.
- `range`: herdado do SkillInfo (9); editável só se necessário.

**Pseudo-lógica do tick:**
1. Sem alvo válido **ou** `not config.UseSummon` → `FAILURE`.
2. Resolver `level` (clamp à `list[SERA]`).
3. **Não desperdiçar SP (política `resummon`):** decide se já há legião
   suficiente — `onExpire`: `FAILURE` enquanto `legion.alive`; `keepFull`:
   `FAILURE` enquanto `legion.count >= max(nível)`; `minCount`: `FAILURE`
   enquanto `legion.count >= minCount`. *Correção central vs. AzzyAI: decisão por
   estimador/timer, não por contagem de visão crua.*
4. `vsBossOnly` e alvo não-boss → `FAILURE`.
5. `minMobCount` não atingido → `FAILURE`.
6. `knows` + `ready`(sem reuse real, mas respeita delay) + `enoughSP` +
   `inRange(9)` → emite `intent {skill, level, target, mode=1, kind="summon"}`;
   senão `FAILURE`.

### 3.1 Documentação dos campos de configuração

Cada campo aparece no painel (§6) com este texto de ajuda (tooltip/legenda) e é
replicado em `docs/referencia-nos.md` — atende ao pedido de "documentar os
campos, explicando-os".

| Campo | O que faz | Valores | Default | Observação |
|---|---|---|---|---|
| `enable` | Liga/desliga a invocação automática | on/off | on | Espelha `config.UseSummon` |
| `level` | Nível da Summon Legion — define mob, quantidade e duração (§1) | 1–5 | 5 | Clampado à skill conhecida; nível 0 **nunca** desliga em silêncio (corrige bug A1) |
| `resummon` | **Quando re-invocar** a legião | `onExpire` / `keepFull` / `minCount` | `onExpire` | 3 políticas abaixo |
| `minCount` | Só com `resummon=minCount`: piso de insetos vivos | 1–5 | 3 | Re-invoca quando `vivos < minCount` |
| `minMobCount` | Mínimo de inimigos no alcance para invocar | 0–N | 1 | Evita gastar SP por 1 mob trivial; 0 = sempre |
| `vsBossOnly` | Só invoca contra Boss/MVP | on/off | off | A swarm rende muito em alvo de HP alto |
| `range` | Alcance para considerar o alvo "anexável" | células | 9 | Vem do SkillInfo; raramente mexido |

**Políticas de `resummon` (texto explicativo na UI):**
- **`onExpire`** *(recomendado / fiel à AzzyAI)* — re-invoca só quando a legião
  **expira ou zera** (por timer). Mais econômico em SP; aceita ficar com menos
  bichos no fim da janela.
- **`keepFull`** — re-invoca assim que **faltar qualquer** inseto (mantém a swarm
  no máximo do nível). Mais agressivo e **gasta mais SP**.
- **`minCount`** — meio-termo: re-invoca quando os vivos caem abaixo de
  `minCount`. Sustenta pressão sem re-castar a cada baixa.

> Todas as políticas decidem pelo **estimador** (§2), não pela contagem de visão
> crua — então nenhuma re-invoca por perder os bichos de vista por 1 tick (corrige
> bug A3).

**Peças internas testáveis** (funções locais, não nós do editor):
`legionAlive(bb)`, `shouldSummon(bb, p)`, `resolveLevel(bb, p)`. Expostas em
`BRAI.sera` para os testes (padrão `BRAI.eleanor`).

**Condições novas (reutilizáveis no editor):**
- `LegionActive` — `bb.self.legion.alive`.
- `LegionBelow{count}` — `legion.count < count` (gatilho de reforço).
- `LegionExpiring{ms}` — `expiresAt - now < ms` (re-summon antecipado).

Reaproveita `TargetIsBoss` (já existe — `conditions.lua`) e `HasValidTarget`/
`InAttackRange`.

**Colocação na árvore:** no ramo de combate, como **manutenção da swarm** antes
de `UseAoESkill`/`UseMainSkill`/ataque normal; como checa alcance internamente, o
`ChaseTarget` ainda corre no `FAILURE`.

**Testes (`tools/summon_decision_test.lua`):** não re-summona com legião viva
(timer); re-summona ao expirar; gating por SP/alcance/level; `vsBossOnly`;
`minMobCount`; **não mira a própria legião** (aquisição de alvo ignora `isSummon`).

---

## 4. Fase 3 — Atores invocados no simulador

O coração do "ver a invocação acontecer". Hoje o `applyIntent` trata a skill
(modo 1) como dano em alvo único — precisamos de um **ramo de invocação**.

**Catálogo `data/summons.lua`** (fonte única, estilo `data/combos.lua`), também
consumido pelo editor (§6) e pelo estimador (§2):
```lua
BRAI.summons = {
  [S.MH_SUMMON_LEGION] = {
    types = {2158,2159,2160},            -- conjunto p/ detecção
    perLevel = {
      [1] = { mob=2158, count=3, duration=20000, atk=150, aggro=9, atkInterval=800 },
      [2] = { mob=2159, count=3, duration=30000, atk=220, aggro=9, atkInterval=800 },
      [3] = { mob=2159, count=4, duration=40000, atk=260, aggro=9, atkInterval=750 },
      [4] = { mob=2160, count=4, duration=50000, atk=320, aggro=9, atkInterval=700 },
      [5] = { mob=2160, count=5, duration=60000, atk=380, aggro=9, atkInterval=700 },
    },
    names = { [2158]="Hornet", [2159]="Giant Hornet", [2160]="Luciola Vespa" },
  },
}
```

**`applyIntent` — ramo summon (`sim/runtime.lua` ~202-263):** quando
`fx.kind=="summon"`, em vez de dano:
- Lê `summons[skill].perLevel[level]` → spawna `count` entidades com:
  ```lua
  { kind="summon", summonOf=homunId, homunType=mob,   -- 2158/2160 (V_HOMUNTYPE no backend)
    x,y = perto da Sera, hp,maxhp, atk, aggro, atkInterval,
    isMonster=false, faction="homun",
    ttl = duration, bornAt = w.tick, target = bb.target }
  ```
- Setar `bb.persist.legion.expiresAt` via `markUsed` (§2).
- IDs auto-gerados (padrão do `addMonster`, `runtime.lua:557-573`).

**`stepSummons()` (novo, chamado no `SIM.tick` antes/junto de `stepMonsters`):**
- **Alvo:** se `target` morto/ausente → copiar o alvo do mestre
  (`bb.target` / intent atual) — réplica do `slavemob`. **Se a Sera fica sem
  alvo:** os insetos atacam a **própria Sera com dano real** (fiel ao servidor —
  `AI_LEGION` os mantém agressivos; ver cenário §9.5). Cria pressão para a Sera
  re-engajar rápido; também serve de feedback visual de "swarm sem ordem".
- **Mover/atacar:** mesma mecânica de `stepMonsters` (Chebyshev; ataca se
  `dist<=1` respeitando `atkInterval`, senão dá um passo). Dano no monstro alvo →
  é o que faz a swarm "trabalhar" na tela.
- **TTL:** `if w.tick - bornAt >= ttl then remover`. **Morte com o mestre:** se a
  Sera morre, remover todos os `summonOf==homunId`.

**Monstros revidam:** incluir os IDs de `kind=="summon"` no conjunto de alvos da
IA dos monstros (`stepMonsters` usa `w.aggroIds`) — assim os mobs selvagens
batem nos insetos (realista e ótimo para a viz: HP dos bichos caindo).

**`SIM_DISPATCH`:** nada novo obrigatório (o spawn nasce do `applyIntent`).
Opcional: `summonStatus` para depurar. `failNextCast` já cobre o fail-safe (§2).

**Cenário pode pré-popular** insetos (entidades `kind:"summon"`) para testar a
viz sem esperar o cast.

**Testes (`tools/summon_sim_test.lua`):** spawn de N por nível; insetos batem no
alvo; copiam o alvo do mestre quando o deles morre; **sem alvo do mestre, batem
na Sera (dano real — HP da Sera cai)**; somem por TTL; somem com a morte da Sera;
monstros revidam nos insetos.

---

## 5. Fase 4 — Snapshot + visualização da Legião (criativa)

Espelha o tratamento da Eleanor (bloco `eleanor` no snapshot +
`renderEleanor`/`drawEleanorOverlay`/`elOrbsHtml` no `renderer.js`), mas com uma
linguagem visual própria de **enxame**.

**Bloco de snapshot `sera` (em `SIM.snapshot`, gated `homunType==SERA`,
`runtime.lua` ~410):**
```lua
sera = {
  active      = legion.alive,
  count       = legion.count,         -- vivos agora
  max         = perLevel[level].count, -- esperado p/ o nível
  level       = legion.level,
  tier        = "Hornet"|"Giant Hornet"|"Luciola Vespa",
  remaining   = expiresAt - tick,     -- ms restantes da legião
  total       = duration(level),      -- p/ o anel radial
  resummonReady = (not legion.alive) and spOk and inRange,
  spOk        = bb.self.spPct alto o bastante p/ o custo,
  members = { {id,x,y,hpPct,target,ttl}, ... },  -- p/ desenhar cada inseto
  damageDealt = <acumulado da swarm no tick/total>,  -- "DPS do enxame"
}
```
Os próprios insetos também saem em `entities` com `kind="summon"` (o render já
itera entidades) — então aparecem no grid naturalmente; o bloco `sera` é o
**HUD agregado**.

**Painel lateral `renderSera(f)` (criativo):**
- **Cabeçalho do enxame:** badge da *tier* com cor por nível
  (Hornet `#f2c14e` → Giant Hornet `#e08a3c` → Luciola Vespa `#c0476a`), nome do
  mob e nível.
- **Pips de contagem** `legionPipsHtml(count, max)`: ícones de vespa (▲/♦)
  cheios = vivos, vazios = baixas — leitura instantânea de "3/5".
- **Anel de duração** (radial timer) `remaining/total` — quanto resta da legião
  (a "ampulheta" do enxame). Vira **vermelho piscando** quando `LegionExpiring`.
- **HP agregado** da swarm (soma dos `hpPct`) + **"DPS do enxame"**
  (`damageDealt`) — o número que mostra a invocação *fazendo trabalho*.
- **Selo "Re-summonar"** quando `resummonReady` (verde) / "SP baixo" (cinza).

**Overlay no canvas `drawSeraLegionOverlay(f, c)` (sobre o sprite, criativo):**
- **Arco de duração** ao redor da Sera (consome `remaining/total`) — a Eleanor
  tem orbs; a Sera tem um **halo de enxame** que encolhe com o tempo.
- **Cada inseto** desenhado como um ponto na cor da tier, com **mini-barra de HP**
  e uma **linha fina até o seu alvo** (mostra a swarm convergindo no inimigo).
- Insetos **esmaecem** conforme o TTL acaba (alpha proporcional a `ttl`).
- Pulso suave (raio oscilante) para dar sensação de "zumbido"/movimento.

**Funções a adicionar** (paralelas às da Eleanor, `renderer.js`):
`seraActiveTier(f)`, `legionPipsHtml(n,max)`, `renderSera(f)`,
`drawSeraLegionOverlay(f,c)`. CSS: `.lg-pip.full/.empty`, `.lg-ring`,
`.lg-tier-1/2/3`.

**Smoke (`desktop/sera_viz_smoke.js`):** alimenta um snapshot fake (3/5 vivos,
12s restantes de 60s, 2 insetos com alvo) e valida pips, anel e linhas — padrão
do `eleanor_viz_smoke.js`.

---

## 6. Fase 5 — Editor: role `summon` na tela "Skills" + params por skill

Atende os pedidos 1 e 2. Hoje a tela "Skills" (`roleConfig` →
`editor.js:1213+`) só mostra `mainAtk/aoeAtk/offBuff/defBuff`, porque
`ROLE_KEYS` (`skill_choice.lua:11`) não inclui `summon`.

**Passo A — fazer a skill aparecer:** adicionar `summon` a `ROLE_KEYS` e à
montagem do `roleConfig`. Para a Sera, a linha "Invocação" passa a listar
*Summon Legion* (e qualquer futura skill de invocação) — exatamente "caso o
homúnculo possua uma skill de summonar, ela aparece".

**Passo B — params específicos por skill (ao clicar):** ao selecionar a skill de
invocação, abre um **sub-painel** dirigido por um dispatch novo
`summonInfo(skillId)` (padrão do `comboInfo`, `skill_meta.lua` / `runtime.lua`).
O catálogo (`data/summons.lua`, §4) alimenta:
- **Visão (read-only):** mob/qtd/duração por nível (a tabela da §1).
- **Editável:** `level`, `resummon` (+`minCount`), `minMobCount`, `vsBossOnly` —
  cada um com **texto de ajuda** (a documentação da §3.1) no painel; o schema vem
  do `summonInfo`, então **skills diferentes podem ter params diferentes**
  (extensível além da Sera).

**Persistência:** os params editáveis ficam nos **params do nó `UseSeraLegion`**
da árvore (viajam pro jogo via codegen, igual aos params do `UseEleanorOffense`).
A escolha de *nível* pode também ir para um `homun_summons.json` global (padrão
do `homun_skills.json`, aplicado em `profileFor`) como **evolução futura** se
quisermos config por-homúnculo independente da árvore.

**Cuidado da ponte (CLAUDE.md):** ao expor I/O no `preload.js`, nomear a global
de ponte como `summonIO` (NÃO `summon`) para não colidir com `let` de topo no
`renderer.js`/`editor.js` — mesmo motivo do `skillChoiceIO`.

**Smoke (`desktop/host_smoke.js`):** carrega árvore com `UseSeraLegion`, grava/lê
os params pelo painel, valida o schema.

---

## 7. Bugs da AzzyAI — regressão (pedido 5)

Meta (igual à Eleanor §9.2): **cada bug conhecido tem um teste que falha se
regredirmos.** Fontes: `USER_AI/Changelog.txt` + inspeção do código.

| # | Bug AzzyAI (fonte) | Sintoma | Nosso guard | Teste |
|---|---|---|---|---|
| A1 | `SeraCallLegionLevel` default 0 desliga a skill em silêncio (`Changelog.txt:15,46`) | Sera nunca invoca e ninguém percebe | `level` default 5, validado/clampado à `list` | E-lvl |
| A2 | Detector de "bugado" apressado → re-summon à toa (`Changelog.txt:16`) | Desperdício de SP | **Sem** heurística "STAND+dist>3"; re-summon só por timer | E-noresum |
| A3 | Re-cast por perda de visão (contagem cai a 0 → `:3460` zera cooldown) | Re-summona com legião viva fora de tela | `alive` por **timer** + suavização; perda de 1 tick não derruba | E-vision |
| A4 | Cooldown sintético sem confirmação de cast (servidor cd=0) | Janela de duplo-cast | `expiresAt` só no `applyIntent`; fail-safe em cast falho (`failNextCast`) | E-failcast |
| A5 | "Magic number" classifica invocação como monstro normal (`Changelog.txt:555-556`) | Sera mira/ataca os próprios insetos; alvo errado | Detecção por **tipo de mob** + **excluir `isSummon` da aquisição** | D-notarget |
| A6 | `targetMode` divergente (enemy vs Self) → "errors" históricos (`Changelog.txt:152`) | Cast rejeitado/erro | Modo explícito; sim não aplica dano no alvo, só spawna | S-spawn |
| A7 | Eleanor usa combo quando tactic = minion (`Changelog.txt:81`) | Cruzamento de papéis entre homúnculos | Papéis por **perfil** (sem FSM global); Sera≠Eleanor | (perfil) |

---

## 8. Ações e condições disponíveis para invocações (pedido 6)

**Realidade do RO:** os invocados são **autônomos** (`AI_LEGION`) — o jogador/
homúnculo **não comanda** os bichos diretamente. As "ações" possíveis para a IA
são: **(re)invocar**, **manter** a legião e **manter um alvo** (a swarm segue o
alvo do mestre). Não há "ordenar recuo/foco" para a legião.

**Já existem e reaproveitamos** (`registry`): `AcquireTarget` / `ReacquireIfBetter`
/ `AcquireOwnerAttacker` (alvo p/ a swarm seguir), `ChaseTarget`, `AttackTarget`,
`UseAoESkill` (Poison Mist junto), `UseOwnerBuff` (Painkiller no dono),
`TargetIsBoss`, `HasValidTarget`, `InAttackRange`, `Mobbed`, `threatCount`.

**A criar** (este plano): ação `UseSeraLegion` (evolui `UseSummon`); condições
`LegionActive`, `LegionBelow{count}`, `LegionExpiring{ms}`. Filtro de percepção
**`isSummon`** para a aquisição de alvo nunca mirar a própria legião.

> Nota: como os bichos copiam o alvo do mestre, a melhor "ação de comando" da
> Sera sobre a swarm é **escolher bem o próprio alvo** e mantê-lo — por isso o
> `UseSeraLegion` fica no ramo de combate **junto** da aquisição/ataque, não
> isolado.

---

## 9. Árvores e cenários de demonstração (pedido 7, p/ vídeo)

**Árvore `trees/Sera - <base>/tree.json`** — `homunType:50`. Ramo de combate:
`UseSeraLegion` (manutenção do enxame, estilo `keepAlive`) **antes** de
`UseAoESkill` (Poison Mist) / `UseMainSkill` (Needle of Paralyze) / ataque;
`UseOwnerBuff` (Painkiller); seguir dono / ocioso / comandos (reusa o esqueleto
das árvores `Sera - Vanilmirth` / `Dieter - Amistr`).

**Cenários `scenarios/` (`homunType=50`)** — cada um destaca uma capacidade e
serve de **regressão** headless:

1. **Enxame no alvo isolado** *(Fase 3/5)* — 1 alvo isolado → invoca 5 Luciola,
   a swarm converge e abate; painel mostra contagem/anel de duração/DPS.
2. **MVP/Boss** *(Fase 3)* — alvo `boss` → a Legião brilha no dano sustentado;
   re-summon ao expirar; ótimo plano para o vídeo (HUD do enxame vs. barra de HP
   gigante do chefe).
3. **Expiração e re-summon** *(Fase 1/2)* — deixa a duração acabar → re-summona
   **uma vez** (não antecipa, não duplica).
4. **Perda de visão não re-summona** *(Fase 1, regressão A3)* — alvo arrasta os
   bichos p/ fora da visão por alguns ticks → `alive` segura pelo timer; sem
   re-cast.
5. **Alvo morre no meio** *(Fase 3)* — alvo abatido → insetos **re-miram** o
   próximo alvo do mestre (slavemob); se a Sera fica **sem alvo**, os insetos
   batem na **própria Sera** (dano real) — pressão para re-engajar. *(exercita o
   dano de retorno no `summon_sim_test`)*
6. **Swarm + Poison Mist** *(Fase 3)* — multidão → invoca e solta Poison Mist;
   enxame + DoT na mesma cena (vídeo).

---

## 10. Arquivos a tocar

| Arquivo | Mudança |
|---|---|
| `lua/src/core/perception.lua` | estimador `legion` (contagem por tipo + timer), `isSummon`, excluir da aquisição |
| `lua/src/core/skillsys.lua` | `markUsed` seta `legion.expiresAt` para `kind=="summon"`; helper `summonLevelInfo` |
| `lua/src/data/summons.lua` (novo) | catálogo mob/qtd/duração/atk por nível + tipos de detecção |
| `lua/src/behaviors/skills.lua` | nó `UseSeraLegion` (evolui `UseSummon`); condições `LegionActive/LegionBelow/LegionExpiring` |
| `lua/src/behaviors/combat.lua` | aquisição de alvo ignora `m.isSummon` |
| `lua/src/core/blackboard.lua` | configs (`SummonMobTypes`, `LegionSmoothTicks`) |
| `lua/bootstrap.lua` | registrar `data/summons.lua` (ordem antes de skillsys/behaviors) |
| `lua/src/sim/runtime.lua` | ramo summon no `applyIntent`; `stepSummons`; bloco snapshot `sera`; revide nos insetos |
| `lua/src/data/skill_choice.lua` | `summon` em `ROLE_KEYS` |
| `lua/src/data/skill_meta.lua` | `summonInfo(skillId)` (catálogo p/ o editor) |
| `desktop/editor/editor.js` + `index.html` | role "Invocação" na tela Skills + sub-painel de params |
| `desktop/.../preload.js` + `*_io.js` | ponte `summonIO` |
| `desktop/renderer/renderer.js` | `renderSera` + `drawSeraLegionOverlay` + `legionPipsHtml` + CSS |
| `docs/referencia-nos.md` | documentar `UseSeraLegion` + condições + **campos de config (§3.1)** |
| `tools/summon_*_test.lua` | estimador, decisão, sim, cenários |
| `desktop/sera_viz_smoke.js` | smoke da viz |
| `trees/Sera - */tree.json` | árvore de demonstração |
| `scenarios/Sera - *.json` | 6 cenários de demo/regressão |

---

## 11. Catálogo de testes automatizados

Padrão dos harness `tools/*_test.lua` (mundo falso; `RESULTADO: N ok, 0 falhas`).
Dois níveis (unidade: peças internas com blackboard à mão; integração: via
`SIM_DISPATCH`, carrega cenário, dá `step`s, valida a sequência de `intent`s e o
estado do mundo). Cada cenário da §9 vira um teste de integração.

**`summon_estimator_test.lua` (Fase 1):**
- contagem por tipo (`2158/2159/2160`); `alive` por timer com `count==0`;
  expiração no tempo certo; reset ao re-summonar; **perda de visão 1 tick mantém
  `alive`** (A3); não-Sera não cria `legion` (isolamento); invariante de
  contagem ≥ 0.

**`summon_decision_test.lua` (Fase 2):**
- não re-summona com legião viva (timer) — *no-op* de SP (A2); re-summona ao
  expirar; gating por SP / alcance / `level` válido (A1); `vsBossOnly`;
  `minMobCount`; **aquisição não mira a própria legião** (A5).

**`summon_sim_test.lua` (Fase 3):**
- spawn de `count` por nível (3/3/4/4/5); insetos batem no alvo (HP do mob cai);
  re-miram o alvo do mestre quando o deles morre; **sem alvo do mestre, batem na
  Sera (dano real — HP da Sera cai)**; somem por TTL; somem com a morte da Sera;
  monstros revidam nos insetos (HP do inseto cai); cast falho não estende
  `expiresAt` (A4); skill summon **não** dá dano direto no alvo do cast (A6).

**`summon_scenarios_test.lua` (Fase 6, regressão):** os 6 cenários da §9.

**Editor (Fase 5) — smoke:** `desktop/host_smoke.js` grava/lê params de
`UseSeraLegion`; role "Invocação" aparece p/ Sera no `roleConfig`.

**Mapa bug→teste:** A1→E-lvl, A2→E-noresum, A3→E-vision, A4→E-failcast,
A5→D-notarget, A6→S-spawn, A7→perfil.

**Definition of Done (por fase):** testes da fase verdes **e** guards da §7 da
fase cobertos **e** suíte global intacta — `texlua tools/bt_test.lua`,
`texlua outputs_chk.lua`, e os `tools/*_test.lua` relevantes (incl.
`skillinfo_test`, `homun_test`, `skill_meta_test` que já tocam a Sera).

---

## Ordem sugerida

**Fase 1 (estimador)** → **Fase 2 (`UseSeraLegion`)** → **Fase 3 (atores no
sim)** → **Fase 4 (snapshot + viz)** → **Fase 5 (editor)** → **Fase 6 (árvore +
cenários)**. Cada fase entra com nó(s)/percepção/config + **teste texlua** +
suporte no simulador. Os cenários 1/3/4 já dão material de vídeo logo após a
Fase 3; 2/5/6 após a Fase 4 (a viz é o que vende a cena).

## Decisões (2ª rodada — fechadas)

1. **Escopo:** catálogo `summons.lua` **genérico** (chaveado por skill), mas
   **populado só com a Sera** (Summon Legion) nesta etapa. Outras criações de
   ator (ex.: Stein Wand da Bayeri, *ground unit* tipo Safety Wall) ficam como
   **extensão futura** do mesmo framework, sem reescrita.
2. **Re-invocação configurável:** a política é **configuração do usuário** (campo
   `resummon`, §3.1), com **documentação de cada campo** na própria UI (texto de
   ajuda) e em `docs/referencia-nos.md`. Default fiel à AzzyAI (`onExpire`); os
   modos `keepFull` e `minCount` ficam disponíveis e explicados.
3. **Edge "sem alvo do mestre":** modelar com **dano real** — os insetos atacam a
   **própria Sera** quando ela não tem alvo (fiel ao servidor: `AI_LEGION` os
   mantém agressivos e eles batem no mestre na falta de alvo). Vira um cenário e
   uma asserção de teste (§9.5, §11).
