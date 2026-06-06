// lua_host_web.js — host Lua para o NAVEGADOR (porta de desktop/lua_host.js).
// Usa window.fengari (bundle de navegador) + fetch das fontes Lua. Carrega os
// módulos na MESMA ordem de lua/bootstrap.lua e expõe window.BRAIHost.
//   window.BRAIHost.ready            -> Promise resolvida quando a VM está pronta
//   window.BRAIHost.dispatch(m, arg) -> async, retorna a string JSON do SIM_DISPATCH
(function () {
  'use strict';
  if (!window.fengari) { throw new Error('fengari-web não carregou antes de lua_host_web.js'); }
  var F = window.fengari;
  var lua = F.lua, lauxlib = F.lauxlib, lualib = F.lualib;
  var to_luastring = F.to_luastring, to_jsstring = F.to_jsstring;

  // pasta lua/ relativa à página (servida): .../desktop/web/<pág> -> .../lua/
  var LUA_BASE = new URL('../../lua/', document.baseURI).href;
  var L = null;

  async function fetchText(rel) {
    var r = await fetch(LUA_BASE + rel, { cache: 'no-cache' });
    if (!r.ok) throw new Error('falha ao buscar ' + rel + ' (HTTP ' + r.status + ')');
    return await r.text();
  }

  function loadChunk(rel, src) {
    var st = lauxlib.luaL_loadstring(L, to_luastring('--@' + rel + '\n' + src));
    if (st !== lua.LUA_OK) throw new Error('compilar ' + rel + ': ' + to_jsstring(lua.lua_tostring(L, -1)));
    if (lua.lua_pcall(L, 0, lua.LUA_MULTRET, 0) !== lua.LUA_OK) throw new Error('executar ' + rel + ': ' + to_jsstring(lua.lua_tostring(L, -1)));
    lua.lua_settop(L, 0);
  }

  function rawDispatch(method, argJson) {
    lua.lua_getglobal(L, to_luastring('SIM_DISPATCH'));
    lua.lua_pushstring(L, to_luastring(method));
    lua.lua_pushstring(L, to_luastring(argJson || ''));
    if (lua.lua_pcall(L, 2, 1, 0) !== lua.LUA_OK) {
      var e = to_jsstring(lua.lua_tostring(L, -1)); lua.lua_settop(L, 0);
      throw new Error('SIM_DISPATCH(' + method + '): ' + e);
    }
    var res = to_jsstring(lua.lua_tostring(L, -1)); lua.lua_settop(L, 0);
    return res;
  }

  async function init() {
    L = lauxlib.luaL_newstate();
    lualib.luaL_openlibs(L);

    // ordem dos módulos = derivada de bootstrap.lua (linhas f("...")) + sim
    var boot = await fetchText('bootstrap.lua');
    var files = [];
    var re = /f\(\s*"([^"]+)"\s*\)/g, m;
    while ((m = re.exec(boot)) !== null) files.push(m[1]);
    files.push('src/sim/json.lua', 'src/sim/runtime.lua');

    // busca todas em paralelo, carrega na ordem
    var srcs = await Promise.all(files.map(function (f) { return fetchText(f).then(function (t) { return [f, t]; }); }));
    var byName = {}; srcs.forEach(function (p) { byName[p[0]] = p[1]; });
    for (var i = 0; i < files.length; i++) loadChunk(files[i], byName[files[i]]);

    // reaplica a ÁRVORE editada que veio do editor (persistida na navegação)
    try { var t = sessionStorage.getItem('brai.simTree'); if (t) rawDispatch('setTree', t); } catch (e) {}
  }

  var ready = init();
  window.BRAIHost = {
    ready: ready,
    dispatch: async function (method, argJson) { await ready; return rawDispatch(method, argJson); },
  };
})();
