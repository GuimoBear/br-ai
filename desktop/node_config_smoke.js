// node_config_smoke.js — smoke (Playwright) do #4 inspetor: ao selecionar UseAoESkill/
// UseMainSkill/UseOffensiveBuff/UseDefensiveBuff, o inspetor renderiza os knobs de config
// (number + boolean tri-estado herdar|sim|não); editar grava em n.params (aparece no
// rótulo do nó); deixar em "herdar" não grava. [PLANO-GERACAO-LUA G6b]
'use strict';
const fs = require('fs'), os = require('os'), path = require('path'), http = require('http');
const ROOT = path.join(__dirname, '..');
function serve(dir, port) {
  const M = { '.html': 'text/html', '.js': 'text/javascript', '.css': 'text/css', '.json': 'application/json' };
  const s = http.createServer((q, r) => { let p = decodeURIComponent(q.url.split('?')[0]); if (p === '/') p = '/index.html'; const f = path.join(dir, p); fs.readFile(f, (e, d) => { if (e) { r.writeHead(404); r.end('404'); } else { r.writeHead(200, { 'Content-Type': M[path.extname(f)] || 'application/octet-stream' }); r.end(d); } }); });
  return new Promise(x => s.listen(port, () => x(s)));
}
async function main() {
  let chromium; try { ({ chromium } = require('playwright')); } catch (e) { console.log('SKIP: playwright'); process.exit(0); }
  const { build } = require(path.join(ROOT, 'tools', 'build_static.js'));
  const o = fs.mkdtempSync(path.join(os.tmpdir(), 'ncfg-')); build(o);
  const s = await serve(o, 8137); let browser, pass = 0, fail = 0;
  const ok = (c, m) => { if (c) pass++; else { fail++; console.log('  FAIL-', m); } };
  const bodyText = () => pg.evaluate(() => document.body.innerText);
  let pg;
  try {
    try { browser = await chromium.launch(); } catch (e) { console.log('SKIP: chromium'); s.close(); process.exit(0); }
    pg = await browser.newPage({ viewport: { width: 1280, height: 820 } }); const errs = [];
    pg.on('pageerror', e => errs.push(String(e)));
    await pg.goto('http://localhost:8137/editor.html', { waitUntil: 'load' });
    await pg.waitForFunction(() => document.querySelectorAll('.gnode').length > 3, null, { timeout: 30000 });

    // seleciona um nó de AÇÃO e troca p/ UseAoESkill
    await pg.locator('.gnode:has(span.type.t-act)').first().click();
    await pg.waitForSelector('#iName', { timeout: 8000 });
    await pg.selectOption('#iName', 'UseAoESkill');
    await pg.waitForTimeout(200);

    // C6: knobs por nó RECOLHIDOS por padrão (a parede some) + toggle + link Parâmetros
    ok(!(await pg.locator('#inspector .iParam[data-f="AutoMobCount"]').isVisible()), 'C6: knobs por nó recolhidos por padrão');
    ok((await pg.locator('#inspector details.insp-adv summary').count()) === 1, 'C6: toggle "Avançado" presente');
    ok((await pg.locator('#iParamCfg').count()) === 1, 'C6: botão "Parâmetros desta skill" presente');
    // o link abre o #spModal focado no papel aoeAtk
    await pg.click('#iParamCfg');
    await pg.waitForSelector('#spModal', { timeout: 8000 });
    ok((await pg.locator('#spModal .sp-tab[data-role="aoeAtk"].active').count()) === 1, 'C6: link Parâmetros abre #spModal na aba do papel aoeAtk');
    await pg.evaluate(() => { const m = document.getElementById('spModal'); if (m) m.remove(); });
    // expandir o "Avançado" p/ testar o override por nó (#4)
    await pg.locator('#inspector details.insp-adv summary').click();
    await pg.waitForTimeout(150);
    ok(await pg.locator('#inspector .iParam[data-f="AutoMobCount"]').isVisible(), 'C6: "Avançado" revela os knobs');

    for (const k of ['AutoMobCount', 'AutoMobMode', 'AttackSkillReserveSP', 'AoEFixedLevel'])
      ok(await pg.locator('.iParam[data-f="' + k + '"]').count() > 0, 'UseAoESkill: campo number ' + k);
    ok(await pg.locator('.iParamBool[data-f="UseAttackSkill"]').count() > 0, 'UseAoESkill: boolean tri-estado UseAttackSkill');
    ok(await pg.locator('.iParamBool[data-f="AoEMaximizeTargets"]').count() > 0, 'UseAoESkill: boolean tri-estado AoEMaximizeTargets');
    // dica do valor global no campo number (AutoMobCount global = 2)
    ok(/AutoMobCount.*global: 2/s.test(await bodyText()), 'UseAoESkill: dica "global: 2" no AutoMobCount');

    // editar AutoMobCount=1 -> grava em n.params (aparece no rótulo do nó)
    await pg.fill('.iParam[data-f="AutoMobCount"]', '1');
    await pg.waitForTimeout(150);
    ok(/AutoMobCount=1/.test(await bodyText()), 'editar AutoMobCount=1 grava em n.params (rótulo do nó)');

    // boolean tri-estado: começa em "herdar" (value vazio); "não" grava false; "herdar" remove
    ok((await pg.locator('.iParamBool[data-f="UseAttackSkill"]').inputValue()) === '', 'boolean começa em "herdar" (ausente)');
    await pg.selectOption('.iParamBool[data-f="UseAttackSkill"]', 'false');
    await pg.waitForTimeout(150);
    ok(/UseAttackSkill=false/.test(await bodyText()), 'boolean "não" grava UseAttackSkill=false (rótulo)');
    await pg.selectOption('.iParamBool[data-f="UseAttackSkill"]', '');
    await pg.waitForTimeout(150);
    ok(!/UseAttackSkill=false/.test(await bodyText()), 'voltar a "herdar" remove o override do rótulo');

    // idem p/ UseMainSkill (boolean UseHomunSSkillChase + number AttackRange)
    await pg.selectOption('#iName', 'UseMainSkill'); await pg.waitForTimeout(200);
    ok(await pg.locator('.iParamBool[data-f="UseHomunSSkillChase"]').count() > 0, 'UseMainSkill: boolean UseHomunSSkillChase');
    ok(await pg.locator('.iParam[data-f="AttackRange"]').count() > 0, 'UseMainSkill: number AttackRange');

    // UseOffensiveBuff / UseDefensiveBuff: knob enable
    await pg.selectOption('#iName', 'UseOffensiveBuff'); await pg.waitForTimeout(200);
    ok(await pg.locator('.iParamBool[data-f="UseOffensiveBuff"]').count() > 0, 'UseOffensiveBuff: boolean UseOffensiveBuff');
    await pg.selectOption('#iName', 'UseDefensiveBuff'); await pg.waitForTimeout(200);
    ok(await pg.locator('.iParamBool[data-f="UseDefensiveBuff"]').count() > 0, 'UseDefensiveBuff: boolean UseDefensiveBuff');

    // C8: ações cura/ownerBuff/castling têm o link Parâmetros (sem knobs por nó)
    await pg.selectOption('#iName', 'UseHealOwner'); await pg.waitForTimeout(200);
    ok((await pg.locator('#iParamCfg').count()) === 1, 'C8: UseHealOwner tem link "Parâmetros desta skill"');
    ok((await pg.locator('#inspector .iParam, #inspector .iParamBool').count()) === 0, 'C8: UseHealOwner sem parede de knobs por nó');
    await pg.click('#iParamCfg'); await pg.waitForSelector('#spModal', { timeout: 8000 });
    ok((await pg.locator('#spModal .sp-tab[data-role="healOwner"].active').count()) === 1, 'C8: link abre #spModal na aba do papel healOwner');
    await pg.evaluate(() => { const m = document.getElementById('spModal'); if (m) m.remove(); });

    ok(errs.length === 0, 'sem erros de página (' + errs.slice(0, 2).join(' | ') + ')');
  } finally { if (browser) await browser.close(); s.close(); }
  console.log('\nRESULTADO: ' + pass + ' ok, ' + fail + ' falhas');
  process.exit(fail > 0 ? 1 : 0);
}
main().catch(e => { console.error('ERRO:', e); process.exit(1); });
