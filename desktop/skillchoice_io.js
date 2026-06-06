// skillchoice_io.js — persistência da escolha GLOBAL de skills por homúnculo.
// Um único arquivo na raiz (homun_skills.json), compartilhado por todas as árvores.
// Alguns Homunculus S têm mais de uma skill no mesmo papel; aqui escolhe-se qual
// cada ação automática usa. Formato:
//   { choices: { "<homunType>": { mainAtk, aoeAtk, offBuff, defBuff } } }
'use strict';
const fs = require('fs');
const path = require('path');

const FILE = 'homun_skills.json';
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
