// trees_io.js — persistência de árvores nomeadas em pastas trees/<nome>/.
// Cada pasta tem: tree.json (árvore + contexto homún/base) e, ao gerar, tree_homun.lua.
const fs = require('fs');
const path = require('path');

function treesDir(root) { return path.join(root, 'trees'); }
function safeName(name) { return String(name || '').replace(/[\\/:*?"<>|]+/g, '_').replace(/\s+/g, ' ').trim(); }
function folderOf(root, name) { return path.join(treesDir(root), safeName(name)); }

function list(root) {
  const d = treesDir(root);
  if (!fs.existsSync(d)) return [];
  return fs.readdirSync(d, { withFileTypes: true })
    .filter(e => e.isDirectory())
    .map(e => e.name)
    .sort((a, b) => a.localeCompare(b));
}

function load(root, name) {
  return fs.readFileSync(path.join(folderOf(root, name), 'tree.json'), 'utf8');
}

function save(root, name, jsonText) {
  const sn = safeName(name);
  if (!sn) throw new Error('nome da árvore vazio');
  const folder = folderOf(root, sn);
  fs.mkdirSync(folder, { recursive: true });
  fs.writeFileSync(path.join(folder, 'tree.json'), jsonText, 'utf8');
  return { name: sn, folder };
}

function writeFile(root, name, filename, text) {
  const sn = safeName(name);
  if (!sn) throw new Error('nome da árvore vazio');
  const folder = folderOf(root, sn);
  fs.mkdirSync(folder, { recursive: true });
  const file = path.join(folder, filename);
  fs.writeFileSync(file, text, 'utf8');
  return { name: sn, file };
}
function buildLua(root, name, luaText) { return writeFile(root, name, 'tree_homun.lua', luaText); }

module.exports = { treesDir, safeName, folderOf, list, load, save, buildLua, writeFile };
