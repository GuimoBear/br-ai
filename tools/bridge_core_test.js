// bridge_core_test.js — valida o CONTRATO do núcleo da ponte (desktop/shared/bridge_core.js)
// com um backend mock. Garante que a refatoração de fs_bridge.js (e o futuro s3_backend.js)
// preservam o comportamento dos globais window.brai/trees/scenarios/monsters/...
// Uso: node tools/bridge_core_test.js
'use strict';
const path = require('path');
const { install } = require(path.join(__dirname, '..', 'desktop', 'shared', 'bridge_core.js'));

let pass = 0, fail = 0;
function ok(cond, msg) { if (cond) { pass++; } else { fail++; console.log('  FAIL- ' + msg); } }
function eq(a, b, msg) { ok(JSON.stringify(a) === JSON.stringify(b), msg + '  (got ' + JSON.stringify(a) + ', want ' + JSON.stringify(b) + ')'); }

function mkBackend(opts) {
  opts = opts || {};
  const fsmap = opts.fs || {};
  const dirs = opts.dirs || {};
  const b = {
    ready: Promise.resolve(),
    canWrite: opts.canWrite || function () { return null; },
    readText: async function (rel) { if (Object.prototype.hasOwnProperty.call(fsmap, rel)) return fsmap[rel]; throw new Error('missing ' + rel); },
    readBytes: async function (rel) { if (Object.prototype.hasOwnProperty.call(fsmap, rel)) return Buffer.from(fsmap[rel]); throw new Error('missing ' + rel); },
    listDir: async function (rel) { return dirs[rel] || { dirs: [], files: [] }; },
    writeData: async function (rel, data) { b._writes.push({ rel, data }); fsmap[rel] = typeof data === 'string' ? data : '<bytes>'; return { ok: true, path: rel }; },
    writeArtifact: async function (rel, data) { b._artifacts.push({ rel, data }); return { ok: true, path: rel }; },
    readLuaTree: async function () { return opts.luaTree || [{ rel: 'AI.lua', data: '-- ai' }, { rel: 'src/tree_homun.lua', data: '-- old' }, { rel: 'src/core/util.lua', data: '-- u' }]; },
    download: function (name, data) { b._downloads.push({ name, data }); },
    host: opts.host || { dispatch: async function (m, a) { return JSON.stringify({ method: m, arg: a }); } },
    rememberTree: function (arg) { b._remembered.push(arg); },
    updateBanner: function () { b._banner++; },
    _writes: [], _artifacts: [], _downloads: [], _remembered: [], _banner: 0, _fs: fsmap,
  };
  return b;
}
function mkTarget(backend) {
  const t = {};
  t.BRAI_BUILD = {
    generate: () => '-- tree', generateConfig: () => '-- cfg', generateMonsters: () => '-- mon',
    generateSkillChoice: () => '-- skill', generateSummonChoice: () => '-- summon',
  };
  t.BRAI_ZIP = { zipBytes: (entries) => Buffer.from('ZIP:' + entries.length) };
  install(backend, t);
  return t;
}

(async function () {
  // --- dispatch ---
  {
    const b = mkBackend(); const t = mkTarget(b);
    const r = await t.brai.dispatch('step', '');
    ok(r.ok === true, 'dispatch retorna ok');
    eq(JSON.parse(r.data).method, 'step', 'dispatch repassa o método ao host');
    await t.brai.dispatch('setTree', '{"x":1}');
    eq(b._remembered, ['{"x":1}'], 'dispatch persiste setTree via rememberTree');
    const b2 = mkBackend({ host: { dispatch: async () => { throw new Error('boom'); } } }); const t2 = mkTarget(b2);
    const e = await t2.brai.dispatch('step', '');
    ok(e.ok === false && /boom/.test(e.error), 'dispatch captura erro do host');
  }
  // --- trees ---
  {
    const b = mkBackend({ dirs: { trees: { dirs: ['B', 'A'], files: [] } }, fs: { 'trees/Foo/tree.json': '{"n":1}' } });
    const t = mkTarget(b);
    eq((await t.trees.list()).data, ['A', 'B'], 'trees.list ordena');
    ok((await t.trees.load('Foo')).data === '{"n":1}', 'trees.load lê tree.json');
    ok((await t.trees.load('Nope')).ok === false, 'trees.load falha em ausente');
    const sv = await t.trees.save('Minha Árvore', '{"spec":{}}');
    ok(sv.ok && sv.name === 'Minha Árvore', 'trees.save retorna nome saneado');
    ok(b._writes.some(w => w.rel === 'trees/Minha Árvore/tree.json'), 'trees.save grava tree.json');
    ok((await t.trees.save('', 'x')).ok === false, 'trees.save recusa nome vazio');
  }
  // --- trees.save gate (canWrite) ---
  {
    const b = mkBackend({ canWrite: () => ({ ok: false, error: 'sem escrita' }) }); const t = mkTarget(b);
    const r = await t.trees.save('X', '{}');
    ok(r.ok === false && r.error === 'sem escrita', 'trees.save respeita canWrite()');
    ok(b._writes.length === 0, 'nada gravado quando canWrite bloqueia');
  }
  // --- trees.build ---
  {
    const b = mkBackend({ fs: { 'monsters.json': '{"monsters":[],"groups":[]}', 'homun_skills.json': '{"choices":{}}', 'homun_summons.json': '{"choices":{}}' } });
    const t = mkTarget(b);
    const r = await t.trees.build('Pacote', JSON.stringify({ spec: { type: 'selector' }, homunType: 50, baseType: 4 }));
    ok(r.ok === true, 'trees.build ok');
    ok(b._artifacts.some(a => a.rel === 'trees/Pacote/tree_homun.lua'), 'build gera tree_homun.lua (artefato)');
    ok(b._artifacts.some(a => a.rel === 'trees/Pacote/Pacote.zip'), 'build grava o zip (artefato)');
    ok(b._downloads.some(d => d.name === 'Pacote.zip'), 'build dispara download do zip');
    ok(r.files >= 4, 'build conta entradas do zip');
  }
  // --- scenarios ---
  {
    const b = mkBackend({ dirs: { scenarios: { dirs: [], files: ['b.json', 'a.json', 'x.txt'] } }, fs: { 'scenarios/a.json': '{"a":1}' } });
    const t = mkTarget(b);
    eq((await t.scenarios.list()).data, ['a', 'b'], 'scenarios.list filtra .json e ordena');
    ok((await t.scenarios.load('a')).data === '{"a":1}', 'scenarios.load lê');
    const sv = await t.scenarios.save('Cen 1', '{"k":1}');
    ok(sv.ok && b._writes.some(w => w.rel === 'scenarios/Cen 1.json'), 'scenarios.save grava .json');
  }
  // --- monsters / skill / summon (default + present + save) ---
  {
    const b = mkBackend(); const t = mkTarget(b);
    eq(JSON.parse((await t.monsters.load()).data), { monsters: [], groups: [] }, 'monsters.load default quando ausente');
    eq(JSON.parse((await t.skillChoiceIO.load()).data), { choices: {} }, 'skillChoiceIO.load default');
    eq(JSON.parse((await t.summonIO.load()).data), { choices: {} }, 'summonIO.load default');
    await t.monsters.save('{"monsters":[1]}'); ok(b._writes.some(w => w.rel === 'monsters.json'), 'monsters.save grava');
    await t.skillChoiceIO.save('{"choices":{"50":{}}}'); ok(b._writes.some(w => w.rel === 'homun_skills.json'), 'skillChoiceIO.save grava');
    await t.summonIO.save('{"choices":{"50":{}}}'); ok(b._writes.some(w => w.rel === 'homun_summons.json'), 'summonIO.save grava');
    const b2 = mkBackend({ fs: { 'monsters.json': '{"monsters":[{"id":1}],"groups":[]}' } }); const t2 = mkTarget(b2);
    ok(JSON.parse((await t2.monsters.load()).data).monsters.length === 1, 'monsters.load lê arquivo presente');
  }
  // --- files (fallbacks do editor) ---
  {
    const b = mkBackend({ fs: { 'desktop/shared/tree_homun.json': '{"spec":{}}' } }); const t = mkTarget(b);
    ok((await t.files.loadTree()).data === '{"spec":{}}', 'files.loadTree lê');
    await t.files.saveTree('{"spec":1}'); ok(b._writes.some(w => w.rel === 'desktop/shared/tree_homun.json'), 'files.saveTree grava');
    await t.files.buildLua('{"type":"selector"}'); ok(b._writes.some(w => w.rel === 'lua/src/tree_homun.lua'), 'files.buildLua gera lua');
    const b2 = mkBackend(); const t2 = mkTarget(b2);
    ok((await t2.files.loadTree()).ok === false, 'files.loadTree falha quando ausente');
  }

  console.log('\nRESULTADO: ' + pass + ' ok, ' + fail + ' falhas');
  if (fail > 0) process.exit(1);
})().catch(e => { console.error('ERRO no teste:', e); process.exit(1); });
