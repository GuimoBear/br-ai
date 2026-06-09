# Guia do Simulador / Depurador

O simulador roda a **mesma árvore de comportamento em Lua** que rodaria no cliente do RO, mas contra um **mundo falso** desenhado por você. É a ferramenta mais útil do projeto: você vê o homúnculo seguir, perseguir e atacar num mapa, controla o tempo (passo a passo, replay), e acompanha a **árvore colorida ao vivo** — cada nó pintado pelo status que teve naquele tick. Isso transforma "por que o homún travou?" numa inspeção visual de segundos.

O segredo é a arquitetura "mesma BT, cliente trocável": o simulador apenas substitui o backend de `ro_api.lua` por um mock (`lua/src/sim/runtime.lua`). A árvore não sabe que está num mundo simulado.

## Pré-requisitos e como rodar

- Node.js 18+.
- Acesso à internet para o `npm install` (baixa `electron` e `fengari`).

```bash
cd desktop
npm install
npm start          # abre o simulador
```

Antes da UI, dá para validar a ponte JS↔Lua no terminal:

```bash
npm run host-smoke   # carrega a BT no Fengari e roda ~50 passos sem UI
```

A saída esperada confirma que o homúnculo localizou e matou o monstro pela ponte Fengari.

## A tela

A tela é dividida entre o **mapa** (canvas em grid, 40×40 células), os **controles de tempo**, e os painéis de depuração: **inspetor de blackboard**, **árvore ao vivo**, **skills/buffs ativos** e **log**.

## Controles de tempo (transporte)

| Botão | Atalho | O que faz |
|---|---|---|
| ⏮ | Home | Volta ao primeiro frame gravado. |
| ◀ | ← | Volta 1 frame. |
| ▶ / ⏸ | Espaço | Play / pause. |
| ▶❘ | → | Avança 1 frame. |
| ⤓ | End | Salta para o frame "ao vivo" (presente). |
| ⟲ | — | Reinicia o cenário. |

Há ainda um **controle de velocidade** (slider de FPS) e a **timeline**, uma barra que mostra `frame atual / total` e que você pode arrastar para revisitar qualquer tick passado — inclusive o **estado da árvore daquele tick**.

### AO VIVO vs REPLAY

O simulador grava o histórico de estado por tick (até alguns milhares de frames). Quando você está no presente, está **AO VIVO** e cada passo avança a simulação de verdade. Quando você volta no tempo, está em **REPLAY**: reproduz frames gravados; ao alcançar o presente, volta a avançar ao vivo. Um badge indica em qual modo você está. No passado, clicar no mapa volta ao vivo.

## Interagir com o mapa

Cada entidade aparece como um marcador circular rotulado, com barras de HP/SP: **D** (dono), **H** (homúnculo), **A** (aliado), **M** (monstro).

- **Clique numa célula vazia** — move o dono para lá (veja o homúnculo seguir).
- **Clique num monstro** — comanda o homúnculo a atacá-lo.
- **Clique numa entidade** — seleciona para editar no painel (HP/SP, ataque, agressividade, posição).
- **Arraste uma entidade** — reposiciona em tempo real.

Sobreposições visuais ajudam a entender a decisão: o **alcance de aggro** do monstro selecionado (quadrado pontilhado), os **FX de skills de área** no chão, a linha tracejada da **intenção de movimento** do homúnculo e a linha vermelha de **ataques em progresso**.

### Montar o cenário

Você pinta o mundo: adicione monstros (com HP, ataque, intervalo de ataque e se são agressivos), adicione aliados (úteis para testar a proteção anti-KS), mova o dono, edite os stats de qualquer entidade. O relógio do mundo é **determinístico** (avança por um `dt` fixo por frame), o que torna os testes reproduzíveis — essencial para depurar cooldowns e timeouts.

## Barras de HP e SP no mapa

Cada entidade mostra barras acima de si: **HP** (verde › amarelo › vermelho conforme a porcentagem) e, abaixo, **SP** (azul). Dono, homúnculo e aliados exibem as barras sempre. **Monstros só mostram as barras quando são o alvo atual do homúnculo** (ou quando você clica neles para inspecionar) — assim o mapa não fica poluído com dezenas de barras.

Outros indicadores visuais:

- **Anel amarelo** — o alvo atual do homúnculo. **Anel branco tracejado** — a entidade selecionada (clicada).
- **Linha vermelha sólida** — ataque/skill em andamento, do atacante ao alvo.
- **Linha vermelha pontilhada (sutil)** — ameaça: um monstro que está mirando no homúnculo, no dono ou num aliado.
- **Linha azul tracejada** — a intenção de movimento do homúnculo no tick.

## Efeitos de skill (dados Renewal)

As skills aplicam **efeitos representativos** baseados nos dados Renewal (ratemyserver), em vez de um dano genérico. O homúnculo tem **ATK** e **MATK** editáveis no painel (clique nele): skills **físicas** escalam por ATK e **mágicas** (Caprice, Erase Cutter, Xeno Slasher, Poison Mist, Heilige Stange) por MATK. Os tipos de efeito modelados:

- **Dano direto** — `% do ATK/MATK` por nível, em alvo único ou em área.
- **Dano fixo** — combos grappler da Eleanor (Tinder Breaker, C.B.C., E.Q.C.).
- **% do HP máximo** — Self Destruction (dano em área proporcional ao HP do homúnculo).
- **Dano por segundo (DoT)** — Lava Slide, Blast Forge e Poison Mist criam uma área no chão que **causa dano a cada intervalo** enquanto persiste; você vê o HP do monstro caindo a cada tick.
- **Cura** — cura representativa por % do HP do alvo (Healing Hands, Chaotic, Silent Breeze).
- **Status/debuff** — Paralisia, Atordoamento, Cinzas, etc., marcados no monstro e exibidos no tooltip.

Não são os números exatos do servidor (o mundo simulado não modela todos os atributos de RO), mas reproduzem o **caráter** de cada skill — burst vs. dano contínuo, cura, status. Os mesmos dados aparecem no editor por nível.

## Tooltip no hover (informações do ator)

Passe o mouse sobre qualquer ator no mapa para abrir um **tooltip** com seus dados:

- **Homúnculo** — id, tipo (Vanilmirth, Filir, ...), HP atual/máximo, SP atual/máximo.
- **Dono / aliado** — id, HP atual/máximo, SP atual/máximo.
- **Monstro** — id, classe (`V_TYPE`) com o **nome do cadastro** quando disponível, HP atual/máximo, SP atual/máximo e estado (agressivo/passivo/provocado).

O tooltip **atualiza em tempo real**: enquanto você mantém o mouse sobre o ator durante a simulação (play/replay), os valores que mudam — como o HP perdendo pontos num combate — são refletidos a cada tick. Ele segue o cursor e some ao sair do mapa ou ao arrastar um ator.

## Inspetor de blackboard

Mostra, ao vivo, o que a árvore "enxerga" naquele tick:

- **self** — HP% e SP% (com barra).
- **owner** — se existe, distância até ele, HP%.
- **monsters** — quantos estão à vista.
- **config** — AggroDist, AggroHP, AggroSP, FollowStayBack, MoveBounds, AttackRange, FleeHP.
- **flags** — berserk e standby (chips).
- **intent** — a intenção emitida pela árvore (ex.: "move · chase").
- **target** — ID do alvo atual (0 = nenhum).

## Painel da árvore ao vivo

A árvore inteira é renderizada como uma lista indentada, e **cada nó é colorido pelo status do tick exibido**:

- verde ✓ — **SUCCESS**
- amarelo ▶ — **RUNNING** (em destaque)
- cinza · — **FAILURE** ou não avaliado
- fundo vermelho — uma **ação que falhou**

Isso mostra de imediato **qual ramo a raiz escolheu** e por quê — combinado com a timeline, você "rebobina" até o tick onde o comportamento divergiu e vê exatamente qual condição falhou.

### Skills de cada ação (filhos do nó)

Cada **ação automática de skill** (ataque em área, ataque principal, buffs, cura, castling…) aparece com as **skills que ela resolve** para o homúnculo atual listadas como **filhos** logo abaixo dela — ✦ uma por skill (nome + nível). A skill **efetivamente usada naquele tick acende** (amarelo), então dá pra ver qual escolha o homún fez naquele momento. Dois avisos discretos (⚠) cobrem os casos sem skill:

- **"este tipo não tem esta skill"** — o tipo de homúnculo não tem skill para aquele papel (ex.: o Dieter não tem ataque principal single-target). A ação é simplesmente ignorada.
- **"nenhuma skill selecionada"** — o tipo até tem skills do papel, mas você as removeu todas na tela *Skills por homúnculo*; a ação não será usada até você selecionar pelo menos uma.

**Clique** no nó da ação (ou no filho de skill) para ver a mensagem completa. As skills vêm da MESMA resolução que o motor usa de verdade (perfil + override da tela Skills + forma base do Homunculus S), então o que aparece é exatamente o que o homún fará.

## Skills e buffs ativos

Um painel lista os **cooldowns** em andamento, os **buffs ativos** e os **FX de área** ainda no chão, cada um com uma barra de tempo restante. Útil para confirmar recasts de buff e janelas de recarga.

## Log (TraceAI)

As chamadas de `TraceAI` da árvore são redirecionadas para um painel de log, mostrando as últimas linhas no formato `[tick] mensagem`. Linhas de falha aparecem destacadas. Como tudo é gravado por frame, o log acompanha o replay.

## Cenários: salvar e carregar

Um cenário é um mundo completo (mapa, entidades, config, tipo de homúnculo) salvo como `.json` em `scenarios/`. Use os botões de **salvar** (captura o estado ao vivo atual) e **carregar**. Cenários servem como **casos de regressão**: todo bug reproduzido vira um cenário salvo, que você reabre para confirmar a correção.

Formato (`scenarios/<nome>.json`):

```json
{
  "grid": { "w": 40, "h": 40 },
  "dt": 50,
  "homunId": 100,
  "ownerId": 1,
  "entities": [ /* dono, homún, monstros, aliados */ ],
  "config": { "AggroDist": 12, "AggroHP": 50, "BaseHomunType": 0 },
  "homunType": 4,
  "baseType": 0
}
```

Cada entidade salva preserva os campos editáveis: `hp`/`maxhp`, `sp`/`maxsp`, posição, e — quando se aplicam — `atk` e `matk` (homúnculo), e `atk`, `aggro`, `atkInterval`, `aggressive` e `etype` (classe/ID do monstro). Assim o cenário recarregado reproduz exatamente o que você montou, inclusive ATK/MATK do homúnculo e a classe dos monstros (usada pelos nós `monsterCheck`).

## Vindo do editor

No editor, **▶ Simular** envia a árvore atual ao simulador (junto com o contexto de tipo/base) e abre o simulador para testá-la — sem exportar arquivo manualmente. É o laço de iteração mais rápido: edite → simule → ajuste.

## O que o simulador modela (e o que não)

**Modela bem:** a lógica da árvore e da decisão, com altíssima fidelidade — movimento célula a célula, alcance, aggro de monstros, HP/SP, skills resolvidas pelos mesmos metadados do jogo, tempo determinístico.

**Não substitui o jogo:** comportamentos que dependem de quirks do servidor real (poslag, alocação de IDs, timing fino de cast e a detecção heurística de fim de skill) ainda exigem validação final no cliente. O simulador **reduz**, mas não elimina, esse passo — e cada divergência encontrada no jogo deve virar um cenário de regressão.
