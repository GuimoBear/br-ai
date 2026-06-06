// fs_bridge.js — implementa window.brai/trees/scenarios/monsters/files no NAVEGADOR.
// Modo SERVIDOR: lê os arquivos por fetch e grava pela API local (/__brai/write) do
// serve.js — o servidor (com acesso ao disco, como o "main" do Electron) acessa as
// pastas reais do projeto. Sem File System Access API, sem conectar pasta, qualquer navegador.
(function () {
  'use strict';
  var API = '/__brai';

  function safeName(n) { return String(n || '').replace(/[\\/:*?"<>|]+/g, '_').replace(/\s+/g, ' ').trim(); }
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

  // ---- brai.dispatch (host Lua da página) ----
  window.brai = {
    dispatch: async function (method, argJson) {
      try {
        if (method === 'setTree' && argJson) { try { sessionStorage.setItem('brai.simTree', argJson); } catch (e) {} }
        var data = await window.BRAIHost.dispatch(method, argJson);
        return { ok: true, data: data };
      } catch (e) { return { ok: false, error: String((e && e.message) || e) }; }
    },
  };

  // ---- trees ----
  window.trees = {
    list: async function () { await ready; try { var j = await listDir('trees'); return { ok: true, data: (j.dirs || []).sort(function (a, b) { return a.localeCompare(b); }) }; } catch (e) { return { ok: true, data: [] }; } },
    load: async function (name) { await ready; try { return { ok: true, data: await readText('trees/' + safeName(name) + '/tree.json') }; } catch (e) { return { ok: false, error: 'não foi possível abrir tree.json: ' + (e.message || e) }; } },
    save: async function (name, jsonText) {
      await ready; var n = need(); if (n) return n; var sn = safeName(name); if (!sn) return { ok: false, error: 'nome da árvore vazio' };
      try { await writeData('trees/' + sn + '/tree.json', jsonText); return { ok: true, name: sn, folder: 'trees/' + sn }; } catch (e) { return { ok: false, error: String(e.message || e) }; }
    },
    build: async function (name, payloadJson) {
      await ready; var n = need(); if (n) return n;
      try {
        var payload = JSON.parse(payloadJson);
        var spec = payload.spec || payload;
        var sn = safeName(name); if (!sn) return { ok: false, error: 'nome da árvore vazio' };
        var ctx = { homunType: payload.homunType, baseType: payload.baseType };
        var catalog = { monsters: [], groups: [] };
        try { catalog = JSON.parse((await window.monsters.load()).data); } catch (e) {}
        var choices = { choices: {} };
        try { choices = JSON.parse((await window.skillChoiceIO.load()).data); } catch (e) {}
        var summonChoices = { choices: {} };
        try { summonChoices = JSON.parse((await window.summonIO.load()).data); } catch (e) {}
        var gen = {
          'tree_homun.lua': window.BRAI_BUILD.generate(spec),
          'config.lua': window.BRAI_BUILD.generateConfig(ctx),
          'monsters.lua': window.BRAI_BUILD.generateMonsters(catalog),
          'skill_choice.lua': window.BRAI_BUILD.generateSkillChoice(choices),
          'summon_choice.lua': window.BRAI_BUILD.generateSummonChoice(summonChoices),
        };
        for (var fn in gen) await writeData('trees/' + sn + '/' + fn, gen[fn]);

        var runtime = await readLuaTree();
        var entries = [];
        for (var i = 0; i < runtime.length; i++) {
          var rel = runtime[i].rel;
          entries.push({ name: rel === 'AI.lua' ? 'AI.lua' : ('brai/lua/' + rel), data: runtime[i].data });
        }
        ['tree_homun.lua', 'config.lua', 'monsters.lua', 'skill_choice.lua'].forEach(function (f) {
          var zn = 'brai/lua/src/' + f, idx = -1;
          for (var k = 0; k < entries.length; k++) if (entries[k].name === zn) { idx = k; break; }
          if (idx >= 0) entries[idx].data = gen[f]; else entries.push({ name: zn, data: gen[f] });
        });
        var hn = { 1: 'Lif', 2: 'Amistr', 3: 'Filir', 4: 'Vanilmirth', 48: 'Eira', 49: 'Bayeri', 50: 'Sera', 51: 'Dieter', 52: 'Eleanor' };
        entries.push({ name: 'LEIA-ME.txt', data: [
          'BR-AI — pacote da IA "' + sn + '"', '',
          'INSTALAR: extraia AI.lua + a pasta brai/ em <RO>/AI/USER_AI/ e ative com /hoai.',
          'Homúnculo: ' + (hn[ctx.homunType] || ctx.homunType || '?') + (ctx.baseType ? (' / base ' + (hn[ctx.baseType] || ctx.baseType)) : '') + '.',
        ].join('\r\n') });

        for (var e = 0; e < entries.length; e++) await writeData('trees/' + sn + '/dist/' + entries[e].name, entries[e].data);
        var zipBytes = window.BRAI_ZIP.zipBytes(entries);
        await writeData('trees/' + sn + '/' + sn + '.zip', zipBytes);
        download(sn + '.zip', zipBytes);
        return { ok: true, name: sn, dist: 'trees/' + sn + '/dist', zip: 'trees/' + sn + '/' + sn + '.zip', files: entries.length };
      } catch (e) { return { ok: false, error: String((e && e.message) || e) }; }
    },
  };

  // ---- scenarios ----
  window.scenarios = {
    list: async function () { await ready; try { var j = await listDir('scenarios'); return { ok: true, data: (j.files || []).filter(function (f) { return f.toLowerCase().endsWith('.json'); }).map(function (f) { return f.slice(0, -5); }).sort(function (a, b) { return a.localeCompare(b); }) }; } catch (e) { return { ok: true, data: [] }; } },
    load: async function (name) { await ready; try { return { ok: true, data: await readText('scenarios/' + safeName(name) + '.json') }; } catch (e) { return { ok: false, error: 'não foi possível abrir o cenário: ' + (e.message || e) }; } },
    save: async function (name, jsonText) { await ready; var n = need(); if (n) return n; var sn = safeName(name); if (!sn) return { ok: false, error: 'nome do cenário vazio' }; try { await writeData('scenarios/' + sn + '.json', jsonText); return { ok: true, name: sn }; } catch (e) { return { ok: false, error: String(e.message || e) }; } },
  };

  // ---- monsters (catálogo global na raiz) ----
  window.monsters = {
    load: async function () { await ready; try { return { ok: true, data: await readText('monsters.json') }; } catch (e) { return { ok: true, data: JSON.stringify({ monsters: [], groups: [] }) }; } },
    save: async function (jsonText) { await ready; var n = need(); if (n) return n; try { await writeData('monsters.json', jsonText); return { ok: true, path: 'monsters.json' }; } catch (e) { return { ok: false, error: String(e.message || e) }; } },
  };

  // ---- skillChoice (escolha global de skills na raiz: homun_skills.json) ----
  window.skillChoiceIO = {
    load: async function () { await ready; try { return { ok: true, data: await readText('homun_skills.json') }; } catch (e) { return { ok: true, data: JSON.stringify({ choices: {} }) }; } },
    save: async function (jsonText) { await ready; var n = need(); if (n) return n; try { await writeData('homun_skills.json', jsonText); return { ok: true, path: 'homun_skills.json' }; } catch (e) { return { ok: false, error: String(e.message || e) }; } },
  };

  // ---- summonIO (config global de invocacoes na raiz: homun_summons.json) ----
  window.summonIO = {
    load: async function () { await ready; try { return { ok: true, data: await readText('homun_summons.json') }; } catch (e) { return { ok: true, data: JSON.stringify({ choices: {} }) }; } },
    save: async function (jsonText) { await ready; var n = need(); if (n) return n; try { await writeData('homun_summons.json', jsonText); return { ok: true, path: 'homun_summons.json' }; } catch (e) { return { ok: false, error: String(e.message || e) }; } },
  };

  // ---- files (fallbacks usados pelo editor) ----
  window.files = {
    loadTree: async function () { await ready; try { return { ok: true, data: await readText('desktop/shared/tree_homun.json') }; } catch (e) { return { ok: false, error: 'sem arquivo' }; } },
    saveTree: async function (jsonText) { await ready; var n = need(); if (n) return n; try { await writeData('desktop/shared/tree_homun.json', jsonText); return { ok: true }; } catch (e) { return { ok: false, error: String(e.message || e) }; } },
    buildLua: async function (jsonText) { await ready; var n = need(); if (n) return n; try { await writeData('lua/src/tree_homun.lua', window.BRAI_BUILD.generate(JSON.parse(jsonText))); return { ok: true }; } catch (e) { return { ok: false, error: String(e.message || e) }; } },
  };

  // compat: alguns HTMLs têm o botão antigo
  window.BRAIConnectFolder = function () { alert('No modo servidor não é preciso conectar pasta — o servidor já lê e grava as pastas reais do projeto.'); };

  document.addEventListener('DOMContentLoaded', updateBanner);
})();
