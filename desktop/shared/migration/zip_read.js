// zip_read.js — LEITOR de zip client-side (o desktop/zip.js só ESCREVE, via zlib do Node).
// Lê o diretório central do ZIP e descompacta cada entrada (deflate/method 8 ou store/0).
//   • Node: zlib.inflateRawSync (síncrono) — usado nos testes.
//   • Navegador: DecompressionStream('deflate-raw') (assíncrono) ou window.fflate, se presente.
// readZip(bytes) → Promise<{ basename → texto }>  (ignora caminho/pasta-raiz; latin1 p/ não quebrar).
(function (root) {
  'use strict';
  var isNode = (typeof module !== 'undefined' && module.exports);
  var zlib = null; if (isNode) { try { zlib = require('zlib'); } catch (e) {} }

  function u16(b, o) { return b[o] | (b[o + 1] << 8); }
  function u32(b, o) { return (b[o] | (b[o + 1] << 8) | (b[o + 2] << 16) | (b[o + 3] << 24)) >>> 0; }

  function toBytes(buf) {
    if (buf instanceof Uint8Array) return buf;
    if (isNode && Buffer.isBuffer(buf)) return new Uint8Array(buf);
    if (buf && buf.buffer) return new Uint8Array(buf.buffer);
    return new Uint8Array(buf);
  }
  function decodeText(bytes) {
    if (typeof TextDecoder !== 'undefined') {
      try { return new TextDecoder('latin1').decode(bytes); } catch (e) {}
      try { return new TextDecoder('utf-8').decode(bytes); } catch (e2) {}
    }
    if (isNode) return Buffer.from(bytes).toString('latin1');
    var s = ''; for (var i = 0; i < bytes.length; i++) s += String.fromCharCode(bytes[i]); return s;
  }
  function baseName(p) { return String(p).replace(/^.*[\\/]/, ''); }

  // localiza o EOCD (End Of Central Directory) varrendo de trás p/ frente
  function findEOCD(b) {
    for (var i = b.length - 22; i >= 0; i--) {
      if (u32(b, i) === 0x06054b50) return i;
    }
    return -1;
  }

  // lista de entradas {name, method, offset(local header), compSize, uncompSize}
  function parseEntries(b) {
    var eocd = findEOCD(b);
    if (eocd < 0) throw new Error('zip inválido (EOCD não encontrado)');
    var count = u16(b, eocd + 10);
    var cdOff = u32(b, eocd + 16);
    var entries = [], p = cdOff;
    for (var i = 0; i < count && p + 46 <= b.length; i++) {
      if (u32(b, p) !== 0x02014b50) break;
      var method = u16(b, p + 10);
      var compSize = u32(b, p + 20);
      var uncompSize = u32(b, p + 24);
      var nameLen = u16(b, p + 28);
      var extraLen = u16(b, p + 30);
      var commentLen = u16(b, p + 32);
      var lho = u32(b, p + 42);
      var name = decodeText(b.subarray(p + 46, p + 46 + nameLen));
      entries.push({ name: name, method: method, lho: lho, compSize: compSize, uncompSize: uncompSize });
      p += 46 + nameLen + extraLen + commentLen;
    }
    return entries;
  }

  // posição+tamanho dos dados comprimidos a partir do local header
  function dataSlice(b, e) {
    var p = e.lho;
    if (u32(b, p) !== 0x04034b50) throw new Error('local header inválido: ' + e.name);
    var nameLen = u16(b, p + 26);
    var extraLen = u16(b, p + 28);
    var start = p + 30 + nameLen + extraLen;
    return b.subarray(start, start + e.compSize);
  }

  function inflateSyncNode(slice, method) {
    if (method === 0) return slice;
    return new Uint8Array(zlib.inflateRawSync(Buffer.from(slice)));
  }
  function inflateAsync(slice, method) {
    if (method === 0) return Promise.resolve(slice);
    if (isNode && zlib) return Promise.resolve(inflateSyncNode(slice, method));
    if (root.fflate && root.fflate.inflateSync) { try { return Promise.resolve(root.fflate.inflateSync(slice)); } catch (e) {} }
    if (typeof DecompressionStream !== 'undefined') {
      var ds = new DecompressionStream('deflate-raw');
      var stream = new Blob([slice]).stream().pipeThrough(ds);
      return new Response(stream).arrayBuffer().then(function (ab) { return new Uint8Array(ab); });
    }
    return Promise.reject(new Error('sem descompactador disponível no ambiente'));
  }

  // Node síncrono (testes)
  function readZipSync(buf) {
    if (!zlib) throw new Error('readZipSync só no Node');
    var b = toBytes(buf), out = {};
    parseEntries(b).forEach(function (e) {
      if (/\/$/.test(e.name)) return; // diretório
      var data = inflateSyncNode(dataSlice(b, e), e.method);
      out[baseName(e.name)] = decodeText(data);
    });
    return out;
  }

  // universal (assíncrono) — usado pela UI no navegador
  function readZip(buf) {
    var b = toBytes(buf);
    var entries;
    try { entries = parseEntries(b); } catch (e) { return Promise.reject(e); }
    var out = {};
    var chain = Promise.resolve();
    entries.forEach(function (e) {
      if (/\/$/.test(e.name)) return;
      chain = chain.then(function () {
        return inflateAsync(dataSlice(b, e), e.method).then(function (data) {
          out[baseName(e.name)] = decodeText(toBytes(data));
        });
      });
    });
    return chain.then(function () { return out; });
  }

  var api = { readZip: readZip, readZipSync: readZipSync, parseEntries: parseEntries, baseName: baseName };
  if (typeof module !== 'undefined' && module.exports) module.exports = api;
  if (typeof window !== 'undefined') window.BRAI_ZIP_READ = api;
})(typeof globalThis !== 'undefined' ? globalThis : this);
