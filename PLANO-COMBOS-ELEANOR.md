# Plano de implementação — Combos da Eleanor (Homunculus S)

Migração do sistema de combos da Eleanor da AzzyAI (`USER_AI/`) para a nossa
árvore de comportamento. Documento de trabalho — iteramos em cima dele antes de
codar. Companion do [`PLANO-PARIDADE-AZZYAI.md`](PLANO-PARIDADE-AZZYAI.md)
(itens D1/D2).

> **Status: IMPLEMENTADO ✅ (6 fases)** — todas verdes. Esferas (estimador),
> `UseEleanorOffense` (combo+estilo+barragem), segurança do Agarrão (threat+boss),
> painel no editor, polimento (lag/docs) e a árvore Eleanor-Filir + 5 cenários.
> Testes: `tools/eleanor_{sphere,combo,grapple,editor,scenarios}_test.lua`
> (84 asserts Eleanor; suíte total 272 ok, 0 falhas). Os 9 bugs da AzzyAI da §9.2
> têm guard de regressão verde.

## Decisões já alinhadas

1. **Esferas Espirituais** → **estimador estilo AzzyAI** (a API do cliente não
   expõe a contagem; confirmado: só há `V_OWNER`…`V_SKILLATTACKRANGE_LEVEL`).
   Mora na **percepção**, a árvore só lê.
2. **Arquitetura** → **nó guarda-chuva** `UseEleanorOffense`, que orquestra
   estilo + esfera + combo + ameaça internamente. Internamente é montado de
   peças granulares e testáveis (não é caixa-preta para os testes, só para o
   editor).
3. **Editor** → **painel dedicado "Combos da Eleanor"** (nos moldes da tela
   "Skills" / `roleConfig`).

Sub-decisões (2ª rodada): (4) **corrigir** o bug do EQC — deduz 2 esferas; (5)
`AutoComboSpheres` é **configuração do usuário**, editável no painel com texto
explicando o que o número significa; (6) níveis por elo ficam nos **params do
nó**, com a UI deixando claro que são editáveis ali (global fica como evolução
futura).

## Princípio (por que isto fica mais simples que na AzzyAI)

A AzzyAI sofre porque é uma FSM com **estado preso**: `EleanorMode` travado,
`nil`-compares, loop de Style Change. **Metade desses bugs não existe na nossa
arquitetura** — reavaliamos a árvore inteira a cada tick a partir da raiz, então
não há "estado preso". Mantemos a regra da casa: a árvore é **decisão pura**
(escreve um `bb.intent`), os efeitos e a contabilidade saem só no `applyIntent`
/ `skillsys.markUsed`.

---

## 1. Modelo mecânico (fonte da verdade)

Tabela única consultada pela lógica (Artefato 1 do documento, com os números
reais conferidos no código da AzzyAI + Renewal):

| ID lógico            | Skill            | Estilo  | Custo esferas | Próximo elo     | Proibição     |
|----------------------|------------------|---------|---------------|-----------------|---------------|
| FIGHTER_INIT         | Sonic Claw       | power   | 0             | FIGHTER_BRIDGE  | —             |
| FIGHTER_BRIDGE       | Silvervein Rush  | power   | 1             | FIGHTER_FINISH  | —             |
| FIGHTER_FINISH       | Midnight Frenzy  | power   | 2             | volta ao INIT   | —             |
| GRAPPLE_INIT         | Tinder Breaker   | grapple | 1             | GRAPPLE_BLEED   | —             |
| GRAPPLE_BLEED        | C.B.C.           | grapple | 1             | GRAPPLE_FINISH  | —             |
| GRAPPLE_FINISH       | E.Q.C.           | grapple | 2 (corrigido) | fim             | **Boss/MVP**  |

- **Janela de encadeamento:** 2000ms entre elos (config `ComboWindow`). O elo
  seguinte só vale se disparado dentro da janela do anterior.
- **Correção vs. AzzyAI:** o `MarkSkillUsed` deles **não deduz esfera no EQC**
  (`--No sphere use?`) — bug do estimador. **Decisão: corrigimos** — EQC deduz
  **2** (coerente com a skill).
- **Ganho de esfera:** +0,5 por ataque físico despachado **e** +0,5 por dano
  recebido (cada um 50% de chance no jogo → fator 2). Teto 10, piso 0.

---

## 2. Fase 1 — Subsistema de esferas (percepção)

A base de tudo. Sem isto, o combo dispara o finalizador sem recurso → servidor
rejeita → trava (o "stutter step", problema nº 1 do documento).

**Onde mora:** estado em `bb.persist.spheres` (sobrevive aos ticks, pois a
percepção é reconstruída a cada tick), espelhado em `bb.self.spheres` para
leitura da árvore.

**Regras por tick (`perception.update`, só quando `homunType == ELEANOR`):**
- Se houve **ataque despachado** no tick anterior → `+0,5`.
- Se o **HP caiu** desde o último tick (dano recebido) → `+0,5`.
- `clamp(0, 10)`.

**Decremento (`skillsys.markUsed`):** ao aplicar uma skill de combo, subtrai o
custo da tabela §1. Tabela nova `BRAI.sphereCost[skillId]`.

**Fail-safe (dessincronização):** se um combo foi despachado mas o cast falhou
(cliente: hook de falha tipo `AAI_SKILLFAIL`; simulador: modelado), subtrai 1
para forçar a volta ao ataque básico e regenerar a economia.

**Config nova** (`blackboard.lua`): `SphereTrackFactor=2`, `SphereStartCount=0`
(reset ao invocar) e `AutoComboSpheres` — a **barragem**, exposta como
**configuração editável pelo usuário** no painel (Fase 4), com texto explicativo
na própria UI: *"mínimo de esferas estimadas antes de iniciar um combo, para
garantir que dá pra fechar o finalizador"*. Default **5** (faixa 0–10; AzzyAI
usa 5–10).

**Suporte de simulador (`sim/runtime.lua`):** expor evento de dano recebido (já
temos HP por entidade — basta delta), e um caminho para modelar cast falho
(novo campo no cenário, ex. `failCast`).

**Testes (`tools/eleanor_sphere_test.lua`):** ganho por ataque; ganho por dano;
clamp em 10; piso em 0; decremento por custo de cada skill; fail-safe ao falhar
cast; reset ao reinvocar.

---

## 3. Fase 2 — Nó `UseEleanorOffense` (estilo + combo + barragem)

Ação única no registry. Decisão pura: escreve um `bb.intent` de skill por tick e
devolve `SUCCESS` (emitiu) ou `FAILURE` (deixa o ramo seguir p/ chase/ataque).

**Params (expostos ao editor):**
- `style`: `power` | `grapple` | `auto` (default `power`).
- `comboSpheres`: barragem (sobrescreve `AutoComboSpheres` no nó); editável no
  painel com explicação na UI do que o número significa.
- `window`: janela de encadeamento (default 2000).
- `allowStyleSwitch`: bool (trava anti-loop; equivale a `EleanorDoNotSwitchMode`).
- `levels`: nível por elo (**params do nó**; default = nível conhecido). Editável
  no painel — a UI deixa claro que dá pra ajustar ali.
- `grappleThreatLimit`: máx. de agressores p/ liberar Agarrão (Fase 3).

**Pseudo-lógica do tick:**
1. Sem alvo válido → `FAILURE`.
2. Resolver estilo desejado (`power`/`grapple`/`auto`; `auto` = grapple só se
   isolado+seguro, senão power — Fase 3).
3. **Garantir estilo:** se o atual ≠ desejado e `allowStyleSwitch`, emitir Style
   Change (respeitando a trava anti-loop: não troca se trocou há < X ms) e
   `RUNNING`/`SUCCESS`.
4. **Encadear combo com gate de esfera:**
   - Step atual vem de `bb.persist.combo {key, step, at, targetId}`.
   - **Reset se o alvo mudou de identidade** ou a janela expirou → volta ao INIT.
   - **Barragem:** só inicia (step 1) se `spheres >= comboSpheres` (garante fechar
     o finalizador). Isto é melhor que o fail-safe reativo da AzzyAI: nunca começa
     o que não pode terminar.
   - Cada elo: `knows` + `ready`(cooldown) + `enoughSP` + `inRange` +
     `spheres >= custo` → emite intent; senão `FAILURE` (cai p/ ataque básico).

**Peças internas testáveis** (funções locais, não nós do editor): `sphereOk`,
`ensureStyle`, `stepCombo`, `desiredStyle`. Os nós atuais `UseCombo`/`SetStyle`/
`StyleIs` viram blocos de construção reaproveitados (mantemos seus testes).

**Colocação na árvore:** no ramo de combate, **antes** de `UseMainSkill`/ataque
normal; como checa alcance internamente, o `ChaseTarget` ainda corre quando
`FAILURE`.

**Testes (`tools/eleanor_combo_test.lua`):** ordem da cadeia power; ordem grapple;
barragem (não inicia abaixo do limiar; inicia ao atingir); expiração da janela
reseta ao INIT; **morte do alvo no meio reseta** (não dispara elo no alvo
novo/nulo); estilo troca quando necessário; trava anti-loop impede oscilação;
`allowStyleSwitch=false` respeitado.

---

## 4. Fase 3 — Segurança do Agarrão (Threat Assessment)

Tinder Breaker zera o Flee da Eleanor (e do alvo). Sem checar isolamento, o
Agarrão é sentença de morte em multidão (Artefato 4 do documento).

- **Condição `SafeToGrapple`** (reutilizável, exposta no editor): conta
  agressores num raio (`radius`, default 5x5/7x7) que miram a Eleanor **ou** o
  dono; libera se `<= grappleThreatLimit` (default 1 = só a presa).
- **Boss guard:** EQC é proibido em Boss/MVP — `UseEleanorOffense` poda o
  finalizador no elo anterior se o alvo for chefe (usa o catálogo `monsters.json`
  / flag de boss na percepção).
- **Fallback:** se inseguro e `style=auto`/`grapple`, reverter para power para
  limpar o aglomerado com mobilidade.

**Suporte de simulador:** já temos `target`/`aggro` por entidade; adicionar flag
`boss` no cenário.

**Testes:** grapple bloqueado com agressores > limite; liberado isolado; EQC não
dispara em alvo boss; fallback para power quando inseguro.

---

## 5. Fase 4 — Painel "Combos da Eleanor" (editor)

Botão na toolbar → modal/tela (como a tela "Skills" / `roleConfig`). Mostra as
duas cadeias (power/grapple) visualmente:
- Por elo: skill, **seletor de nível**, custo de esfera, janela de encadeamento.
- Globais do nó: estilo padrão, barragem `AutoComboSpheres` (com texto de ajuda
  na UI explicando o significado), `grappleThreatLimit`, `allowStyleSwitch`.

**Persistência:** edita os **params do nó `UseEleanorOffense`** selecionado (já
trafegam para o jogo via codegen da árvore). **Decisão:** níveis por elo e
barragem ficam nos params do nó; o painel deixa claro na própria UI que esses
valores são editáveis ali. Promover para um `eleanor_combos.json` global (padrão
do `homun_skills.json`, aplicado em `profileFor`) fica como **evolução futura**,
só se precisarmos de config por-homúnculo independente da árvore.

**Smoke:** `desktop/host_smoke.js` carrega a árvore com o nó e valida que o
painel grava/lê os params.

---

## 6. Fase 5 — Polimento

- **Anti-loop de Style** consolidado (trava temporal + reconciliação com o estado
  real do jogo quando observável).
- **Modulação de delay/lag** (`LagReduction`): reusar o decorator `cooldown`/
  intervalo já existente para espaçar os despachos em mapas lotados.
- **Cenário de regressão** em `scenarios/` (combo + morte do alvo + multidão),
  conforme o checklist do `CLAUDE.md`.

---

## 7. Fase 6 — Árvore e cenários de demonstração (Eleanor base Filir, p/ vídeo)

Asset de teste/demonstração para o vídeo. Layered sobre as fases anteriores: cada
cenário entra quando a fase que ele exercita fica pronta.

**Árvore `trees/Eleanor - Filir/tree.json`** — `homunType: 52` (Eleanor),
`baseType: 3` (Filir), `config.BaseHomunType: 3`:
- Ramo de combate com **`UseEleanorOffense`** (estilo `auto`) como ataque
  principal, antes de Moonlight/ataque normal/`ChaseTarget`.
- Buffs da base Filir via `UseSkillBuff` explícitos: **Flitting** (`8010`,
  ofensivo) e **Accelerated Flight** (`8011`, defensivo). SBR44 (`8012`) omitido
  (nuke suicida).
- Seguir o dono / ocioso / comandos padrão (reaproveita o esqueleto das árvores
  `Dieter - Amistr` / `Sera - Vanilmirth`).
- *Nota de arquitetura:* a profile da Eleanor **não herda** os buffs da base —
  por isso os nós `UseSkillBuff` explícitos. Evolução opcional (paridade): fazer
  `profileFor` mesclar os buffs do `BaseHomunType` para Homunculus S, e aí
  `UseOffensiveBuff`/`UseDefensiveBuff` automáticos cobririam Flitting/Accelerated
  Flight sem nós explícitos.

**Cenários `scenarios/` (`config.BaseHomunType=3`, `homunType=52`, `baseType=3`)**
— cada um destaca uma capacidade no vídeo e serve de **regressão** headless:
1. **Combo Lutador (alvo isolado)** — 1 monstro isolado, SP/esferas sobrando →
   cadeia power Sonic → Silvervein → Midnight + ganho/gasto de esferas. *(Fase 2)*
2. **Combo Agarrão (alvo forte isolado)** — 1 alvo forte e isolado → Style Change
   + Tinder → C.B.C. → E.Q.C. e a liberação do Flee no fim. *(Fase 3)*
3. **Multidão bloqueia Agarrão** — vários agressores em volta → threat assessment
   **bloqueia** o Agarrão; ela fica no Lutador (salvaguarda anti-Flee=0). *(Fase 3)*
4. **Alvo morre no meio do combo** — alvo com pouco HP que morre após o 1º/2º elo
   → **reset anti-stutter** (não dispara o elo no alvo nulo/novo). *(Fase 2)*
5. *(opcional)* **Boss bloqueia EQC** — alvo com flag `boss` → boss guard: combo
   Agarrão sem o finalizador. *(Fase 3)*

---

## 8. Arquivos a tocar

| Arquivo | Mudança |
|---|---|
| `lua/src/core/perception.lua` | estimar `spheres` por tick (ataque/dano), espelhar em `bb.self` |
| `lua/src/core/skillsys.lua` | `sphereCost`, decremento no `markUsed`, fail-safe |
| `lua/src/data/skill_meta.lua` (ou novo `data/combos.lua`) | tabela §1 (custo/janela/proibição por elo) |
| `lua/src/behaviors/skills.lua` | nó `UseEleanorOffense`; condição `SafeToGrapple` |
| `lua/src/core/blackboard.lua` | configs novas (`AutoComboSpheres`, `SphereTrackFactor`, …) |
| `lua/bootstrap.lua` | registrar arquivo novo se houver |
| `lua/src/sim/runtime.lua` | evento de dano, cast falho, flag `boss` |
| `desktop/editor/editor.js` + `index.html` | painel "Combos da Eleanor" |
| `docs/referencia-nos.md` | documentar `UseEleanorOffense`/`SafeToGrapple` |
| `tools/eleanor_sphere_test.lua` | testes de esferas (Fase 1) |
| `tools/eleanor_combo_test.lua` | testes de combo/estilo (Fase 2) |
| `tools/eleanor_grapple_test.lua` | testes de ameaça/boss (Fase 3) |
| `tools/eleanor_scenarios_test.lua` | regressão dos 5 cenários (Fase 6) |
| `trees/Eleanor - Filir/tree.json` | árvore de demonstração (vídeo) |
| `scenarios/Eleanor - *.json` | cenários de demonstração/regressão (5) |

---

## 9. Catálogo de testes automatizados

Meta: **cada bug conhecido da AzzyAI tem um teste que falha se regredirmos**, e
cada comportamento novo tem um teste positivo. Sem isto a Eleanor não é dada como
pronta.

### 9.1 Como os testes rodam

Padrão dos harness `tools/*_test.lua` (rodam fora do jogo, contra o mundo falso;
saída esperada `RESULTADO: N ok, 0 falhas`). Dois níveis:

- **Unidade** — chama as peças internas direto (`sphereOk`, `stepCombo`,
  `ensureStyle`, `desiredStyle`, `threatCount`) com um blackboard montado à mão.
  Rápido e isola a lógica de decisão.
- **Integração** — via `SIM_DISPATCH` (como o `combo_test.lua` atual): carrega um
  cenário, dá `step`s e valida a **sequência de `intent`s** emitida. É o que
  reproduz os bugs de ponta a ponta.

Cada cenário de demonstração da Fase 6 vira um teste de integração (§9.5) — o
mesmo JSON serve de demo no vídeo **e** de regressão.

### 9.2 Regressão contra os bugs da AzzyAI (prioridade)

| # | Bug AzzyAI (fonte) | Sintoma | Nosso guard | Teste |
|---|---|---|---|---|
| R1 | Stutter-step: alvo morre no meio do combo (doc §7.1; issue #19) | Dispara o próximo elo no alvo nulo → trava ~3s | Reset do combo ao alvo sumir/mudar de identidade | C7, D4 |
| R2 | EQC não deduz esfera (`--No sphere use?`) | Estimador dessincroniza, finalizador "fantasma" | EQC deduz 2; contabilidade por skill | S5 |
| R3 | `EleanorMode` nil→number compare (doc §5.1) | Crash ao avaliar timers do modo errado | Sem FSM com estado; elo só sai no estilo certo | C9, C15 |
| R4 | Loop infinito de Style Change (doc §5.1) | Alterna Lutador↔Agarrão a cada ~0,5s | Trava anti-loop (`allowStyleSwitch`) + janela | C10, C11 |
| R5 | Finalizador sem recurso (doc §3.2) | Midnight/EQC rejeitado → espera cooldown que não houve | Barragem + gate de esfera por elo | C3, C5 |
| R6 | Retarget oportunista corrompe o combo (doc §7.3) | Herda Silvervein no alvo B → colisão de pacote | Estado do combo atrelado ao `targetId` | C8 |
| R7 | Agarrão na multidão (doc §4.2/Artefato 4) | Flee=0 + vários agressores = morte | Threat assessment antes do Tinder | G1, D3 |
| R8 | EQC em Boss/MVP (doc §4.2) | Servidor rejeita o finalizador | Boss guard (poda no elo anterior) | G3, D5 |
| R9 | Over/underflow de esferas | Contagem negativa/acima de 10 | `clamp(0,10)` + invariante | S3, S4, S9 |

### 9.3 `eleanor_sphere_test.lua` — esferas (Fase 1)

- **S1** ganho por ataque: após N ataques despachados, esferas = `min(10, N·0,5)`.
- **S2** ganho por dano recebido: HP do homún cai num tick → `+0,5`.
- **S3** teto: nunca passa de 10 (vários ganhos seguidos).
- **S4** piso: nunca abaixo de 0 (vários gastos seguidos).
- **S5** decremento por custo, **um caso por skill**: Sonic −0, Silvervein −1,
  Midnight −2, Tinder −1, C.B.C. −1, **EQC −2** (trava o bug R2).
- **S6** fail-safe: cast marcado como falho → `−1`.
- **S7** reset ao reinvocar (re-summon zera a contagem).
- **S8** isolamento: homún que não é Eleanor não acumula esferas (não polui estado).
- **S9** *invariante (fuzz)*: para qualquer sequência aleatória de
  ataque/dano/cast/falha, mantém-se `0 ≤ esferas ≤ 10` (1000 iterações).

### 9.4 `eleanor_combo_test.lua` — combo + estilo (Fase 2)

- **C1/C2** ordem das cadeias: power (Sonic→Silvervein→Midnight) e grapple
  (Tinder→C.B.C.→E.Q.C.). *(já existem; manter)*
- **C3** barragem: esferas < `AutoComboSpheres` → não inicia (cai no ataque básico).
- **C4** barragem: esferas ≥ limiar → inicia.
- **C5** gate por elo: finalizador não sai com esferas < custo, mesmo na janela.
- **C6** janela expira → reseta ao INIT (não pula tardiamente pro elo 2).
- **C7** **alvo morre no meio** → reset; **nenhum** `intent` de skill no alvo
  morto/nulo. *(R1)*
- **C8** **retarget** (muda `targetId`) → reset; não herda o step no alvo B. *(R6)*
- **C9** `ensureStyle`: estilo errado p/ a cadeia → emite Style Change antes.
- **C10** anti-loop: ticks seguidos não ficam alternando estilo. *(R4)*
- **C11** `allowStyleSwitch=false` → nunca emite Style Change; usa só o atual. *(R4)*
- **C12** fora de alcance → `UseEleanorOffense` devolve FAILURE (deixa `ChaseTarget`).
- **C13** SP insuficiente → não emite; cai no ataque básico.
- **C14** cooldown do elo → espera (não spamma o mesmo elo).
- **C15** elo só dispara no estilo correto (Sonic não sai em grapple; Tinder não
  sai em power). *(R3)*

### 9.5 `eleanor_grapple_test.lua` — ameaça + boss (Fase 3)

- **G1** multidão (> `grappleThreatLimit` agressores no raio) → não entra em
  grapple; permanece power. *(R7)*
- **G2** isolado (≤ limite) → entra em grapple.
- **G3** boss guard: alvo com flag `boss` → **não** dispara EQC (poda no elo
  anterior). *(R8)*
- **G4** fallback: `style=auto` + inseguro → usa power.
- **G5** liberação do Flee: ao concluir EQC, o estado de grapple encerra
  (flag/persist interna some) — homún volta à mobilidade normal.

### 9.6 `eleanor_scenarios_test.lua` — os 5 cenários (Fase 6, regressão)

Carrega cada JSON de `scenarios/` e afirma o resultado observável:

- **D1** *Combo Lutador (alvo isolado)* → sequência power + esferas evoluindo.
- **D2** *Combo Agarrão (alvo forte isolado)* → Style Change + sequência grapple.
- **D3** *Multidão bloqueia Agarrão* → nunca emite Tinder/Style p/ grapple. *(R7)*
- **D4** *Alvo morre no meio* → reset; sem `intent` no alvo nulo. *(R1)*
- **D5** *Boss bloqueia EQC* → grapple sem o finalizador. *(R8)*

### 9.7 Editor (Fase 4) — smoke

`desktop/host_smoke.js`: carrega árvore com `UseEleanorOffense`, grava/lê os
params pelo painel e valida o schema (níveis por elo, barragem, threat, estilo).

### 9.8 Suporte de simulador necessário (transversal)

`sim/runtime.lua`: delta de HP → evento de dano recebido; campo `failCast` no
cenário p/ exercitar o fail-safe (S6); flag `boss` por entidade (G3/D5);
contagem de agressores no raio (já há `target`/`aggro`); relógio determinístico
(já há `dt`).

### 9.9 Definition of Done (por fase)

Uma fase só fecha quando: todos os testes dela verdes **e** os guards da §9.2 da
fase cobertos **e** a suíte global continua intacta — `texlua tools/bt_test.lua`
(30 ok), `texlua outputs_chk.lua`, e os demais `tools/*_test.lua` relevantes.

---

## Ordem sugerida

**Fase 1 (esferas)** → **Fase 2 (`UseEleanorOffense`)** → **Fase 3 (segurança do
Agarrão)** → **Fase 4 (painel)** → **Fase 5 (polimento)** → **Fase 6 (árvore +
cenários de demonstração)**. Cada fase entra com nó(s) + percepção/config +
**teste texlua** + suporte no simulador. Os cenários da Fase 6 podem ser criados
incrementalmente: o cenário 1/4 logo após a Fase 2, e os 2/3/5 após a Fase 3 —
assim você já tem material de vídeo cedo.
