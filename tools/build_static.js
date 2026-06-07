// build_static.js — gera a versão ESTÁTICA (S3/CloudFront) do BR-AI em dist-static/.
// Duas páginas (index.html=simulador, editor.html=editor) que reusam renderer.js/editor.js
// SEM modificação; assets com hash no nome (cache imutável); Lua num único bundle;
// defaults em data/ + manifest.json; Fengari via CDN (jsDelivr). Sem segredos.
// Uso: node tools/build_static.js [outDir]     (default: <repo>/dist-static)
'use strict';
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const ROOT = path.join(__dirname, '..');
const FENGARI_CDN = 'https://cdn.jsdelivr.net/npm/fengari-web@0.1.4/dist/fengari-web.js';

function hash(buf) { return crypto.createHash('sha256').update(buf).digest('hex').slice(0, 10); }
function mkdirp(d) { fs.mkdirSync(d, { recursive: true }); }
function walk(dir, base, out) {
  for (const e of fs.readdirSync(dir, { withFileTypes: true })) {
    const abs = path.join(dir, e.name);
    const rel = base ? base + '/' + e.name : e.name;
    if (e.isDirectory()) walk(abs, rel, out); else out[rel] = fs.readFileSync(abs, 'utf8');
  }
  return out;
}

function build(outDir) {
  outDir = outDir || path.join(ROOT, 'dist-static');
  const assetsDir = path.join(outDir, 'assets');
  const dataDir = path.join(outDir, 'data');
  mkdirp(assetsDir); mkdirp(path.join(dataDir, 'trees')); mkdirp(path.join(dataDir, 'scenarios'));

  const A = {}; // chave lógica -> url pública (assets/<base>.<hash>.<ext>)
  function emitAsset(srcRel, key, ext) {
    const content = fs.readFileSync(path.join(ROOT, srcRel));
    const fname = key + '.' + hash(content) + '.' + ext;
    fs.writeFileSync(path.join(assetsDir, fname), content);
    A[key] = 'assets/' + fname;
    return A[key];
  }
  function emitAssetStr(str, key, ext) {
    const buf = Buffer.from(str, 'utf8');
    const fname = key + '.' + hash(buf) + '.' + ext;
    fs.writeFileSync(path.join(assetsDir, fname), buf);
    A[key] = 'assets/' + fname;
    return A[key];
  }

  // 1) Lua bundle (toda a pasta lua/) -> window.BRAI_LUA_FILES
  const luaFiles = walk(path.join(ROOT, 'lua'), '', {});
  emitAssetStr('window.BRAI_LUA_FILES = ' + JSON.stringify(luaFiles) + ';\n', 'lua-bundle', 'js');

  // 2) Assets (com hash) — CHAVES DISTINTAS p/ JS e CSS (evita colisão)
  emitAsset('desktop/web/lib/build_tree_web.js', 'build_tree_web', 'js');
  emitAsset('desktop/web/lib/zip_web.js', 'zip_web', 'js');
  emitAsset('desktop/shared/lua_host_core.js', 'lua_host_core', 'js');
  emitAsset('desktop/static/static_host.js', 'static_host', 'js');
  emitAsset('desktop/shared/bridge_core.js', 'bridge_core', 'js');
  emitAsset('desktop/static/s3_backend.js', 's3_backend', 'js');
  emitAsset('desktop/static/static_ui.js', 'static_ui', 'js');
  emitAsset('desktop/renderer/renderer.js', 'renderer', 'js');
  emitAsset('desktop/editor/editor.js', 'editor', 'js');
  emitAsset('desktop/renderer/style.css', 'style', 'css');
  emitAsset('desktop/editor/editor.css', 'editor_css', 'css');
  emitAsset('desktop/static/static.css', 'static', 'css');

  // 3) Dados (defaults) + manifest
  const trees = [];
  const treesRoot = path.join(ROOT, 'trees');
  for (const name of fs.readdirSync(treesRoot)) {
    const tj = path.join(treesRoot, name, 'tree.json');
    if (fs.existsSync(tj)) { fs.writeFileSync(path.join(dataDir, 'trees', name + '.json'), fs.readFileSync(tj)); trees.push(name); }
  }
  const scenarios = [];
  const scnRoot = path.join(ROOT, 'scenarios');
  if (fs.existsSync(scnRoot)) for (const f of fs.readdirSync(scnRoot)) {
    if (f.toLowerCase().endsWith('.json')) { fs.writeFileSync(path.join(dataDir, 'scenarios', f), fs.readFileSync(path.join(scnRoot, f))); scenarios.push(f.slice(0, -5)); }
  }
  for (const g of ['monsters.json', 'homun_skills.json', 'homun_summons.json']) {
    if (fs.existsSync(path.join(ROOT, g))) fs.writeFileSync(path.join(dataDir, g), fs.readFileSync(path.join(ROOT, g)));
  }
  // fallback do editor (window.files.loadTree) — evita 404 e dá árvore padrão
  const sharedTree = path.join(ROOT, 'desktop/shared/tree_homun.json');
  if (fs.existsSync(sharedTree)) { mkdirp(path.join(dataDir, 'desktop', 'shared')); fs.writeFileSync(path.join(dataDir, 'desktop', 'shared', 'tree_homun.json'), fs.readFileSync(sharedTree)); }
  trees.sort((a, b) => a.localeCompare(b)); scenarios.sort((a, b) => a.localeCompare(b));
  fs.writeFileSync(path.join(dataDir, 'manifest.json'), JSON.stringify({ trees, scenarios, builtAt: new Date().toISOString() }, null, 0));

  // 4) HTMLs (reusa o DOM/ids do renderer/editor; só troca CSS/scripts)
  function tag(src) { return '  <script src="' + src + '"></script>'; }
  function transform(html, appKey, cssKey, isEditor) {
    html = html.replace(
      isEditor ? '<link rel="stylesheet" href="../editor/editor.css" />' : '<link rel="stylesheet" href="../renderer/style.css" />',
      '<link rel="stylesheet" href="' + A[cssKey] + '" />\n  <link rel="stylesheet" href="' + A['static'] + '" />'
    );
    html = html.replace('  <script src="lib/fengari-web.js"></script>', tag(FENGARI_CDN));
    html = html.replace('  <script src="lib/build_tree_web.js"></script>', tag(A['build_tree_web']));
    html = html.replace('  <script src="lib/zip_web.js"></script>', tag(A['zip_web']));
    html = html.replace('  <script src="../shared/lua_host_core.js"></script>', tag(A['lua_host_core']));
    html = html.replace('  <script src="lua_host_web.js"></script>', tag(A['lua-bundle']) + '\n' + tag(A['static_host']));
    html = html.replace('  <script src="../shared/bridge_core.js"></script>', tag(A['bridge_core']));
    html = html.replace('  <script src="fs_bridge.js"></script>', tag(A['s3_backend']) + '\n' + tag(A['static_ui']));
    html = html.replace(isEditor ? '  <script src="../editor/editor.js"></script>' : '  <script src="../renderer/renderer.js"></script>', tag(A[appKey]));
    if (isEditor) html = html.replace("window.BRAI_SIM_URL = './sim.html';", "window.BRAI_SIM_URL = './index.html';");
    return html;
  }
  const simHtml = transform(fs.readFileSync(path.join(ROOT, 'desktop/web/sim.html'), 'utf8'), 'renderer', 'style', false);
  const edHtml = transform(fs.readFileSync(path.join(ROOT, 'desktop/web/editor.html'), 'utf8'), 'editor', 'editor_css', true);
  fs.writeFileSync(path.join(outDir, 'index.html'), simHtml);
  fs.writeFileSync(path.join(outDir, 'editor.html'), edHtml);

  return { outDir, assets: A, manifest: { trees, scenarios }, pages: ['index.html', 'editor.html'] };
}

if (require.main === module) {
  const out = process.argv[2] || path.join(ROOT, 'dist-static');
  const r = build(out);
  console.log('build estático -> ' + r.outDir);
  console.log('  árvores: ' + r.manifest.trees.length + ' | cenários: ' + r.manifest.scenarios.length + ' | assets: ' + Object.keys(r.assets).length);
}
module.exports = { build };
