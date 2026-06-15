// config_jump_smoke.js — atalhos de configuração nos nós (PLANO-ATALHOS-CONFIG): botões do
// inspetor (Configurar skills / Parâmetros / monstros) e o ⚙ NO NÓ abrem o modal certo,
// pré-selecionados (homún do editor + role destacada; monsterCheck no grupo/monstro do nó).
// Sobe a estática e dirige o editor. Uso: node desktop/config_jump_smoke.js
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
  const o = fs.mkdtempSync(path.join(os.tmpdir(), 'cfgjump-')); build(o);
  const s = await serve(o, 8157); let browser, pass = 0, fail = 0;
  const ok = (c, m) => { if (c) pass++; else { fail++; console.log('  FAIL-', m); } };
  let pg;
  try {
    try { browser = await chromium.launch(); } catch (e) { console.log('SKIP: chromium'); s.close(); process.exit(0); }
    pg = await browser.newPage({ viewport: { width: 1280, height: 900 } }); const errs = [];
    pg.on('pageerror', e => errs.push(String(e)));
    await pg.goto('http://localhost:8157/editor.html', { waitUntil: 'load' });
    await pg.waitForFunction(() => document.querySelectorAll('.gnode').length > 3, null, { timeout: 30000 });
    await pg.selectOption('#ctxHomun', '51'); // Dieter
    await pg.waitForTimeout(300);

    // prepara um nó como UseAoESkill (Dieter tem AoE)
    await pg.locator('.gnode:has(span.type.t-act)').first().click();
    await pg.waitForSelector('#iName', { timeout: 8000 });
    await pg.selectOption('#iName', 'UseAoESkill'); await pg.waitForTimeout(400);

    // ===== inspetor: "Configurar skills…" abre Skills no homún certo + role destacada =====
    await pg.click('#iSkillCfg'); await pg.waitForSelector('#scModal', { timeout: 8000 });
    ok(await pg.locator('#scModal').isVisible(), 'Configurar skills abre o modal de Skills');
    ok((await pg.locator('#scHomunSel').inputValue()) === '51', 'Skills abre no homún do editor (Dieter=51)');
    ok((await pg.locator('#scModal .sc-row[data-role="aoeAtk"].sc-focus, #scModal .sc-skills[data-role="aoeAtk"].sc-focus').count()) >= 1, 'papel aoeAtk destacado (sc-focus)');
    await pg.click('#scModal #scClose'); await pg.waitForTimeout(200);

    // troca o homún do editor e reabre: deve abrir no NOVO homún (mata o "grudento")
    await pg.selectOption('#ctxHomun', '50'); await pg.waitForTimeout(300); // Sera
    await pg.locator('.gnode:has(span.type.t-act)').first().click();
    await pg.waitForSelector('#iName', { timeout: 8000 });
    await pg.selectOption('#iName', 'UseAoESkill'); await pg.waitForTimeout(300);
    await pg.click('#iSkillCfg'); await pg.waitForSelector('#scModal', { timeout: 8000 });
    ok((await pg.locator('#scHomunSel').inputValue()) === '50', 'reabrir usa o homún ATUAL (Sera=50), não o grudento');
    await pg.click('#scModal #scClose'); await pg.waitForTimeout(200);

    // ===== inspetor: "Parâmetros desta skill…" abre na aba do papel =====
    await pg.click('#iParamCfg'); await pg.waitForSelector('#spModal', { timeout: 8000 });
    ok((await pg.locator('#spModal .sp-tab.active[data-role="aoeAtk"]').count()) === 1, 'Parâmetros abre na aba aoeAtk');
    await pg.click('#spModal #spClose'); await pg.waitForTimeout(200);

    // ===== botões NO NÓ: DOIS (skills do homún + parâmetros) =====
    ok((await pg.locator('.gnode.sel .cfgbtn').count()) === 2, 'nó de skill tem 2 botões (skills + parâmetros)');
    await pg.locator('.gnode.sel .cfgbtn.cfg-skills').click(); await pg.waitForSelector('#scModal', { timeout: 8000 });
    ok(await pg.locator('#scModal').isVisible(), '⚙ skills no nó abre o modal de Skills');
    ok((await pg.locator('#scHomunSel').inputValue()) === '50', '⚙ skills no nó usa o homún do editor');
    await pg.click('#scModal #scClose'); await pg.waitForTimeout(200);
    await pg.locator('.gnode.sel .cfgbtn.cfg-params').click(); await pg.waitForSelector('#spModal', { timeout: 8000 });
    ok((await pg.locator('#spModal .sp-tab.active[data-role="aoeAtk"]').count()) === 1, 'botão de parâmetros no nó abre na aba aoeAtk');
    await pg.click('#spModal #spClose'); await pg.waitForTimeout(200);

    // ⚙ NÃO seleciona/arrasta o nó: clicar nele não muda a seleção atual
    // (o nó já está selecionado; garantimos que continua selecionado e o grafo não quebrou)
    ok((await pg.locator('.gnode.sel').count()) === 1, 'clicar ⚙ não bagunça a seleção');

    // ===== ⚙ só aparece em nós de skill/monsterCheck =====
    const totalNodes = await pg.locator('.gnode').count();
    const nodesWithCfg = await pg.locator('.gnode:has(.cfgbtn)').count();
    ok(nodesWithCfg >= 1 && nodesWithCfg < totalNodes, '⚙ aparece só em alguns nós (skill/monsterCheck), não em todos [' + nodesWithCfg + '/' + totalNodes + ']');

    // ===== base-homún: skill vinda da base abre Skills no homún BASE =====
    await pg.selectOption('#ctxHomun', '50');           // Sera (S)
    await pg.waitForTimeout(200);
    await pg.selectOption('#ctxBase', '4');              // base Vanilmirth
    await pg.waitForTimeout(200);
    await pg.check('#ctxUseBase'); await pg.waitForTimeout(400);
    // um nó UseHealOwner: Sera não tem cura, vem do Vanilmirth (fromBase)
    await pg.locator('.gnode:has(span.type.t-act)').first().click();
    await pg.waitForSelector('#iName', { timeout: 8000 });
    await pg.selectOption('#iName', 'UseHealOwner'); await pg.waitForTimeout(400);
    await pg.locator('.gnode.sel .cfgbtn.cfg-skills').click(); await pg.waitForSelector('#scModal', { timeout: 8000 });
    ok((await pg.locator('#scHomunSel').inputValue()) === '4', 'skill via base: Skills abre no homún BASE (Vanilmirth=4)');
    await pg.click('#scModal #scClose'); await pg.waitForTimeout(200);
    // desmarcando, volta ao homún principal
    await pg.uncheck('#ctxUseBase'); await pg.waitForTimeout(300);
    await pg.locator('.gnode.sel .cfgbtn.cfg-skills').click(); await pg.waitForSelector('#scModal', { timeout: 8000 });
    ok((await pg.locator('#scHomunSel').inputValue()) === '50', 'sem usar base: Skills volta ao homún principal (Sera=50)');
    await pg.click('#scModal #scClose'); await pg.waitForTimeout(200);

    // ===== monsterCheck: ⚙/inspetor abrem o gerenciador de monstros =====
    await pg.locator('.gnode:has(span.type.t-act)').first().click();
    await pg.waitForSelector('#iType', { timeout: 8000 });
    await pg.selectOption('#iType', 'monsterCheck'); await pg.waitForTimeout(400);
    ok((await pg.locator('.gnode.sel .cfgbtn').count()) === 1, 'nó monsterCheck tem ⚙');
    await pg.click('#iMonMgr'); await pg.waitForSelector('#monModal', { timeout: 8000 });
    ok(await pg.locator('#monModal').isVisible(), 'monsterCheck: abre o gerenciador de monstros');
    await pg.click('#monModal .mm-x'); await pg.waitForTimeout(200);

    // ===== esconde "configurar skills" quando nem homún nem base têm o tipo (missing) =====
    await pg.selectOption('#ctxHomun', '51'); await pg.waitForTimeout(150); // Dieter (AoE-only, sem mainAtk)
    await pg.selectOption('#ctxBase', '0'); await pg.waitForTimeout(300);   // sem base
    await pg.locator('.gnode:has(span.type.t-act)').first().click();
    await pg.waitForSelector('#iName', { timeout: 8000 });
    await pg.selectOption('#iName', 'UseMainSkill'); await pg.waitForTimeout(400); // Dieter não tem mainAtk -> missing
    ok((await pg.locator('.gnode.sel .cfgbtn.cfg-skills').count()) === 0, 'missing: botão "configurar skills" (homún) some do nó');
    ok((await pg.locator('.gnode.sel .cfgbtn.cfg-params').count()) === 1, 'missing: botão de parâmetros continua no nó');
    ok((await pg.locator('#iSkillCfg').count()) === 0, 'missing: "Configurar skills" some do inspetor');
    ok((await pg.locator('#iParamCfg').count()) === 1, 'missing: "Parâmetros" continua no inspetor');

    ok(errs.length === 0, 'sem erros de página (' + errs.slice(0, 2).join(' | ') + ')');
  } finally {
    if (browser) await browser.close();
    s.close();
  }
  console.log('\nRESULTADO: ' + pass + ' ok, ' + fail + ' falhas');
  process.exit(fail > 0 ? 1 : 0);
}
main().catch(e => { console.error('ERRO:', e); process.exit(1); });
