// main.js — processo principal do Electron. Inicializa o host Lua e roteia IPC.
const { app, BrowserWindow, ipcMain } = require('electron');
const path = require('path');
const fs = require('fs');
const treesIo = require('./trees_io');
const scnIo = require('./scenarios_io');
const monIo = require('./monsters_io');
const skillIo = require('./skillchoice_io');
const skillParamsIo = require('./skillparams_io');
const summonIo = require('./summonchoice_io');
const installer = require('./installer');

const ROOT = path.join(__dirname, '..');
const LUA_BASE = path.join(__dirname, '..', 'lua');
const TREE_JSON = path.join(__dirname, 'shared', 'tree_homun.json');
const TREE_LUA = path.join(LUA_BASE, 'src', 'tree_homun.lua');

let luaHost = null;
let buildTree = null;
let initError = null;

function tryInit() {
  try {
    luaHost = require('./lua_host');
    buildTree = require('../tools/build_tree');
    luaHost.init(LUA_BASE);
  } catch (e) {
    initError = String((e && e.stack) || (e && e.message) || e);
    console.error('=== BR-AI init falhou ===\n' + initError);
  }
}

function createWindow() {
  const win = new BrowserWindow({
    width: 1280,
    height: 800,
    title: 'BR-AI — Simulador',
    webPreferences: {
      preload: path.join(__dirname, 'preload.js'),
      contextIsolation: true,
      nodeIntegration: false,
    },
  });
  win.loadFile(path.join(__dirname, 'editor', 'index.html'));
}

app.whenReady().then(() => {
  // Handlers registrados SEMPRE (mesmo se o init falhar) — assim o renderer
  // nunca fica pendurado: ou recebe dados, ou recebe um erro claro.
  ipcMain.handle('sim:dispatch', (_evt, method, argJson) => {
    if (initError) return { ok: false, error: 'Host Lua não inicializou: ' + initError };
    try {
      return { ok: true, data: luaHost.dispatch(method, argJson) };
    } catch (e) {
      return { ok: false, error: String((e && e.message) || e) };
    }
  });

  ipcMain.handle('files:loadTree', () => {
    try { return { ok: true, data: fs.readFileSync(TREE_JSON, 'utf8') }; }
    catch (e) { return { ok: false, error: String(e.message || e) }; }
  });

  ipcMain.handle('files:saveTree', (_evt, jsonText) => {
    try { fs.writeFileSync(TREE_JSON, jsonText, 'utf8'); return { ok: true, path: TREE_JSON }; }
    catch (e) { return { ok: false, error: String(e.message || e) }; }
  });

  ipcMain.handle('files:buildLua', (_evt, jsonText) => {
    if (!buildTree) return { ok: false, error: 'buildTree indisponível: ' + initError };
    try {
      const spec = JSON.parse(jsonText);
      fs.writeFileSync(TREE_LUA, buildTree.generate(spec), 'utf8');
      return { ok: true, path: TREE_LUA };
    } catch (e) { return { ok: false, error: String(e.message || e) }; }
  });

  ipcMain.handle('trees:list', () => {
    try { return { ok: true, data: treesIo.list(ROOT) }; } catch (e) { return { ok: false, error: String(e.message || e) }; }
  });
  ipcMain.handle('trees:load', (_evt, name) => {
    try { return { ok: true, data: treesIo.load(ROOT, name) }; } catch (e) { return { ok: false, error: String(e.message || e) }; }
  });
  ipcMain.handle('trees:save', (_evt, name, jsonText) => {
    try { const r = treesIo.save(ROOT, name, jsonText); return { ok: true, name: r.name, folder: r.folder }; }
    catch (e) { return { ok: false, error: String(e.message || e) }; }
  });
  ipcMain.handle('trees:build', (_evt, name, payloadJson) => {
    if (!buildTree) return { ok: false, error: 'buildTree indisponível: ' + initError };
    try {
      const payload = JSON.parse(payloadJson);
      const spec = payload.spec || payload;
      treesIo.writeFile(ROOT, name, 'tree_homun.lua', buildTree.generate(spec));
      treesIo.writeFile(ROOT, name, 'config.lua', buildTree.generateConfig({ homunType: payload.homunType, baseType: payload.baseType, config: payload.config }));
      // emite tambem o catalogo de monstros/grupos (global) p/ os nos monsterCheck
      let catalog = { monsters: [], groups: [] };
      let monstersRaw = null;
      try { monstersRaw = monIo.load(ROOT); catalog = JSON.parse(monstersRaw); } catch (e) {}
      // #2: so escreve monsters.lua se a arvore usa monsterCheck (consistente com o pacote)
      if (buildTree.treeUsesMonsterCheck(spec)) treesIo.writeFile(ROOT, name, 'monsters.lua', buildTree.generateMonsters(catalog));
      // emite a escolha de skills por homúnculo (global) p/ as ações automáticas
      let choices = { choices: {} };
      let skillsRaw = null;
      try { skillsRaw = skillIo.load(ROOT); choices = JSON.parse(skillsRaw); } catch (e) {}
      // #3: expande p/ a escolha EFETIVA de TODOS os 9 homuns (defaults+overrides) via o host Lua,
      // deixando o pacote auto-descritivo. Fallback p/ o JSON cru se o host falhar.
      let effChoices = choices;
      try { effChoices = { choices: JSON.parse(luaHost.dispatch('allSkillChoices', JSON.stringify(choices))) }; } catch (e) {}
      treesIo.writeFile(ROOT, name, 'skill_choice.lua', buildTree.generateSkillChoice(effChoices));
      let summonChoices = { choices: {} };
      try { summonChoices = JSON.parse(summonIo.load(ROOT)); } catch (e) {}
      treesIo.writeFile(ROOT, name, 'summon_choice.lua', buildTree.generateSummonChoice(summonChoices));
      let skillParams = { params: {} };
      let skillParamsRaw = null;
      try { skillParamsRaw = skillParamsIo.load(ROOT); skillParams = JSON.parse(skillParamsRaw); } catch (e) {}
      treesIo.writeFile(ROOT, name, 'skill_params.lua', buildTree.generateSkillParams(skillParams));
      // monta o PACOTE auto-suficiente (runtime completo + gerados) + .zip
      const pkg = installer.buildPackage({
        root: ROOT, luaBase: LUA_BASE, name: name, spec: spec,
        ctx: { homunType: payload.homunType, baseType: payload.baseType, config: payload.config },
        catalog: catalog, choices: effChoices, summonChoices: summonChoices, skillParams: skillParams, buildTree: buildTree, safeName: treesIo.safeName,
        sourceJson: {   // #6: JSONs-fonte (re-importacao) em source/ do pacote
          tree: JSON.stringify({ name: treesIo.safeName(name), homunType: payload.homunType, baseType: payload.baseType, config: payload.config, spec: spec }, null, 2),
          skills: skillsRaw, monsters: monstersRaw, skillParams: skillParamsRaw,
        },
      });
      return { ok: true, name: treesIo.safeName(name), dist: pkg.distDir, zip: pkg.zipPath, files: pkg.fileCount };
    } catch (e) { return { ok: false, error: String(e.message || e) }; }
  });

  ipcMain.handle('scenarios:list', () => {
    try { return { ok: true, data: scnIo.list(ROOT) }; } catch (e) { return { ok: false, error: String(e.message || e) }; }
  });
  ipcMain.handle('scenarios:load', (_evt, name) => {
    try { return { ok: true, data: scnIo.load(ROOT, name) }; } catch (e) { return { ok: false, error: String(e.message || e) }; }
  });
  ipcMain.handle('scenarios:save', (_evt, name, jsonText) => {
    try { const r = scnIo.save(ROOT, name, jsonText); return { ok: true, name: r.name }; }
    catch (e) { return { ok: false, error: String(e.message || e) }; }
  });

  ipcMain.handle('monsters:load', () => {
    try { return { ok: true, data: monIo.load(ROOT) }; } catch (e) { return { ok: false, error: String(e.message || e) }; }
  });
  ipcMain.handle('monsters:save', (_evt, jsonText) => {
    try { const r = monIo.save(ROOT, jsonText); return { ok: true, path: r.path }; }
    catch (e) { return { ok: false, error: String(e.message || e) }; }
  });

  ipcMain.handle('skillChoice:load', () => {
    try { return { ok: true, data: skillIo.load(ROOT) }; } catch (e) { return { ok: false, error: String(e.message || e) }; }
  });
  ipcMain.handle('skillChoice:save', (_evt, jsonText) => {
    try { const r = skillIo.save(ROOT, jsonText); return { ok: true, path: r.path }; }
    catch (e) { return { ok: false, error: String(e.message || e) }; }
  });
  ipcMain.handle('skillParams:load', () => {
    try { return { ok: true, data: skillParamsIo.load(ROOT) }; } catch (e) { return { ok: false, error: String(e.message || e) }; }
  });
  ipcMain.handle('skillParams:save', (_evt, jsonText) => {
    try { const r = skillParamsIo.save(ROOT, jsonText); return { ok: true, path: r.path }; }
    catch (e) { return { ok: false, error: String(e.message || e) }; }
  });

  ipcMain.handle('summonChoice:load', () => {
    try { return { ok: true, data: summonIo.load(ROOT) }; } catch (e) { return { ok: false, error: String(e.message || e) }; }
  });
  ipcMain.handle('summonChoice:save', (_evt, jsonText) => {
    try { const r = summonIo.save(ROOT, jsonText); return { ok: true, path: r.path }; }
    catch (e) { return { ok: false, error: String(e.message || e) }; }
  });

  tryInit();
  createWindow();

  app.on('activate', () => {
    if (BrowserWindow.getAllWindows().length === 0) createWindow();
  });
});

app.on('window-all-closed', () => {
  if (process.platform !== 'darwin') app.quit();
});
