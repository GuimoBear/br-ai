// sim_skills_smoke.js — render dos FILHOS de skill no simulador (PLANO-SKILLS-NO-NO S2).
// Carrega renderer.js num sandbox vm (igual ao eleanor_viz_smoke) e valida renderTree/
// explainNode/showTreeTip: linhas skillRef, destaque da ativa, aviso none/missing no nó-ação
// e a mensagem do tooltip ao clicar. Uso: node desktop/sim_skills_smoke.js
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

let ok = 0, fail = 0;
const chk = (c, n) => { if (c) { ok++; console.log('  ok  - ' + n); } else { fail++; console.log('  FAIL- ' + n); } };

// Frame falso = snapshot que a S1 produz p/ um Dieter: AoE (2 skills, Blast Forge ativa),
// ataque principal (missing) e cura do dono (none).
const f = { tree: [
  { kind: 'selector', label: 'Seletor', depth: 0 },
  { kind: 'action', name: 'UseAoESkill', label: 'Skill em área (AoE)', depth: 1, skillState: 'ok' },
  { kind: 'skillRef', label: 'Lava Slide Lv10', depth: 2, skillId: 8041, active: false },
  { kind: 'skillRef', label: 'Blast Forge Lv10', depth: 2, skillId: 8044, active: true },
  { kind: 'action', name: 'UseMainSkill', label: 'Skill principal', depth: 1, skillState: 'missing' },
  { kind: 'skillRef', label: '— este tipo não tem esta skill', depth: 2, skillState: 'missing' },
  { kind: 'action', name: 'UseHealOwner', label: 'Cura do dono', depth: 1, skillState: 'none' },
  { kind: 'skillRef', label: '— nenhuma skill selecionada', depth: 2, skillState: 'none' },
] };
sandbox.renderTree(f);
const html = els['tree'].innerHTML;

console.log('== renderTree: filhos de skill ==');
chk((html.match(/tnode tn-skill\b/g) || []).length === 4, 'renderiza 4 linhas skillRef');
chk(html.includes('Lava Slide Lv10') && html.includes('Blast Forge Lv10'), 'lista Lava Slide + Blast Forge (multi-skill)');
const rows = html.split('<div ').filter(Boolean);
const lavaRow = rows.find(r => r.includes('Lava Slide')) || '';
const blastRow = rows.find(r => r.includes('Blast Forge')) || '';
chk(blastRow.includes('tn-skill-on'), 'a skill ativa (Blast Forge) acende (tn-skill-on)');
chk(lavaRow && !lavaRow.includes('tn-skill-on'), 'Lava Slide (não-ativa) NÃO acende');
chk((html.match(/tn-skill-warn/g) || []).length === 2, '2 linhas de aviso (missing + none) com tn-skill-warn');
chk((html.match(/⚠/g) || []).length === 2, '2 marcadores ⚠ nos avisos');
chk((html.match(/✦/g) || []).length === 2, '2 marcadores ✦ nas skills ok');

console.log('== renderTree: destaque sutil no nó-ação ==');
chk((html.match(/tn-needs-skill/g) || []).length === 2, 'ações missing/none ganham tn-needs-skill');
// a AoE (ok) não deve ter tn-needs-skill: confere que o trecho da AoE não tem a classe
const aoeChunk = html.substring(html.indexOf('Skill em área'), html.indexOf('Lava Slide'));
chk(!aoeChunk.includes('tn-needs-skill'), 'nó AoE (ok) não recebe destaque de aviso');

console.log('== explainNode (skillRef) ==');
chk(/não tem skill/.test(sandbox.explainNode({ kind: 'skillRef', skillState: 'missing' })), 'missing: "não tem skill"');
chk(/Nenhuma skill selecionada/.test(sandbox.explainNode({ kind: 'skillRef', skillState: 'none' })), 'none: "Nenhuma skill selecionada"');
chk(/em uso neste tick/.test(sandbox.explainNode({ kind: 'skillRef', active: true })), 'ativa: "em uso neste tick"');

console.log('== showTreeTip: mensagem ao clicar na ação ==');
sandbox.showTreeTip(10, 10, { kind: 'action', name: 'UseMainSkill', label: 'Skill principal', skillState: 'missing' });
let tip = els['treetip'].innerHTML;
chk(tip.includes('tt-skill-missing') && /não tem skill/.test(tip), 'clique em ação missing -> aviso "não tem skill"');
sandbox.showTreeTip(10, 10, { kind: 'action', name: 'UseHealOwner', label: 'Cura do dono', skillState: 'none' });
tip = els['treetip'].innerHTML;
chk(tip.includes('tt-skill-none') && /Nenhuma skill selecionada/.test(tip), 'clique em ação none -> aviso "nenhuma selecionada"');
// ação normal (ok) não injeta aviso
sandbox.showTreeTip(10, 10, { kind: 'action', name: 'UseAoESkill', label: 'AoE', skillState: 'ok' });
chk(!els['treetip'].innerHTML.includes('tt-skill-'), 'ação ok não mostra aviso de skill');

console.log('\nRESULTADO: ' + ok + ' ok, ' + fail + ' falhas');
process.exit(fail ? 1 : 0);
