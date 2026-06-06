// sera_viz_smoke.js — smoke da visualização da Legião da Sera (sem UI real).
// Carrega o renderer.js num ambiente stub (vm) e valida o HTML do painel "Sera —
// Legião invocada" (pips, tier, janela de duração, métricas) e que o overlay no
// canvas não quebra. Uso: node sera_viz_smoke.js
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

function panelFor(sr) {
  const f = { tick: 100, sera: sr, target: 200, entities: [
    { id: 100, kind: 'homun', x: 5, y: 5, motion: 0 },
    { id: 200, kind: 'monster', x: 9, y: 5, motion: 0 },
  ] };
  sandbox.renderSera(f);
  sandbox.drawSeraLegionOverlay(f, 16);   // exercita o overlay (canvas stub) — não pode quebrar
  return els['sera'].innerHTML;
}
let ok = 0, fail = 0;
const chk = (c, n) => { if (c) { ok++; console.log('  ok  - ' + n); } else { fail++; console.log('  FAIL- ' + n); } };

// Legião ativa nível 5 (Luciola), 4/5 vivos, 40s de 60s, dano 1234
let h = panelFor({ active: true, count: 4, max: 5, level: 5, tier: 'Luciola Vespa', remaining: 40000, total: 60000,
  spOk: true, resummonReady: false, damageDealt: 1234, members: [
    { id: 201, x: 6, y: 5, mob: 2160, hpPct: 80, ttl: 40000, target: 200 },
    { id: 202, x: 5, y: 6, mob: 2160, hpPct: 100, ttl: 40000, target: 200 },
    { id: 203, x: 4, y: 5, mob: 2160, hpPct: 60, ttl: 40000, target: 200 },
    { id: 204, x: 6, y: 6, mob: 2160, hpPct: 100, ttl: 40000, target: 200 },
  ] });
chk((h.match(/lg-pip full/g) || []).length === 4, 'pips: 4 cheios p/ 4 vivos');
chk((h.match(/lg-pip empty/g) || []).length === 1, 'pips: 1 vazio (baixa)');
chk(h.includes('4 / 5'), 'mostra 4 / 5');
chk(h.includes('Luciola Vespa') && h.includes('Lv5'), 'badge tier + nível');
chk(h.includes('ativa'), 'badge ativa');
chk(h.includes('40s'), 'tempo restante 40s');
chk(h.includes('1234'), 'dano total do enxame');
chk(h.includes('HP médio 85%'), 'HP médio agregado (85%)');

// Inativa, pronta p/ invocar
h = panelFor({ active: false, count: 0, max: 5, level: 5, tier: 'Luciola Vespa', remaining: 0, total: 60000,
  spOk: true, resummonReady: true, damageDealt: 0, members: [] });
chk((h.match(/lg-pip full/g) || []).length === 0, 'pips: 0 cheios quando vazia');
chk(h.includes('pronta p/ invocar'), 'badge pronta p/ invocar');

// Inativa, sem SP/alvo
h = panelFor({ active: false, count: 0, max: 5, level: 5, tier: 'Luciola Vespa', remaining: 0, total: 60000,
  spOk: false, resummonReady: false, damageDealt: 0, members: [] });
chk(h.includes('sem SP/alvo'), 'badge sem SP/alvo');

// Nível 1 (Hornet), 3/3
h = panelFor({ active: true, count: 3, max: 3, level: 1, tier: 'Hornet', remaining: 20000, total: 20000,
  spOk: true, resummonReady: false, damageDealt: 50, members: [
    { id: 201, x: 6, y: 5, mob: 2158, hpPct: 100, ttl: 20000, target: 200 } ] });
chk(h.includes('Hornet') && h.includes('Lv1'), 'tier Hornet nível 1');
chk(h.includes('3 / 3'), 'mostra 3 / 3');

// não-Sera (sem bloco sera) -> painel escondido, sem erro
sandbox.renderSera({ tick: 1, sera: null, entities: [] });
chk(els['seraPanel'].style.display === 'none', 'painel escondido quando não há legião');

console.log('\nRESULTADO: ' + ok + ' ok, ' + fail + ' falhas');
process.exit(fail ? 1 : 0);
