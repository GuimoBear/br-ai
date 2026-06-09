// palette_smoke.js — smoke (Playwright) da usabilidade da paleta:
//  - dropdowns de condição/ação AGRUPADOS (optgroup) com TÍTULOS legíveis + código na dica;
//  - nós mostram o título legível (código na dica do nó);
//  - ações de skill têm botão "Configurar skills" que abre o modal de Skills;
//  - o SIMULADOR mostra os mesmos rótulos legíveis (sem "?Name"/"!Name").
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
  const o = fs.mkdtempSync(path.join(os.tmpdir(), 'pal-')); build(o);
  const s = await serve(o, 8139); let browser, pass = 0, fail = 0;
  const ok = (c, m) => { if (c) pass++; else { fail++; console.log('  FAIL-', m); } };
  let pg;
  try {
    try { browser = await chromium.launch(); } catch (e) { console.log('SKIP: chromium'); s.close(); process.exit(0); }
    pg = await browser.newPage({ viewport: { width: 1280, height: 820 } }); const errs = [];
    pg.on('pageerror', e => errs.push(String(e)));

    // ===== EDITOR =====
    await pg.goto('http://localhost:8139/editor.html', { waitUntil: 'load' });
    await pg.waitForFunction(() => document.querySelectorAll('.gnode').length > 3, null, { timeout: 30000 });

    // ação: dropdown agrupado + títulos + código na dica
    await pg.locator('.gnode:has(span.type.t-act)').first().click();
    await pg.waitForSelector('#iName', { timeout: 8000 });
    ok((await pg.locator('#iName optgroup').count()) >= 3, 'ações: dropdown agrupado (>=3 optgroups)');
    ok((await pg.locator('#iName optgroup[label="Skills ofensivas"]').count()) === 1, 'grupo "Skills ofensivas" presente');
    const aoeOpt = pg.locator('#iName option[value="UseAoESkill"]');
    ok((await aoeOpt.innerText()).includes('Skill em área (AoE)'), 'opção UseAoESkill traz título legível');
    ok((await aoeOpt.getAttribute('title')) === 'UseAoESkill', 'opção traz o código na dica (title=UseAoESkill)');

    // selecionar UseAoESkill -> nó mostra o título; dica do nó traz o código
    await pg.selectOption('#iName', 'UseAoESkill');
    await pg.waitForTimeout(200);
    ok(/Skill em área \(AoE\)/.test(await pg.locator('.gnode.sel .t').first().innerText()), 'nó mostra o título legível');
    ok(/UseAoESkill/.test(await pg.locator('.gnode.sel .t').first().getAttribute('title') || ''), 'dica do nó traz o código');

    // ação de skill: botão abre o modal de Skills
    ok((await pg.locator('#iSkillCfg').count()) === 1, 'ação de skill tem botão "Configurar skills"');
    await pg.click('#iSkillCfg');
    await pg.waitForSelector('#scModal', { timeout: 8000 });
    ok(await pg.locator('#scModal').isVisible(), 'botão abre o modal de Skills (#scModal)');
    await pg.evaluate(() => { const m = document.getElementById('scModal'); if (m) m.remove(); });

    // condição: dropdown do check também agrupado + título legível
    const chk = pg.locator('.gnode:has(span.type.t-chk)').first();
    if (await chk.count()) {
      await chk.click();
      await pg.waitForSelector('#iCheckName', { timeout: 8000 });
      ok((await pg.locator('#iCheckName optgroup').count()) >= 2, 'condições: dropdown do check agrupado');
      ok((await pg.locator('#iCheckName option').first().innerText()) !== (await pg.locator('#iCheckName option').first().getAttribute('value')), 'condições: opção mostra título ≠ código');
    } else { ok(true, '(sem nó check na árvore padrão — pulado)'); }

    // ===== SIMULADOR =====
    await pg.goto('http://localhost:8139/sim.html', { waitUntil: 'load' });
    await pg.waitForFunction(() => window.brai && window.BRAIHost, null, { timeout: 30000 });
    const spec = await pg.evaluate(async () => { const r = await window.brai.dispatch('treeSpec', ''); return r.ok ? r.data : null; });
    await pg.evaluate((j) => sessionStorage.setItem('brai.simTree', j), spec);
    await pg.reload({ waitUntil: 'load' });
    await pg.waitForFunction(() => document.querySelectorAll('#tree .tnode').length > 3, null, { timeout: 30000 });
    const labels = await pg.evaluate(() => [].slice.call(document.querySelectorAll('#tree .tn-lbl')).map(e => e.textContent));
    ok(labels.length > 0 && !labels.some(l => /^[?!]/.test(l)), 'simulador: rótulos legíveis (sem prefixo ?Name/!Name)');
    ok(!labels.some(l => /^(parallel|cooldown|limiter):|^alvo\?$/.test(l)), 'simulador: nenhum rótulo cru/default do motor vaza');
    ok(labels.some(l => /Seguir o dono|Escolher alvo|Atacar|Seletor|Sequência|Skill/i.test(l)), 'simulador: ao menos um rótulo PT reconhecível [' + labels.slice(0, 4).join(' | ') + ']');

    ok(errs.length === 0, 'sem erros de página (' + errs.slice(0, 2).join(' | ') + ')');
  } finally { if (browser) await browser.close(); s.close(); }
  console.log('\nRESULTADO: ' + pass + ' ok, ' + fail + ' falhas');
  process.exit(fail > 0 ? 1 : 0);
}
main().catch(e => { console.error('ERRO:', e); process.exit(1); });
