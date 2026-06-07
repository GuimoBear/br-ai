// s3_backend_test.js — valida o backend ESTÁTICO (defaults do S3 + overlay de upload em
// sessão + save=download) via o núcleo bridge_core, com fetch/storage/download mockados.
// Uso: node tools/s3_backend_test.js
'use strict';
const path = require('path');
const ROOT = path.join(__dirname, '..');
const { makeStaticBackend } = require(path.join(ROOT, 'desktop', 'static', 's3_backend.js'));
const { install } = require(path.join(ROOT, 'desktop', 'shared', 'bridge_core.js'));
const { classify } = require(path.join(ROOT, 'desktop', 'static', 'static_ui.js'));

let pass = 0, fail = 0;
function ok(c, m) { if (c) pass++; else { fail++; console.log('  FAIL- ' + m); } }
function eq(a, b, m) { ok(JSON.stringify(a) === JSON.stringify(b), m + '  (got ' + JSON.stringify(a) + ')'); }

function mkFetch(files) {
  return async function (url) {
    if (Object.prototype.hasOwnProperty.call(files, url)) {
      const body = files[url];
      return { ok: true, status: 200, text: async () => body, json: async () => JSON.parse(body), arrayBuffer: async () => Buffer.from(body) };
    }
    return { ok: false, status: 404, text: async () => '', json: async () => ({}), arrayBuffer: async () => Buffer.from('') };
  };
}
function mkStorage() { const m = {}; return { getItem: k => (Object.prototype.hasOwnProperty.call(m, k) ? m[k] : null), setItem: (k, v) => { m[k] = String(v); }, _m: m }; }
function mkTarget(backend) {
  const t = {};
  t.BRAI_BUILD = { generate: () => '-- t', generateConfig: () => '-- c', generateMonsters: () => '-- m', generateSkillChoice: () => '-- s', generateSummonChoice: () => '-- su' };
  t.BRAI_ZIP = { zipBytes: (e) => Buffer.from('ZIP' + e.length) };
  install(backend, t);
  return t;
}

(async function () {
  const files = {
    'data/manifest.json': JSON.stringify({ trees: ['Amistr Base', 'Eleanor - Filir'], scenarios: ['Padrão', 'Sera - 1'] }),
    ['data/trees/' + encodeURIComponent('Amistr Base') + '.json']: '{"name":"Amistr Base","spec":{"type":"selector"}}',
    ['data/scenarios/' + encodeURIComponent('Padrão') + '.json']: '{"grid":{"w":40,"h":40},"entities":[]}',
    'data/monsters.json': '{"monsters":[{"id":1002}],"groups":[]}',
    'data/homun_skills.json': '{"choices":{"50":{}}}',
  };
  const storage = mkStorage();
  const downloads = [];
  const backend = makeStaticBackend({
    fetchImpl: mkFetch(files),
    storage: storage,
    download: (name, data) => downloads.push({ name, data }),
    encodeUtf8: (s) => Buffer.from(s, 'utf8'),
    luaFiles: { 'AI.lua': '-- ai', 'src/tree_homun.lua': '-- tree', 'src/sim/runtime.lua': '-- sim(excluir)' },
    host: { dispatch: async () => '{}' },
  });
  const t = mkTarget(backend);

  // defaults do S3
  eq((await t.trees.list()).data, ['Amistr Base', 'Eleanor - Filir'], 'trees.list vem do manifest');
  ok(/Amistr Base/.test((await t.trees.load('Amistr Base')).data), 'trees.load busca data/trees/<n>.json');
  eq((await t.scenarios.list()).data, ['Padrão', 'Sera - 1'], 'scenarios.list vem do manifest');
  ok(/grid/.test((await t.scenarios.load('Padrão')).data), 'scenarios.load busca (com encode)');
  ok(JSON.parse((await t.monsters.load()).data).monsters.length === 1, 'monsters.load do S3');
  // default quando ausente
  const backend2 = makeStaticBackend({ fetchImpl: mkFetch({}), storage: mkStorage(), download: () => {}, encodeUtf8: s => Buffer.from(s), luaFiles: {}, host: {} });
  const t2 = mkTarget(backend2);
  eq(JSON.parse((await t2.monsters.load()).data), { monsters: [], groups: [] }, 'monsters.load default quando 404');

  // SAVE = download (+ overlay de sessão), sem localStorage
  const sv = await t.scenarios.save('Meu Cen', '{"grid":{"w":5}}');
  ok(sv.ok, 'scenarios.save ok (canWrite liberado)');
  ok(downloads.some(d => d.name === 'Meu Cen.json'), 'save DISPAROU download do .json');
  ok(storage._m['brai.overlay'] && /Meu Cen/.test(storage._m['brai.overlay']), 'save guardou no overlay de sessão (storage injetado)');
  ok((await t.scenarios.list()).data.indexOf('Meu Cen') >= 0, 'cenário salvo aparece na lista (overlay ∪ manifest)');
  ok(/"w":5/.test((await t.scenarios.load('Meu Cen')).data), 'load do salvo vem do overlay (não do fetch)');

  // importFile (upload) entra no overlay e aparece na lista
  backend.importFile('trees/Importada/tree.json', '{"name":"Importada","spec":{}}');
  ok((await t.trees.list()).data.indexOf('Importada') >= 0, 'árvore importada aparece na lista');
  ok(/Importada/.test((await t.trees.load('Importada')).data), 'árvore importada carrega do overlay');

  // build: baixa zip, NÃO persiste artefatos (writeArtifact no-op)
  downloads.length = 0;
  const before = storage._m['brai.overlay'] || '{}';
  const rb = await t.trees.build('Pkg', JSON.stringify({ spec: { type: 'selector' }, homunType: 50 }));
  ok(rb.ok, 'trees.build ok');
  ok(downloads.some(d => d.name === 'Pkg.zip'), 'build baixou Pkg.zip');
  ok(!/trees\/Pkg\//.test(storage._m['brai.overlay'] || '{}'), 'build NÃO persiste artefatos no overlay');
  // readLuaTree exclui src/sim
  const lt = await backend.readLuaTree();
  ok(lt.every(e => e.rel.indexOf('src/sim/') !== 0), 'readLuaTree exclui src/sim/');

  // classify (static_ui)
  eq(classify('cen.json', { entities: [] }).kind, 'scenario', 'classify: cenário');
  eq(classify('arv.json', { spec: {} }).kind, 'tree', 'classify: árvore (spec)');
  eq(classify('arv.json', { type: 'selector', children: [] }).kind, 'tree', 'classify: árvore (type+children)');
  eq(classify('mon.json', { monsters: [], groups: [] }).kind, 'monsters', 'classify: monstros');
  eq(classify('skills.json', { choices: {} }).kind, 'skills', 'classify: skills');
  eq(classify('homun_summons.json', { choices: {} }).kind, 'summons', 'classify: summons (dica no nome)');

  console.log('\nRESULTADO: ' + pass + ' ok, ' + fail + ' falhas');
  if (fail > 0) process.exit(1);
})().catch(e => { console.error('ERRO no teste:', e); process.exit(1); });
