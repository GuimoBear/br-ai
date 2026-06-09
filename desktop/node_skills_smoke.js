// node_skills_smoke.js — rótulo do nó no EDITOR mostra as skills (PLANO-SKILLS-NO-NO S3):
// UMA skill por linha (multilinha), nó mais largo (200px), e estados none/missing visíveis.
// Sobe a estática (build_static) e dirige o editor. Uso: node desktop/node_skills_smoke.js
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
  const o = fs.mkdtempSync(path.join(os.tmpdir(), 'nskills-')); build(o);
  const s = await serve(o, 8147); let browser, pass = 0, fail = 0;
  const ok = (c, m) => { if (c) pass++; else { fail++; console.log('  FAIL-', m); } };
  let pg;
  try {
    try { browser = await chromium.launch(); } catch (e) { console.log('SKIP: chromium'); s.close(); process.exit(0); }
    pg = await browser.newPage({ viewport: { width: 1280, height: 900 } }); const errs = [];
    pg.on('pageerror', e => errs.push(String(e)));
    await pg.goto('http://localhost:8147/editor.html', { waitUntil: 'load' });
    await pg.waitForFunction(() => document.querySelectorAll('.gnode').length > 3, null, { timeout: 30000 });
    await pg.selectOption('#ctxHomun', '51'); // Dieter
    await pg.waitForTimeout(300);
    await pg.locator('.gnode:has(span.type.t-act)').first().click();
    await pg.waitForSelector('#iName', { timeout: 8000 });

    // ===== ok: AoE do Dieter = 2 skills, multilinha =====
    await pg.selectOption('#iName', 'UseAoESkill'); await pg.waitForTimeout(400);
    const skills = pg.locator('.gnode.sel .s-skills .sk');
    ok((await skills.count()) === 2, 'AoE do Dieter: 2 linhas de skill (multilinha) [' + (await skills.count()) + ']');
    const txt = await pg.locator('.gnode.sel .s-skills').innerText();
    ok(/Lava Slide/.test(txt) && /Blast Forge/.test(txt), 'mostra Lava Slide + Blast Forge [' + txt.replace(/\n/g, ' | ') + ']');
    ok(/Lv10/.test(txt), 'inclui o nível (Lv10)');

    // ===== nó mais largo (200px) =====
    const box = await pg.locator('.gnode.sel').boundingBox();
    ok(box && Math.round(box.width) === 200, 'nó mais largo (200px) [' + (box && Math.round(box.width)) + ']');

    // ===== missing: Dieter não tem ataque principal =====
    await pg.selectOption('#iName', 'UseMainSkill'); await pg.waitForTimeout(400);
    const mtxt = await pg.locator('.gnode.sel .s-skills').innerText();
    ok(/sem skill p\/ este tipo/.test(mtxt), 'ataque principal (Dieter): "sem skill p/ este tipo" (missing) [' + mtxt + ']');
    ok((await pg.locator('.gnode.sel .s-skills .sk-na').count()) >= 1, 'missing usa estilo sk-na');

    // ===== none: AoE esvaziada na tela Skills =====
    await pg.selectOption('#iName', 'UseAoESkill'); await pg.waitForTimeout(300);
    await pg.click('#btnSkills'); await pg.waitForSelector('#scModal', { timeout: 8000 });
    await pg.selectOption('#scModal #scHomunSel', '51'); await pg.waitForTimeout(300);
    for (const sk of ['8041', '8044']) {
      const b = pg.locator('#scModal .sc-rm[data-role="aoeAtk"][data-skill="' + sk + '"]');
      if (await b.count()) { await b.click(); await pg.waitForTimeout(200); }
    }
    await pg.click('#scSave'); await pg.waitForTimeout(200);
    await pg.click('#scClose'); await pg.waitForTimeout(500);
    const ntxt = await pg.locator('.gnode.sel .s-skills').innerText();
    ok(/nenhuma skill selecionada/.test(ntxt), 'AoE esvaziada: "nenhuma skill selecionada" (none) [' + ntxt + ']');
    ok((await pg.locator('.gnode.sel .s-skills .sk-warn').count()) >= 1, 'none usa estilo sk-warn');

    ok(errs.length === 0, 'sem erros de página (' + errs.slice(0, 2).join(' | ') + ')');
  } finally {
    if (browser) await browser.close();
    s.close();
  }
  console.log('\nRESULTADO: ' + pass + ' ok, ' + fail + ' falhas');
  process.exit(fail > 0 ? 1 : 0);
}
main().catch(e => { console.error('ERRO:', e); process.exit(1); });
