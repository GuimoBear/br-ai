// s3_backend.js — backend ESTÁTICO da ponte do BR-AI (S3/CloudFront, sem servidor).
// Defaults vêm do S3 (data/manifest.json + data/*.json, somente leitura, com cache);
// o upload do usuário fica num OVERLAY de SESSÃO (sessionStorage, some ao fechar a aba)
// e o "save" sempre DISPARA DOWNLOAD do arquivo. Nada de conteúdo do usuário em
// localStorage. Usa o núcleo COMUM desktop/shared/bridge_core.js (mesmo contrato da web).
//
// makeStaticBackend(deps) é uma fábrica pura (testável em Node). deps:
//   fetchImpl, storage (sessionStorage-like), download(name,data,mime),
//   encodeUtf8(str)->Uint8Array, luaFiles (map rel->src), host (BRAIHost), dataPrefix?
(function (root) {
  'use strict';
  var OVERLAY_KEY = 'brai.overlay';

  function makeStaticBackend(deps) {
    var DATA = deps.dataPrefix || 'data/';
    var storage = deps.storage;
    var fetchImpl = deps.fetchImpl;

    function readOverlay() { try { return JSON.parse(storage.getItem(OVERLAY_KEY) || '{}'); } catch (e) { return {}; } }
    function writeOverlay(o) { try { storage.setItem(OVERLAY_KEY, JSON.stringify(o)); } catch (e) {} }
    function overlayGet(rel) { var o = readOverlay(); return Object.prototype.hasOwnProperty.call(o, rel) ? o[rel] : null; }
    function overlayPut(rel, text) { var o = readOverlay(); o[rel] = text; writeOverlay(o); }

    function dataUrl(rel) {
      var m;
      if ((m = /^trees\/(.+)\/tree\.json$/.exec(rel))) return DATA + 'trees/' + encodeURIComponent(m[1]) + '.json';
      if ((m = /^scenarios\/(.+)\.json$/.exec(rel))) return DATA + 'scenarios/' + encodeURIComponent(m[1]) + '.json';
      return DATA + rel; // monsters.json, homun_skills.json, homun_summons.json, etc.
    }

    var manifestP = null;
    function manifest() {
      if (!manifestP) {
        manifestP = Promise.resolve(fetchImpl(DATA + 'manifest.json', { cache: 'force-cache' }))
          .then(function (r) { return r.ok ? r.json() : { trees: [], scenarios: [] }; })
          .catch(function () { return { trees: [], scenarios: [] }; });
      }
      return manifestP;
    }

    async function readText(rel) {
      var ov = overlayGet(rel);
      if (ov != null) return ov;
      var r = await fetchImpl(dataUrl(rel), { cache: 'force-cache' });
      if (!r.ok) throw new Error('HTTP ' + r.status + ' ao ler ' + rel);
      return await r.text();
    }
    async function readBytes(rel) { return deps.encodeUtf8(await readText(rel)); }

    async function listDir(rel) {
      var mf = await manifest();
      var ov = readOverlay(), k, m, names;
      if (rel === 'trees') {
        names = (mf.trees || []).slice();
        for (k in ov) { if ((m = /^trees\/(.+)\/tree\.json$/.exec(k)) && names.indexOf(m[1]) < 0) names.push(m[1]); }
        return { dirs: names, files: [] };
      }
      if (rel === 'scenarios') {
        names = (mf.scenarios || []).slice();
        for (k in ov) { if ((m = /^scenarios\/(.+)\.json$/.exec(k)) && names.indexOf(m[1]) < 0) names.push(m[1]); }
        return { dirs: [], files: names.map(function (n) { return n + '.json'; }) };
      }
      return { dirs: [], files: [] };
    }

    function basename(rel) { var p = rel.split('/'); return p[p.length - 1]; }

    // SAVE do usuário: grava no overlay (sessão) E baixa o arquivo.
    async function writeData(rel, data) {
      overlayPut(rel, typeof data === 'string' ? data : '');
      deps.download(basename(rel), data, mimeFor(basename(rel)));
      return { ok: true, path: rel };
    }
    // Artefatos do build: NÃO persistem (na estática só o .zip final é baixado pelo bridge_core).
    async function writeArtifact() { return { ok: true }; }

    async function readLuaTree() {
      var out = [], F = deps.luaFiles || {};
      for (var rel in F) {
        if (rel.indexOf('src/sim/') === 0) continue;   // simulador não vai pro cliente do RO
        if (rel === 'sim_boot.lua') continue;
        out.push({ rel: rel, data: F[rel] });
      }
      return out;
    }

    return {
      ready: Promise.resolve(),
      canWrite: function () { return null; },          // save sempre disponível (= download)
      readText: readText,
      readBytes: readBytes,
      listDir: listDir,
      writeData: writeData,
      writeArtifact: writeArtifact,
      readLuaTree: readLuaTree,
      importFile: function (rel, text) { overlayPut(rel, text); },
      download: function (name, data) { deps.download(name, data, mimeFor(name)); },
      host: deps.host,
      rememberTree: function (arg) { try { storage.setItem('brai.simTree', arg); } catch (e) {} },
      updateBanner: deps.updateBanner || function () {},
    };
  }

  function mimeFor(name) {
    if (/\.zip$/i.test(name)) return 'application/zip';
    if (/\.json$/i.test(name)) return 'application/json';
    if (/\.lua$/i.test(name)) return 'text/plain';
    return 'application/octet-stream';
  }

  var api = { makeStaticBackend: makeStaticBackend, mimeFor: mimeFor };
  if (typeof module !== 'undefined' && module.exports) module.exports = api;

  // Auto-instalação no NAVEGADOR (quando há o núcleo comum + host carregados).
  if (typeof window !== 'undefined' && window.BRAI_BRIDGE) {
    function browserDownload(name, data, mime) {
      try {
        var blob = new Blob([data], { type: mime || 'application/octet-stream' });
        var a = document.createElement('a');
        a.href = URL.createObjectURL(blob); a.download = name;
        document.body.appendChild(a); a.click();
        setTimeout(function () { URL.revokeObjectURL(a.href); a.remove(); }, 1000);
      } catch (e) {}
    }
    var backend = makeStaticBackend({
      fetchImpl: window.fetch.bind(window),
      storage: window.sessionStorage,
      download: browserDownload,
      encodeUtf8: function (s) { return new TextEncoder().encode(s); },
      luaFiles: window.BRAI_LUA_FILES || {},
      host: window.BRAIHost,
    });
    window.BRAI_STATIC_BACKEND = backend;
    window.BRAI_BRIDGE.install(backend);
    window.BRAIConnectFolder = window.BRAIConnectFolder || function () {};
  }
})(typeof globalThis !== 'undefined' ? globalThis : this);
