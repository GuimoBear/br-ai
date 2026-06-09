// build_static_test.js — valida a SAÍDA do build estático (modelo: index.html=redirect p/ o EDITOR
// [tela principal], editor.html=editor, sim.html=simulador). Sem #braibar, exemplos presentes,
// bundle completo, auto-contenção, ordem de scripts, editor->sim.html. Uso: node tools/build_static_test.js
'use strict';
const fs = require('fs'), path = require('path'), os = require('os'), vm = require('vm');
const ROOT = path.join(__dirname, '..');
const { build } = require(path.join(ROOT, 'tools', 'build_static.js'));
const { parseModuleList } = require(path.join(ROOT, 'desktop', 'shared', 'lua_host_core.js'));
let pass = 0, fail = 0; const ok = (c, m) => { if (c) pass++; else { fail++; console.log('  FAIL- ' + m); } };

const out = fs.mkdtempSync(path.join(os.tmpdir(), 'brai-build-'));
const r = build(out);
const idx = fs.readFileSync(path.join(out, 'index.html'), 'utf8');
const sim = fs.readFileSync(path.join(out, 'sim.html'), 'utf8');
const ed = fs.readFileSync(path.join(out, 'editor.html'), 'utf8');
const manifest = JSON.parse(fs.readFileSync(path.join(out, 'data', 'examples', 'manifest.json'), 'utf8'));

ok(fs.existsSync(path.join(out, 'index.html')), 'index.html gerado');
ok(fs.existsSync(path.join(out, 'sim.html')), 'sim.html gerado');
ok(fs.existsSync(path.join(out, 'editor.html')), 'editor.html gerado');
// TELA PRINCIPAL: index.html redireciona p/ o editor
ok(/url=\.\/editor\.html/.test(idx) && /location\.replace\((['"])\.\/editor\.html\1\)/.test(idx), 'index.html redireciona p/ editor.html (tela principal)');
ok(idx.indexOf('sim.html') >= 0, 'index.html também linka o simulador (fallback)');
// migração (migrar.html + bundle dos módulos do migrador)
ok(fs.existsSync(path.join(out, 'migrar.html')), 'migrar.html gerado');
{ const mig = fs.readFileSync(path.join(out, 'migrar.html'), 'utf8');
  ok(/assets\/migration_bundle\.[0-9a-f]+\.js/.test(mig), 'migrar.html carrega o bundle do migrador');
  ok(/assets\/migration_ui\.[0-9a-f]+\.js/.test(mig), 'migrar.html carrega migration_ui');
  ok(mig.indexOf('../shared/migration') < 0, 'migrar.html sem refs ../shared (auto-contido)');
  ok(sim.indexOf('migrar.html') >= 0 && ed.indexOf('migrar.html') >= 0, 'sim e editor linkam a tela de migração'); }
// braibar removida
ok(sim.indexOf('id="braibar"') < 0, 'sim sem #braibar');
ok(ed.indexOf('id="braibar"') < 0, 'editor sem #braibar');
ok((sim + ed).indexOf('conectar pasta') < 0, 'sem "conectar pasta do projeto"');
// app NÃO semeia cenários/árvores no dropdown
ok(!fs.existsSync(path.join(out, 'data', 'scenarios')), 'sem data/scenarios (upload-only)');
ok(!fs.existsSync(path.join(out, 'data', 'trees')), 'sem data/trees (upload-only)');
// seeds de config
['monsters.json', 'homun_skills.json', 'homun_summons.json'].forEach(g => ok(fs.existsSync(path.join(out, 'data', g)), 'seed data/' + g));
// exemplos p/ baixar
ok(manifest.trees.length > 0 && manifest.scenarios.length > 0, 'manifest de exemplos populado');
manifest.trees.forEach(n => ok(fs.existsSync(path.join(out, 'data', 'examples', 'trees', n + '.json')), 'exemplo árvore: ' + n));
manifest.scenarios.forEach(n => ok(fs.existsSync(path.join(out, 'data', 'examples', 'scenarios', n + '.json')), 'exemplo cenário: ' + n));
// bundle completo
const sandbox = { window: {} }; vm.runInNewContext(fs.readFileSync(path.join(out, r.assets['lua-bundle']), 'utf8'), sandbox);
const luaFiles = sandbox.window.BRAI_LUA_FILES;
parseModuleList(fs.readFileSync(path.join(ROOT, 'lua', 'bootstrap.lua'), 'utf8')).forEach(rel => ok(luaFiles[rel] != null, 'bundle contém ' + rel));
ok(luaFiles['AI.lua'] != null, 'bundle contém AI.lua');
// auto-contenção (páginas reais: sim + editor)
['lib/fengari-web.js', '../shared/', 'fs_bridge.js', 'lua_host_web.js', '../renderer/renderer.js', '../editor/editor.js', '/__brai/'].forEach(bad => { ok(sim.indexOf(bad) < 0, 'sim sem ' + bad); ok(ed.indexOf(bad) < 0, 'editor sem ' + bad); });
const extx = (sim + ed).match(/(?:src|href)\s*=\s*"https?:\/\/[^"]+"/g) || [];
ok(extx.every(u => /cdn\.jsdelivr\.net\/npm\/fengari-web/.test(u)), 'única dep externa: Fengari ' + JSON.stringify(extx));
// scripts nunca apontam p/ .css
function scripts(h) { return (h.match(/<script src="([^"]+)"/g) || []).map(s => s.replace(/<script src="|"/g, '')); }
scripts(sim).concat(scripts(ed)).forEach(s => ok(!/\.css(\?|$)/.test(s), 'script não-css: ' + s));
ok(scripts(ed).some(s => /\/editor\.[0-9a-f]+\.js$/.test(s)), 'editor.html carrega editor.js');
ok(scripts(sim).some(s => /\/renderer\.[0-9a-f]+\.js$/.test(s)), 'sim.html carrega renderer.js');
// ordem (na página do simulador)
const p = (h, s) => h.indexOf(s);
ok(p(sim, r.assets['lua-bundle']) < p(sim, r.assets['static_host']), 'lua-bundle antes de static_host');
ok(p(sim, r.assets['static_host']) < p(sim, r.assets['bridge_core']), 'static_host antes de bridge_core');
ok(p(sim, r.assets['bridge_core']) < p(sim, r.assets['s3_backend']), 'bridge_core antes de s3_backend');
ok(p(sim, r.assets['s3_backend']) < p(sim, r.assets['renderer']), 's3_backend antes de renderer');
// editor -> sim.html (o simulador é uma página real agora; index.html é só redirect)
ok(ed.indexOf('href="./sim.html"') >= 0, 'editor nav/SIM_URL -> ./sim.html');
ok(ed.indexOf('href="./index.html"') < 0, 'editor não aponta p/ index.html (redirect)');
// docs (site de ajuda) copiado + link injetado nas páginas reais
ok(fs.existsSync(path.join(out, 'docs', 'index.html')), 'docs/index.html gerado');
['editor.html','simulador.html','referencia-nos.html','primeiros-passos.html','monstros-e-skills.html','conceitos.html','help.css'].forEach(f => ok(fs.existsSync(path.join(out, 'docs', f)), 'docs/' + f));
ok(fs.existsSync(path.join(out, 'docs', 'img', 'editor-visao-geral.png')), 'docs/img/* (prints) copiados');
ok(r.docs === true, 'build reporta docs:true');
[['sim', sim], ['editor', ed]].forEach(([nm, h]) => {
  ok(/href="docs\/index\.html"/.test(h), nm + '.html linka docs/index.html');
  ok(/docs\/index\.html"[^>]*target="_blank"/.test(h), nm + '.html abre docs em nova aba');
});

// favicon / ícones do site estático
['favicon.ico','favicon.svg','favicon-32.png','apple-touch-icon.png','icon-192.png','icon-512.png','site.webmanifest'].forEach(f => ok(fs.existsSync(path.join(out, f)), 'ícone na raiz: ' + f));
ok(r.icons === true, 'build reporta icons:true');
[['index', idx], ['sim', sim], ['editor', ed]].forEach(([nm, h]) => {
  ok(/rel="icon" href="favicon\.svg"/.test(h), nm + '.html linka favicon.svg');
  ok(/rel="icon" href="favicon\.ico"/.test(h), nm + '.html linka favicon.ico');
  ok(/rel="manifest" href="site\.webmanifest"/.test(h), nm + '.html linka o manifest');
  ok(/name="theme-color"/.test(h), nm + '.html tem theme-color');
});

console.log('\nRESULTADO: ' + pass + ' ok, ' + fail + ' falhas');
if (fail > 0) process.exit(1);
