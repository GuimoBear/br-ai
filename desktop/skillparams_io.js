// skillparams_io.js — persistência dos PARÂMETROS de skill por homúnculo/papel.
// Um único arquivo na raiz (homun_skill_params.json), compartilhado por todas as árvores.
// Knobs (AutoMobCount, AoEFixedLevel, HealSelfHP, ...) por papel. Formato:
//   { params: { "<homunType>": { aoeAtk: { AutoMobCount: 1, ... }, ... } } }
'use strict';
const fs = require('fs');
const path = require('path');

const FILE = 'homun_skill_params.json';
const EMPTY = { params: {} };

function filePath(root) { return path.join(root, FILE); }

function load(root) {
  const fp = filePath(root);
  if (!fs.existsSync(fp)) return JSON.stringify(EMPTY, null, 2);
  return fs.readFileSync(fp, 'utf8');
}

function save(root, jsonText) {
  const data = JSON.parse(jsonText);
  data.params = (data.params && typeof data.params === 'object') ? data.params : {};
  const fp = filePath(root);
  fs.writeFileSync(fp, JSON.stringify(data, null, 2), 'utf8');
  return { path: fp };
}

module.exports = { load, save, filePath, EMPTY };
