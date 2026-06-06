// monsters_io.js — persistência do catálogo GLOBAL de monstros e grupos.
// Um único arquivo na raiz do projeto (monsters.json), compartilhado por todas
// as árvores. Formato:
//   { monsters: [ { id, desc } ], groups: [ { id, name, members:[ids] } ] }
'use strict';
const fs = require('fs');
const path = require('path');

const FILE = 'monsters.json';
const EMPTY = { monsters: [], groups: [] };

function filePath(root) { return path.join(root, FILE); }

function load(root) {
  const fp = filePath(root);
  if (!fs.existsSync(fp)) return JSON.stringify(EMPTY, null, 2);
  return fs.readFileSync(fp, 'utf8');
}

function save(root, jsonText) {
  // valida o JSON antes de gravar
  const data = JSON.parse(jsonText);
  data.monsters = Array.isArray(data.monsters) ? data.monsters : [];
  data.groups = Array.isArray(data.groups) ? data.groups : [];
  const fp = filePath(root);
  fs.writeFileSync(fp, JSON.stringify(data, null, 2), 'utf8');
  return { path: fp };
}

module.exports = { load, save, filePath, EMPTY };
