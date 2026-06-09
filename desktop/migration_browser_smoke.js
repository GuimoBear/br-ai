// migration_browser_smoke.js — smoke de BROWSER REAL (Playwright) da tela de migração.
// Monta um USER_AI.zip a partir do USER_AI/ do repo, abre migrar.html, faz upload, confere o
// de→para e que "OK" leva ao editor com a árvore migrada persistida. Uso: node desktop/migration_browser_smoke.js
'use strict';
const path = require('path');
const fs = require('fs');
const { spawn } = require('child_process');
const zip = require('./zip.js');

function buildZip() {
  const dir = path.join(__dirname, '..', 'USER_AI');
  const want = ['Const_.lua', 'H_Config.lua', 'H_Tactics.lua', 'H_SkillList.lua', 'H_Avoid.lua', 'A_Friends.lua'];
  const entries = [];
  want.forEach(f => { const p = path.join(dir, f); if (fs.existsSync(p)) entries.push({ name: 'USER_AI/' + f, data: fs.readFileSync(p) }); });
  const out = path.join(require('os').tmpdir(), 'USER_AI_smoke.zip');
  fs.writeFileSync(out, zip.zipBuffer(entries));
  return out;
}

async function main() {
  let chromium;
  try { ({ chromium } = require('playwright')); } catch (e) { console.log('SKIP: playwright não instalado'); process.exit(0); }
  const zipPath = buildZip();
  const PORT = 8137;
  const srv = spawn('node', [path.join(__dirname, 'web', 'serve.js')], { env: { ...process.env, PORT: String(PORT) }, stdio: 'ignore' });
  await new Promise(r => setTimeout(r, 1200));
  let browser, fail = 0, pass = 0;
  const ok = (c, m) => { if (c) pass++; else { fail++; console.log('  FAIL- ' + m); } };
  try {
    try { browser = await chromium.launch(); } catch (e) { console.log('SKIP: chromium não instalado (npx playwright install chromium)'); srv.kill(); process.exit(0); }
    const page = await browser.newPage();
    const errors = [];
    page.on('pageerror', e => errors.push(String(e)));
    page.on('console', m => { if (m.type() === 'error') errors.push(m.text()); });

    const base = 'http://localhost:' + PORT + '/desktop/web/';
    await page.goto(base + 'migrar.html', { waitUntil: 'load' });
    await page.waitForFunction(() => window.BRAI_MIGRATE && window.BRAI_DEFAULT_TREE, null, { timeout: 20000 });

    // upload do zip (input #file está oculto, mas setInputFiles funciona)
    await page.setInputFiles('#file', zipPath);
    await page.waitForSelector('#step2.active', { timeout: 20000 });

    const res = await page.evaluate(() => {
      const r = window.BRAI_MIGRATION_UI.getResult();
      let mc = 0, hasFlee = false; (function w(n){ if(n.type==='monsterCheck') mc++; if(n.label==='fugir do chefe') hasFlee = true; (n.children||[]).forEach(w); if(n.child) w(n.child); })(r.wrapper.spec);
      return { homunType: r.wrapper.homunType, groups: r.report.counts.groups, singles: r.report.counts.singles, mapped: r.report.counts.mapped,
               bossGroup: r.config.BossGroup || 0, hasFlee,
               mc, hasSkill51: !!(r.skillChoices.choices['51']), summaryPills: document.querySelectorAll('#summary .pill').length,
               gInputs: document.querySelectorAll('input.gname').length, mInputs: document.querySelectorAll('input.mname').length,
               sectionCards: document.querySelectorAll('#sections .card').length };
    });
    ok(res.homunType === 51, 'detectou Dieter (51) — tipo com mais skills (' + res.homunType + ')');
    ok(res.groups > 0 && res.singles > 0, 'tem grupos (2+) E táticas por monstro (1): ' + res.groups + ' grupos / ' + res.singles + ' singles');
    // Fase 8a: com UseAvoid=0 o grupo MVP fica no catálogo (alimenta BossGroup) mas SEM nó monsterCheck de fuga
    var avoidNoBranch = (res.bossGroup > 0 && !res.hasFlee) ? 1 : 0;
    ok(res.mc === res.groups + res.singles - avoidNoBranch, 'monsterCheck = grupos + singles' + (avoidNoBranch ? ' − 1 (MVP sem fuga, UseAvoid=0)' : '') + ' (' + res.mc + ' = ' + res.groups + '+' + res.singles + '−' + avoidNoBranch + ')');
    ok(res.gInputs === res.groups && res.mInputs === res.singles, 'dois painéis editáveis (' + res.gInputs + ' grupos, ' + res.mInputs + ' monstros)');
    ok(res.mapped > 0, 'há itens mapeados no relatório (' + res.mapped + ')');
    ok(res.hasSkill51, 'skillChoices do Dieter presente (Blast Forge/Tempering)');
    ok(res.summaryPills >= 5, 'painel de resumo renderizado (' + res.summaryPills + ' pills)');
    ok(res.sectionCards >= 3, 'seções de→para renderizadas (' + res.sectionCards + ' cards)');

    // Fase 5: loading existe, forma base habilitada p/ S, troca de base, renomear grupo
    const f5 = await page.evaluate(() => ({
      loadingEl: !!document.getElementById('loading'),
      baseDisabled: document.getElementById('baseSel').disabled,
      homunVal: document.getElementById('homunSel').value,
      optMonDisabled: document.getElementById('optMon').disabled,
    }));
    ok(f5.loadingEl, 'overlay de loading existe');
    ok(f5.optMonDisabled, 'Árvore marcada (padrão) => Monstros travado/incluído');
    ok(f5.baseDisabled === false, 'forma base habilitada p/ Homun S (Dieter)');
    ok(f5.homunVal === '51', 'seletor de homún reflete Dieter');
    await page.selectOption('#baseSel', '3');
    await page.waitForTimeout(150);
    const baseT = await page.evaluate(() => window.BRAI_MIGRATION_UI.getResult().wrapper.baseType);
    ok(baseT === 3, 'trocar a forma base re-migra com baseType=3 (' + baseT + ')');
    const renamed = await page.evaluate(() => {
      const inp = document.querySelector('input.gname');
      const gid = Number(inp.getAttribute('data-gid'));
      inp.value = 'Grupo Renomeado QA'; inp.dispatchEvent(new Event('input', { bubbles: true }));
      const r = window.BRAI_MIGRATION_UI.getResult();
      let lbl = null; (function w(n){ if(n.type==='monsterCheck'&&n.group===gid) lbl=n.label; (n.children||[]).forEach(w); if(n.child) w(n.child); })(r.wrapper.spec);
      const g = r.monsters.groups.find(x => x.id === gid);
      return { name: g && g.name, lbl };
    });
    ok(renamed.name === 'Grupo Renomeado QA' && renamed.lbl === 'Grupo Renomeado QA', 'renomear grupo atualiza result + label do nó');
    const renamedS = await page.evaluate(() => {
      const inp = document.querySelector('input.mname'); const mid = Number(inp.getAttribute('data-mid'));
      inp.value = 'Mob Renomeado QA'; inp.dispatchEvent(new Event('input', { bubbles: true }));
      const r = window.BRAI_MIGRATION_UI.getResult();
      let lbl = null; (function w(n){ if(n.type==='monsterCheck'&&n.monster===mid) lbl=n.label; (n.children||[]).forEach(w); if(n.child) w(n.child); })(r.wrapper.spec);
      const m = r.monsters.monsters.find(x => x.id === mid); return { desc: m && m.desc, lbl: lbl };
    });
    ok(renamedS.desc === 'Mob Renomeado QA' && renamedS.lbl === 'Mob Renomeado QA', 'renomear monstro (single) atualiza desc + label do nó');

    // clica OK → vai p/ o editor; confere persistência do handoff
    await Promise.all([
      page.waitForURL('**/editor.html', { timeout: 20000 }),
      page.click('#ok'),
    ]);
    const handoff = await page.evaluate(() => {
      let skills = null, tree = null, monsters = null, ctxBase = null;
      try { skills = JSON.parse(localStorage.getItem('brai.skills')); } catch (e) {}
      try { monsters = JSON.parse(localStorage.getItem('brai.monsters')); } catch (e) {}
      var renMon = !!(monsters && monsters.monsters && monsters.monsters.some(function(m){return m.desc==='Mob Renomeado QA';}));
      try { const s = JSON.parse(sessionStorage.getItem('brai.editorState')); tree = s && s.tree ? { uid: s.tree._uid, from: s.fromMigration } : null; ctxBase = s ? s.ctxBase : null; } catch (e) {}
      return { skills: skills && skills.choices ? Object.keys(skills.choices).length : 0, tree,
               renamed: !!(monsters && monsters.groups && monsters.groups.some(g => g.name === 'Grupo Renomeado QA')), renamedMon: renMon, ctxBase: ctxBase };
    });
    ok(handoff.skills > 0, 'handoff persistiu skillChoices no localStorage (' + handoff.skills + ' tipos)');
    ok(handoff.tree && handoff.tree.uid > 0, 'editorState tem árvore com _uid (layout aplicado)');
    ok(handoff.renamed, 'grupo renomeado persistiu no handoff (brai.monsters)');
    ok(handoff.renamedMon, 'monstro (single) renomeado persistiu no handoff (brai.monsters)');
    ok(handoff.ctxBase === 3, 'forma base escolhida foi p/ o editor (ctxBase=' + handoff.ctxBase + ')');
    ok(await page.evaluate(() => !!(window.trees)), 'editor.html carregou (window.trees presente)');
    // Fase 7: o config migrado chega ao editor (painel Config reflete os knobs)
    var cfg7 = { hasPanel: false, healOwner: null };
    try {
      // espera o boot do editor terminar (fia os botões + restaura treeConfig) — árvore migrada é grande
      await page.waitForFunction(() => { var b = document.getElementById('btnConfig'); return !!(b && b.onclick); }, null, { timeout: 20000 });
      await page.click('#btnConfig');
      await page.waitForSelector('#cfgModal .cfg-in[data-k="HealOwnerHP"]', { timeout: 8000 });
      cfg7 = await page.evaluate(() => {
        var inp = document.querySelector('#cfgModal .cfg-in[data-k="HealOwnerHP"]');
        return { hasPanel: !!document.getElementById('cfgModal'), healOwner: inp ? inp.value : null };
      });
    } catch (e) { cfg7.err = String(e.message || e); }
    ok(cfg7.hasPanel, 'painel Config abre no editor (botão Config)' + (cfg7.err ? ' — ' + cfg7.err : ''));
    ok(cfg7.healOwner === '40', 'config migrado chega ao editor (HealOwnerHP=40 no painel) [' + cfg7.healOwner + ']');
    // Fase 6: migração PARCIAL (só monstros & grupos, sem árvore nem skills)
    await page.goto(base + 'migrar.html', { waitUntil: 'load' });
    await page.waitForFunction(() => window.BRAI_MIGRATE && window.BRAI_DEFAULT_TREE, null, { timeout: 20000 });
    await page.evaluate(() => { sessionStorage.clear(); localStorage.removeItem('brai.monsters'); localStorage.removeItem('brai.skills'); });
    await page.setInputFiles('#file', zipPath);
    await page.waitForSelector('#step2.active', { timeout: 20000 });
    await page.uncheck('#optTree');     // árvore off -> monstros volta a ser editável
    await page.uncheck('#optSkills');
    const psel = await page.evaluate(() => ({
      monChecked: document.getElementById('optMon').checked, monDisabled: document.getElementById('optMon').disabled,
      okDisabled: document.getElementById('ok').disabled, sel: window.BRAI_MIGRATION_UI.selection(),
    }));
    ok(psel.monChecked && psel.monDisabled === false, 'Árvore off => Monstros habilitado e marcado');
    ok(psel.sel.tree === false && psel.sel.mon === true && psel.sel.skills === false, 'seleção parcial: só monstros');
    // nada marcado => OK desabilitado
    await page.uncheck('#optMon');
    ok(await page.evaluate(() => document.getElementById('ok').disabled), 'nada marcado => OK desabilitado');
    await page.check('#optMon');
    await Promise.all([ page.waitForURL('**/editor.html', { timeout: 20000 }), page.click('#ok') ]);
    const partial = await page.evaluate(() => {
      let mon = null, es = null;
      try { mon = JSON.parse(localStorage.getItem('brai.monsters')); } catch (e) {}
      try { es = JSON.parse(sessionStorage.getItem('brai.editorState')); } catch (e) {}
      return { hasMon: !!(mon && mon.groups && mon.groups.length), skills: localStorage.getItem('brai.skills'), migTree: !!(es && es.fromMigration) };
    });
    ok(partial.hasMon, 'parcial: aplicou monstros & grupos');
    ok(partial.migTree === false, 'parcial: NÃO substituiu a árvore (sem editorState de migração)');
    ok(!partial.skills, 'parcial: não aplicou skills (desmarcado)');

    ok(errors.filter(e => !/favicon/.test(e)).length === 0, 'sem erros de console (' + errors.slice(0, 3).join(' | ') + ')');
  } finally {
    if (browser) await browser.close();
    srv.kill();
  }
  console.log('\nRESULTADO migration_browser: ' + pass + ' ok, ' + fail + ' falhas');
  process.exit(fail > 0 ? 1 : 0);
}
main().catch(e => { console.error('ERRO:', e); process.exit(1); });
