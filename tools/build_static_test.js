// build_static_test.js — valida a SAÍDA do build estático: completude do bundle,
// presença dos dados/manifest, ordem dos scripts e auto-contenção (só assets/ + data/
// + Fengari via CDN). Uso: node tools/build_static_test.js
'use strict';
const fs = require('fs');
const path = require('path');
const os = require('os');
const vm = require('vm');
const ROOT = path.join(__dirname, '..');
const { build } = require(path.join(ROOT, 'tools', 'build_static.js'));
const { parseModuleList } = require(path.join(ROOT, 'desktop', 'shared', 'lua_host_core.js'));

let pass = 0, fail = 0;
function ok(c, m) { if (c) pass++; else { fail++; console.log('  FAIL- ' + m); } }

const out = fs.mkdtempSync(path.join(os.tmpdir(), 'brai-build-'));
const r = build(out);
const idx = fs.readFileSync(path.join(out, 'index.html'), 'utf8');
const ed = fs.readFileSync(path.join(out, 'editor.html'), 'utf8');
const manifest = JSON.parse(fs.readFileSync(path.join(out, 'data', 'manifest.json'), 'utf8'));

// páginas + dados
ok(fs.existsSync(path.join(out, 'index.html')), 'index.html gerado');
ok(fs.existsSync(path.join(out, 'editor.html')), 'editor.html gerado');
ok(manifest.trees.length > 0 && manifest.scenarios.length > 0, 'manifest tem árvores e cenários');
manifest.trees.forEach(n => ok(fs.existsSync(path.join(out, 'data', 'trees', n + '.json')), 'data/trees/' + n + '.json existe'));
manifest.scenarios.forEach(n => ok(fs.existsSync(path.join(out, 'data', 'scenarios', n + '.json')), 'data/scenarios presente: ' + n));
['monsters.json', 'homun_skills.json', 'homun_summons.json'].forEach(g => ok(fs.existsSync(path.join(out, 'data', g)), 'data/' + g + ' copiado'));

// completude do bundle Lua
const bundlePath = path.join(out, r.assets['lua-bundle']);
const sandbox = { window: {} };
vm.runInNewContext(fs.readFileSync(bundlePath, 'utf8'), sandbox);
const luaFiles = sandbox.window.BRAI_LUA_FILES;
const need = parseModuleList(fs.readFileSync(path.join(ROOT, 'lua', 'bootstrap.lua'), 'utf8'));
need.forEach(rel => ok(luaFiles[rel] != null, 'bundle contém ' + rel));
ok(luaFiles['AI.lua'] != null, 'bundle contém AI.lua (p/ Gerar Lua)');

// auto-contenção: nada de caminhos da web nas páginas
['lib/fengari-web.js', '../shared/', 'fs_bridge.js', 'lua_host_web.js', '../renderer/renderer.js', '../editor/editor.js', '/__brai/'].forEach(bad => {
  ok(idx.indexOf(bad) < 0, 'index.html sem ref antiga: ' + bad);
  ok(ed.indexOf(bad) < 0, 'editor.html sem ref antiga: ' + bad);
});
// só http(s) externo permitido: jsDelivr (fengari). (svg xmlns é namespace, não fetch)
const ext = (idx + ed).match(/(?:src|href)\s*=\s*"https?:\/\/[^"]+"/g) || [];
ok(ext.every(u => /cdn\.jsdelivr\.net\/npm\/fengari-web/.test(u)), 'única dependência externa é o Fengari (jsDelivr): ' + JSON.stringify(ext));

// ordem dos scripts no index.html
function pos(h, s) { return h.indexOf(s); }
ok(pos(idx, r.assets['lua-bundle']) < pos(idx, r.assets['static_host']), 'lua-bundle antes de static_host');
ok(pos(idx, r.assets['lua_host_core']) < pos(idx, r.assets['static_host']), 'lua_host_core antes de static_host');
ok(pos(idx, r.assets['bridge_core']) < pos(idx, r.assets['s3_backend']), 'bridge_core antes de s3_backend');
ok(pos(idx, r.assets['s3_backend']) < pos(idx, r.assets['renderer']), 's3_backend antes de renderer');
ok(pos(idx, r.assets['static_host']) < pos(idx, r.assets['bridge_core']), 'static_host (BRAIHost) antes de bridge_core');
ok(ed.indexOf("window.BRAI_SIM_URL = './index.html';") >= 0, 'editor aponta o simulador para ./index.html');

console.log('\nRESULTADO: ' + pass + ' ok, ' + fail + ' falhas');
if (fail > 0) process.exit(1);

// --- guarda extra: nenhum <script> aponta para .css (colisão de chave de asset) ---
(function () {
  const idx2 = fs.readFileSync(path.join(out, 'index.html'), 'utf8');
  const ed2 = fs.readFileSync(path.join(out, 'editor.html'), 'utf8');
  function scripts(h) { return (h.match(/<script src="([^"]+)"/g) || []).map(s => s.replace(/<script src="|"/g, '')); }
  scripts(idx2).concat(scripts(ed2)).forEach(function (s) {
    ok(!/\.css(\?|$)/.test(s), 'nenhum <script> aponta para .css: ' + s);
  });
  ok(scripts(ed2).some(s => /\/editor\.[0-9a-f]+\.js$/.test(s)), 'editor.html carrega o editor.js (não o css)');
  ok(scripts(idx2).some(s => /\/renderer\.[0-9a-f]+\.js$/.test(s)), 'index.html carrega o renderer.js');
  console.log('RESULTADO(guarda css): ' + pass + ' ok, ' + fail + ' falhas');
  if (fail > 0) process.exit(1);
})();
