// installer.js — monta um PACOTE auto-suficiente da IA, pronto p/ a pasta da IA do RO.
// Ao "Gerar Lua", além dos arquivos gerados, copia TODO o runtime Lua (exceto o
// simulador) e produz uma pasta self-contained + um .zip.
//
// Layout do pacote (extrair dentro de <RO>/AI/USER_AI/):
//   AI.lua                       <- entry; define AI(myid); BRAI_BASE='./AI/USER_AI/brai/lua'
//   brai/lua/bootstrap.lua
//   brai/lua/src/**              <- runtime completo (compat, core, data, bt, behaviors, registry)
//   brai/lua/src/tree_homun.lua  <- GERADO (a árvore)
//   brai/lua/src/config.lua      <- GERADO (BaseHomunType, etc.)
//   brai/lua/src/monsters.lua    <- GERADO (catálogo de monstros/grupos)
//   LEIA-ME.txt
'use strict';
const fs = require('fs');
const path = require('path');
const { zipBuffer } = require('./zip');

// pastas/arquivos do runtime que NÃO vão para o jogo (só servem ao simulador/dev)
const EXCLUDE_DIRS = new Set(['sim']);
const EXCLUDE_FILES = new Set(['sim_boot.lua']);

function rmrf(p) { if (fs.existsSync(p)) fs.rmSync(p, { recursive: true, force: true }); }
function ensureDir(p) { fs.mkdirSync(p, { recursive: true }); }

// copia recursivamente luaDir -> destDir, ignorando sim/ e sim_boot.lua; coleta entradas p/ o zip
function copyRuntime(luaDir, destDir, zipPrefix, zipEntries) {
  ensureDir(destDir);
  for (const name of fs.readdirSync(luaDir)) {
    const src = path.join(luaDir, name);
    const st = fs.statSync(src);
    if (st.isDirectory()) {
      if (EXCLUDE_DIRS.has(name)) continue;
      copyRuntime(src, path.join(destDir, name), zipPrefix + name + '/', zipEntries);
    } else {
      if (EXCLUDE_FILES.has(name)) continue;
      const data = fs.readFileSync(src);
      fs.writeFileSync(path.join(destDir, name), data);
      zipEntries.push({ name: zipPrefix + name, data });
    }
  }
}

function readme(name, ctx) {
  return [
    'BR-AI — pacote da IA "' + name + '"',
    '',
    'COMO INSTALAR (servidor oficial / cliente padrao):',
    '1. Copie o conteudo desta pasta (AI.lua e a pasta brai/) para dentro de:',
    '       <pasta do RO>/AI/USER_AI/',
    '   Ficando assim:',
    '       <RO>/AI/USER_AI/AI.lua',
    '       <RO>/AI/USER_AI/brai/lua/...',
    '2. No jogo, ative a IA customizada do homunculo com o comando /hoai',
    '   (digite de novo para desligar).',
    '',
    'OBS:',
    '- O AI.lua usa BRAI_BASE = "./AI/USER_AI/brai/lua" (relativo a pasta do RO).',
    '  Se a sua instalacao usar outro caminho, edite a 1a linha util de AI.lua.',
    '- Homunculo: tipo ' + (ctx.homunType || 0) + (ctx.baseType ? (' / forma base ' + ctx.baseType) : '') + '.',
    '- Este pacote e auto-suficiente: contem todo o runtime necessario.',
    '',
  ].join('\r\n');
}

// Monta o pacote em trees/<safe>/dist/ e o zip trees/<safe>/<safe>.zip
// opts: { root, luaBase, name, spec, ctx, catalog, buildTree, safeName }
function buildPackage(opts) {
  const safe = opts.safeName(opts.name);
  const treeDir = path.join(opts.root, 'trees', safe);
  const distDir = path.join(treeDir, 'dist');
  rmrf(distDir);
  ensureDir(distDir);

  const zipEntries = [];

  // 1) runtime completo -> dist/brai/lua/** (exceto AI.lua, que vai p/ a raiz)
  const luaDest = path.join(distDir, 'brai', 'lua');
  ensureDir(luaDest);
  for (const name of fs.readdirSync(opts.luaBase)) {
    if (name === 'AI.lua') continue;            // entry vai p/ a raiz do pacote
    const src = path.join(opts.luaBase, name);
    const st = fs.statSync(src);
    if (st.isDirectory()) {
      if (EXCLUDE_DIRS.has(name)) continue;
      copyRuntime(src, path.join(luaDest, name), 'brai/lua/' + name + '/', zipEntries);
    } else {
      if (EXCLUDE_FILES.has(name)) continue;
      const data = fs.readFileSync(src);
      fs.writeFileSync(path.join(luaDest, name), data);
      zipEntries.push({ name: 'brai/lua/' + name, data });
    }
  }

  // 2) entry AI.lua -> raiz do pacote
  const aiSrc = path.join(opts.luaBase, 'AI.lua');
  const aiData = fs.readFileSync(aiSrc);
  fs.writeFileSync(path.join(distDir, 'AI.lua'), aiData);
  zipEntries.push({ name: 'AI.lua', data: aiData });

  // 3) arquivos GERADOS -> dist/brai/lua/src/
  const srcDir = path.join(luaDest, 'src');
  ensureDir(srcDir);
  const gen = {
    'tree_homun.lua': opts.buildTree.generate(opts.spec),
    'config.lua': opts.buildTree.generateConfig(opts.ctx || {}),
    'monsters.lua': opts.buildTree.generateMonsters(opts.catalog || { monsters: [], groups: [] }),
    'skill_choice.lua': opts.buildTree.generateSkillChoice(opts.choices || { choices: {} }),
    'summon_choice.lua': opts.buildTree.generateSummonChoice(opts.summonChoices || { choices: {} }),
  };
  for (const [fname, text] of Object.entries(gen)) {
    fs.writeFileSync(path.join(srcDir, fname), text, 'utf8');
    // substitui (ou adiciona) a entrada no zip
    const zname = 'brai/lua/src/' + fname;
    const idx = zipEntries.findIndex(z => z.name === zname);
    const buf = Buffer.from(text, 'utf8');
    if (idx >= 0) zipEntries[idx].data = buf; else zipEntries.push({ name: zname, data: buf });
  }

  // 4) LEIA-ME
  const rm = readme(safe, opts.ctx || {});
  fs.writeFileSync(path.join(distDir, 'LEIA-ME.txt'), rm, 'utf8');
  zipEntries.push({ name: 'LEIA-ME.txt', data: Buffer.from(rm, 'utf8') });

  // 5) zip -> trees/<safe>/<safe>.zip
  const zipPath = path.join(treeDir, safe + '.zip');
  fs.writeFileSync(zipPath, zipBuffer(zipEntries));

  return { distDir, zipPath, fileCount: zipEntries.length };
}

module.exports = { buildPackage };
