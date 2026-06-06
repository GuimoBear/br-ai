// preload.js — ponte segura renderer <-> main (contextIsolation ligado).
const { contextBridge, ipcRenderer } = require('electron');

contextBridge.exposeInMainWorld('brai', {
  dispatch: (method, argJson) => ipcRenderer.invoke('sim:dispatch', method, argJson),
});

contextBridge.exposeInMainWorld('files', {
  loadTree: () => ipcRenderer.invoke('files:loadTree'),
  saveTree: (jsonText) => ipcRenderer.invoke('files:saveTree', jsonText),
  buildLua: (jsonText) => ipcRenderer.invoke('files:buildLua', jsonText),
});

contextBridge.exposeInMainWorld('trees', {
  list: () => ipcRenderer.invoke('trees:list'),
  load: (name) => ipcRenderer.invoke('trees:load', name),
  save: (name, jsonText) => ipcRenderer.invoke('trees:save', name, jsonText),
  build: (name, specJson) => ipcRenderer.invoke('trees:build', name, specJson),
});

contextBridge.exposeInMainWorld('scenarios', {
  list: () => ipcRenderer.invoke('scenarios:list'),
  load: (name) => ipcRenderer.invoke('scenarios:load', name),
  save: (name, jsonText) => ipcRenderer.invoke('scenarios:save', name, jsonText),
});

contextBridge.exposeInMainWorld('monsters', {
  load: () => ipcRenderer.invoke('monsters:load'),
  save: (jsonText) => ipcRenderer.invoke('monsters:save', jsonText),
});

contextBridge.exposeInMainWorld('skillChoiceIO', {
  load: () => ipcRenderer.invoke('skillChoice:load'),
  save: (jsonText) => ipcRenderer.invoke('skillChoice:save', jsonText),
});

contextBridge.exposeInMainWorld('summonIO', {
  load: () => ipcRenderer.invoke('summonChoice:load'),
  save: (jsonText) => ipcRenderer.invoke('summonChoice:save', jsonText),
});
