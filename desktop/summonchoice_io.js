// summonchoice_io.js — persistência da config GLOBAL de invocações por homúnculo.
// Um único arquivo na raiz (homun_summons.json), compartilhado por todas as árvores.
// Formato: { choices: { "<homunType>": { level, resummon, minCount, minMobCount, vsBossOnly } } }
'use strict';
const fs = require('fs');
const path = require('path');

const FILE = 'homun_summons.json';
const EMPTY = { choices: {} };

function filePath(root) { return path.join(root, FILE); }

function load(root) {
  const fp = filePath(root);
  if (!fs.existsSync(fp)) return JSON.stringify(EMPTY, null, 2);
  return fs.readFileSync(fp, 'utf8');
}

function save(root, jsonText) {
  const data = JSON.parse(jsonText);
  data.choices = (data.choices && typeof data.choices === 'object') ? data.choices : {};
  const fp = filePath(root);
  fs.writeFileSync(fp, JSON.stringify(data, null, 2), 'utf8');
  return { path: fp };
}

module.exports = { load, save, filePath, EMPTY };
