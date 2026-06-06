// scenarios_io.js — persistência de cenários do simulador em scenarios/<nome>.json.
// Um cenário guarda o estado inicial: entidades (homún/dono/monstros/aliados),
// posições, HP/SP, configs dos monstros e o homún/base escolhidos.
const fs = require('fs');
const path = require('path');

function scnDir(root) { return path.join(root, 'scenarios'); }
function safeName(name) { return String(name || '').replace(/[\\/:*?"<>|]+/g, '_').replace(/\s+/g, ' ').trim(); }

function list(root) {
  const d = scnDir(root);
  if (!fs.existsSync(d)) return [];
  return fs.readdirSync(d)
    .filter(f => f.toLowerCase().endsWith('.json'))
    .map(f => f.slice(0, -5))
    .sort((a, b) => a.localeCompare(b));
}

function load(root, name) {
  return fs.readFileSync(path.join(scnDir(root), safeName(name) + '.json'), 'utf8');
}

function save(root, name, jsonText) {
  const sn = safeName(name);
  if (!sn) throw new Error('nome do cenário vazio');
  const d = scnDir(root);
  fs.mkdirSync(d, { recursive: true });
  fs.writeFileSync(path.join(d, sn + '.json'), jsonText, 'utf8');
  return { name: sn };
}

module.exports = { scnDir, safeName, list, load, save };
