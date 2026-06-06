# BR-AI no navegador (editor + simulador)

Roda o **editor de árvores** e o **simulador** no navegador — a **mesma IA em Lua** que roda no Electron e no jogo, via [Fengari](https://fengari.io/) (Lua em JS). Nada da IA foi reescrito: só a casca do Electron foi substituída.

A leitura e a **gravação** nas pastas reais do projeto (`trees/`, `scenarios/`, `monsters.json`) são feitas pelo **servidor local** `serve.js` — que tem acesso ao disco, igual ao processo principal do Electron. A página fala com ele por HTTP. **Não precisa conectar pasta nem dar permissão**, e funciona em qualquer navegador moderno.

## Como rodar

A partir da pasta `desktop/`:

```bash
npm run web
# (equivale a: node web/serve.js)
```

Abra **http://localhost:8000/desktop/web/**. Pronto — o editor e o simulador já enxergam as pastas do projeto.

> Sirva sempre pela raiz do repo (o `npm run web` já faz isso): a página busca o runtime em `/lua/` e lê/grava em `/trees`, `/scenarios`, `/monsters.json`.

## O que funciona

- **Editor**: montar/abrir/salvar árvores em `trees/<nome>/tree.json`, paleta/validação do registry, skills por tipo/base, monstros/grupos (`monsters.json`), **▶ Simular** e **Gerar Lua** (gera `dist/` + `.zip` na pasta da árvore e também baixa o `.zip`).
- **Simulador**: mesma árvore, mundo falso, timeline/replay, blackboard, árvore ao vivo, skills/buffs, log; salvar/carregar cenários em `scenarios/`.

## Arquivos

- `serve.js` — servidor local: serve a raiz e expõe `GET /__brai/list`, `POST /__brai/write`, `GET /__brai/ping`.
- `fs_bridge.js` — implementa `window.brai/trees/scenarios/monsters/files` (mesmo contrato do `preload.js` do Electron) falando com o servidor.
- `lua_host_web.js` — carrega `lua/` por `fetch` (ordem do `bootstrap.lua` + `sim/`) e expõe `window.BRAIHost`.
- `lib/fengari-web.js` — Fengari empacotado p/ navegador (sem CDN). `lib/build_tree_web.js`, `lib/zip_web.js` — codegen e zip.
- `editor.html`, `sim.html`, `index.html` — reusam `../editor/editor.js` e `../renderer/renderer.js` sem alteração.

A versão **Electron continua funcionando** sem mudanças (a única alteração compartilhada foi tornar o "▶ Simular" compatível com ambos via `window.BRAI_SIM_URL`).

## Observação de segurança

O `serve.js` grava arquivos sob a raiz do repo (com proteção contra path traversal). É um servidor de **desenvolvimento local** — não exponha a porta na rede.
