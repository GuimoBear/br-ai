// skillparams_smoke.js — smoke (Playwright) do modal #spModal (C4):
//  - 8 seções por papel; skill em destaque; knob number + booleano tri-estado;
//  - editar grava no JSON (skillParamsIO); "herdar" remove; persiste ao reabrir; export.
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
  const o = fs.mkdtempSync(path.join(os.tmpdir(), 'sp-')); build(o);
  const s = await serve(o, 8142); let browser, pass = 0, fail = 0;
  const ok = (c, m) => { if (c) pass++; else { fail++; console.log('  FAIL-', m); } };
  const loadJson = () => pg.evaluate(async () => JSON.parse((await window.skillParamsIO.load()).data));
  let pg;
  try {
    try { browser = await chromium.launch(); } catch (e) { console.log('SKIP: chromium'); s.close(); process.exit(0); }
    pg = await browser.newPage({ viewport: { width: 1280, height: 900 } }); const errs = [];
    pg.on('pageerror', e => errs.push(String(e)));
    await pg.goto('http://localhost:8142/editor.html', { waitUntil: 'load' });
    await pg.waitForFunction(() => document.querySelectorAll('.gnode').length > 3, null, { timeout: 30000 });

    await pg.click('#btnSkillParams');
    await pg.waitForSelector('#spModal', { timeout: 8000 });
    await pg.selectOption('#spModal #spHomunSel', '51');   // Dieter
    await pg.waitForTimeout(300);

    ok((await pg.locator('#spModal .sp-row').count()) === 8, 'modal: 8 seções de papel');
    ok(/Lava Slide/.test(await pg.locator('#spModal .sp-row').first().innerText()), 'aoeAtk mostra a skill em destaque (Lava Slide)');
    // C5: card rico (skillInfoHtml) com Alcance/SP/Cast
    ok((await pg.locator('#spModal .sp-row .skillinfo').count()) >= 1, 'C5: card rico (skillinfo) presente');
    ok(/Alcance|SP|Cast|Recarga/.test(await pg.locator('#spModal .sp-row').first().innerText()), 'C5: card mostra dados (Alcance/SP/Cast/...)');

    // knob number AutoMobCount (aoeAtk) -> 1 -> grava
    const amc = pg.locator('#spModal .spKnob[data-role="aoeAtk"][data-key="AutoMobCount"]');
    ok((await amc.count()) === 1, 'knob number AutoMobCount (aoeAtk) presente');
    await amc.fill('1'); await amc.dispatchEvent('change'); await pg.waitForTimeout(300);
    let j = await loadJson();
    ok(j.params['51'] && j.params['51'].aoeAtk && j.params['51'].aoeAtk.AutoMobCount === 1, 'editar AutoMobCount=1 grava no JSON');

    // booleano tri-estado UseAttackSkill -> "não" (false)
    const uas = pg.locator('#spModal .spKnob[data-role="aoeAtk"][data-key="UseAttackSkill"]');
    ok((await uas.count()) === 1 && (await uas.evaluate(e => e.tagName)) === 'SELECT', 'UseAttackSkill é booleano tri-estado (select)');
    await uas.selectOption('false'); await pg.waitForTimeout(300);
    j = await loadJson();
    ok(j.params['51'].aoeAtk.UseAttackSkill === false, 'booleano "não" grava false');

    // herdar: limpar AutoMobCount remove do JSON
    await amc.fill(''); await amc.dispatchEvent('change'); await pg.waitForTimeout(300);
    j = await loadJson();
    ok(!(j.params['51'] && j.params['51'].aoeAtk && ('AutoMobCount' in j.params['51'].aoeAtk)), 'limpar = herdar (remove do JSON)');

    // persiste ao reabrir
    await pg.evaluate(() => { const m = document.getElementById('spModal'); if (m) m.remove(); });
    await pg.click('#btnSkillParams'); await pg.waitForSelector('#spModal');
    await pg.selectOption('#spModal #spHomunSel', '51'); await pg.waitForTimeout(300);
    ok((await pg.locator('#spModal .spKnob[data-role="aoeAtk"][data-key="UseAttackSkill"]').inputValue()) === 'false', 'reabrir: UseAttackSkill="não" persistiu');

    // papel de cura (Vanilmirth healSelf -> HealSelfHP)
    await pg.selectOption('#spModal #spHomunSel', '4'); await pg.waitForTimeout(300);
    ok((await pg.locator('#spModal .spKnob[data-role="healSelf"][data-key="HealSelfHP"]').count()) === 1, 'Vanilmirth: papel healSelf tem HealSelfHP');
    ok(/Caprice/.test(await pg.locator('#spModal').innerText()), 'C5: trocar homún atualiza o card (Vanilmirth → Caprice)');
    // C7: Homunculus S mostra a nota da forma base
    await pg.selectOption('#spModal #spHomunSel', '50'); await pg.waitForTimeout(300);
    ok((await pg.locator('#spModal .sp-basenote').count()) === 1, 'C7: Homunculus S (Sera) mostra nota da forma base');

    ok((await pg.locator('#spExport').count()) === 1 && (await pg.locator('#spImport').count()) === 1, 'tem botões exportar/importar parâmetros');
    ok(errs.length === 0, 'sem erros de página (' + errs.slice(0, 2).join(' | ') + ')');
  } finally { if (browser) await browser.close(); s.close(); }
  console.log('\nRESULTADO: ' + pass + ' ok, ' + fail + ' falhas');
  process.exit(fail > 0 ? 1 : 0);
}
main().catch(e => { console.error('ERRO:', e); process.exit(1); });
