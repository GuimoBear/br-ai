# BR-AI — Desktop (Simulador / Depurador)

App Electron que roda a **mesma BT em Lua** do cliente do RO, porém contra um
**mock do cliente** implementado em `lua/src/sim/runtime.lua`. O Lua é embutido via
**Fengari**; o JS só transporta strings JSON (`SIM_DISPATCH`).

## Pré-requisitos

- Node.js 18+
- Acesso à internet para `npm install` (baixa `electron` e `fengari`).

## Instalar e rodar

```bash
cd desktop
npm install
npm start          # abre o simulador
```

Antes de abrir a UI, dá para validar a ponte JS↔Lua no terminal:

```bash
npm run host-smoke   # carrega a BT no Fengari e roda 50 passos sem UI
```

Saída esperada: o homúnculo localiza e mata o monstro, terminando com
`OK: a IA localizou e matou o monstro pela ponte Fengari.`

## O que dá pra fazer na UI (T1/T2)

- **Transporte**: ⏮ início · ◀ voltar 1 · ▶/⏸ play · ▶❘ avançar 1 · ⤓ vivo · ⟲ reset · velocidade.
- **Timeline / replay**: arraste a linha do tempo para revisitar qualquer tick passado
  (inclusive o estado da árvore daquele tick). O play reproduz os frames gravados e,
  ao alcançar o presente, continua avançando a simulação ao vivo. Badge **AO VIVO / REPLAY**.
- **Atalhos**: Espaço = play/pause · ←/→ = passo · Home = início · End = ao vivo.
- **Clique numa célula**: move o dono (veja o homúnculo seguir). **Clique num monstro**:
  comanda ataque. (No passado, o clique volta ao vivo.)
- **Inspetor de blackboard**: HP/SP, distância do dono, nº de monstros, alvo, intenção e flags.
- **Painel da árvore ao vivo**: cada nó colorido pelo status do tick exibido
  (verde ✓ sucesso, amarelo ▶ RUNNING, cinza · falha/não avaliado).
- **Log** captura o `TraceAI`.

## Arquitetura

```
renderer/ (UI, sem Node)  --IPC-->  main.js  -->  lua_host.js (Fengari)
                                                    └─ carrega lua/** e chama SIM_DISPATCH
```

A lógica de simulação (mock + aplicação de intenção + IA dos monstros + JSON) é
**toda em Lua** (`lua/src/sim/`), testada por `tools/sim_test.lua` com `texlua`/`lua`.
O JS é só wiring + desenho. Trocar o backend de `ro_api.lua` é o que permite a
mesma BT rodar aqui e no cliente real.


## Editor visual de árvores (T3)

Abra pelo link **“Editor de árvores →”** no topo do simulador (ou navegue até `editor/index.html`).

- **Paleta dirigida pelo registry**: os nós de condição/ação disponíveis vêm do
  `BRAI.registry` do runtime Lua — a mesma fonte que o jogo usa. Sem nós inventados.
- **Outliner**: selecione um nó; use `+ filho`, `+ irmão`, `excluir`, `▲`/`▼` para montar a árvore.
- **Inspetor**: troca o tipo do nó, edita rótulo, política (parallel), ms (cooldown),
  max (limiter) e os **parâmetros tipados** (ex.: `HpBelow.pct`) com base no schema do registry.
- **Validação ao vivo**: nós sem filho, params ausentes, nomes inexistentes, kind incompatível.
- **Pré-visualização SVG** da árvore.
- **Salvar JSON** → `desktop/shared/tree_homun.json` (fonte da verdade).
- **Gerar Lua** → `lua/src/tree_homun.lua` (via `tools/build_tree.js`), pronto para o cliente.
- **▶ Simular esta árvore** → injeta a árvore no runtime (`setTree`) e abre o simulador.

Fluxo: editar no graph → **Simular** (feedback imediato) → **Gerar Lua** → rodar no cliente.
O JSON é a fonte da verdade; o `.lua` é gerado.

### Regenerar o Lua pela linha de comando

```bash
node tools/build_tree.js                       # usa desktop/shared/tree_homun.json
node tools/build_tree.js entrada.json saida.lua
```
