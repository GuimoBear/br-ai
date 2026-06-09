// static_browser_smoke.js — smoke de BROWSER REAL (Playwright) do fluxo estático:
//  - SEM barra no topo; "Importar cenário" dentro do #scnbar (sim) e "Importar árvore" no #toolbar (editor);
//  - combobox de cenários começa OCULTO; upload inválido -> erro; upload válido -> aparece e roda;
//  - monstros PERSISTEM no localStorage após reload; cenários/árvores NUNCA vão p/ localStorage;
//  - TELA PRINCIPAL = editor (index.html redireciona); simulador em sim.html; editor "← Simulador" -> ./sim.html.
'use strict';
const fs = require('fs'), os = require('os'), path = require('path'), http = require('http');
const ROOT = path.join(__dirname, '..');
function serve(dir, port) {
  const MIME = { '.html': 'text/html; charset=utf-8', '.js': 'text/javascript; charset=utf-8', '.css': 'text/css; charset=utf-8', '.json': 'application/json; charset=utf-8' };
  const s = http.createServer((req, res) => { let p = decodeURIComponent(req.url.split('?')[0]); if (p === '/') p = '/index.html'; const f = path.join(dir, p); fs.readFile(f, (e, d) => { if (e) { res.writeHead(404); res.end('404'); } else { res.writeHead(200, { 'Content-Type': MIME[path.extname(f)] || 'application/octet-stream' }); res.end(d); } }); });
  return new Promise(r => s.listen(port, () => r(s)));
}
const VALID = JSON.stringify({ grid: { w: 40, h: 40 }, dt: 50, homunId: 100, ownerId: 1, entities: [
  { id: 1, kind: 'owner', x: 10, y: 10, hp: 1000, maxhp: 1000 },
  { id: 100, kind: 'homun', x: 20, y: 20, hp: 100, maxhp: 100, sp: 100, maxsp: 100 },
  { id: 200, kind: 'monster', x: 23, y: 23, hp: 40, maxhp: 40, atk: 5, aggro: 8, etype: 1042 } ] });

async function main() {
  let chromium;
  try { ({ chromium } = require('playwright')); } catch (e) { console.log('SKIP: playwright não instalado'); process.exit(0); }
  const { build } = require(path.join(ROOT, 'tools', 'build_static.js'));
  const out = fs.mkdtempSync(path.join(os.tmpdir(), 'brai-staticsmoke-'));
  build(out);
  const PORT = 8134; const server = await serve(out, PORT);
  let browser, pass = 0, fail = 0; const ok = (c, m) => { if (c) pass++; else { fail++; console.log('  FAIL- ' + m); } };
  try {
    try { browser = await chromium.launch(); } catch (e) { console.log('SKIP: chromium não instalado'); server.close(); process.exit(0); }
    const page = await browser.newPage(); const errors = [];
    page.on('pageerror', e => errors.push(String(e)));
    page.on('console', m => { if (m.type() === 'error') errors.push(m.text()); });

    // TELA PRINCIPAL: index.html redireciona p/ o editor
    await page.goto('http://localhost:' + PORT + '/index.html', { waitUntil: 'load' });
    await page.waitForFunction(() => window.trees && document.getElementById('braiImpTree'), null, { timeout: 30000 });
    ok(/\/editor\.html$/.test(page.url()), 'index.html (tela principal) abre o editor (' + page.url() + ')');

    // SIMULADOR em /sim.html
    await page.goto('http://localhost:' + PORT + '/sim.html', { waitUntil: 'load' });
    await page.waitForFunction(() => window.brai && window.scenarios && document.getElementById('braiImpScn'), null, { timeout: 30000 });
    // SEM barra no topo + botão dentro do #scnbar
    ok(await page.evaluate(() => !document.getElementById('braiStaticBar')), 'sem barra no topo (braiStaticBar removido)');
    ok(await page.evaluate(() => !!document.getElementById('braiImpScn') && !!document.getElementById('braiImpScn').closest('#scnbar')), '"Importar cenário" está dentro de #scnbar');
    const hidden = () => page.evaluate(() => { const el = document.getElementById('scnList'); return !el || getComputedStyle(el).display === 'none'; });
    ok(await hidden(), 'combobox de cenários começa OCULTO');

    const inp = await page.$('#braiImpScn');
    await inp.setInputFiles({ name: 'ruim.json', mimeType: 'application/json', buffer: Buffer.from('{"grid":{"foo":1}}') });
    await page.waitForFunction(() => { const m = document.getElementById('braiMsg'); return m && m.textContent && m.className.indexOf('err') >= 0; }, null, { timeout: 8000 });
    ok(/cenário/i.test(await page.evaluate(() => document.getElementById('braiMsg').textContent)), 'upload inválido -> erro de cenário');
    ok(await hidden(), 'combobox segue oculto após upload inválido');

    await inp.setInputFiles({ name: 'MeuCenario.json', mimeType: 'application/json', buffer: Buffer.from(VALID) });
    await page.waitForFunction(() => { const el = document.getElementById('scnList'); return el && getComputedStyle(el).display !== 'none'; }, null, { timeout: 8000 });
    ok(true, 'combobox APARECE após upload válido');
    ok((await page.evaluate(() => document.getElementById('scnList').value)) === 'MeuCenario', 'cenário selecionado');
    const mob = await page.evaluate(async (scn) => { let r = await window.brai.dispatch('load', scn); let s = JSON.parse(r.data); for (let i = 0; i < 50; i++) { r = await window.brai.dispatch('step', ''); s = JSON.parse(r.data); } return s.entities.find(e => e.id === 200).hp; }, VALID);
    ok(mob === 0, 'IA roda o cenário e mata o monstro');
    ok((await page.evaluate(() => Object.keys(window.localStorage))).every(k => !/cenario|scenario|tree|MeuCenario/i.test(k)), 'cenário NÃO vai p/ localStorage');

    await page.evaluate(async () => { await window.monsters.save(JSON.stringify({ monsters: [{ id: 111 }, { id: 222 }], groups: [] })); });
    await page.reload({ waitUntil: 'load' });
    await page.waitForFunction(() => window.monsters, null, { timeout: 30000 });
    ok((await page.evaluate(async () => JSON.parse((await window.monsters.load()).data).monsters.length)) === 2, 'monstros persistem no localStorage após reload');
    ok(await hidden(), 'após reload, combobox de cenários volta a ficar oculto');

    await page.goto('http://localhost:' + PORT + '/editor.html', { waitUntil: 'load' });
    await page.waitForFunction(() => window.trees && document.querySelector('a.nav') && document.getElementById('braiImpTree'), null, { timeout: 30000 });
    ok(await page.evaluate(() => !document.getElementById('braiStaticBar')), 'editor: sem barra no topo');
    ok(await page.evaluate(() => !!document.getElementById('braiImpTree') && !!document.getElementById('braiImpTree').closest('#toolbar')), 'editor: "Importar árvore" no #toolbar');
    ok(await page.evaluate(() => !document.getElementById('braiImpMon') && !document.getElementById('braiImpSkill')), 'editor: ⬇/⬆ de monstros/skills REMOVIDOS do toolbar (agora nos modais)');
    ok(/sim\.html$/.test(await page.evaluate(() => document.querySelector('a.nav').getAttribute('href'))), 'editor: "← Simulador" -> sim.html');

    // Skills modal (ESTÁTICO): importar/exportar logo abaixo do título
    await page.waitForFunction(() => { const b = document.getElementById('btnSkills'); return !!(b && b.onclick); }, null, { timeout: 30000 });
    await page.click('#btnSkills');
    await page.waitForFunction(() => !!document.querySelector('#scModal .sc-rows[data-homun]'), null, { timeout: 20000 });
    ok(await page.evaluate(() => !!document.getElementById('scExport') && !!document.getElementById('scImport')), 'editor estático: exportar/importar skills no modal');
    ok(await page.evaluate(() => { const io = document.querySelector('#scModal .sc-io'); const body = io && io.parentElement; return !!io && body && body.firstElementChild === io; }), 'barra import/export é o 1º elemento do corpo (logo abaixo do título)');
    // importar uma config (Dieter aoeAtk = [Blast Forge 8044]) → aplica (1 skill na AoE)
    await page.selectOption('#scModal #scHomunSel', '51');
    await page.waitForFunction(() => !!document.querySelector('#scModal .sc-rows[data-homun="51"]'), null, { timeout: 10000 });
    await page.setInputFiles('#scModal #scImportFile', { name: 'minhas-skills.json', mimeType: 'application/json', buffer: Buffer.from(JSON.stringify({ choices: { '51': { aoeAtk: [8044] } } })) });
    await page.waitForFunction(() => document.querySelectorAll('#scModal .sc-skills[data-role="aoeAtk"] .sc-skill').length === 1, null, { timeout: 10000 });
    ok(true, 'importar skills aplica a config (Dieter AoE = 1 skill)');
    // exportar → dispara download de homun_skills.json
    const [dl] = await Promise.all([page.waitForEvent('download', { timeout: 10000 }), page.click('#scModal #scExport')]);
    ok(dl.suggestedFilename() === 'homun_skills.json', 'exportar baixa homun_skills.json (' + dl.suggestedFilename() + ')');

    // Monstros modal (ESTÁTICO): importar/exportar abaixo do título
    await page.click('#scModal #scClose').catch(() => {});
    await page.waitForFunction(() => { const b = document.getElementById('btnMonsters'); return !!(b && b.onclick); }, null, { timeout: 20000 });
    await page.click('#btnMonsters');
    await page.waitForSelector('#monModal .mm-head', { timeout: 20000 });
    ok(await page.evaluate(() => !!document.getElementById('monExport') && !!document.getElementById('monImport')), 'editor estático: exportar/importar monstros no modal');
    await page.setInputFiles('#monModal #monImportFile', { name: 'meus-monstros.json', mimeType: 'application/json', buffer: Buffer.from(JSON.stringify({ monsters: [{ id: 1500, desc: 'TesteMob' }], groups: [] })) });
    await page.waitForFunction(() => { const l = document.querySelector('#monModal .mm-list'); return l && /TesteMob/.test(l.textContent); }, null, { timeout: 10000 });
    ok(true, 'importar monstros aplica (TesteMob na lista)');
    const [dl2] = await Promise.all([page.waitForEvent('download', { timeout: 10000 }), page.click('#monModal #monExport')]);
    ok(dl2.suggestedFilename() === 'monsters.json', 'exportar baixa monsters.json (' + dl2.suggestedFilename() + ')');

    ok(errors.length === 0, 'sem erros de console/página (' + errors.slice(0, 3).join(' | ') + ')');
  } finally { if (browser) await browser.close(); server.close(); }
  console.log('\nRESULTADO: ' + pass + ' ok, ' + fail + ' falhas');
  process.exit(fail > 0 ? 1 : 0);
}
main().catch(e => { console.error('ERRO:', e); process.exit(1); });
