# Plano de melhorias de usabilidade — BR-AI

Base: análise dos screenshots do app real (editor + simulador) e do código
(`desktop/editor/editor.js`, `desktop/renderer/renderer.js`, `lua/src/registry.lua`).
Status: **para revisão** — nada executado ainda.

Legenda de veredito: ✅ concordo · 🔁 concordo, mas reenquadrando · ⚠️ concordo com ressalva · 💡 ideia minha.

---

## Editor de árvores

**1. Painel de skill em grade de 2 colunas** — ✅
Hoje é um bloco corrido separado por "·" (difícil de escanear). Proposta: cabeçalho
(nome + chips de categoria/elemento) → grade rótulo/valor (Alcance, SP, Área, Cast,
Recarga, Duração) → linha "Efeito" (dano, DoT, status). Omitir linhas vazias.
Onde: `editor.js → skillInfoHtml`. Esforço: baixo. Impacto: alto.

**2. Tooltips/ajuda nos componentes com exemplos** — ✅
O registry já tem `desc` para condições e ações (já aparece no inspetor). Falta texto
para os **tipos** (selector/sequence/parallel/cooldown/limiter/check/monsterCheck):
criar um dicionário de ajuda (1 linha + 1 exemplo curto) e mostrar no hover do nó e no
inspetor. Onde: novo `help` map + `editor.js`. Esforço: baixo/médio. Impacto: alto.

**3. Traduzir componentes + i18n** — ⚠️ (a ressalva mais importante do plano)
Traduzir o que **aparece na tela**: sim. Mas **não traduzir os identificadores internos**
de tipo (`selector`, `sequence`, `action`…) nem nomes de skill — eles são chaves do
JSON, do registry, do codegen e da portabilidade pro jogo; traduzir quebraria tudo.
Solução: camada leve de i18n (dicionário `pt`/`en`) que mapeia `tipo → rótulo exibido`,
preservando o id. Um framework de i18n completo é prematuro agora — fazer leve, mas já
estruturado pra receber `en` depois. Esforço: médio. Impacto: médio (alto p/ alcance).

**4. No card: tipo em cima, descrição embaixo** — ✅
Hoje o tipo vem por símbolo (!/?/🎯) e o rótulo às vezes some. Proposta: chip de tipo
colorido + rótulo em negrito + sub (params/skill). Ver mockup. Atenção ao espaço
(card é 150×46) — talvez aumentar levemente a altura. Onde: `editor.js →
nodeTitle/nodeSub/renderGraph/nodeClass`. Esforço: médio. Impacto: alto.

**5. Melhorar os botões "+"** — 🔁
Concordo no objetivo, mas o problema real não são os botões e sim o padrão "escolher o
tipo num dropdown e clicar +filho" (pouco intuitivo). Proposta melhor: uma **paleta de
blocos** (ícone + nome + cor por tipo) e/ou um **"+" contextual no próprio nó** que abre
um menu de tipos. Resolve de verdade em vez de só estilizar. Esforço: médio. Impacto: alto.

### Ideias minhas (editor)
- 💡 **Undo/redo** — essencial num editor; hoje não existe. Alto impacto.
- 💡 **Menu de contexto (botão direito)** no nó: +filho/+irmão, trocar tipo, duplicar, excluir.
- 💡 **Duplicar nó/subárvore** (copiar/colar) — não há hoje.
- 💡 **Busca nos seletores** de skill/condição/ação (as listas são longas).
- 💡 **Validação clicável** — clicar no aviso foca/destaca o nó com problema.
- 💡 **Fit-to-screen + minimapa** para árvores grandes (já há zoom/organizar).
- 💡 **Atalhos**: Tab = +filho, Enter = +irmão, Del = excluir, Ctrl+Z/Y.
- 💡 **Templates por tipo de homún** — "comece com um modelo" (reduz a barreira inicial).

---

## Simulador

**1. Texto flutuante de ação sobre as entidades (acumula, some em ~4s)** — ✅
Excelente — vira "combat text" ("Poison Mist Lv5", "ataque básico", "Chaotic Blessing",
dano/cura). Os dados já existem (intent/skill/log no snapshot). Ressalvas: limitar
quantos aparecem juntos e manter curto; e deixar claro que é **texto flutuante** (aparece
sozinho), não tooltip de hover. Onde: `renderer.js → draw` + um buffer de eventos por
entidade. Esforço: médio. Impacto: alto (legibilidade).

**2. i18n do simulador** — ✅
Mesma camada leve do editor (rótulos dos painéis, transporte, legendas). Esforço: baixo
(depois da camada pronta).

**3. Árvore ao vivo mais gráfica (mesmo espaço)** — ✅ (núcleo "criativo")
Hoje é lista de texto com ✓/▶/✗. Proposta (ver mockup): dot de status + barrinha de cor
por tipo + "pulse" no nó que está rodando + mini-barra de recarga nos decorators
(cooldown). O snapshot já traz `status` e `skills/cooldowns`. Onde: `renderer.js →
renderTree`. Esforço: médio. Impacto: alto.

**4. Legenda das cores da árvore** — ✅
Barata e necessária. Importante: hoje **vermelho = ação que falhou**; condição que falha
é fluxo normal (cinza/·). A legenda deve explicar isso: verde = sucesso, amarelo =
rodando, vermelho = ação falhou, cinza = não avaliado. Onde: `sim.html` + `renderer.js`.

### Ideias minhas (simulador)
- 💡 **Barras de HP de todos os monstros (toggle)** — hoje só o alvo mostra HP, então o
  "HP de todos caindo" não aparece. Um botão "mostrar HP de todos" ajuda a ensinar.
- 💡 **Clicar num nó da árvore → "por que falhou"** (liga o log à árvore). Ótimo p/ depurar.
- 💡 **Presets de velocidade** (0,5× / 1× / 2×) além do slider de FPS.
- 💡 **Números de dano/cura flutuantes** (junto do combat text).

---

## Geral

**1. Transição entre simulação e edição** — 🔁 (proposta criativa = "norte" do projeto)
Hoje são duas páginas (`editor.html` ↔ `renderer/index.html`) com reload + `sessionStorage`.
Proposta: **shell único (uma página) com abas "Editor | Simulador"** compartilhando a
**mesma árvore em memória**, permitindo o loop **edição → simulação ao vivo** (edita de um
lado, vê o sim reagir do outro, sem reload). Caminho incremental:
1. Shell com abas + transição animada, preservando estado (já há `sessionStorage`).
2. Sincronizar a árvore ao vivo (`setTree` sem reload) ao alternar.
3. (Opcional) split-view lado a lado para o loop instantâneo.
Esse é o maior ganho de usabilidade do conjunto. Esforço: alto. Impacto: muito alto.

### Ideias minhas (geral)
- 💡 **Onboarding curto / galeria de templates** na primeira abertura (o objetivo do app é
  justamente baixar a barreira de entrada).
- 💡 **Design system unificado** (botões, cores, espaçamento) entre editor e simulador.
- 💡 **Acessibilidade**: foco visível, contraste, navegação por teclado.

---

## Fases sugeridas (ordem recomendada)

- **Fase 1 — Ganhos rápidos (baixo esforço, alto impacto):** legenda de cores da árvore
  (Sim 4) · grade do painel de skill (Ed 1) · chip de tipo + descrição no card (Ed 4) ·
  ajuda/tooltips nos tipos (Ed 2) · validação clicável.
- **Fase 1.5 — Base de i18n:** montar a tabela de strings (pt agora, estrutura p/ en).
- **Fase 2 — Interação do editor:** paleta / "+" contextual (Ed 5) · menu de contexto ·
  undo/redo · duplicar · busca nos seletores · atalhos.
- **Fase 3 — Legibilidade do simulador:** combat text flutuante (Sim 1) · árvore ao vivo
  gráfica (Sim 3) · "por que falhou" ao clicar · toggle de HP · presets de velocidade.
- **Fase 4 — i18n aplicado:** traduzir rótulos do editor + simulador (não os identificadores).
- **Fase 5 — Norte:** shell único com loop edição↔simulação ao vivo + transições ·
  templates / onboarding.

## Pontos a decidir (antes de executar)
1. Por onde começar (Fase 1? simulador? app unificado primeiro?).
2. i18n: só pt-BR por enquanto, ou já estruturar pt+en?
3. Manter o app em duas páginas (incremental) ou ir pro shell único agora?
4. Algum item que você quer cortar ou repriorizar?
