// fs_bridge.js — backend HTTP (servidor local) da ponte do BR-AI no NAVEGADOR.
// A lógica dos globais (window.brai/trees/scenarios/...) agora vive no núcleo COMUM
// desktop/shared/bridge_core.js; este arquivo só implementa o "backend" que lê por
// fetch e grava pela API local (/__brai/write) do serve.js. Comportamento idêntico
// ao anterior — só desacoplado para a versão estática reaproveitar o mesmo contrato.
(function () {
  'use strict';
  if (!window.BRAI_BRIDGE) { throw new Error('bridge_core.js não carregou antes de fs_bridge.js'); }
  var API = '/__brai';

  function encPath(rel) { return '/' + rel.split('/').map(encodeURIComponent).join('/'); }

  // ---- backend (servidor local) ----
  async function readText(rel) { var r = await fetch(encPath(rel), { cache: 'no-cache' }); if (!r.ok) throw new Error('HTTP ' + r.status + ' ao ler ' + rel); return await r.text(); }
  async function readBytes(rel) { var r = await fetch(encPath(rel), { cache: 'no-cache' }); if (!r.ok) throw new Error('HTTP ' + r.status + ' ao ler ' + rel); return new Uint8Array(await r.arrayBuffer()); }
  async function listDir(rel) { var r = await fetch(API + '/list?dir=' + encodeURIComponent(rel), { cache: 'no-cache' }); if (!r.ok) throw new Error('list ' + rel + ' HTTP ' + r.status); return await r.json(); }
  function toB64(u8) { var s = ''; var CH = 0x8000; for (var i = 0; i < u8.length; i += CH) s += String.fromCharCode.apply(null, u8.subarray(i, i + CH)); return btoa(s); }
  async function writeData(rel, data) {
    var body = (typeof data === 'string') ? { path: rel, content: data } : { path: rel, base64: toB64(data) };
    var r = await fetch(API + '/write', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(body) });
    var j = null; try { j = await r.json(); } catch (e) {}
    if (!r.ok || !j || !j.ok) throw new Error((j && j.error) || ('HTTP ' + r.status + ' ao gravar ' + rel));
    return j;
  }

  // ---- detecção do servidor (API de escrita) ----
  var serverOK = false;
  var ready = (async function () { try { var r = await fetch(API + '/ping', { cache: 'no-cache' }); serverOK = r.ok; } catch (e) { serverOK = false; } updateBanner(); })();
  function updateBanner() {
    var el = document.getElementById('braiFolder');
    if (el) el.textContent = serverOK ? 'pasta do projeto: lida e gravada pelo servidor local (' + location.origin + ')' : 'sem API de escrita — rode o servidor com: npm run web';
    var btn = document.getElementById('btnConnectFolder');
    if (btn) btn.style.display = 'none'; // não precisa conectar nada no modo servidor
  }
  function need() { return serverOK ? null : { ok: false, error: 'Servidor sem API de escrita. Rode `npm run web` na pasta desktop/.' }; }

  function download(filename, bytes) {
    try {
      var a = document.createElement('a');
      a.href = URL.createObjectURL(new Blob([bytes], { type: 'application/zip' })); a.download = filename;
      document.body.appendChild(a); a.click();
      setTimeout(function () { URL.revokeObjectURL(a.href); a.remove(); }, 1000);
    } catch (e) {}
  }

  // lê lua/ recursivamente (exceto src/sim e sim_boot.lua) p/ montar o pacote
  async function readLuaTree() {
    var out = [];
    async function walk(rel) {
      var j = await listDir(rel);
      var dirs = j.dirs || [], files = j.files || [];
      for (var i = 0; i < dirs.length; i++) { var d = rel + '/' + dirs[i]; if (d === 'lua/src/sim') continue; await walk(d); }
      for (var k = 0; k < files.length; k++) { var fp = rel + '/' + files[k]; if (fp === 'lua/sim_boot.lua') continue; out.push({ rel: fp.slice(4), data: await readBytes(fp) }); }
    }
    await walk('lua');
    return out;
  }

  var httpBackend = {
    ready: ready,
    canWrite: need,
    readText: readText,
    readBytes: readBytes,
    listDir: listDir,
    writeData: writeData,       // SAVE do usuário (POST)
    writeArtifact: writeData,   // artefatos do build (POST — igual ao comportamento antigo)
    readLuaTree: readLuaTree,
    download: download,
    host: window.BRAIHost,
    rememberTree: function (argJson) { try { sessionStorage.setItem('brai.simTree', argJson); } catch (e) {} },
    updateBanner: updateBanner,
  };

  window.BRAI_BRIDGE.install(httpBackend);

  // compat: alguns HTMLs têm o botão antigo
  window.BRAIConnectFolder = function () { alert('No modo servidor não é preciso conectar pasta — o servidor já lê e grava as pastas reais do projeto.'); };

  document.addEventListener('DOMContentLoaded', updateBanner);
})();
