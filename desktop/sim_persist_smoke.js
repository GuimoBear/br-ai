// sim_persist_smoke.js — valida a PERSISTÊNCIA do setup do simulador na troca de
// tela (editor <-> simulador), rodando o renderer.js REAL sob um shim de DOM +
// sessionStorage, e confirmando que o cenário capturado é carregável no runtime
// Lua real. Uso: node sim_persist_smoke.js
'use strict';
const fs = require('fs');
const path = require('path');

const SRC = fs.readFileSync(path.join(__dirname, 'renderer', 'renderer.js'), 'utf8');

let fails = 0, passes = 0;
function ok(cond, msg) { if (cond) { passes++; } else { fails++; console.log('  ✗ FALHA: ' + msg); } }

// ---- shim de ambiente de navegador -----------------------------------------
function makeCtx() { return new Proxy({}, { get(t, k) { return (k in t) ? t[k] : (() => ({ width: 0 })); }, set(t, k, v) { t[k] = v; return true; } }); }
function makeDoc() {
  const els = {};
  function el(id) {
    if (els[id]) return els[id];
    const e = {
      id, value: '', textContent: '', innerHTML: '', disabled: false, checked: false,
      width: 600, height: 600, style: {}, options: [], dataset: {},
      classList: { _s: new Set(), add(c){this._s.add(c);}, remove(c){this._s.delete(c);}, toggle(c,f){f?this._s.add(c):this._s.delete(c);}, contains(c){return this._s.has(c);} },
      onclick: null, oninput: null, onchange: null,
      addEventListener() {}, removeEventListener() {}, dispatchEvent() { return true; },
      appendChild() {}, removeChild() {}, remove() {}, setAttribute() {}, contains() { return false; },
      getBoundingClientRect() { return { left: 0, top: 0, width: 600, height: 600 }; },
      getContext() { return makeCtx(); }, focus() {}, querySelector() { return null; }, closest() { return null; },
    };
    els[id] = e; return e;
  }
  const doc = {
    _els: els,
    getElementById: (id) => el(id),
    createElement: () => el('__tmp_' + Math.random()),
    addEventListener() {}, removeEventListener() {},
    body: el('__body'), documentElement: el('__html'),
  };
  return doc;
}
function makeWin(sessionStorage) {
  const evs = {};
  return {
    _evs: evs,
    addEventListener: (t, fn) => { (evs[t] = evs[t] || []).push(fn); },
    removeEventListener() {},
    sessionStorage,
    innerWidth: 1280, innerHeight: 800,
    // pontes: travam o boot em loadMonsters (1º await) -> restoreSetup/applySimContext já rodaram
    monsters: { load: () => new Promise(() => {}) },
    skillChoiceIO: { load: () => new Promise(() => {}) },
    scenarios: { list: () => new Promise(() => {}) },
    brai: { dispatch: () => new Promise(() => {}) },
  };
}
function makeSession(initial) {
  const m = new Map(Object.entries(initial || {}));
  return { getItem: (k) => (m.has(k) ? m.get(k) : null), setItem: (k, v) => m.set(k, String(v)), removeItem: (k) => m.delete(k), _map: m };
}
const perf = { now: () => 0 };
const gcs = () => ({ getPropertyValue: () => '#000000' });

// carrega o renderer.js como uma "página", devolvendo handles internos
function loadPage(win, doc, ss) {
  const factory = new Function('window', 'document', 'sessionStorage', 'performance', 'getComputedStyle', 'console',
    SRC + '\n;return { persistSetup, restoreSetup, captureScenario, scenarioForFile, SCENARIO,' +
    ' get frames(){return frames}, set frames(v){frames=v},' +
    ' get showAllHp(){return showAllHp}, set showAllHp(v){showAllHp=v} };');
  return factory(win, doc, ss, perf, gcs, console);
}

// ============================================================================
console.log('TESTE 1 — persistSetup captura cenário (frame 0) + UI');
const ss1 = makeSession();
const doc1 = makeDoc(), win1 = makeWin(ss1);
const p1 = loadPage(win1, doc1, ss1);
ok((win1._evs.beforeunload || []).length === 1, 'boot registra beforeunload=persistSetup');

// usuário monta o setup
doc1.getElementById('homun').value = '52';   // Eleanor
doc1.getElementById('base').value = '3';      // Filir
doc1.getElementById('speed').value = '12';
doc1.getElementById('mapsize').value = '800';
doc1.getElementById('scnName').value = 'boss';
doc1.getElementById('scnList').value = 'boss';
p1.showAllHp = true;
p1.frames = [{ grid: { w: 40, h: 40 }, entities: [
  { id: 1, kind: 'owner', x: 10, y: 10, hp: 1000, maxhp: 1000 },
  { id: 100, kind: 'homun', x: 20, y: 20, hp: 100, maxhp: 100, sp: 100, maxsp: 100, motion: 0 },
  { id: 200, kind: 'monster', x: 24, y: 23, hp: 60, maxhp: 60, atk: 6, aggro: 9, etype: 1042, aggressive: true, motion: 0 },
  { id: 202, kind: 'monster', x: 30, y: 18, hp: 300, maxhp: 300, atk: 6, aggro: 10, etype: 1042, aggressive: true, boss: true, motion: 0 },
] }];

// dispara como o beforeunload faria
(win1._evs.beforeunload[0])();
const saved = JSON.parse(ss1.getItem('brai.simSetup'));
ok(!!saved && !!saved.scenario, 'simSetup salvo com scenario');
ok(saved.scenario.entities.length === 4, 'cenário tem 4 entidades (incl. monstro adicionado): ' + saved.scenario.entities.length);
const m202 = saved.scenario.entities.find(e => e.id === 202);
ok(!!m202 && m202.boss === true, 'monstro 202 preservado com flag boss');
const homunE = saved.scenario.entities.find(e => e.kind === 'homun');
ok(homunE && homunE.homunType === 52, 'homún salvo com homunType=52 (Eleanor): ' + (homunE && homunE.homunType));
ok(saved.ui.homun === '52' && saved.ui.base === '3', 'UI homún/base salvos');
ok(saved.ui.speed === '12' && saved.ui.mapsize === '800', 'UI velocidade/mapa salvos');
ok(saved.ui.scnName === 'boss' && saved.ui.scnListSel === 'boss', 'UI nome/seleção de cenário salvos');
ok(saved.ui.showAllHp === true, 'UI showAllHp salvo');

// ============================================================================
console.log('TESTE 2 — restore via "Simular" do editor (simContext sobrescreve homún, one-shot)');
const ss2 = makeSession({ 'brai.simSetup': ss1.getItem('brai.simSetup'), 'brai.simContext': JSON.stringify({ homunType: 3, baseType: 0 }) });
const doc2 = makeDoc(), win2 = makeWin(ss2);
const p2 = loadPage(win2, doc2, ss2);   // boot roda restoreSetup + applySimContext sincronamente
ok(p2.SCENARIO.entities.length === 4, 'cenário restaurado tem 4 entidades');
ok(!!p2.SCENARIO.entities.find(e => e.id === 202), 'monstro 202 restaurado no SCENARIO');
ok(doc2.getElementById('homun').value === '3', 'homún sobrescrito pelo editor (Filir=3): ' + doc2.getElementById('homun').value);
ok(doc2.getElementById('mapsize').value === '800', 'mapa restaurado (800)');
ok(doc2.getElementById('grid').width === 800, 'canvas redimensionado p/ 800: ' + doc2.getElementById('grid').width);
ok(doc2.getElementById('scnName').value === 'boss', 'nome do cenário restaurado');
ok(ss2.getItem('brai.simContext') === null, 'simContext consumido (one-shot)');
ok((win2._evs.beforeunload || []).length === 1, 'beforeunload registrado no boot');

// ============================================================================
console.log('TESTE 3 — restore via link de navegação (sem simContext: mantém o homún do simulador)');
const ss3 = makeSession({ 'brai.simSetup': ss1.getItem('brai.simSetup') });
const doc3 = makeDoc(), win3 = makeWin(ss3);
const p3 = loadPage(win3, doc3, ss3);
ok(doc3.getElementById('homun').value === '52', 'homún do simulador mantido (Eleanor=52): ' + doc3.getElementById('homun').value);
ok(doc3.getElementById('base').value === '3', 'base do simulador mantida (Filir=3)');

// ============================================================================
console.log('TESTE 4 — boot SEM estado salvo não quebra (1ª execução)');
const ss4 = makeSession();
const doc4 = makeDoc(), win4 = makeWin(ss4);
const p4 = loadPage(win4, doc4, ss4);
ok(p4.SCENARIO.entities.length === 4, 'SCENARIO padrão intacto (4 entidades)');
ok(ss4.getItem('brai.simSetup') === null, 'nada salvo ainda (sem beforeunload disparado)');

// ============================================================================
console.log('TESTE 5 — o cenário capturado é carregável no runtime Lua REAL');
try {
  const luaHost = require('./lua_host');
  luaHost.init(path.join(__dirname, '..', 'lua'));
  const scn = JSON.parse(ss1.getItem('brai.simSetup')).scenario;
  const s0 = JSON.parse(luaHost.dispatch('load', JSON.stringify(scn)));
  ok(s0.tick === 0, 'load reseta tick=0: ' + s0.tick);
  ok(Array.isArray(s0.entities) && s0.entities.length === 4, 'mundo carregado com 4 entidades: ' + (s0.entities && s0.entities.length));
  ok(!!s0.entities.find(e => e.id === 202), 'monstro 202 presente no mundo Lua');
  let sN = s0; for (let i = 0; i < 5; i++) sN = JSON.parse(luaHost.dispatch('step', ''));
  ok(sN.tick === 250, 'avança 5 passos sem erro (tick=250): ' + sN.tick);
} catch (e) {
  fails++; console.log('  ✗ FALHA: runtime Lua: ' + (e && e.message || e));
}

// ============================================================================
// ============================================================================
console.log('TESTE 6 — arquivo de cenário IGNORA o homúnculo (não persiste info do homún)');
{
  const ssX = makeSession();
  const docX = makeDoc(), winX = makeWin(ssX);
  const pX = loadPage(winX, docX, ssX);
  docX.getElementById('homun').value = '52'; docX.getElementById('base').value = '3';
  pX.frames = [{ grid: { w: 40, h: 40 }, entities: [
    { id: 1, kind: 'owner', x: 10, y: 10, hp: 1000, maxhp: 1000 },
    { id: 100, kind: 'homun', x: 20, y: 20, hp: 100, maxhp: 100, sp: 100, maxsp: 100, homunType: 52, motion: 0 },
    { id: 200, kind: 'monster', x: 24, y: 23, hp: 60, maxhp: 60, atk: 6, aggro: 9, etype: 1042, aggressive: true, motion: 0 },
  ] }];
  const full = pX.captureScenario(pX.frames[0]);
  const file = pX.scenarioForFile(full);
  // a captura de SESSÃO mantém o homún (handoff editor->sim)
  ok(!!full.entities.find(e => e.kind === 'homun'), 'sessão (captureScenario) AINDA tem o homún');
  ok(full.homunType === 52, 'sessão mantém homunType');
  // o ARQUIVO não tem nada do homún
  ok(!file.entities.find(e => e.kind === 'homun'), 'arquivo: SEM entidade homún');
  ok(file.homunType === undefined && file.baseType === undefined, 'arquivo: SEM homunType/baseType');
  ok(!file.config || file.config.BaseHomunType === undefined, 'arquivo: SEM config.BaseHomunType');
  ok(file.entities.some(e => e.kind === 'owner') && file.entities.some(e => e.kind === 'monster'), 'arquivo: mundo (dono+monstro) preservado');
}

console.log('\nRESULTADO: ' + passes + ' ok, ' + fails + ' falhas');
process.exit(fails ? 1 : 0);
