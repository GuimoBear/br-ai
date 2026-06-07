// lua_host_web.js — host Lua para o NAVEGADOR (provider de fetch sobre o núcleo COMUM).
// A ordem dos módulos e a VM ficam em desktop/shared/lua_host_core.js; aqui só buscamos
// as fontes Lua por fetch e expomos window.BRAIHost (ready + dispatch). Comportamento
// idêntico ao anterior.
(function () {
  'use strict';
  if (!window.fengari) { throw new Error('fengari-web não carregou antes de lua_host_web.js'); }
  if (!window.BRAI_LUA_HOST) { throw new Error('lua_host_core.js não carregou antes de lua_host_web.js'); }

  // pasta lua/ relativa à página (servida): .../desktop/web/<pág> -> .../lua/
  var LUA_BASE = new URL('../../lua/', document.baseURI).href;

  function fetchText(rel) {
    return fetch(LUA_BASE + rel, { cache: 'no-cache' }).then(function (r) {
      if (!r.ok) throw new Error('falha ao buscar ' + rel + ' (HTTP ' + r.status + ')');
      return r.text();
    });
  }

  window.BRAIHost = window.BRAI_LUA_HOST.create({
    fengari: window.fengari,
    getText: fetchText,
    // reaplica a ÁRVORE editada que veio do editor (persistida na navegação)
    onReadyTree: function () { try { return sessionStorage.getItem('brai.simTree'); } catch (e) { return null; } },
  });
})();
