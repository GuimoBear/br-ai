// skillparams_smoke.js — smoke (Playwright) do modal GLOBAL #spModal:
//  - 8 seções por papel (AÇÃO); SEM seletor de homúnculo; SEM combo "herdar".
//  - knob number + booleano sim/não; editar grava no JSON GLOBAL por papel
//    (skillParamsIO, sem dimensão de homúnculo); persiste ao reabrir; export/import.
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
    await pg.waitForTimeout(300);

    // GLOBAL em ABAS: sem seletor de homúnculo; 8 abas; só o papel ATIVO aparece
    const clickTab = async (role) => { await pg.click('#spModal .sp-tab[data-role="' + role + '"]'); await pg.waitForFunction((role) => { const t = document.querySelector('#spModal .sp-tab.active'); return !!t && t.dataset.role === role; }, role, { timeout: 3000 }); };
    ok((await pg.locator('#spModal #spHomunSel').count()) === 0, 'modal GLOBAL: sem seletor de homúnculo');
    ok((await pg.locator('#spModal .sp-tab').count()) === 8, 'modal: 8 abas de papel (ação)');
    ok((await pg.locator('#spModal .sp-row').count()) === 1, 'só o papel ATIVO aparece (1 seção)');
    ok((await pg.locator('#spModal .sp-tab.active').count()) === 1, 'exatamente 1 aba ativa');
    ok((await pg.locator('#spModal .sp-tab[data-role="aoeAtk"]').count()) === 1 && (await pg.locator('#spModal .sp-tab[data-role="castling"]').count()) === 1, 'há abas aoeAtk e castling');
    ok((await pg.locator('#spModal .sp-desc').count()) >= 1, 'a aba ativa mostra a descrição da ação');
    ok((await pg.locator('#spModal .sp-row[data-role="aoeAtk"]').count()) === 1, 'aba ativa inicial = aoeAtk (1º papel)');

    // knob number AutoMobCount (aoeAtk) -> 1 -> grava GLOBAL (params.aoeAtk, sem chave de homún)
    const amc = pg.locator('#spModal .spKnob[data-role="aoeAtk"][data-key="AutoMobCount"]');
    ok((await amc.count()) === 1, 'knob number AutoMobCount (aoeAtk) presente');
    await amc.fill('1'); await amc.dispatchEvent('change'); await pg.waitForTimeout(300);
    let j = await loadJson();
    ok(j.params.aoeAtk && j.params.aoeAtk.AutoMobCount === 1, 'editar AutoMobCount=1 grava em params.aoeAtk (global)');
    ok(!('51' in j.params) && !('4' in j.params) && !('50' in j.params), 'JSON não tem mais dimensão por homúnculo');

    // booleano sim/não (SEM "herdar")
    const uas = pg.locator('#spModal .spKnob[data-role="aoeAtk"][data-key="UseAttackSkill"]');
    ok((await uas.count()) === 1 && (await uas.evaluate(e => e.tagName)) === 'SELECT', 'UseAttackSkill é booleano (select)');
    const opts = await uas.evaluate(e => Array.from(e.options).map(x => x.value));
    ok(opts.length === 2 && opts.indexOf('true') >= 0 && opts.indexOf('false') >= 0 && opts.indexOf('') < 0, 'booleano só tem sim/não (sem opção "herdar")');
    await uas.selectOption('false'); await pg.waitForTimeout(300);
    j = await loadJson();
    ok(j.params.aoeAtk.UseAttackSkill === false, 'booleano "não" grava false (global)');

    // limpar número remove a chave do JSON
    await amc.fill(''); await amc.dispatchEvent('change'); await pg.waitForTimeout(300);
    j = await loadJson();
    ok(!(j.params.aoeAtk && ('AutoMobCount' in j.params.aoeAtk)), 'limpar número remove a chave do JSON');

    // cura/castling continuam configuráveis aqui (trocando de aba)
    await clickTab('healSelf');
    ok((await pg.locator('#spModal .spKnob[data-role="healSelf"][data-key="HealSelfHP"]').count()) === 1, 'aba healSelf tem HealSelfHP');
    ok((await pg.locator('#spModal .sp-row[data-role="aoeAtk"]').count()) === 0, 'ao trocar de aba, o papel anterior some (só 1 ativo)');
    await clickTab('healOwner');
    ok((await pg.locator('#spModal .spKnob[data-role="healOwner"][data-key="HealOwnerHP"]').count()) === 1, 'aba healOwner tem HealOwnerHP');
    await clickTab('castling');
    ok((await pg.locator('#spModal .spKnob[data-role="castling"][data-key="CastleDefendThreshold"]').count()) === 1, 'aba castling tem CastleDefendThreshold');

    // persiste ao reabrir
    await pg.evaluate(() => { const m = document.getElementById('spModal'); if (m) m.remove(); });
    await pg.click('#btnSkillParams'); await pg.waitForSelector('#spModal'); await pg.waitForTimeout(300);
    await clickTab('aoeAtk');
    ok((await pg.locator('#spModal .spKnob[data-role="aoeAtk"][data-key="UseAttackSkill"]').inputValue()) === 'false', 'reabrir: UseAttackSkill="não" persistiu');

    ok((await pg.locator('#spExport').count()) === 1 && (await pg.locator('#spImport').count()) === 1, 'tem botões exportar/importar parâmetros');
    ok(errs.length === 0, 'sem erros de página (' + errs.slice(0, 2).join(' | ') + ')');
  } finally { if (browser) await browser.close(); s.close(); }
  console.log('\nRESULTADO: ' + pass + ' ok, ' + fail + ' falhas');
  process.exit(fail > 0 ? 1 : 0);
}
main().catch(e => { console.error('ERRO:', e); process.exit(1); });
