// lua_host_core_test.js — valida o núcleo COMUM do host Lua (desktop/shared/lua_host_core.js)
// em Node: parseModuleList (ordem) + create() rodando a BT real no Fengari (espelha host-smoke,
// mas através do MESMO core que a versão estática usa). Uso: node tools/lua_host_core_test.js
'use strict';
const fs = require('fs');
const path = require('path');
const ROOT = path.join(__dirname, '..');
const LUA = path.join(ROOT, 'lua');
const { create, parseModuleList } = require(path.join(ROOT, 'desktop', 'shared', 'lua_host_core.js'));
const F = require(path.join(ROOT, 'desktop', 'node_modules', 'fengari'));

let pass = 0, fail = 0;
function ok(c, m) { if (c) pass++; else { fail++; console.log('  FAIL- ' + m); } }

// --- parseModuleList: ordem/estrutura ---
const boot = fs.readFileSync(path.join(LUA, 'bootstrap.lua'), 'utf8');
const list = parseModuleList(boot);
ok(list[0] === 'src/compat.lua', 'primeiro módulo é src/compat.lua');
ok(list.indexOf('src/tree_homun.lua') >= 0, 'inclui src/tree_homun.lua');
ok(list[list.length - 3] === 'src/sim/json.lua' && list[list.length - 2] === 'src/sim/skill_req_level.lua' && list[list.length - 1] === 'src/sim/runtime.lua', 'termina com os módulos do simulador');
ok(new Set(list).size === list.length, 'sem duplicatas na ordem');
const fcount = (boot.match(/f\(\s*"[^"]+"\s*\)/g) || []).length;
ok(list.length === fcount + 3, 'tamanho = nº de f(...) + 3 (json/skill_req_level/runtime)');

(async function () {
  // --- create(): roda a BT real via Fengari pelo core ---
  const host = create({
    fengari: F,
    getText: function (rel) { return fs.readFileSync(path.join(LUA, rel), 'utf8'); },
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
  ok(Array.isArray(s.tree) && s.tree.length > 0, 'load monta a árvore (' + (s.tree ? s.tree.length : 0) + ' nós)');
  for (let i = 0; i < 50; i++) s = JSON.parse(await host.dispatch('step', ''));
  const mob = s.entities.find(e => e.id === 200);
  ok(mob && mob.hp === 0, 'após 50 passos a IA matou o monstro (hp=' + (mob ? mob.hp : '?') + ')');

  // --- onReadyTree: setTree aplicado na inicialização ---
  const customSpec = { type: 'selector', label: 'root-custom', children: [{ type: 'action', name: 'Idle' }] };
  const host2 = create({
    fengari: F,
    getText: function (rel) { return fs.readFileSync(path.join(LUA, rel), 'utf8'); },
    onReadyTree: function () { return JSON.stringify(customSpec); },
  });
  await host2.ready;
  let s2 = JSON.parse(await host2.dispatch('load', JSON.stringify(scenario)));
  ok(s2.tree.some(n => n.label === 'root-custom'), 'onReadyTree aplica a árvore custom (setTree)');

  console.log('\nRESULTADO: ' + pass + ' ok, ' + fail + ' falhas');
  if (fail > 0) process.exit(1);
})().catch(e => { console.error('ERRO no teste:', e); process.exit(1); });
