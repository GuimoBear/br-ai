// eleanor_viz_smoke.js — smoke da visualização da Eleanor no simulador (sem UI real).
// Carrega o renderer.js num ambiente stub (vm) e valida o HTML do painel "Eleanor —
// Esferas & Combo" (orbs, stepper, badges) para vários estados. Uso: node eleanor_viz_smoke.js
'use strict';
const fs = require('fs'), vm = require('vm'), path = require('path');
const code = fs.readFileSync(path.join(__dirname, 'renderer', 'renderer.js'), 'utf8');

const ctxProxy = new Proxy({}, { get: () => () => {} });
function fakeEl() {
  return new Proxy({ innerHTML: '', style: {}, dataset: {}, classList: { add() {}, remove() {}, toggle() {} },
    value: '4', max: '0', textContent: '', scrollTop: 0, scrollHeight: 0, offsetWidth: 0, offsetHeight: 0 }, {
    get(t, k) {
      if (k in t) return t[k];
      if (k === 'getContext') return () => ctxProxy;
      if (k === 'closest' || k === 'querySelector') return () => null;
      if (k === 'querySelectorAll') return () => [];
      if (k === 'getBoundingClientRect') return () => ({ left: 0, top: 0, width: 0, height: 0 });
      return () => {};
    }, set(t, k, v) { t[k] = v; return true; } });
}
const els = {};
const document = { getElementById: id => els[id] || (els[id] = fakeEl()), createElement: () => fakeEl(),
  querySelectorAll: () => [], querySelector: () => null, addEventListener() {}, body: fakeEl() };
const windowStub = { addEventListener() {}, innerWidth: 1200, innerHeight: 800,
  brai: { dispatch: async () => ({ ok: true, data: '{}' }) }, devicePixelRatio: 1 };
const sandbox = { document, window: windowStub, console, performance: { now: () => 0 },
  requestAnimationFrame: () => 0, setTimeout, clearTimeout, setInterval, clearInterval, JSON, Math, Set, Map, Date };
sandbox.globalThis = sandbox; vm.createContext(sandbox);
vm.runInContext(code, sandbox);
sandbox.SCENARIO = { homunId: 100, grid: { w: 40, h: 40 } };

function htmlFor(el, tick) {
  const f = { tick: tick || 100, eleanor: el, entities: [{ id: 100, kind: 'homun', x: 5, y: 5, motion: 0 }] };
  sandbox.renderEleanor(f);
  return els['eleanor'].innerHTML;
}
let ok = 0, fail = 0;
const chk = (c, n) => { if (c) { ok++; console.log('  ok  - ' + n); } else { fail++; console.log('  FAIL- ' + n); } };

let h = htmlFor({ spheres: 7.5, style: 'power', rooted: false, step: 2, comboKey: 'power', comboAt: 50 }, 100);
chk((h.match(/el-orb full/g) || []).length === 7, 'orbs: 7 cheios p/ 7.5');
chk((h.match(/el-orb half/g) || []).length === 1, 'orbs: 1 meio p/ 7.5');
chk((h.match(/el-orb empty/g) || []).length === 2, 'orbs: 2 vazios p/ 7.5');
chk(h.includes('7.5 / 10'), 'mostra 7.5 / 10');
chk(/el-step done[^>]*><b>Sonic Claw/.test(h), 'Sonic = done');
chk(/el-step cur[^>]*><b>Silvervein Rush/.test(h), 'Silvervein = cur (passo atual)');
chk(/el-step next[^>]*><b>Midnight Frenzy/.test(h), 'Midnight = next');

h = htmlFor({ spheres: 10, style: 'grapple', rooted: true, step: 1, comboKey: 'grapple', comboAt: 90 }, 100);
chk((h.match(/el-orb full/g) || []).length === 10, 'orbs: 10 cheios p/ 10');
chk(h.includes('enraizada'), 'badge enraizada (rooted/Flee 0)');
chk(h.includes('Agarrão (Grapple)'), 'badge estilo grapple');
chk(/E\.Q\.C\.<\/b><span class="el-cost">💠 2 · ⊘ boss/.test(h), 'EQC: custo 2 + proibido em boss');

h = htmlFor({ spheres: 3, style: 'power', rooted: false, step: 3, comboKey: 'power', comboAt: 0 }, 3000);
chk(!h.includes('el-step done') && !h.includes('el-step cur'), 'janela expirada -> stepper sem destaque');

h = htmlFor({ spheres: 0, style: 'power', rooted: false, step: 0, comboKey: null, comboAt: null }, 100);
chk((h.match(/el-orb full/g) || []).length === 0, 'orbs: 0 cheios p/ 0 esferas');

console.log('\nRESULTADO: ' + ok + ' ok, ' + fail + ' falhas');
process.exit(fail ? 1 : 0);
