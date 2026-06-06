#!/usr/bin/env node
// build_all_dists.js — gera o pacote dist/ + .zip de TODAS as árvores em trees/.
// Espelha o handler "trees:build" do desktop (main.js), mas headless (sem Electron).
// Não precisa de `npm install` (usa só módulos Node puros). Uso:
//   node tools/build_all_dists.js
'use strict';
const fs = require('fs');
const path = require('path');
const root = path.resolve(__dirname, '..');
const luaBase = path.join(root, 'lua');
const buildTree = require('./build_tree');
const installer = require('../desktop/installer');
const treesIo = require('../desktop/trees_io');

function readJson(p, fallback) {
  try { return JSON.parse(fs.readFileSync(p, 'utf8')); } catch (e) { return fallback; }
}
const catalog = readJson(path.join(root, 'monsters.json'), { monsters: [], groups: [] });
const choices = readJson(path.join(root, 'homun_skills.json'), { choices: {} });
const summonChoices = readJson(path.join(root, 'homun_summons.json'), { choices: {} });

const treesDir = path.join(root, 'trees');
const names = fs.readdirSync(treesDir, { withFileTypes: true })
  .filter((e) => e.isDirectory() && fs.existsSync(path.join(treesDir, e.name, 'tree.json')))
  .map((e) => e.name).sort();

let ok = 0, fail = 0;
for (const name of names) {
  try {
    const j = JSON.parse(fs.readFileSync(path.join(treesDir, name, 'tree.json'), 'utf8'));
    const r = installer.buildPackage({
      root, luaBase, name,
      spec: j.spec || j,
      ctx: { homunType: j.homunType, baseType: j.baseType },
      catalog, choices, summonChoices,
      buildTree, safeName: treesIo.safeName,
    });
    ok++;
    console.log('  ok    ' + name.padEnd(28) + ' -> ' + path.relative(root, r.zipPath) + ' (' + r.fileCount + ' arquivos)');
  } catch (e) {
    fail++;
    console.log('  FALHA ' + name + ': ' + (e && e.message || e));
  }
}
console.log('\n' + ok + ' pacote(s) gerados, ' + fail + ' falha(s)');
process.exit(fail ? 1 : 0);
