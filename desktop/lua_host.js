// lua_host.js — embute o Lua (Fengari) e carrega a BT + runtime do simulador.
// Expoe um unico metodo: dispatch(method, argJson) -> jsonString.
// Carregamos cada modulo .lua explicitamente (sem dofile), pois o codigo da BT
// se registra no namespace global BRAI; a ordem replica lua/bootstrap.lua.
const fs = require('fs');
const path = require('path');
const { lua, lauxlib, lualib, to_luastring, to_jsstring } = require('fengari');

// Ordem de carga (igual a lua/bootstrap.lua) + json + runtime do simulador.
// FONTE ÚNICA da ordem de módulos: deriva do próprio bootstrap.lua (as linhas f("..."))
// e acrescenta os arquivos exclusivos do simulador. Evita duplicação/dessincronização.
function moduleList(luaBase) {
  const boot = fs.readFileSync(path.join(luaBase, 'bootstrap.lua'), 'utf8');
  const files = [];
  const re = /f\(\s*"([^"]+)"\s*\)/g;
  let m;
  while ((m = re.exec(boot)) !== null) files.push(m[1]);
  // módulos do simulador (não carregados no cliente do RO)
  files.push('src/sim/json.lua', 'src/sim/runtime.lua');
  return files;
}

let L = null;

function loadLuaFile(L, absFile) {
  const src = fs.readFileSync(absFile, 'utf8');
  // prefixo de comentario com o nome do arquivo ajuda nas mensagens de erro
  let st = lauxlib.luaL_loadstring(L, to_luastring('--@' + absFile + '\n' + src));
  if (st !== lua.LUA_OK) {
    const msg = to_jsstring(lua.lua_tostring(L, -1));
    throw new Error('Falha ao compilar ' + absFile + ': ' + msg);
  }
  if (lua.lua_pcall(L, 0, lua.LUA_MULTRET, 0) !== lua.LUA_OK) {
    const msg = to_jsstring(lua.lua_tostring(L, -1));
    throw new Error('Falha ao executar ' + absFile + ': ' + msg);
  }
  lua.lua_settop(L, 0);
}

// luaBase = caminho absoluto da pasta "lua" do projeto.
function init(luaBase) {
  L = lauxlib.luaL_newstate();
  lualib.luaL_openlibs(L);
  for (const rel of moduleList(luaBase)) {
    loadLuaFile(L, path.join(luaBase, rel));
  }
}

function dispatch(method, argJson) {
  if (!L) throw new Error('lua_host nao inicializado');
  lua.lua_getglobal(L, to_luastring('SIM_DISPATCH'));
  lua.lua_pushstring(L, to_luastring(method));
  lua.lua_pushstring(L, to_luastring(argJson || ''));
  if (lua.lua_pcall(L, 2, 1, 0) !== lua.LUA_OK) {
    const msg = to_jsstring(lua.lua_tostring(L, -1));
    lua.lua_settop(L, 0);
    throw new Error('SIM_DISPATCH(' + method + '): ' + msg);
  }
  const res = to_jsstring(lua.lua_tostring(L, -1));
  lua.lua_settop(L, 0);
  return res;
}


module.exports = { init, dispatch };
