// static_browser_smoke.js — smoke de BROWSER REAL (Playwright) da versão ESTÁTICA.
// Faz o build em tmp, serve via http local, abre index.html (simulador), roda a BT, e
// confere a REGRA DE STORAGE: nada de conteúdo do usuário em localStorage. Depois abre
// editor.html e confere as listas vindas do data/. Uso: node desktop/static_browser_smoke.js
'use strict';
const fs = require('fs');
const os = require('os');
const path = require('path');
const http = require('http');
const ROOT = path.join(__dirname, '..');

function serve(dir, port) {
  const MIME = { '.html': 'text/html; charset=utf-8', '.js': 'text/javascript; charset=utf-8', '.css': 'text/css; charset=utf-8', '.json': 'application/json; charset=utf-8' };
  const s = http.createServer((req, res) => {
    let p = decodeURIComponent(req.url.split('?')[0]); if (p === '/') p = '/index.html';
    const f = path.join(dir, p);
    fs.readFile(f, (e, d) => { if (e) { res.writeHead(404); res.end('404'); } else { res.writeHead(200, { 'Content-Type': MIME[path.extname(f)] || 'application/octet-stream' }); res.end(d); } });
  });
  return new Promise(r => s.listen(port, () => r(s)));
}

async function main() {
  let chromium;
  try { ({ chromium } = require('playwright')); } catch (e) { console.log('SKIP: playwright não instalado'); process.exit(0); }
  const { build } = require(path.join(ROOT, 'tools', 'build_static.js'));
  const out = fs.mkdtempSync(path.join(os.tmpdir(), 'brai-staticsmoke-'));
  build(out);
  const PORT = 8132;
  const server = await serve(out, PORT);
  let browser, pass = 0, fail = 0;
  const ok = (c, m) => { if (c) pass++; else { fail++; console.log('  FAIL- ' + m); } };
  try {
    try { browser = await chromium.launch(); } catch (e) { console.log('SKIP: chromium não instalado (npx playwright install chromium)'); server.close(); process.exit(0); }
    const page = await browser.newPage();
    const errors = [];
    page.on('pageerror', e => errors.push(String(e)));
    page.on('console', m => { if (m.type() === 'error') errors.push(m.text()); });
    await page.goto('http://localhost:' + PORT + '/index.html', { waitUntil: 'load' });
    await page.waitForFunction(() => window.brai && window.BRAIHost && window.scenarios, null, { timeout: 30000 });
    const res = await page.evaluate(async () => {
      const scn = { grid: { w: 40, h: 40 }, dt: 50, homunId: 100, ownerId: 1, entities: [
        { id: 1, kind: 'owner', x: 10, y: 10, hp: 1000, maxhp: 1000 },
        { id: 100, kind: 'homun', x: 20, y: 20, hp: 100, maxhp: 100, sp: 100, maxsp: 100 },
        { id: 200, kind: 'monster', x: 23, y: 23, hp: 40, maxhp: 40, atk: 5, aggro: 8, etype: 1042 } ] };
      let r = await window.brai.dispatch('load', JSON.stringify(scn)); if (!r.ok) return { err: r.error };
      let s = JSON.parse(r.data);
      for (let i = 0; i < 50; i++) { r = await window.brai.dispatch('step', ''); s = JSON.parse(r.data); }
      const scnList = (await window.scenarios.list()).data;
      return { mobhp: s.entities.find(e => e.id === 200).hp, scn: scnList.length, ls: window.localStorage.length };
    });
    ok(res && !res.err, 'index.html: load/step sem erro (' + (res && res.err || '') + ')');
    ok(res && res.mobhp === 0, 'index.html: IA matou o monstro (bundle Lua + S3 backend)');
    ok(res && res.scn > 0, 'index.html: scenarios.list() vem do data/ (' + (res && res.scn) + ')');
    ok(res && res.ls === 0, 'REGRA: nada de conteúdo do usuário em localStorage (len=' + (res && res.ls) + ')');
    await page.goto('http://localhost:' + PORT + '/editor.html', { waitUntil: 'load' });
    await page.waitForFunction(() => window.trees, null, { timeout: 30000 });
    const tl = await page.evaluate(async () => (await window.trees.list()).data.length);
    ok(tl > 0, 'editor.html: trees.list() vem do data/ (' + tl + ')');
    ok(errors.length === 0, 'sem erros de console/página (' + errors.slice(0, 3).join(' | ') + ')');
  } finally {
    if (browser) await browser.close();
    server.close();
  }
  console.log('\nRESULTADO: ' + pass + ' ok, ' + fail + ' falhas');
  process.exit(fail > 0 ? 1 : 0);
}
main().catch(e => { console.error('ERRO:', e); process.exit(1); });
