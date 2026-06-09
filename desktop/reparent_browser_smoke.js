// reparent_browser_smoke.js — smoke (Playwright) do arrastar-ligação do editor:
//  - reordenar movendo os pontos (ponto-fantasma + aresta viva), e
//  - TROCAR DE PAI arrastando o ponto sobre outro nó (realce "novo pai").
// Usa o hook window.BRAI_EDITOR (load/spec) com uma árvore pequena (determinístico).
'use strict';
const fs = require('fs'), os = require('os'), path = require('path'), http = require('http');
const ROOT = path.join(__dirname, '..');
function serve(dir, port) {
  const M = { '.html': 'text/html', '.js': 'text/javascript', '.css': 'text/css', '.json': 'application/json' };
  const s = http.createServer((q, r) => { let p = decodeURIComponent(q.url.split('?')[0]); if (p === '/') p = '/index.html'; const f = path.join(dir, p); fs.readFile(f, (e, d) => { if (e) { r.writeHead(404); r.end('404'); } else { r.writeHead(200, { 'Content-Type': M[path.extname(f)] || 'application/octet-stream' }); r.end(d); } }); });
  return new Promise(x => s.listen(port, () => x(s)));
}
let pass = 0, fail = 0; const ok = (c, m) => { if (c) pass++; else { fail++; console.log('  FAIL-', m); } };
const SMALL = { type: 'selector', label: 'root', children: [{ type: 'action', name: 'Idle' }, { type: 'action', name: 'Flee' }, { type: 'sequence', label: 'combo', children: [{ type: 'action', name: 'AcquireTarget' }] }] };
function findByType(s, t) { if (s.type === t) return s; for (const c of (s.children || [])) { const r = findByType(c, t); if (r) return r; } if (s.child) { const r = findByType(s.child, t); if (r) return r; } return null; }
const names = s => (s.children || []).map(c => c.name || c.label || c.type);
const topDots = pg => pg.evaluate(() => { const ds = [...document.querySelectorAll('.linkh')].map(e => { const r = e.getBoundingClientRect(); return { x: r.x + r.width / 2, y: r.y + r.height / 2 }; }); const ymin = Math.min(...ds.map(d => d.y)); return ds.filter(d => d.y < ymin + 8).sort((a, b) => a.x - b.x); });
// Espera o layout do grafo ASSENTAR com exatamente `n` pontos no topo (largura != 0) e os devolve.
// Leitura ATÔMICA (o mesmo tick que satisfaz a condição é o retornado) — elimina a corrida de
// 'esperar >=4 .linkh, depois ler' que tornava o teste flaky (posições ainda em 0 -> ymin errado).
const topDotsStable = (pg, n) => pg.waitForFunction((n) => {
  const els = [...document.querySelectorAll('.linkh')];
  if (els.length < 4) return null;
  const ds = els.map(e => { const r = e.getBoundingClientRect(); return { x: r.x + r.width / 2, y: r.y + r.height / 2, w: r.width }; });
  if (ds.some(d => d.w === 0)) return null;            // ainda posicionando
  const ymin = Math.min(...ds.map(d => d.y));
  const top = ds.filter(d => d.y < ymin + 8).sort((a, b) => a.x - b.x);
  return top.length === n ? top.map(d => ({ x: d.x, y: d.y })) : null;
}, n, { timeout: 8000 }).then(h => h.jsonValue());
async function main() {
  let chromium; try { ({ chromium } = require('playwright')); } catch (e) { console.log('SKIP: playwright'); process.exit(0); }
  const { build } = require(path.join(ROOT, 'tools', 'build_static.js'));
  const o = fs.mkdtempSync(path.join(os.tmpdir(), 'rep-')); build(o);
  const s = await serve(o, 8136); let browser;
  try {
    try { browser = await chromium.launch(); } catch (e) { console.log('SKIP: chromium'); s.close(); process.exit(0); }
    const pg = await browser.newPage({ viewport: { width: 1100, height: 680 } }); const errs = [];
    pg.on('pageerror', e => errs.push(String(e)));
    await pg.goto('http://localhost:8136/editor.html', { waitUntil: 'load' });
    await pg.waitForFunction(() => window.BRAI_EDITOR && window.BRAI_EDITOR.load, null, { timeout: 30000 });
    // reordenar
    await pg.evaluate(sp => window.BRAI_EDITOR.load(sp), SMALL);
    let dots = await topDotsStable(pg, 3);   // espera o layout assentar (3 pontos no topo) e lê atomicamente
    ok(dots.length === 3, 'raiz com 3 pontos');
    await pg.mouse.move(dots[0].x, dots[0].y); await pg.mouse.down();
    await pg.mouse.move(dots[2].x + 30, dots[0].y, { steps: 8 });
    // espera o ponto-fantasma + a aresta viva aparecerem (condição, não sleep fixo)
    await pg.waitForFunction(() => { const g = document.querySelector('.linkh-preview.ghost-dot'); return !!g && getComputedStyle(g).display !== 'none' && document.querySelectorAll('.live-edge').length > 0; }, null, { timeout: 3000 }).catch(() => {});
    ok(await pg.evaluate(() => { const g = document.querySelector('.linkh-preview.ghost-dot'); return !!g && getComputedStyle(g).display !== 'none'; }), 'reordenar: ponto-fantasma visível');
    ok(await pg.evaluate(() => document.querySelectorAll('.live-edge').length > 0), 'reordenar: aresta viva');
    await pg.mouse.up();
    await pg.waitForFunction(() => { const n = (window.BRAI_EDITOR.spec().children || []).map(c => c.name || c.label || c.type); return n.length === 3 && n[0] !== 'Idle'; }, null, { timeout: 3000 }).catch(() => {});
    const r1 = await pg.evaluate(() => window.BRAI_EDITOR.spec());
    ok(names(r1)[0] !== 'Idle' && names(r1).length === 3, 'reordenar: ordem mudou, 3 filhos');
    // trocar de pai
    await pg.evaluate(sp => window.BRAI_EDITOR.load(sp), SMALL);
    dots = await topDotsStable(pg, 3);
    const seq = await pg.evaluate(() => { for (const n of document.querySelectorAll('.gnode')) { if (/SEQU/i.test((n.querySelector('.type') || {}).textContent || '')) { const r = n.getBoundingClientRect(); return { x: r.x + r.width / 2, y: r.y + r.height / 2 }; } } return null; });
    ok(!!seq, 'achou nó sequence (alvo)');
    await pg.mouse.move(dots[0].x, dots[0].y); await pg.mouse.down();
    await pg.mouse.move((dots[0].x + seq.x) / 2, (dots[0].y + seq.y) / 2, { steps: 6 });
    await pg.mouse.move(seq.x, seq.y, { steps: 8 });
    // espera o alvo acender (.reparent-ok) — condição, não sleep fixo
    await pg.waitForFunction(() => document.querySelectorAll('.gnode.reparent-ok').length > 0, null, { timeout: 3000 }).catch(() => {});
    ok(await pg.evaluate(() => document.querySelectorAll('.gnode.reparent-ok').length > 0), 'reparentar: alvo acende (.reparent-ok)');
    await pg.mouse.up();
    await pg.waitForFunction(() => (window.BRAI_EDITOR.spec().children || []).length === 2, null, { timeout: 3000 }).catch(() => {});
    const r2 = await pg.evaluate(() => window.BRAI_EDITOR.spec());
    ok(names(r2).length === 2, 'reparentar: raiz ficou com 2 filhos');
    const sq = findByType(r2, 'sequence');
    ok(sq && names(sq).indexOf('Idle') >= 0, 'reparentar: "Idle" virou filho da sequence');
    ok(errs.length === 0, 'sem erros de página (' + errs.slice(0, 2).join(' | ') + ')');
  } finally { if (browser) await browser.close(); s.close(); }
  console.log('\nRESULTADO: ' + pass + ' ok, ' + fail + ' falhas');
  process.exit(fail > 0 ? 1 : 0);
}
main().catch(e => { console.error('ERRO:', e); process.exit(1); });
