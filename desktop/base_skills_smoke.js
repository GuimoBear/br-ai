// base_skills_smoke.js — feature "usar skills da base" no EDITOR: checkbox #ctxUseBase
// (opt-in, habilitado só p/ Homunculus S com base) e destaque "via base" (g-frombase) no nó
// quando o S não tem o papel mas a base supre. Sobe a estática e dirige o editor.
// Uso: node desktop/base_skills_smoke.js
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
  const o = fs.mkdtempSync(path.join(os.tmpdir(), 'basesk-')); build(o);
  const s = await serve(o, 8153); let browser, pass = 0, fail = 0;
  const ok = (c, m) => { if (c) pass++; else { fail++; console.log('  FAIL-', m); } };
  let pg;
  try {
    try { browser = await chromium.launch(); } catch (e) { console.log('SKIP: chromium'); s.close(); process.exit(0); }
    pg = await browser.newPage({ viewport: { width: 1280, height: 900 } }); const errs = [];
    pg.on('pageerror', e => errs.push(String(e)));
    await pg.goto('http://localhost:8153/editor.html', { waitUntil: 'load' });
    await pg.waitForFunction(() => document.querySelectorAll('.gnode').length > 3, null, { timeout: 30000 });

    // ===== checkbox: desabilitado p/ não-S =====
    await pg.selectOption('#ctxHomun', '4'); // Vanilmirth (não é S)
    await pg.waitForTimeout(200);
    ok(await pg.locator('#ctxUseBase').isDisabled(), 'checkbox desabilitado p/ homún não-S');

    // ===== Sera + base Vanilmirth habilita o checkbox =====
    await pg.selectOption('#ctxHomun', '50'); // Sera (S)
    await pg.waitForTimeout(200);
    ok(await pg.locator('#ctxUseBase').isDisabled(), 'Sera SEM base: checkbox ainda desabilitado');
    await pg.selectOption('#ctxBase', '4'); // base Vanilmirth
    await pg.waitForTimeout(300);
    ok(!(await pg.locator('#ctxUseBase').isDisabled()), 'Sera + base Vanilmirth: checkbox habilitado');

    // prepara um nó de ação como UseHealOwner (Sera não tem cura própria)
    await pg.locator('.gnode:has(span.type.t-act)').first().click();
    await pg.waitForSelector('#iName', { timeout: 8000 });
    await pg.selectOption('#iName', 'UseHealOwner'); await pg.waitForTimeout(400);

    // ===== opt-in OFF: cura aparece como "sem skill" (missing) =====
    let t = await pg.locator('.gnode.sel .s-skills').innerText();
    ok(/sem skill/.test(t), 'flag OFF: UseHealOwner "sem skill" (opt-in) [' + t.replace(/\n/g, ' | ') + ']');
    ok((await pg.locator('.gnode.sel.g-frombase').count()) === 0, 'flag OFF: nó NÃO tem destaque via base');

    // ===== liga o checkbox: agora "via base (Vanilmirth)" =====
    await pg.check('#ctxUseBase'); await pg.waitForTimeout(500);
    t = await pg.locator('.gnode.sel .s-skills').innerText();
    ok(/via base/.test(t), 'flag ON: UseHealOwner mostra "via base" [' + t.replace(/\n/g, ' | ') + ']');
    ok(/Vanilmirth/.test(t), 'flag ON: nomeia a base (Vanilmirth)');
    ok(/Chaotic/.test(t), 'flag ON: herda Chaotic Blessings do Vanilmirth');
    ok((await pg.locator('.gnode.sel.g-frombase').count()) === 1, 'flag ON: nó ganha destaque g-frombase');
    ok((await pg.locator('.gnode.sel.g-noskill').count()) === 0, 'flag ON: NÃO usa o âmbar de "sem skill"');

    // ===== desliga: volta a missing =====
    await pg.uncheck('#ctxUseBase'); await pg.waitForTimeout(500);
    ok((await pg.locator('.gnode.sel.g-frombase').count()) === 0, 'desligar volta a remover o destaque via base');

    ok(errs.length === 0, 'sem erros de página (' + errs.slice(0, 2).join(' | ') + ')');
  } finally {
    if (browser) await browser.close();
    s.close();
  }
  console.log('\nRESULTADO: ' + pass + ' ok, ' + fail + ' falhas');
  process.exit(fail > 0 ? 1 : 0);
}
main().catch(e => { console.error('ERRO:', e); process.exit(1); });
