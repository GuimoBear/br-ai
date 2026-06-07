// static_host_smoke.js — prova que o BUNDLE Lua gerado pelo build_static roda no Fengari
// pelo MESMO núcleo (lua_host_core) que a página estática usa. Espelha o host-smoke,
// mas lendo os módulos do bundle (não do disco). Uso: node tools/static_host_smoke.js
'use strict';
const fs = require('fs');
const path = require('path');
const os = require('os');
const vm = require('vm');
const ROOT = path.join(__dirname, '..');
const { build } = require(path.join(ROOT, 'tools', 'build_static.js'));
const { create } = require(path.join(ROOT, 'desktop', 'shared', 'lua_host_core.js'));
const F = require(path.join(ROOT, 'desktop', 'node_modules', 'fengari'));

let pass = 0, fail = 0;
function ok(c, m) { if (c) pass++; else { fail++; console.log('  FAIL- ' + m); } }

(async function () {
  const out = fs.mkdtempSync(path.join(os.tmpdir(), 'brai-static-'));
  const r = build(out);
  // carrega o bundle (window.BRAI_LUA_FILES = {...};) num sandbox
  const bundlePath = path.join(out, r.assets['lua-bundle']);
  const sandbox = { window: {} };
  vm.runInNewContext(fs.readFileSync(bundlePath, 'utf8'), sandbox);
  const luaFiles = sandbox.window.BRAI_LUA_FILES;
  ok(luaFiles && luaFiles['bootstrap.lua'], 'bundle contém bootstrap.lua');

  const host = create({
    fengari: F,
    getText: function (rel) { var s = luaFiles[rel]; if (s == null) return Promise.reject(new Error('faltando ' + rel)); return Promise.resolve(s); },
    onReadyTree: function () { return null; },
  });
  await host.ready;
  const scenario = {
    grid: { w: 40, h: 40 }, dt: 50, homunId: 100, ownerId: 1,
    entities: [
      { id: 1, kind: 'owner', x: 10, y: 10, hp: 1000, maxhp: 1000 },
      { id: 100, kind: 'homun', x: 20, y: 20, hp: 100, maxhp: 100, sp: 100, maxsp: 100 },
      { id: 200, kind: 'monster', x: 23, y: 23, hp: 40, maxhp: 40, atk: 5, aggro: 8, etype: 1042 },
    ],
  };
  let s = JSON.parse(await host.dispatch('load', JSON.stringify(scenario)));
  ok(Array.isArray(s.tree) && s.tree.length > 0, 'load monta a árvore a partir do bundle (' + (s.tree ? s.tree.length : 0) + ' nós)');
  for (let i = 0; i < 50; i++) s = JSON.parse(await host.dispatch('step', ''));
  const mob = s.entities.find(e => e.id === 200);
  ok(mob && mob.hp === 0, 'IA matou o monstro rodando do bundle (hp=' + (mob ? mob.hp : '?') + ')');

  console.log('\nRESULTADO: ' + pass + ' ok, ' + fail + ' falhas');
  if (fail > 0) process.exit(1);
})().catch(e => { console.error('ERRO no smoke:', e); process.exit(1); });
