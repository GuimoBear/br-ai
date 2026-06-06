// zip.js — escritor de ZIP mínimo, sem dependências (usa zlib do Node).
// Cria um .zip (método DEFLATE) a partir de uma lista de { name, data }.
// Suficiente para empacotar a IA gerada; nomes usam '/' como separador.
'use strict';
const zlib = require('zlib');

// CRC-32 (tabela padrão IEEE)
const CRC_TABLE = (() => {
  const t = new Uint32Array(256);
  for (let n = 0; n < 256; n++) {
    let c = n;
    for (let k = 0; k < 8; k++) c = (c & 1) ? (0xEDB88320 ^ (c >>> 1)) : (c >>> 1);
    t[n] = c >>> 0;
  }
  return t;
})();
function crc32(buf) {
  let c = 0xFFFFFFFF;
  for (let i = 0; i < buf.length; i++) c = CRC_TABLE[(c ^ buf[i]) & 0xFF] ^ (c >>> 8);
  return (c ^ 0xFFFFFFFF) >>> 0;
}

function dosTime(d) {
  const t = ((d.getHours() & 0x1F) << 11) | ((d.getMinutes() & 0x3F) << 5) | ((Math.floor(d.getSeconds() / 2)) & 0x1F);
  const dt = (((d.getFullYear() - 1980) & 0x7F) << 9) | (((d.getMonth() + 1) & 0x0F) << 5) | (d.getDate() & 0x1F);
  return { t, dt };
}

// entries: [{ name: 'AI.lua' | 'brai/lua/...', data: Buffer|string }]
function zipBuffer(entries) {
  const now = dosTime(new Date());
  const locals = [];
  const central = [];
  let offset = 0;

  for (const e of entries) {
    const nameBuf = Buffer.from(e.name, 'utf8');
    const raw = Buffer.isBuffer(e.data) ? e.data : Buffer.from(String(e.data), 'utf8');
    const crc = crc32(raw);
    const comp = zlib.deflateRawSync(raw, { level: 9 });

    const lh = Buffer.alloc(30);
    lh.writeUInt32LE(0x04034b50, 0);     // local file header signature
    lh.writeUInt16LE(20, 4);             // version needed
    lh.writeUInt16LE(0, 6);              // flags
    lh.writeUInt16LE(8, 8);              // method = deflate
    lh.writeUInt16LE(now.t, 10);
    lh.writeUInt16LE(now.dt, 12);
    lh.writeUInt32LE(crc, 14);
    lh.writeUInt32LE(comp.length, 18);
    lh.writeUInt32LE(raw.length, 22);
    lh.writeUInt16LE(nameBuf.length, 26);
    lh.writeUInt16LE(0, 28);             // extra len
    locals.push(lh, nameBuf, comp);

    const ch = Buffer.alloc(46);
    ch.writeUInt32LE(0x02014b50, 0);     // central dir signature
    ch.writeUInt16LE(20, 4);             // version made by
    ch.writeUInt16LE(20, 6);             // version needed
    ch.writeUInt16LE(0, 8);
    ch.writeUInt16LE(8, 10);
    ch.writeUInt16LE(now.t, 12);
    ch.writeUInt16LE(now.dt, 14);
    ch.writeUInt32LE(crc, 16);
    ch.writeUInt32LE(comp.length, 20);
    ch.writeUInt32LE(raw.length, 24);
    ch.writeUInt16LE(nameBuf.length, 28);
    ch.writeUInt16LE(0, 30);             // extra
    ch.writeUInt16LE(0, 32);             // comment
    ch.writeUInt16LE(0, 34);             // disk
    ch.writeUInt16LE(0, 36);             // internal attrs
    ch.writeUInt32LE(0, 38);             // external attrs
    ch.writeUInt32LE(offset, 42);        // local header offset
    central.push(ch, nameBuf);

    offset += lh.length + nameBuf.length + comp.length;
  }

  const localPart = Buffer.concat(locals);
  const centralPart = Buffer.concat(central);
  const eocd = Buffer.alloc(22);
  eocd.writeUInt32LE(0x06054b50, 0);
  eocd.writeUInt16LE(0, 4);
  eocd.writeUInt16LE(0, 6);
  eocd.writeUInt16LE(entries.length, 8);
  eocd.writeUInt16LE(entries.length, 10);
  eocd.writeUInt32LE(centralPart.length, 12);
  eocd.writeUInt32LE(localPart.length, 16);
  eocd.writeUInt16LE(0, 20);
  return Buffer.concat([localPart, centralPart, eocd]);
}

module.exports = { zipBuffer, crc32 };
