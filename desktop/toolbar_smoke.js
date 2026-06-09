// toolbar_smoke.js — smoke (Playwright) da toolbar em 2 linhas (C3):
//  - #tbRow1 (edição/arquivo) e #tbRow2 (config) existem e estão empilhadas;
//  - #tbRow2 tem Monstros/Skills/Parâmetros/Combos/Config; #tbRow1 tem Simular/Gerar Lua;
//  - o botão "Parâmetros" (#btnSkillParams) abre o modal #spModal.
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
  const o = fs.mkdtempSync(path.join(os.tmpdir(), 'tb-')); build(o);
  const s = await serve(o, 8141); let browser, pass = 0, fail = 0;
  const ok = (c, m) => { if (c) pass++; else { fail++; console.log('  FAIL-', m); } };
  let pg;
  try {
    try { browser = await chromium.launch(); } catch (e) { console.log('SKIP: chromium'); s.close(); process.exit(0); }
    pg = await browser.newPage({ viewport: { width: 1280, height: 820 } }); const errs = [];
    pg.on('pageerror', e => errs.push(String(e)));
    await pg.goto('http://localhost:8141/editor.html', { waitUntil: 'load' });
    await pg.waitForFunction(() => document.querySelectorAll('.gnode').length > 3, null, { timeout: 30000 });

    ok((await pg.locator('#tbRow1').count()) === 1, 'toolbar tem #tbRow1');
    ok((await pg.locator('#tbRow2').count()) === 1, 'toolbar tem #tbRow2');
    // 2ª linha tem os botões de config
    for (const id of ['btnMonsters', 'btnSkills', 'btnSkillParams', 'btnCombos', 'btnConfig'])
      ok((await pg.locator('#tbRow2 #' + id).count()) === 1, '#tbRow2 tem #' + id);
    // 1ª linha tem edição/arquivo
    for (const id of ['btnSimulate', 'btnBuildTree', 'btnAddChild'])
      ok((await pg.locator('#tbRow1 #' + id).count()) === 1, '#tbRow1 tem #' + id);
    // empilhadas: tbRow2 abaixo de tbRow1
    const r1 = await pg.locator('#tbRow1').boundingBox(), r2 = await pg.locator('#tbRow2').boundingBox();
    ok(r1 && r2 && r2.y >= r1.y + r1.height - 2, 'tbRow2 está ABAIXO de tbRow1 (2 linhas)');

    // botão Parâmetros abre o #spModal
    await pg.click('#btnSkillParams');
    await pg.waitForSelector('#spModal', { timeout: 8000 });
    ok(await pg.locator('#spModal').isVisible(), 'botão Parâmetros abre o modal #spModal');
    ok((await pg.locator('#spModal #spHomunSel').count()) === 1, '#spModal tem seletor de homúnculo');

    ok(errs.length === 0, 'sem erros de página (' + errs.slice(0, 2).join(' | ') + ')');
  } finally { if (browser) await browser.close(); s.close(); }
  console.log('\nRESULTADO: ' + pass + ' ok, ' + fail + ' falhas');
  process.exit(fail > 0 ? 1 : 0);
}
main().catch(e => { console.error('ERRO:', e); process.exit(1); });
