// build_static.js — gera a versão ESTÁTICA (S3/CloudFront) do BR-AI em dist-static/.
// Páginas: index.html=redirect p/ o editor (tela principal), editor.html=editor, sim.html=simulador; reusam renderer.js/editor.js
// SEM modificação; assets com hash; Lua num bundle; Fengari via CDN (jsDelivr).
// Cenários/árvores NÃO são semeados (carregam por upload); ficam só como EXEMPLOS p/ baixar.
// Defaults de monsters/skills/summons vão em data/ (sementes do localStorage).
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
    const abs = path.join(dir, e.name); const rel = base ? base + '/' + e.name : e.name;
    if (e.isDirectory()) walk(abs, rel, out); else out[rel] = fs.readFileSync(abs, 'utf8');
  }
  return out;
}

function copyTree(src, dst) {
  fs.mkdirSync(dst, { recursive: true });
  for (const e of fs.readdirSync(src, { withFileTypes: true })) {
    const s = path.join(src, e.name), d = path.join(dst, e.name);
    if (e.isDirectory()) copyTree(s, d); else fs.copyFileSync(s, d);
  }
}

function indexRedirect() {
  var icons = '<link rel="icon" href="favicon.ico" sizes="32x32" /><link rel="icon" href="favicon.svg" type="image/svg+xml" /><link rel="apple-touch-icon" href="apple-touch-icon.png" /><link rel="manifest" href="site.webmanifest" /><meta name="theme-color" content="#0c141b" />';
  return '<!DOCTYPE html>\n<html lang="pt-BR">\n<head>\n  <meta charset="UTF-8" />\n  <meta name="viewport" content="width=device-width, initial-scale=1" />\n  <meta http-equiv="refresh" content="0; url=./editor.html" />\n  <title>BR-AI</title>\n  ' + icons + '\n  <script>location.replace(\'./editor.html\');</script>\n  <style>body{margin:0;font:15px/1.6 system-ui,sans-serif;background:#0c141b;color:#dfe5ea}.wrap{max-width:720px;margin:0 auto;padding:40px 24px}a{color:#7fd1ff}</style>\n</head>\n<body>\n  <div class="wrap"><p>Abrindo o <strong>editor</strong>\u2026 Se n\u00e3o acontecer, clique: <a href="./editor.html">Editor de \u00e1rvores</a> \u00b7 <a href="./sim.html">Simulador</a>.</p></div>\n</body>\n</html>\n';
}

function build(outDir) {
  outDir = outDir || path.join(ROOT, 'dist-static');
  const assetsDir = path.join(outDir, 'assets');
  const dataDir = path.join(outDir, 'data');
  const exDir = path.join(dataDir, 'examples');
  mkdirp(assetsDir); mkdirp(path.join(exDir, 'trees')); mkdirp(path.join(exDir, 'scenarios'));

  const A = {};
  function emitAsset(srcRel, key, ext) { const c = fs.readFileSync(path.join(ROOT, srcRel)); const f = key + '.' + hash(c) + '.' + ext; const dst = path.join(assetsDir, f); if (!fs.existsSync(dst)) fs.writeFileSync(dst, c); A[key] = 'assets/' + f; return A[key]; }
  function emitAssetStr(str, key, ext) { const b = Buffer.from(str, 'utf8'); const f = key + '.' + hash(b) + '.' + ext; const dst = path.join(assetsDir, f); if (!fs.existsSync(dst)) fs.writeFileSync(dst, b); A[key] = 'assets/' + f; return A[key]; }

  // 1) Lua bundle (toda a pasta lua/)
  emitAssetStr('window.BRAI_LUA_FILES = ' + JSON.stringify(walk(path.join(ROOT, 'lua'), '', {})) + ';\n', 'lua-bundle', 'js');

  // 2) Assets (chaves DISTINTAS p/ JS e CSS)
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

  // 3) Sementes de config (localStorage) + fallback do editor
  for (const g of ['monsters.json', 'homun_skills.json', 'homun_summons.json', 'homun_skill_params.json']) {
    if (fs.existsSync(path.join(ROOT, g))) fs.writeFileSync(path.join(dataDir, g), fs.readFileSync(path.join(ROOT, g)));
  }
  const sharedTree = path.join(ROOT, 'desktop/shared/tree_homun.json');
  if (fs.existsSync(sharedTree)) { mkdirp(path.join(dataDir, 'desktop', 'shared')); fs.writeFileSync(path.join(dataDir, 'desktop', 'shared', 'tree_homun.json'), fs.readFileSync(sharedTree)); }

  // 4) EXEMPLOS p/ baixar (não carregados automaticamente)
  const trees = [], scenarios = [];
  const treesRoot = path.join(ROOT, 'trees');
  if (fs.existsSync(treesRoot)) for (const name of fs.readdirSync(treesRoot)) {
    const tj = path.join(treesRoot, name, 'tree.json');
    if (fs.existsSync(tj)) { fs.writeFileSync(path.join(exDir, 'trees', name + '.json'), fs.readFileSync(tj)); trees.push(name); }
  }
  const scnRoot = path.join(ROOT, 'scenarios');
  if (fs.existsSync(scnRoot)) for (const f of fs.readdirSync(scnRoot)) {
    if (f.toLowerCase().endsWith('.json')) { fs.writeFileSync(path.join(exDir, 'scenarios', f), fs.readFileSync(path.join(scnRoot, f))); scenarios.push(f.slice(0, -5)); }
  }
  trees.sort((a, b) => a.localeCompare(b)); scenarios.sort((a, b) => a.localeCompare(b));
  fs.writeFileSync(path.join(exDir, 'manifest.json'), JSON.stringify({ trees, scenarios, builtAt: new Date().toISOString() }, null, 0));

  // 5) HTMLs (reusa o DOM/ids; troca CSS/scripts; REMOVE a #braibar da web)
  function tag(src) { return '  <script src="' + src + '"></script>'; }
  function transform(html, appKey, cssKey, isEditor) {
    html = html.replace('</title>', '</title><link rel="icon" href="favicon.ico" sizes="32x32" /><link rel="icon" href="favicon.svg" type="image/svg+xml" /><link rel="apple-touch-icon" href="apple-touch-icon.png" /><link rel="manifest" href="site.webmanifest" /><meta name="theme-color" content="#0c141b" />');
    html = html.replace(/[ \t]*<div id="braibar">[\s\S]*?<\/div>\n?/, '');  // remove a barra "conectar pasta" (só web)
    var docsLink = '\n    <a class="nav" href="docs/index.html" target="_blank" rel="noopener" title="Abrir a documentação (nova aba)">❔ Documentação</a>';
    html = html.replace('<a class="nav" href="./sim.html">← Simulador</a>', '<a class="nav" href="./sim.html">← Simulador</a>' + docsLink);
    html = html.replace('<a class="nav" href="./editor.html">Editor de árvores →</a>', '<a class="nav" href="./editor.html">Editor de árvores →</a>' + docsLink);
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
    return html;
  }
  fs.writeFileSync(path.join(outDir, 'sim.html'), transform(fs.readFileSync(path.join(ROOT, 'desktop/web/sim.html'), 'utf8'), 'renderer', 'style', false));
  fs.writeFileSync(path.join(outDir, 'editor.html'), transform(fs.readFileSync(path.join(ROOT, 'desktop/web/editor.html'), 'utf8'), 'editor', 'editor_css', true));
  // index.html é a TELA PRINCIPAL: redireciona p/ o editor (mesma ideia da versão web)
  fs.writeFileSync(path.join(outDir, 'index.html'), indexRedirect());

  // 5b) PAGINA DE MIGRACAO (migrar.html) — bundle dos modulos do migrador (JS puro)
  const MIG_MODS = ['lua_parse', 'symbols', 'zip_read', 'map_config', 'map_skills', 'map_tactics', 'map_misc', 'migrate', 'default_tree'];
  emitAssetStr(MIG_MODS.map(function (n) { return fs.readFileSync(path.join(ROOT, 'desktop/shared/migration', n + '.js'), 'utf8'); }).join('\n;\n'), 'migration_bundle', 'js');
  emitAsset('desktop/web/migration_ui.js', 'migration_ui', 'js');
  if (fs.existsSync(path.join(ROOT, 'desktop/web/migrar.html'))) {
    let mig = fs.readFileSync(path.join(ROOT, 'desktop/web/migrar.html'), 'utf8');
    mig = mig.replace('</title>', '</title><link rel="icon" href="favicon.ico" sizes="32x32" /><link rel="icon" href="favicon.svg" type="image/svg+xml" /><link rel="apple-touch-icon" href="apple-touch-icon.png" /><link rel="manifest" href="site.webmanifest" />');
    mig = mig.replace(/[ \t]*<script src="\.\.\/shared\/migration\/[A-Za-z_]+\.js"><\/script>\n/g, '');
    mig = mig.replace('  <script src="migration_ui.js"></script>', tag(A['migration_bundle']) + '\n' + tag(A['migration_ui']));
    fs.writeFileSync(path.join(outDir, 'migrar.html'), mig);
  }
  ['sim.html', 'editor.html'].forEach(function (p) { try { var h = fs.readFileSync(path.join(outDir, p), 'utf8'); if (h.indexOf('migrar.html') < 0) { h = h.replace('<a class="nav" href="docs/index.html"', '<a class="nav" href="migrar.html" title="Migrar uma AzzyAI">🧬 Migrar AzzyAI</a>\n    <a class="nav" href="docs/index.html"'); fs.writeFileSync(path.join(outDir, p), h); } } catch (e) {} });


  // 6) DOCS (site de ajuda estático) -> dist-static/docs/  (link injetado no transform)
  const helpSrc = path.join(ROOT, 'desktop', 'static', 'help');
  let docs = false; if (fs.existsSync(helpSrc)) { copyTree(helpSrc, path.join(outDir, 'docs')); docs = true; }

  // 7) FAVICON / icones do site estatico -> raiz do dist + manifest
  const favSrc = path.join(ROOT, 'desktop', 'static', 'favicon');
  let icons = false;
  if (fs.existsSync(favSrc)) { for (const f of fs.readdirSync(favSrc)) fs.copyFileSync(path.join(favSrc, f), path.join(outDir, f)); icons = true; }

  return { outDir, assets: A, docs: docs, icons: icons, examples: { trees, scenarios }, pages: ['index.html', 'sim.html', 'editor.html', 'migrar.html'] };
}

if (require.main === module) {
  const out = process.argv[2] || path.join(ROOT, 'dist-static');
  const r = build(out);
  console.log('build estático -> ' + r.outDir);
  console.log('  exemplos: ' + r.examples.trees.length + ' árvores, ' + r.examples.scenarios.length + ' cenários | assets: ' + Object.keys(r.assets).length);
}
module.exports = { build };
