// disabled_browser_smoke.js — smoke (Playwright) da feature "desativar nó":
//  - editor: desativar um nó o deixa .gdisabled (recursivo) e o botão vira "Ativar";
//  - simulador (espelho do jogo): nós desativados NÃO aparecem na árvore (são podados).
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
  const o = fs.mkdtempSync(path.join(os.tmpdir(), 'dis-')); build(o);
  const s = await serve(o, 8135); let browser, pass = 0, fail = 0;
  const ok = (c, m) => { if (c) pass++; else { fail++; console.log('  FAIL-', m); } };
  try {
    try { browser = await chromium.launch(); } catch (e) { console.log('SKIP: chromium'); s.close(); process.exit(0); }
    const pg = await browser.newPage({ viewport: { width: 1280, height: 820 } }); const errs = [];
    pg.on('pageerror', e => errs.push(String(e)));
    // EDITOR: desativar mantém visível (cinza)
    await pg.goto('http://localhost:8135/editor.html', { waitUntil: 'load' });
    await pg.waitForFunction(() => document.querySelectorAll('.gnode').length > 3, null, { timeout: 30000 });
    let t = pg.locator('.gnode:has-text("sobrevivencia")').first();
    if (!(await t.count())) t = pg.locator('.gnode').nth(3);
    await t.click();
    await pg.waitForSelector('#iToggleDisabled', { timeout: 8000 });
    await pg.click('#iToggleDisabled'); await pg.waitForTimeout(250);
    ok((await pg.evaluate(() => document.querySelectorAll('.gnode.gdisabled').length)) >= 1, 'editor: nó desativado continua visível (.gdisabled)');
    ok(/Ativar/.test(await pg.evaluate(() => (document.getElementById('iToggleDisabled') || {}).textContent || '')), 'editor: botão vira "Ativar"');
    // SIMULADOR: nós desativados NÃO aparecem
    await pg.goto('http://localhost:8135/sim.html', { waitUntil: 'load' });  // simulador (index.html agora redireciona p/ o editor)
    await pg.waitForFunction(() => window.brai && window.BRAIHost, null, { timeout: 30000 });
    const spec = await pg.evaluate(async () => { const r = await window.brai.dispatch('treeSpec', ''); return r.ok ? r.data : null; });
    ok(!!spec, 'sim: obteve treeSpec');
    const count = async () => pg.evaluate(() => document.querySelectorAll('#tree .tnode').length);
    // árvore completa
    await pg.evaluate((j) => sessionStorage.setItem('brai.simTree', j), spec);
    await pg.reload({ waitUntil: 'load' });
    await pg.waitForFunction(() => document.querySelectorAll('#tree .tnode').length > 3, null, { timeout: 30000 });
    const full = await count();
    // árvore com um ramo desativado
    const obj = JSON.parse(spec); if (obj.children && obj.children[1]) obj.children[1].disabled = true;
    await pg.evaluate((j) => sessionStorage.setItem('brai.simTree', j), JSON.stringify(obj));
    await pg.reload({ waitUntil: 'load' });
    await pg.waitForFunction(() => document.querySelectorAll('#tree .tnode').length > 0, null, { timeout: 30000 });
    const dis = await count();
    const off = await pg.evaluate(() => document.querySelectorAll('#tree .tnode.tn-off').length);
    ok(dis < full, 'sim: ramo desativado é PODADO da árvore (' + dis + ' < ' + full + ' nós)');
    ok(off === 0, 'sim: nenhum nó desativado é exibido (.tn-off = 0)');
    ok(errs.length === 0, 'sem erros de página (' + errs.slice(0, 2).join(' | ') + ')');
  } finally { if (browser) await browser.close(); s.close(); }
  console.log('\nRESULTADO: ' + pass + ' ok, ' + fail + ' falhas');
  process.exit(fail > 0 ? 1 : 0);
}
main().catch(e => { console.error('ERRO:', e); process.exit(1); });
