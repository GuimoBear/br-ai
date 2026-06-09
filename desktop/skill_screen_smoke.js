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
  let browser, fail = 0, pass = 0, origSkills = null, origParams = null, page = null;
  const ok = (c, m) => { if (c) pass++; else { fail++; console.log('  FAIL- ' + m); } };
  const inspect = () => page.evaluate(() => {
    const root = document.querySelector('#scModal .sc-rows');
    const rows = [...root.querySelectorAll('.sc-row')];
    const hasRole = (role) => !!root.querySelector('.sc-skills[data-role="' + role + '"]');
    const lines = (role) => root.querySelectorAll('.sc-skills[data-role="' + role + '"] .sc-skill').length;
    return {
      rows: rows.length, none: root.querySelectorAll('.sc-none').length,
      skills: root.querySelectorAll('.sc-skill').length,
      editSkills: root.querySelectorAll('.sc-skill:not(.sc-skill-ro)').length,
      roSkills: root.querySelectorAll('.sc-skill.sc-skill-ro').length,
      roRm: root.querySelectorAll('.sc-skill.sc-skill-ro .sc-rm').length,
      paramLinks: root.querySelectorAll('.sc-paramlink').length,
      skillLvls: root.querySelectorAll('.sc-skill-lvl').length,
      adds: root.querySelectorAll('.sc-add').length, rms: root.querySelectorAll('.sc-rm').length,
      descInline: root.querySelectorAll('.sc-skills .sc-desc').length,    // deve ser 0 agora
      emptySkill: root.querySelectorAll('.sc-empty-skill').length,
      hasMain: hasRole('mainAtk'), hasAoe: hasRole('aoeAtk'), hasHealSelf: hasRole('healSelf'), hasCastling: hasRole('castling'),
      aoeLines: lines('aoeAtk'), offLines: lines('offBuff'),
      healSelfLines: lines('healSelf'), castlingLines: lines('castling'),
      offReset: !!document.querySelector('#scModal .sc-reset[data-role="offBuff"]'),
      summon: !!document.querySelector('#scModal .sm-panel'),
      comboLink: !!document.querySelector('#scModal #scComboLink'),
    };
  });
  const selHomun = async (t) => { await page.selectOption('#scHomunSel', String(t)); await page.waitForFunction((t) => !!document.querySelector('#scModal .sc-rows[data-homun="' + t + '"]'), t, { timeout: 20000 }); };
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
    origParams = await page.evaluate(async () => (await window.skillParamsIO.load()).data);
    await page.click('#btnSkills');
    await page.waitForFunction(() => !!document.querySelector('#scModal .sc-rows[data-homun]'), null, { timeout: 20000 });

    // Dieter: estrutura nova (add/remove, sem desc inline)
    await selHomun(51);
    let d = await inspect();
    ok(d.none === 0, 'nenhuma linha "Não há skill" — papéis vazios são OCULTOS');
    ok(d.hasAoe && !d.hasMain, 'Dieter: mostra AoE e OCULTA Main (sem skill principal)');
    ok(d.aoeLines === 2, 'Dieter: AoE 2 skills padrão (' + d.aoeLines + ')');
    ok(await page.evaluate(() => !document.getElementById('scExport')), 'web: SEM import/export de skills no modal (só na estática)');
    ok(d.descInline === 0, 'sem descrição inline (.sc-desc) — só no hover (' + d.descInline + ')');
    ok(d.adds === 3, 'um seletor "adicionar" por papel com candidatos (Dieter: AoE/offBuff/defBuff = 3)');
    ok(d.rms === d.editSkills && d.editSkills > 0, 'um ✕ remover por skill editável (' + d.rms + '=' + d.editSkills + ')');
    ok(d.roRm === 0, 'papéis fixos são só leitura (sem ✕ remover)');

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
    ok(!e.hasAoe && e.comboLink, 'Eleanor: AoE OCULTA (sem skill) + link de Combos');
    await selHomun(50); ok((await inspect()).summon, 'Sera: painel de Summon');

    // papéis FIXOS (cura/buff do dono/castling) — só leitura, vindos do perfil/base
    await selHomun(4); let v = await inspect();
    ok(v.hasHealSelf && !v.hasCastling, 'Vanilmirth: mostra Cura própria e OCULTA Castling (não tem)');
    ok(v.healSelfLines === 1, 'Vanilmirth: Cura própria mostra a skill fixa');
    ok(v.roSkills >= 1 && v.roRm === 0, 'Vanilmirth: skill fixa é só leitura (sem ✕)');
    ok(v.paramLinks >= 1, 'Vanilmirth: papéis fixos têm link ⚙ parâmetros (' + v.paramLinks + ')');
    await selHomun(2);
    { const a = await inspect(); ok(a.hasCastling && a.castlingLines === 1, 'Amistr: Castling aparece como skill fixa'); ok(!a.hasHealSelf, 'Amistr: Cura própria OCULTA (não tem)'); }

    // ===== Sobreposição de parâmetros por homúnculo (checkbox por papel) =====
    const loadParams = () => page.evaluate(async () => JSON.parse((await window.skillParamsIO.load()).data));
    await selHomun(51);   // Dieter (tem AoE)
    const ovWrap = '#scModal .sc-ovwrap[data-role="aoeAtk"]';
    const ovAmc = '#scModal .sc-ovknobs[data-role="aoeAtk"] .ovKnob[data-key="AutoMobCount"]';
    ok((await page.locator(ovWrap + ' .sc-ovtoggle').count()) === 1, 'aoeAtk tem checkbox "sobrepor parametros"');
    ok((await page.locator(ovWrap + ' .sc-ovtoggle').isChecked()) === false, 'sobrepor vem DESMARCADO por padrao');
    ok((await page.locator('#scModal .sc-ovknobs[data-role="aoeAtk"]').count()) === 0, 'desmarcado: knobs escondidos');
    ok(!/herdar|padr\u00e3o/i.test(await page.locator(ovWrap).innerText()), 'sem rotulo herdar/padrao na sobreposicao');
    // marcar -> knobs aparecem com o valor GLOBAL (AutoMobCount default=2) e cria override no JSON
    await page.locator(ovWrap + ' .sc-ovtoggle').check();
    await page.waitForFunction(() => document.querySelectorAll('#scModal .sc-ovknobs[data-role="aoeAtk"] .ovKnob').length > 0, null, { timeout: 5000 });
    ok((await page.locator(ovAmc).inputValue()) === '2', 'marcar carrega o valor Global (AutoMobCount=2)');
    let jp = await loadParams();
    ok(!!(jp.overrides && jp.overrides['51'] && jp.overrides['51'].aoeAtk && jp.overrides['51'].aoeAtk.AutoMobCount === 2), 'marcar cria override no JSON (=global)');
    // editar -> persiste
    await page.fill(ovAmc, '1'); await page.dispatchEvent(ovAmc, 'change'); await page.waitForTimeout(300);
    jp = await loadParams();
    ok(jp.overrides['51'].aoeAtk.AutoMobCount === 1, 'editar o override persiste (=1)');
    // desmarcar -> descarta (some do JSON) e esconde os knobs
    await page.locator(ovWrap + ' .sc-ovtoggle').uncheck();
    await page.waitForFunction(() => document.querySelectorAll('#scModal .sc-ovknobs[data-role="aoeAtk"]').length === 0, null, { timeout: 5000 });
    jp = await loadParams();
    ok(!(jp.overrides && jp.overrides['51'] && jp.overrides['51'].aoeAtk), 'desmarcar descarta o override (some do JSON)');
    // remarcar -> recarrega o GLOBAL (volta a 2, nao o 1 editado)
    await page.locator(ovWrap + ' .sc-ovtoggle').check();
    await page.waitForFunction(() => document.querySelectorAll('#scModal .sc-ovknobs[data-role="aoeAtk"] .ovKnob').length > 0, null, { timeout: 5000 });
    ok((await page.locator(ovAmc).inputValue()) === '2', 'remarcar recarrega o Global (volta a 2)');
    await page.locator(ovWrap + ' .sc-ovtoggle').uncheck(); await page.waitForTimeout(200);

    ok(errors.length === 0, 'sem erros de console (' + errors.slice(0, 3).join(' | ') + ')');
  } finally {
    try { if (page && origSkills != null) await page.evaluate(async (dd) => { try { await window.skillChoiceIO.save(dd); } catch (e) {} }, origSkills); } catch (e) {}
    try { if (page && origParams != null) await page.evaluate(async (dd) => { try { await window.skillParamsIO.save(dd); } catch (e) {} }, origParams); } catch (e) {}
    if (browser) await browser.close();
    srv.kill();
  }
  console.log('\nRESULTADO: ' + pass + ' ok, ' + fail + ' falhas');
  process.exit(fail > 0 ? 1 : 0);
}
main().catch(e => { console.error('ERRO:', e); process.exit(1); });
