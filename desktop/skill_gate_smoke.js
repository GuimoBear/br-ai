// skill_gate_smoke.js — F4: condição por skill na tela "Skills por homúnculo" (gate "possui a
// skill X") e a percepção HasSkill no combobox de condições. Sobe a estática e dirige o editor.
// Uso: node desktop/skill_gate_smoke.js  (SKIP sem chromium; roda no CI)
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
  const o = fs.mkdtempSync(path.join(os.tmpdir(), 'skgate-')); build(o);
  const s = await serve(o, 8161); let browser, pass = 0, fail = 0;
  const ok = (c, m) => { if (c) pass++; else { fail++; console.log('  FAIL-', m); } };
  let pg;
  try {
    try { browser = await chromium.launch(); } catch (e) { console.log('SKIP: chromium'); s.close(); process.exit(0); }
    pg = await browser.newPage({ viewport: { width: 1280, height: 900 } }); const errs = [];
    pg.on('pageerror', e => errs.push(String(e)));
    await pg.goto('http://localhost:8161/editor.html', { waitUntil: 'load' });
    await pg.waitForFunction(() => document.querySelectorAll('.gnode').length > 3, null, { timeout: 30000 });
    await pg.selectOption('#ctxHomun', '51'); // Dieter

    // ===== HasSkill no combobox de condições =====
    await pg.locator('.gnode:has(span.type.t-chk), .gnode:has(span.type.t-cnd)').first().click().catch(() => {});
    // garante um nó 'check' e escolhe HasSkill
    await pg.locator('.gnode:has(span.type.t-act)').first().click();
    await pg.waitForSelector('#iType', { timeout: 8000 });
    await pg.selectOption('#iType', 'check'); await pg.waitForTimeout(300);
    const condOpts = await pg.locator('#iCheckName option').allTextContents();
    ok(condOpts.some(t => /Possui a skill/.test(t)), 'HasSkill ("Possui a skill") aparece no combobox de condições');
    await pg.selectOption('#iCheckName', 'HasSkill'); await pg.waitForTimeout(300);
    ok((await pg.locator('.iParamSkill').count()) === 1, 'HasSkill mostra o seletor de skill (param)');
    // escolhe uma skill -> mostra infos
    const skOpt = await pg.locator('.iParamSkill option').nth(1).getAttribute('value');
    await pg.selectOption('.iParamSkill', skOpt); await pg.waitForTimeout(300);
    ok((await pg.locator('.skillinfo').count()) >= 1, 'infos da skill (nível máximo) exibidas ao escolher');
    ok(/n[íi]vel m[áa]ximo/i.test(await pg.locator('#inspector').innerText()), 'rótulo "nível máximo" presente');

    // ===== gate por skill na tela "Skills por homúnculo" =====
    await pg.click('#btnSkills'); await pg.waitForSelector('#scModal', { timeout: 8000 });
    await pg.selectOption('#scModal #scHomunSel', '51'); await pg.waitForTimeout(400); // Dieter
    const modeSel = pg.locator('#scModal .sc-skills[data-role="aoeAtk"] .sc-gate-mode').first();
    ok((await modeSel.count()) === 1, 'cada skill do papel tem o controle de condição (sc-gate-mode)');
    // opções esperadas
    const modeOpts = await modeSel.locator('option').allTextContents();
    ok(modeOpts.some(t => /TIVER/.test(t)) && modeOpts.some(t => /NÃO TIVER/.test(t)), 'opções "só se TIVER / NÃO TIVER"');
    // liga "só se TIVER" -> aparece o seletor da skill X
    await modeSel.selectOption('has'); await pg.waitForTimeout(500);
    ok((await pg.locator('#scModal .sc-skills[data-role="aoeAtk"] .sc-gate-skill:not(.sc-gate-hidden)').count()) >= 1, 'ao escolher uma condição, aparece o seletor da skill X');
    // BUG #3: mexer numa skill NÃO pode afetar a condição das outras
    const modes = pg.locator('#scModal .sc-skills[data-role="aoeAtk"] .sc-gate-mode');
    if ((await modes.count()) >= 2) {
      ok((await modes.nth(1).inputValue()) === '', 'condição da 1ª skill não vaza para a 2ª (continua "sempre")');
    }
    // persiste: reabrir o modal mantém o modo
    const modeNow = await pg.locator('#scModal .sc-skills[data-role="aoeAtk"] .sc-gate-mode').first().inputValue();
    ok(modeNow === 'has', 'condição persiste no modo (has)');
    // volta para sempre (limpa)
    await pg.locator('#scModal .sc-skills[data-role="aoeAtk"] .sc-gate-mode').first().selectOption(''); await pg.waitForTimeout(400);
    ok((await pg.locator('#scModal .sc-skills[data-role="aoeAtk"] .sc-gate-skill:not(.sc-gate-hidden)').count()) === 0, '"sempre" esconde o seletor da skill X');

    ok(errs.length === 0, 'sem erros de página (' + errs.slice(0, 2).join(' | ') + ')');
  } finally {
    if (browser) await browser.close();
    s.close();
  }
  console.log('\nRESULTADO: ' + pass + ' ok, ' + fail + ' falhas');
  process.exit(fail > 0 ? 1 : 0);
}
main().catch(e => { console.error('ERRO:', e); process.exit(1); });
