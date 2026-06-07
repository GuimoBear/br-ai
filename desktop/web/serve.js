// serve.js — servidor local do BR-AI web. Serve a RAIZ do repo e expõe uma API
// mínima de LEITURA+ESCRITA p/ a página acessar as pastas reais (trees/, scenarios/,
// monsters.json) sem a File System Access API — o servidor faz o papel do "main" do Electron.
// Uso: `node web/serve.js`  (ou `npm run web`). http://localhost:8000/desktop/web/
'use strict';
const http = require('http');
const fs = require('fs');
const path = require('path');

const ROOT = path.resolve(__dirname, '..', '..');
const PORT = process.env.PORT ? parseInt(process.env.PORT, 10) : 8000;
const HOME = '/desktop/web/';

const MIME = {
  '.html': 'text/html; charset=utf-8', '.js': 'text/javascript; charset=utf-8',
  '.css': 'text/css; charset=utf-8', '.json': 'application/json; charset=utf-8',
  '.lua': 'text/plain; charset=utf-8', '.svg': 'image/svg+xml', '.png': 'image/png',
  '.txt': 'text/plain; charset=utf-8', '.zip': 'application/zip', '.ico': 'image/x-icon',
};

function insideRoot(abs) { return abs === ROOT || abs.startsWith(ROOT + path.sep); }
function sendJSON(res, code, obj) { res.writeHead(code, { 'Content-Type': 'application/json; charset=utf-8' }); res.end(JSON.stringify(obj)); }

function handleAPI(req, res, urlObj) {
  // GET /__brai/ping
  if (req.method === 'GET' && urlObj.pathname === '/__brai/ping') return sendJSON(res, 200, { ok: true, root: ROOT });
  // GET /__brai/list?dir=trees
  if (req.method === 'GET' && urlObj.pathname === '/__brai/list') {
    const rel = urlObj.searchParams.get('dir') || '';
    const abs = path.normalize(path.join(ROOT, rel));
    if (!insideRoot(abs)) return sendJSON(res, 403, { ok: false, error: 'fora da raiz' });
    try {
      const ents = fs.readdirSync(abs, { withFileTypes: true });
      return sendJSON(res, 200, { ok: true, dirs: ents.filter(e => e.isDirectory()).map(e => e.name), files: ents.filter(e => e.isFile()).map(e => e.name) });
    } catch (e) { return sendJSON(res, 200, { ok: true, dirs: [], files: [] }); }
  }
  // POST /__brai/write  { path, content? | base64? }
  if (req.method === 'POST' && urlObj.pathname === '/__brai/write') {
    let body = '';
    req.on('data', c => { body += c; if (body.length > 80 * 1024 * 1024) req.destroy(); });
    req.on('end', () => {
      try {
        const j = JSON.parse(body || '{}');
        const abs = path.normalize(path.join(ROOT, j.path || ''));
        if (!insideRoot(abs) || !j.path) return sendJSON(res, 403, { ok: false, error: 'caminho inválido' });
        fs.mkdirSync(path.dirname(abs), { recursive: true });
        const data = (j.base64 != null) ? Buffer.from(j.base64, 'base64') : Buffer.from(String(j.content || ''), 'utf8');
        fs.writeFileSync(abs, data);
        return sendJSON(res, 200, { ok: true, path: j.path, bytes: data.length });
      } catch (e) { return sendJSON(res, 500, { ok: false, error: String(e.message || e) }); }
    });
    return;
  }
  return sendJSON(res, 404, { ok: false, error: 'rota desconhecida' });
}

const server = http.createServer((req, res) => {
  try {
    const urlObj = new URL(req.url, 'http://localhost:' + PORT);
    if (urlObj.pathname.startsWith('/__brai/')) return handleAPI(req, res, urlObj);

    let urlPath = decodeURIComponent(urlObj.pathname);
    if (urlPath === '/') urlPath = HOME;
    const filePath = path.normalize(path.join(ROOT, urlPath));
    if (!insideRoot(filePath)) { res.writeHead(403); return res.end('403'); }
    let target = filePath;
    try {
      if (fs.statSync(target).isDirectory()) {
        // a pasta da web abre direto no SIMULADOR (como o app Electron); as demais usam index.html
        const rel = path.relative(ROOT, target).split(path.sep).join('/');
        target = path.join(target, rel === 'desktop/web' ? 'sim.html' : 'index.html');
      }
    } catch (e) {}
    fs.readFile(target, (err, data) => {
      if (err) { res.writeHead(404, { 'Content-Type': 'text/plain; charset=utf-8' }); return res.end('404 — ' + urlPath); }
      res.writeHead(200, { 'Content-Type': MIME[path.extname(target).toLowerCase()] || 'application/octet-stream', 'Cache-Control': 'no-cache' });
      res.end(data);
    });
  } catch (e) { res.writeHead(500); res.end('500'); }
});

server.listen(PORT, () => {
  console.log('BR-AI web em  ->  http://localhost:' + PORT + HOME);
  console.log('servindo (e gravando) a raiz: ' + ROOT);
  console.log('(Ctrl+C para parar)');
});
