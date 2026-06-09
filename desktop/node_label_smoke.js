// node_label_smoke.js — smoke (Playwright) do #5: o rótulo (sub) das ações automáticas
// mostra as skills efetivas (nome+nível) do homún do contexto; vazio quando o papel não
// tem skill (Dieter mainAtk); atualiza ao trocar o homún. [PLANO-GERACAO-LUA G7]
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
  const o = fs.mkdtempSync(path.join(os.tmpdir(), 'nlbl-')); build(o);
  const s = await serve(o, 8138); let browser, pass = 0, fail = 0;
  const ok = (c, m) => { if (c) pass++; else { fail++; console.log('  FAIL-', m); } };
  let pg;
  try {
    try { browser = await chromium.launch(); } catch (e) { console.log('SKIP: chromium'); s.close(); process.exit(0); }
    pg = await browser.newPage({ viewport: { width: 1280, height: 820 } }); const errs = [];
    pg.on('pageerror', e => errs.push(String(e)));
    await pg.goto('http://localhost:8138/editor.html', { waitUntil: 'load' });
    await pg.waitForFunction(() => document.querySelectorAll('.gnode').length > 3, null, { timeout: 30000 });
    const sub = async () => (await pg.locator('.gnode.sel .s').first().innerText());

    // contexto = Dieter (51)
    await pg.selectOption('#ctxHomun', '51');
    await pg.waitForTimeout(400);
    // seleciona uma ação e vira UseAoESkill
    await pg.locator('.gnode:has(span.type.t-act)').first().click();
    await pg.waitForSelector('#iName', { timeout: 8000 });
    await pg.selectOption('#iName', 'UseAoESkill');
    await pg.waitForTimeout(300);
    let txt = await sub();
    ok(/Lava Slide Lv\d+/.test(txt) && /Blast Forge Lv\d+/.test(txt), 'Dieter/UseAoESkill: rótulo mostra Lava Slide + Blast Forge com nível [' + txt + ']');

    // UseMainSkill: Dieter não tem mainAtk -> rótulo sem skill
    await pg.selectOption('#iName', 'UseMainSkill');
    await pg.waitForTimeout(300);
    txt = await sub();
    ok(!/Lv\d+/.test(txt), 'Dieter/UseMainSkill: sem mainAtk -> não exibe skill [' + JSON.stringify(txt) + ']');

    // troca p/ Bayeri (49): UseMainSkill agora mostra Stahl Horn (atualiza ao trocar homún)
    await pg.selectOption('#ctxHomun', '49');
    await pg.waitForTimeout(400);
    txt = await sub();
    ok(/Stahl Horn Lv\d+/.test(txt), 'Bayeri/UseMainSkill: rótulo mostra Stahl Horn (atualizou ao trocar homún) [' + txt + ']');

    // Bayeri/UseAoESkill -> Heilige Stange
    await pg.selectOption('#iName', 'UseAoESkill');
    await pg.waitForTimeout(300);
    txt = await sub();
    ok(/Heilige Stange Lv\d+/.test(txt), 'Bayeri/UseAoESkill: rótulo mostra Heilige Stange [' + txt + ']');

    // Bayeri/UseOffensiveBuff -> mantém TODAS (Golden Ferse + Angriff Modus)
    await pg.selectOption('#iName', 'UseOffensiveBuff');
    await pg.waitForTimeout(300);
    txt = await sub();
    ok(/Golden Ferse/.test(txt) && /Angriff Modus/.test(txt), 'Bayeri/UseOffensiveBuff: rótulo mostra os 2 buffs [' + txt + ']');

    ok(errs.length === 0, 'sem erros de página (' + errs.slice(0, 2).join(' | ') + ')');
  } finally { if (browser) await browser.close(); s.close(); }
  console.log('\nRESULTADO: ' + pass + ' ok, ' + fail + ' falhas');
  process.exit(fail > 0 ? 1 : 0);
}
main().catch(e => { console.error('ERRO:', e); process.exit(1); });
