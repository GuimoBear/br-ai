# Eleanor: combos, esferas e ofensiva 200+

A Eleanor não é um homúnculo de “uma AoE e um ataque”. Três sistemas convivem: **estilos** mutuamente exclusivos (Power / Grapple), **esferas estimadas** (a API do cliente não expõe a contagem) e duas skills **ativas autônomas** de nível 200+ que **não são elos de combo**.

Página do usuário: [`desktop/static/help/eleanor.html`](../desktop/static/help/eleanor.html). Contrato de testes: `tools/eleanor_lvl200_test.lua` + a suíte `eleanor_*`.

## O que não fazer

- **Não** colocar 8050/8051 em `BRAI.combos`. Isso quebraria a janela de 2s, o `Style Change` e o visualizador (contaria Blazing como “passo 2”).
- **Não** mapear Brushup Claw (8049): passiva, como as outras.
- **Não** misturar números de dano jRO. Os % atuais são LATAM/kRO.

## Skills 200+

| ID | Constante | Req | Papel | Esferas | Timings (Gungho / rAthena) |
|---|---|---|---|---|---|
| 8051 | `MH_THE_ONE_FIGHTER_RISES` | 230 | `aoeAtk` (primeiro) | `fillMax` | reuse `3800…2000` ms por nível, delay 500, varCast 0 |
| 8050 | `MH_BLAZING_AND_FURIOUS` | 215 | `aoeAtk` (depois) | `consumeAll` (hits = nº de esferas, ≥1) | CD 1s, delay 500, cast 0 |

Dados: `lua/src/data/skills.lua` (timings), `skill_meta.lua` (`role = "aoeAtk"`), `profiles.lua` (`aoeAtk = { The One, Blazing }`), `combos.lua` (`sphereOps`).

O simulador decide “aprendida” por `lvl` vs `lua/src/sim/skill_req_level.lua` (`GetV(V_SKILLATTACKRANGE)`). `sys.knows` é a lista do tipo, não o nível.

## Duas superfícies

### A — `UseAoESkill` / papel `aoeAtk`

Caminho “usar sem combar” (igual o Dieter com Lava → Blast Forge).

- Eleanor **tem** `mainAtk` (Sonic), então **não** usa o atalho do Dieter (≥1 alvo). Vale `AutoMobCount` (padrão 2).
- `tryCastAoE` chama `BRAI.eleanor.aoeUsable`: skill aprendida +, se `sphereOps == "consumeAll"`, `spheres >= 1`. Sem esse gate o `UseAoESkill` tentaria Blazing com 0 esferas e o jogo recusaria.
- The One é `targetMode = 0` (self), mesmo caminho do Heilige Pferd.
- Árvore padrão `trees/Eleanor - Filir/tree.json`: `UseAoESkill` **acima** de `UseEleanorOffense`.

### B — `UseEleanorOffense` + painel Combos

Guarda-chuva para quem não põe `UseAoESkill`, e para refill em alvo único (a AoE não dispara com 1 mob).

Depois de `ensureStyle` / `comboStep`, **antes** do elo clássico:

1. `step > 1` → **nunca** dispara 200+ (não aborta Midnight/EQC).
2. `lvl200Mode` ausente ou inválido → **`off`** (árvores antigas inalteradas).
3. `fillThenCombo` — The One se `spheres < theOneWhenSpheresBelow` **ou** `threat >= theOneMinMobs`. Não dumpa Blazing.
4. `aoeDump` — The One no cluster; senão Blazing se cluster e `spheres >= blazingMinSpheres`.

Intent 200+ **não** leva `combo=power/grapple`. `parseCombo` aceita as chaves 200+ e descarta valores inválidos. `comboInfo().lvl200` alimenta o painel (ids, iRO, sphereOp, maxLevel, reqLevel).

Precedência: **nó > `homun_skills.json` > off**. O default de *painel* é `fillThenCombo`; o default de *runtime* quando a chave não existe é `off`.

Params: `lvl200Mode`, `theOneMinMobs` (2), `theOneWhenSpheresBelow` (3), `blazingMinMobs` (2), `blazingMinSpheres` (5), `interruptCombo` (false; o meio da cadeia continua protegido), `levels.theOne` / `levels.blazing`.

UI: `desktop/editor/editor.js` — seção **Level 200+** abaixo das cadeias, inspetor resume o modo. Sem segundo modal.

## Testes

Nada fecha sem verde:

- `tools/eleanor_lvl200_test.lua` — ofensiva, AoE, seletor com os dois nós, parse/schema.
- `eleanor_newskills_test.lua` — timings 8051, `role=aoeAtk`.
- `skillscreen_test.lua` / `action_skills_test.lua` — candidatos e `UseAoESkill` The One → Blazing.
- `base_skills_golden_test.lua` — `aoe=[8051,8050]`.
- `eleanor_scenarios_test.lua` — árvore real; pin `lvl = 200` para a regressão clássica (Sonic, não The One).
- `combo_choice_test.lua` / `eleanor_editor_test.lua` — parse 200+ e `comboInfo.lvl200`.
- `eleanor_combo_test.lua` / `eleanor_grapple_test.lua` — sem `lvl200Mode` nos params → runtime `off`.

## Fora de propósito

- Mapear Brushup Claw.
- Terceira cadeia em `BRAI.combos`.
- Números de dano jRO.
