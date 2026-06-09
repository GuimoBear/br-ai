// s3_backend_test.js — valida o backend ESTÁTICO (modelo novo):
//   cenários/árvores em RAM (não persistem), monsters/skills/summons em localStorage
//   (semeados do S3), handoff em sessionStorage, save=download p/ cenário/árvore.
// Uso: node tools/s3_backend_test.js
'use strict';
const path = require('path');
const ROOT = path.join(__dirname, '..');
const { makeStaticBackend } = require(path.join(ROOT, 'desktop', 'static', 's3_backend.js'));
const { install } = require(path.join(ROOT, 'desktop', 'shared', 'bridge_core.js'));

let pass = 0, fail = 0;
function ok(c, m) { if (c) pass++; else { fail++; console.log('  FAIL- ' + m); } }
function eq(a, b, m) { ok(JSON.stringify(a) === JSON.stringify(b), m + '  (got ' + JSON.stringify(a) + ')'); }

function mkStore() { const m = {}; return { getItem: k => (Object.prototype.hasOwnProperty.call(m, k) ? m[k] : null), setItem: (k, v) => { m[k] = String(v); }, removeItem: k => { delete m[k]; }, _m: m }; }
function mkFetch(files, counter) {
  return async function (url) {
    if (counter) counter.n++;
    if (Object.prototype.hasOwnProperty.call(files, url)) { const b = files[url]; return { ok: true, status: 200, text: async () => b, json: async () => JSON.parse(b), arrayBuffer: async () => Buffer.from(b) }; }
    return { ok: false, status: 404, text: async () => '', json: async () => ({}), arrayBuffer: async () => Buffer.from('') };
  };
}
function mkTarget(backend) {
  const t = {};
  t.BRAI_BUILD = { generate: () => '-- t', generateConfig: () => '-- c', generateMonsters: () => '-- m', generateSkillChoice: () => '-- s', generateSummonChoice: () => '-- su', generateSkillParams: () => '-- sp' };
  t.BRAI_ZIP = { zipBytes: (e) => Buffer.from('ZIP' + e.length) };
  install(backend, t);
  return t;
}

(async function () {
  const files = { 'data/monsters.json': '{"monsters":[{"id":1002}],"groups":[]}', 'data/homun_skills.json': '{"choices":{}}', 'data/homun_summons.json': '{"choices":{}}', 'data/homun_skill_params.json': '{"params":{}}' };
  const local = mkStore(), session = mkStore(), downloads = [], fc = { n: 0 };
  const backend = makeStaticBackend({ fetchImpl: mkFetch(files, fc), localStorage: local, session: session, download: (name, data) => downloads.push({ name, data }), encodeUtf8: s => Buffer.from(s, 'utf8'), luaFiles: { 'AI.lua': '-- ai', 'src/tree_homun.lua': '-- tree', 'src/sim/runtime.lua': '-- sim' }, host: { dispatch: async () => '{}' } });
  const t = mkTarget(backend);

  // 1) cenários/árvores começam VAZIOS (combobox vai começar oculto)
  eq((await t.scenarios.list()).data, [], 'scenarios.list vazio no início');
  eq((await t.trees.list()).data, [], 'trees.list vazio no início');

  // 2) upload (importFile) entra na biblioteca em RAM e aparece na lista
  backend.importFile('scenarios/Cen A.json', '{"grid":{"w":5},"entities":[]}');
  eq((await t.scenarios.list()).data, ['Cen A'], 'cenário importado aparece na lista');
  ok(/"w":5/.test((await t.scenarios.load('Cen A')).data), 'cenário importado carrega da memória');
  backend.importFile('trees/Arv X/tree.json', '{"spec":{"type":"selector"}}');
  eq((await t.trees.list()).data, ['Arv X'], 'árvore importada aparece na lista');

  // 3) save de cenário/árvore = DOWNLOAD (+ memória), nunca localStorage
  await t.scenarios.save('Cen B', '{"grid":{"w":9},"entities":[]}');
  ok(downloads.some(d => d.name === 'Cen B.json'), 'save de cenário dispara download');
  ok((await t.scenarios.list()).data.indexOf('Cen B') >= 0, 'cenário salvo entra na lista da sessão');
  ok(Object.keys(local._m).every(k => k.indexOf('scenario') < 0 && k.indexOf('Cen') < 0), 'nada de cenário no localStorage');

  // 4) monsters/skills/summons: semeia do S3 e PERSISTE no localStorage
  fc.n = 0;
  ok(JSON.parse((await t.monsters.load()).data).monsters.length === 1, 'monsters.load semeia do S3');
  ok(local._m['brai.monsters'] != null, 'monsters seed gravado no localStorage');
  ok(fc.n === 1, '1 fetch no 1º load');
  await t.monsters.load();
  ok(fc.n === 1, '2º load NÃO faz fetch (vem do localStorage)');
  await t.monsters.save('{"monsters":[{"id":1},{"id":2}],"groups":[]}');
  ok(JSON.parse(local._m['brai.monsters']).monsters.length === 2, 'monsters.save persiste no localStorage');
  ok(!downloads.some(d => d.name === 'monsters.json'), 'monsters.save NÃO baixa arquivo');
  await t.skillChoiceIO.load(); ok(local._m['brai.skills'] != null, 'skills semeado no localStorage');
  await t.summonIO.load(); ok(local._m['brai.summons'] != null, 'summons semeado no localStorage');
  await t.skillParamsIO.load(); ok(local._m['brai.skillparams'] != null, 'skillParams semeado no localStorage');

  // 5) import de config (monsters) -> localStorage; export -> download
  backend.importFile('monsters.json', '{"monsters":[{"id":9}],"groups":[]}');
  ok(JSON.parse(local._m['brai.monsters']).monsters[0].id === 9, 'import de monsters vai p/ localStorage');
  downloads.length = 0;
  await backend.exportConfig('monsters.json');
  ok(downloads.some(d => d.name === 'monsters.json'), 'exportConfig baixa monsters.json');

  // 6) handoff: setTree -> sessionStorage (não localStorage)
  await t.brai.dispatch('setTree', '{"spec":1}');
  ok(session._m['brai.simTree'] === '{"spec":1}', 'setTree grava no sessionStorage (handoff)');
  ok(local._m['brai.simTree'] == null, 'handoff NÃO usa localStorage');

  // 7) build: baixa zip, não persiste artefatos
  downloads.length = 0;
  const rb = await t.trees.build('Pkg', JSON.stringify({ spec: { type: 'selector' }, homunType: 50 }));
  ok(rb.ok && downloads.some(d => d.name === 'Pkg.zip'), 'build baixa Pkg.zip');
  ok((await t.trees.list()).data.indexOf('Pkg') < 0, 'build NÃO injeta artefato na biblioteca');

  // 8) invariante de storage: localStorage só tem chaves de config
  ok(Object.keys(local._m).every(k => ['brai.monsters', 'brai.skills', 'brai.summons', 'brai.skillparams'].indexOf(k) >= 0), 'localStorage só contém config (' + Object.keys(local._m).join(',') + ')');

  console.log('\nRESULTADO: ' + pass + ' ok, ' + fail + ' falhas');
  if (fail > 0) process.exit(1);
})().catch(e => { console.error('ERRO no teste:', e); process.exit(1); });
