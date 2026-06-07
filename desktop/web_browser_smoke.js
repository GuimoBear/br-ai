// web_browser_smoke.js — smoke de BROWSER REAL (Playwright) da versão WEB existente.
// Rede de segurança da refatoração de fs_bridge.js + lua_host_web.js (que rodam só no
// navegador). Sobe o serve.js, abre sim.html, roda a BT e confere que a IA mata o monstro;
// abre editor.html e confere que a ponte expõe window.trees. Uso: node desktop/web_browser_smoke.js
'use strict';
const path = require('path');
const { spawn } = require('child_process');

async function main() {
  let chromium;
  try { ({ chromium } = require('playwright')); } catch (e) { console.log('SKIP: playwright não instalado'); process.exit(0); }
  const PORT = 8131;
  const srv = spawn('node', [path.join(__dirname, 'web', 'serve.js')], { env: { ...process.env, PORT: String(PORT) }, stdio: 'ignore' });
  await new Promise(r => setTimeout(r, 1200));
  let browser, fail = 0, pass = 0;
  const ok = (c, m) => { if (c) pass++; else { fail++; console.log('  FAIL- ' + m); } };
  try {
    try { browser = await chromium.launch(); } catch (e) { console.log('SKIP: chromium não instalado (npx playwright install chromium)'); srv.kill(); process.exit(0); }
    const page = await browser.newPage();
    const errors = [];
    page.on('pageerror', e => errors.push(String(e)));
    page.on('console', m => { if (m.type() === 'error') errors.push(m.text()); });
    await page.goto('http://localhost:' + PORT + '/desktop/web/sim.html', { waitUntil: 'load' });
    await page.waitForFunction(() => window.brai && window.BRAIHost, null, { timeout: 20000 });
    const res = await page.evaluate(async () => {
      const scn = { grid: { w: 40, h: 40 }, dt: 50, homunId: 100, ownerId: 1, entities: [
        { id: 1, kind: 'owner', x: 10, y: 10, hp: 1000, maxhp: 1000 },
        { id: 100, kind: 'homun', x: 20, y: 20, hp: 100, maxhp: 100, sp: 100, maxsp: 100 },
        { id: 200, kind: 'monster', x: 23, y: 23, hp: 40, maxhp: 40, atk: 5, aggro: 8, etype: 1042 } ] };
      let r = await window.brai.dispatch('load', JSON.stringify(scn)); if (!r.ok) return { err: r.error };
      let s = JSON.parse(r.data);
      for (let i = 0; i < 50; i++) { r = await window.brai.dispatch('step', ''); s = JSON.parse(r.data); }
      const mob = s.entities.find(e => e.id === 200);
      return { nodes: s.tree.length, mobhp: mob.hp };
    });
    ok(res && !res.err, 'sim.html: dispatch load/step sem erro (' + (res && res.err || '') + ')');
    ok(res && res.nodes > 0, 'sim.html: árvore montada (' + (res && res.nodes) + ' nós)');
    ok(res && res.mobhp === 0, 'sim.html: IA matou o monstro no browser real');
    await page.goto('http://localhost:' + PORT + '/desktop/web/editor.html', { waitUntil: 'load' });
    await page.waitForFunction(() => window.trees && window.brai, null, { timeout: 20000 });
    const tlist = await page.evaluate(async () => (await window.trees.list()).data.length);
    ok(tlist > 0, 'editor.html: window.trees.list() retorna árvores (' + tlist + ')');
    ok(errors.length === 0, 'sem erros de console/página (' + errors.slice(0, 3).join(' | ') + ')');
  } finally {
    if (browser) await browser.close();
    srv.kill();
  }
  console.log('\nRESULTADO: ' + pass + ' ok, ' + fail + ' falhas');
  process.exit(fail > 0 ? 1 : 0);
}
main().catch(e => { console.error('ERRO:', e); process.exit(1); });
