// config_propagation_smoke.js — a config dos modais reflete na ÁRVORE e no SIMULADOR:
//  - editar a tela de Skills (remover Lava Slide do Dieter) + fechar -> rótulo do nó atualiza;
//  - botão "Salvar" presente em todos os modais;
//  - o simulador carrega/ aplica skillParams (homun_skill_params.json) no boot.
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
  const o = fs.mkdtempSync(path.join(os.tmpdir(), 'prop-')); build(o);
  const s = await serve(o, 8143); let browser, pass = 0, fail = 0;
  const ok = (c, m) => { if (c) pass++; else { fail++; console.log('  FAIL-', m); } };
  let pg;
  try {
    try { browser = await chromium.launch(); } catch (e) { console.log('SKIP: chromium'); s.close(); process.exit(0); }
    pg = await browser.newPage({ viewport: { width: 1280, height: 900 } }); const errs = [];
    pg.on('pageerror', e => errs.push(String(e)));

    // ===== EDITOR: editar Skills -> rótulo do nó reflete =====
    await pg.goto('http://localhost:8143/editor.html', { waitUntil: 'load' });
    await pg.waitForFunction(() => document.querySelectorAll('.gnode').length > 3, null, { timeout: 30000 });
    await pg.selectOption('#ctxHomun', '51');   // Dieter
    await pg.waitForTimeout(300);
    await pg.locator('.gnode:has(span.type.t-act)').first().click();
    await pg.waitForSelector('#iName', { timeout: 8000 });
    await pg.selectOption('#iName', 'UseAoESkill');
    await pg.waitForTimeout(300);
    const subOf = async () => (await pg.locator('.gnode.sel .s').first().innerText());
    ok(/Lava Slide/.test(await subOf()), 'antes: nó mostra o padrão do Dieter (Lava Slide)');

    // abre Skills, Dieter, remove Lava Slide (8041) do aoeAtk
    await pg.click('#btnSkills'); await pg.waitForSelector('#scModal', { timeout: 8000 });
    await pg.selectOption('#scModal #scHomunSel', '51'); await pg.waitForTimeout(300);
    await pg.click('#scModal .sc-rm[data-role="aoeAtk"][data-skill="8041"]'); await pg.waitForTimeout(300);
    ok((await pg.locator('#scSave').count()) === 1, 'modal Skills tem botão Salvar');
    await pg.click('#scClose'); await pg.waitForTimeout(500);   // fechar dispara refreshTreeLabels
    const sub2 = await subOf();
    ok(/Blast Forge/.test(sub2) && !/Lava Slide/.test(sub2), 'depois de editar+fechar: nó reflete (Blast Forge, sem Lava Slide) [' + sub2 + ']');

    // ===== botão Salvar em todos os modais =====
    for (const [open, save, close] of [['#btnSkillParams', '#spSave', '#spClose'], ['#btnConfig', '#cfgSave', '#cfgClose'], ['#btnMonsters', '#mmSave', '#mmClose']]) {
      await pg.click(open); await pg.waitForTimeout(250);
      ok((await pg.locator(save).count()) === 1, 'modal ' + open + ' tem botão Salvar');
      await pg.click(close); await pg.waitForTimeout(150);
    }
    // Combos (Eleanor): cria/seleciona um nó UseEleanorOffense p/ abrir a UI principal (com Salvar)
    await pg.selectOption('#ctxHomun', '52'); await pg.waitForTimeout(200);
    await pg.locator('.gnode:has(span.type.t-act)').first().click();
    await pg.waitForSelector('#iName', { timeout: 8000 });
    await pg.selectOption('#iName', 'UseEleanorOffense'); await pg.waitForTimeout(200);
    await pg.click('#btnCombos'); await pg.waitForTimeout(300);
    ok((await pg.locator('#ceSave').count()) === 1, 'modal Combos tem botão Salvar');
    await pg.click('#ceClose').catch(() => {}); await pg.waitForTimeout(150);

    // ===== SIMULADOR: aplica skillParams do localStorage no boot =====
    await pg.goto('http://localhost:8143/sim.html', { waitUntil: 'load' });
    await pg.evaluate(() => localStorage.setItem('brai.skillparams', JSON.stringify({ params: { '51': { aoeAtk: { AutoMobCount: 1 } } } })));
    await pg.reload({ waitUntil: 'load' });
    await pg.waitForFunction(() => window.brai && typeof window.brai.dispatch === 'function', null, { timeout: 30000 });
    await pg.waitForTimeout(500);
    const pcVal = await pg.evaluate(async () => {
      const r = await window.brai.dispatch('paramConfig', JSON.stringify({ homunType: 51 }));
      const pc = JSON.parse(r.data);
      const aoe = pc.find(x => x.role === 'aoeAtk');
      const k = aoe.knobs.find(x => x.key === 'AutoMobCount');
      return k ? k.value : null;
    });
    ok(pcVal === 1, 'simulador: loadSkillParams aplicou (paramConfig AutoMobCount.value=1) [' + pcVal + ']');

    ok(errs.length === 0, 'sem erros de página (' + errs.slice(0, 2).join(' | ') + ')');
  } finally { if (browser) await browser.close(); s.close(); }
  console.log('\nRESULTADO: ' + pass + ' ok, ' + fail + ' falhas');
  process.exit(fail > 0 ? 1 : 0);
}
main().catch(e => { console.error('ERRO:', e); process.exit(1); });
