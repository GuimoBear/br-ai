// skill_screen_smoke.js — smoke (Playwright) da tela "Skills por homúnculo" (multi-seleção 0..N).
// Cobre: add/remove/↺ padrão; linha por skill (nome+nível) SEM descrição inline; hover no nome E no
// nível abre o card; estado "nenhuma skill" + persistência da lista vazia; combos (Eleanor)/summon (Sera).
'use strict';
const path = require('path');
const { spawn } = require('child_process');

async function main() {
  let chromium;
  try { ({ chromium } = require('playwright')); } catch (e) { console.log('SKIP: playwright não instalado'); process.exit(0); }
  const PORT = 8137;
  const srv = spawn('node', [path.join(__dirname, 'web', 'serve.js')], { env: { ...process.env, PORT: String(PORT) }, stdio: 'ignore' });
  await new Promise(r => setTimeout(r, 1200));
  let browser, fail = 0, pass = 0, origSkills = null, page = null;
  const ok = (c, m) => { if (c) pass++; else { fail++; console.log('  FAIL- ' + m); } };
  const inspect = () => page.evaluate(() => {
    const root = document.querySelector('#scModal .sc-rows');
    const rows = [...root.querySelectorAll('.sc-row')];
    const roleOf = (frag) => rows.find(r => ((r.querySelector('.sc-role') || {}).textContent || '').toLowerCase().includes(frag));
    const hasNone = (frag) => { const r = roleOf(frag); return !!(r && r.querySelector('.sc-none')); };
    const lines = (role) => root.querySelectorAll('.sc-skills[data-role="' + role + '"] .sc-skill').length;
    return {
      rows: rows.length, none: root.querySelectorAll('.sc-none').length,
      skills: root.querySelectorAll('.sc-skill').length,
      skillLvls: root.querySelectorAll('.sc-skill-lvl').length,
      adds: root.querySelectorAll('.sc-add').length, rms: root.querySelectorAll('.sc-rm').length,
      descInline: root.querySelectorAll('.sc-skills .sc-desc').length,    // deve ser 0 agora
      emptySkill: root.querySelectorAll('.sc-empty-skill').length,
      mainNone: hasNone('main'), aoeNone: hasNone('área'),
      aoeLines: lines('aoeAtk'), offLines: lines('offBuff'),
      offReset: !!document.querySelector('#scModal .sc-reset[data-role="offBuff"]'),
      summon: !!document.querySelector('#scModal .sm-panel'),
      comboLink: !!document.querySelector('#scModal #scComboLink'),
    };
  });
  const selHomun = async (t) => { await page.selectOption('#scHomunSel', String(t)); await page.waitForFunction(() => document.querySelectorAll('#scModal .sc-rows .sc-row').length === 4, null, { timeout: 20000 }); };
  try {
    try { browser = await chromium.launch(); } catch (e) { console.log('SKIP: chromium não instalado'); srv.kill(); process.exit(0); }
    page = await browser.newPage();
    const errors = [];
    page.on('pageerror', e => errors.push(String(e)));
    page.on('console', m => { if (m.type() === 'error') errors.push(m.text()); });
    await page.goto('http://localhost:' + PORT + '/desktop/web/editor.html', { waitUntil: 'load' });
    await page.waitForFunction(() => window.trees && window.brai, null, { timeout: 20000 });
    await page.waitForFunction(() => { const b = document.getElementById('btnSkills'); return !!(b && b.onclick); }, null, { timeout: 20000 });
    origSkills = await page.evaluate(async () => (await window.skillChoiceIO.load()).data);   // p/ restaurar
    await page.click('#btnSkills');
    await page.waitForFunction(() => document.querySelectorAll('#scModal .sc-rows .sc-row').length === 4, null, { timeout: 20000 });

    // Dieter: estrutura nova (add/remove, sem desc inline)
    await selHomun(51);
    let d = await inspect();
    ok(d.rows === 4, 'Dieter: 4 papéis');
    ok(d.mainNone, 'Dieter: Main → "não há skill"');
    ok(d.aoeLines === 2, 'Dieter: AoE 2 skills padrão (' + d.aoeLines + ')');
    ok(await page.evaluate(() => !document.getElementById('scExport')), 'web: SEM import/export de skills no modal (só na estática)');
    ok(d.descInline === 0, 'sem descrição inline (.sc-desc) — só no hover (' + d.descInline + ')');
    ok(d.adds === 3, 'um seletor "adicionar" por papel com candidatos (3; Main não tem)');
    ok(d.rms === d.skills && d.skills > 0, 'um ✕ remover por skill (' + d.rms + '=' + d.skills + ')');

    // hover na ZONA ÚNICA (nome+nível) → card com o NOME REAL (não "undefined")
    await page.hover('#scModal .sc-skills[data-role="aoeAtk"] .sc-skill-hot');
    await page.waitForTimeout(150);
    const tipInfo = await page.evaluate(() => {
      const t = document.getElementById('scTip'); const h = t && t.querySelector('.si-head b');
      return { shown: !!(t && t.style.display === 'block' && t.querySelector('.skillinfo')), name: h ? h.textContent : '', cells: t ? t.querySelectorAll('.si-cell').length : 0 };
    });
    ok(tipInfo.shown, 'hover (zona nome+nível) abre o card');
    ok(tipInfo.name && tipInfo.name !== 'undefined', 'card mostra o NOME real da skill (' + tipInfo.name + ')');
    ok(tipInfo.cells > 0, 'card traz as células de info (alcance/SP/...) — não vazio (' + tipInfo.cells + ')');
    // nível SEM rótulo "Padrão (N)"
    const noPadrao = await page.evaluate(() => [...document.querySelectorAll('#scModal .sc-skill-lvl option')].every(o => !/Padrão/.test(o.textContent)));
    ok(noPadrao, 'seletor de nível sem opção "Padrão (N)"');

    // N2: adicionar (Dieter offBuff: Pyroclastic padrão; Tempering adicionável)
    ok((await inspect()).offLines === 1, 'Dieter offBuff começa com 1 (Pyroclastic)');
    await page.selectOption('#scModal .sc-add[data-role="offBuff"]', { label: 'Tempering' });
    await page.waitForFunction(() => document.querySelectorAll('#scModal .sc-skills[data-role="offBuff"] .sc-skill').length === 2, null, { timeout: 10000 });
    ok((await inspect()).offReset, 'após adicionar, aparece ↺ padrão (override ativo)');
    // remover uma
    await page.click('#scModal .sc-skills[data-role="offBuff"] .sc-rm');
    await page.waitForFunction(() => document.querySelectorAll('#scModal .sc-skills[data-role="offBuff"] .sc-skill').length === 1, null, { timeout: 10000 });
    ok((await inspect()).offLines === 1, 'remover ✕ tira uma skill (volta a 1)');
    // ↺ padrão
    await page.click('#scModal .sc-reset[data-role="offBuff"]');
    await page.waitForFunction(() => !document.querySelector('#scModal .sc-reset[data-role="offBuff"]'), null, { timeout: 10000 });
    ok(!(await inspect()).offReset, '↺ padrão limpa o override');

    // N4: remover TODAS → "nenhuma skill" + persiste []
    await page.click('#scModal .sc-skills[data-role="offBuff"] .sc-rm');
    await page.waitForFunction(() => document.querySelectorAll('#scModal .sc-skills[data-role="offBuff"] .sc-empty-skill').length === 1, null, { timeout: 10000 });
    ok((await inspect()).emptySkill >= 1, 'remover a última → "nenhuma skill"');
    await page.waitForTimeout(400);
    await selHomun(49); await selHomun(51);   // troca e volta → recarrega do salvo
    ok((await inspect()).offLines === 0, 'lista vazia persistiu (offBuff = nenhuma após reabrir)');
    await page.click('#scModal .sc-reset[data-role="offBuff"]');   // restaura p/ padrão
    await page.waitForTimeout(300);

    // Bayeri / Eleanor / Sera
    await selHomun(49); let b = await inspect();
    ok(b.offLines === 2, 'Bayeri offBuff 2 skills (Golden Ferse + Angriff Modus)');
    await selHomun(52); let e = await inspect();
    ok(e.aoeNone && e.comboLink, 'Eleanor: AoE sem skill + link de Combos');
    await selHomun(50); ok((await inspect()).summon, 'Sera: painel de Summon');

    ok(errors.length === 0, 'sem erros de console (' + errors.slice(0, 3).join(' | ') + ')');
  } finally {
    try { if (page && origSkills != null) await page.evaluate(async (dd) => { try { await window.skillChoiceIO.save(dd); } catch (e) {} }, origSkills); } catch (e) {}
    if (browser) await browser.close();
    srv.kill();
  }
  console.log('\nRESULTADO: ' + pass + ' ok, ' + fail + ' falhas');
  process.exit(fail > 0 ? 1 : 0);
}
main().catch(e => { console.error('ERRO:', e); process.exit(1); });
