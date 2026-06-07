# Documentação do BR-AI

BR-AI é uma IA de **homúnculos do Ragnarok Online** construída sobre uma **árvore de comportamento** (*behavior tree*, BT) em Lua. A mesma árvore roda em dois lugares sem alteração: dentro do cliente do RO e dentro de um **simulador/depurador** desktop, que permite criar, testar e depurar comportamentos sem depender do jogo a cada iteração.

O projeto tem três pilares:

1. **Motor de BT em Lua** — decide o que o homúnculo faz a cada tick, lendo o estado do mundo e emitindo uma única intenção (mover, atacar, usar skill...).
2. **Editor visual de árvores** — monta a árvore arrastando nós, com paleta dirigida pelos comportamentos reais disponíveis, validação e geração do Lua que roda no jogo.
3. **Simulador/depurador** — roda a mesma árvore Lua contra um mundo falso, com mapa, controle de tempo, replay, inspetor de blackboard e a árvore colorida ao vivo por status de cada nó.

## Por onde começar

| Se você quer... | Leia |
|---|---|
| Entender a arquitetura e o porquê das decisões | [arquitetura.md](arquitetura.md) |
| Criar e editar árvores de comportamento | [guia-editor.md](guia-editor.md) |
| Testar e depurar uma árvore no mundo simulado | [guia-simulador.md](guia-simulador.md) |
| Saber o que cada nó faz e seus parâmetros | [referencia-nos.md](referencia-nos.md) |
| Reagir ao monstro alvo (cadastro de monstros/grupos + nó `monsterCheck`) | [guia-editor.md](guia-editor.md#monstros-e-grupos) · [referencia-nos.md](referencia-nos.md) |
| Mexer no código: testes, behaviors, dados, integração | [desenvolvimento.md](desenvolvimento.md) |

## Documentos de visão (na raiz do projeto)

- [`DESIGN.md`](../DESIGN.md) — documento de design completo: API real do cliente, mapeamento da máquina de estados do AzzyAI para a BT, sistema de Tactics, roadmap por fases.
- [`README.md`](../README.md) — estado atual do projeto e como rodar os testes.
- [`PLANO-PARIDADE-AZZYAI.md`](../PLANO-PARIDADE-AZZYAI.md) — plano de paridade com o AzzyAI 1.56.

## Visão de 30 segundos

```
            ┌──────────────────────────────┐
            │   Árvore de comportamento     │   (Lua, idêntica nos dois ambientes)
            │   lê estado → 1 intenção       │
            └───────────────┬──────────────┘
        ┌───────────────────┴────────────────────┐
        ▼                                         ▼
  Cliente REAL do RO                       Simulador (Electron)
  GetV/Move/Skill nativos            GetV/Move/Skill simulados (mock Lua)
        ▼                                         ▼
   jogo de verdade                  mapa + tempo controlável + depuração
```

A peça que viabiliza isso é `lua/src/core/ro_api.lua`: a **única** interface com o cliente. No jogo ela aponta para as funções nativas; no simulador, para o mock. Nenhum módulo da árvore chama a API nativa diretamente — é o que permite a mesma BT rodar nos dois lados.

## Fluxo de trabalho típico

1. Abra o **editor** e monte (ou edite) uma árvore para um tipo de homúnculo.
2. Clique **▶ Simular** para carregá-la no **simulador**.
3. Pinte um cenário (dono, monstros), rode os ticks, inspecione a árvore colorida e o blackboard.
4. Ajuste a árvore, salve o cenário como caso de regressão.
5. **Gere o Lua** (`tree_homun.lua`) e leve para o cliente do RO.
