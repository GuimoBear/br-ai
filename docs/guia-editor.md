# Guia do Editor de Árvores

O editor visual permite **criar, editar, salvar, carregar e gerar** árvores de comportamento como um grafo de arrastar e soltar, sem escrever Lua à mão. A paleta de nós e a validação vêm diretamente dos comportamentos reais registrados no motor, então o editor nunca deixa você montar uma árvore que o jogo não saberia executar.

## Abrir o editor

O editor faz parte do app desktop (Electron). Com o app instalado (veja [guia-simulador.md](guia-simulador.md) para os pré-requisitos):

```bash
cd desktop
npm start
```

No topo do simulador há o link **"Editor de árvores →"**. Você também pode abrir `desktop/editor/index.html` diretamente.

## A tela

A área central é o **canvas** (grafo), onde cada nó é um retângulo ligado aos filhos por linhas. À direita fica o **inspetor**, que mostra as propriedades do nó selecionado. No topo ficam os botões de árvore, e há um indicador de **validação** com a contagem de erros.

- **Selecionar um nó:** clique nele.
- **Mover um nó:** arraste-o pelo canvas.
- **Reparentar:** arraste um nó e solte sobre outro nó válido (ou arraste o ponto de ligação).
- **Reordenar filhos:** arraste o ponto de ligação para mudar a ordem (a ordem define a prioridade num `selector`).
- **Zoom:** roda do mouse (0,3× a 2,2×).
- **Pan:** arraste o fundo do canvas.

## Botões de edição de nós

| Botão | O que faz |
|---|---|
| **+ filho** | Adiciona um nó filho ao nó selecionado. |
| **+ irmão** | Adiciona um nó irmão (mesmo pai) ao selecionado. |
| **excluir** | Remove o nó selecionado (e sua subárvore). |
| **⤢ organizar** | Reorganiza o grafo automaticamente (auto-layout). |

## Botões de árvore

| Botão | O que faz |
|---|---|
| **Nova** | Cria uma árvore vazia numa nova pasta `trees/<nome>/`. |
| **Abrir** | Carrega uma árvore já salva (lista as pastas em `trees/`). |
| **Salvar** | Grava a árvore atual em `trees/<nome>/tree.json`. |
| **Gerar Lua** | Gera o **pacote de instalação** da IA em `trees/<nome>/dist/` + um `.zip` — runtime completo + arquivos gerados, pronto para a pasta da IA do RO. |
| **Padrão** | Carrega a árvore padrão embutida (bom ponto de partida). |
| **▶ Simular** | Envia a árvore atual ao simulador e abre o simulador para testá-la. |

## Tipos de nó

Ao adicionar um nó você escolhe o tipo. O inspetor muda os campos conforme o tipo.

### Composites (aceitam vários filhos)

- **selector** — tenta os filhos em ordem; o primeiro que tem sucesso (ou está em andamento) vence. É um "OU de prioridade".
- **sequence** — executa os filhos em ordem; para no primeiro que falha. É um "E".
- **parallel** — tica todos os filhos; campo **policy**: `all` (sucesso só se todos) ou `any` (sucesso se ao menos um).

### Decorators (um único filho)

- **inverter** — inverte sucesso/falha do filho.
- **succeeder** — força sucesso (torna o ramo opcional).
- **cooldown** — bloqueia o filho por **ms** milissegundos após ele ter sucesso (campo `ms`, inteiro > 0).
- **limiter** — permite o filho ter sucesso no máximo **max** vezes (campo `max` ≥ 1; campo opcional `key`).

### Check (condição com filho opcional)

- **check** — avalia uma condição (`name` + `params`); se verdadeira, executa o filho e devolve o status dele; se falsa, falha sem executar o filho. Sem filho, age como condição pura.
- **monsterCheck** — executa o filho conforme **qual monstro é o alvo atual** (é o monstro escolhido ou está no grupo escolhido), com opção de **negar**. Detalhes em [Monstros e grupos](#monstros-e-grupos).

### Folhas

- **condition** — uma condição do registry (ex.: `HpBelow`, `HasValidTarget`). Tem `name` e, conforme a condição, `params`.
- **action** — uma ação do registry (ex.: `AttackTarget`, `ChaseTarget`, `UseSkill`). Tem `name` e, conforme a ação, `params`.

A lista completa de condições e ações, com seus parâmetros, está em [referencia-nos.md](referencia-nos.md).

## Editar parâmetros no inspetor

Ao selecionar um nó, o inspetor mostra:

- **Tipo** — um dropdown que permite trocar o tipo do nó.
- **Label** — rótulo opcional exibido no canvas e no painel do simulador (ajuda a ler a árvore).
- Campos específicos: **policy** (parallel), **ms** (cooldown), **max**/**key** (limiter), **name** (check/condition/action) e os **params** da condição/ação escolhida.

Os parâmetros são editados ao vivo: digitar um valor já atualiza o modelo da árvore.

### Seletor de skills

As ações de skill (`UseSkill`, `UseSkillBuff`) ganham um **seletor de skills por categoria** no inspetor, em vez de pedir um número cru. As categorias são: **dano alvo único**, **dano em área**, **buff**, **cura**, **especial** e **passiva**. O catálogo é montado a partir do **contexto** atual (tipo de homúnculo e, para Homunculus S, o tipo base), então você só vê skills que aquele homúnculo realmente possui. Para cada skill o inspetor mostra alcance, SP, tempos de cast, recarga e duração.

Além disso, ao escolher um **nível**, o inspetor mostra o **efeito daquele nível** com dados Renewal (ratemyserver): o tipo (físico/mágico/cura/buff/status), o **dano** (% de ATK para skills físicas, % de MATK para mágicas, dano fixo, ou % do HP máx), se há **dano por segundo** (DoT) e por quanto tempo, a **cura** representativa e o **status/debuff** aplicado (com chance e duração), além de uma descrição curta por nível. Esses mesmos dados alimentam os efeitos no simulador.

### Contexto: tipo de homúnculo e base

No editor há seletores de **homúnculo** e **base**. Eles definem qual catálogo de skills aparece e são compartilhados com o simulador (round-trip editor↔simulador), de modo que "▶ Simular" já abre o simulador no tipo certo. O seletor de **base** só fica ativo para os tipos Homunculus S.

## Monstros e grupos

Por padrão a árvore decide só pelo **tipo de homúnculo**. Quando você precisa de ações diferentes conforme **o monstro que está sendo o alvo**, há um cadastro de monstros e grupos e um tipo de nó que reage a eles.

### Cadastrar monstros e grupos

Clique em **Monstros** na barra de ferramentas para abrir o gerenciador:

- **Cadastro de monstros** — informe o **ID** (a classe do monstro no jogo, o `V_TYPE`) e uma **descrição**, e clique em *cadastrar*. Como a lista pode crescer, há uma **busca** por nome ou ID. Cada monstro pode ser removido.
- **Grupos** — crie um grupo com um nome; selecione-o no dropdown e marque, na lista da esquerda, **quais monstros cadastrados pertencem a ele**. Você pode renomear ou excluir o grupo (excluir limpa as referências a ele nos nós da árvore).

O cadastro é **global do projeto**: fica em `monsters.json` na raiz e é compartilhado por todas as árvores. As alterações são salvas automaticamente.

### O nó monsterCheck

Adicione um nó **monsterCheck** (tem **um único filho**). No inspetor você escolhe:

- **Monstro alvo** — um monstro do cadastro (ou nenhum).
- **Grupo** — um grupo do cadastro (ou nenhum).
- **negar** — inverte a condição.

O filho roda quando o monstro alvo **é** o monstro escolhido **ou** **está** no grupo escolhido. Com **negar** marcado, roda quando **não é e não está**. Sem alvo atual, o nó sempre falha. Assim você monta, por exemplo, um ramo "se o alvo é um chefe, use a skill X" ou "ataque normalmente, exceto contra o grupo Y".

Ao **Simular**, o catálogo é enviado ao simulador automaticamente; lá você define a **classe (ID)** de cada monstro no painel do monstro (pode escolher do cadastro) para ver o nó disparar. Ao **Gerar Lua**, além de `tree_homun.lua`, é gerado um `monsters.lua` com o catálogo — copie-o junto para o cliente (o `AI.lua` o carrega automaticamente).

## Validação

O editor valida a árvore continuamente e mostra a contagem de problemas. Tipos de aviso/erro:

- Composite **sem filhos** (aviso).
- Decorator **sem filho** (erro).
- **cooldown** com `ms` inválido (erro).
- **limiter** com `max` inválido (erro).
- **check**/folha com `name` inexistente no registry (erro).
- **params** obrigatórios ausentes (aviso).

Isso impede a maior parte das árvores quebradas antes de chegar ao jogo.

## Formato do arquivo salvo

`trees/<nome>/tree.json`:

```json
{
  "name": "minha-arvore",
  "homunType": 4,
  "baseType": 0,
  "spec": {
    "type": "selector",
    "label": "root",
    "children": [
      { "type": "check", "name": "HasOwnerCommand",
        "child": { "type": "action", "name": "HandleOwnerCommand" } }
    ]
  }
}
```

- `homunType` / `baseType` — o contexto de skills com que a árvore foi montada.
- `spec` — a árvore em si. Cada nó tem `type`, e conforme o tipo: `children` ou `child`, `name`, `params`, `label`. O editor também guarda `_uid` e posições `_x`/`_y` para reabrir o grafo exatamente como você deixou.

## Gerar o pacote de instalação (para o jogo)

**Gerar Lua** monta um **pacote auto-suficiente** da IA, pronto para enviar à pasta da IA do RO. Em `trees/<nome>/` ele cria:

- `dist/` — a pasta do pacote, contendo:
  - `AI.lua` — o ponto de entrada (define `AI(myid)`).
  - `brai/lua/**` — **todo o runtime** necessário (motor de BT, behaviors, dados), já com os arquivos gerados embutidos: `src/tree_homun.lua` (sua árvore), `src/config.lua` (tipo/base) e `src/monsters.lua` (catálogo de monstros/grupos).
  - `LEIA-ME.txt` — instruções de instalação.
- `<nome>.zip` — o mesmo pacote compactado, pronto para enviar/extrair.

O pacote é **self-contained**: não depende do repositório nem do app — basta copiá-lo para o cliente.

### Instalar no RO

1. Extraia o `.zip` (ou copie o conteúdo de `dist/`) para dentro de `<pasta do RO>/AI/USER_AI/`, ficando:
   - `<RO>/AI/USER_AI/AI.lua`
   - `<RO>/AI/USER_AI/brai/lua/...`
2. No jogo, ative a IA customizada do homúnculo com **/hoai** (digite de novo para desligar).

O `AI.lua` usa `BRAI_BASE = "./AI/USER_AI/brai/lua"` (relativo à pasta do RO). Se a sua instalação usar outro caminho, edite a primeira linha útil do `AI.lua`.

## Fluxo recomendado

1. **Padrão** para começar de uma árvore que já funciona, ou **Nova** para do zero.
2. Ajuste a árvore (adicione ramos, troque skills, reordene prioridades).
3. **Salvar**.
4. **▶ Simular** e teste num cenário (veja [guia-simulador.md](guia-simulador.md)).
5. Itere até o comportamento ficar correto.
6. **Gerar Lua** e leve `tree_homun.lua` para o cliente.
