// static_ui.js — UI de upload/download da versão estática. Carregar = upload (overlay de
// sessão), salvar = download (já tratado pelo s3_backend). classify() é puro/testável.
(function (root) {
  'use strict';

  // Classifica um arquivo importado pelo conteúdo (+ dica do nome). Retorna {kind, rel, name}.
  function classify(filename, obj) {
    var name = String(filename || 'importado').replace(/\.json$/i, '').replace(/[\\/:*?"<>|]+/g, '_').trim() || 'importado';
    if (obj && (Array.isArray(obj.entities) || obj.grid)) return { kind: 'scenario', rel: 'scenarios/' + name + '.json', name: name };
    if (obj && (obj.spec || (obj.type && obj.children) || obj.homunType != null)) return { kind: 'tree', rel: 'trees/' + name + '/tree.json', name: name };
    if (obj && (Array.isArray(obj.monsters) || Array.isArray(obj.groups))) return { kind: 'monsters', rel: 'monsters.json', name: 'monsters' };
    if (obj && obj.choices) {
      if (/summon|invoc/i.test(filename || '')) return { kind: 'summons', rel: 'homun_summons.json', name: 'homun_summons' };
      return { kind: 'skills', rel: 'homun_skills.json', name: 'homun_skills' };
    }
    return { kind: 'unknown', rel: 'scenarios/' + name + '.json', name: name };
  }

  var api = { classify: classify };
  if (typeof module !== 'undefined' && module.exports) module.exports = api;
  if (typeof window !== 'undefined') window.BRAI_STATIC_UI = api;

  // ---- Wiring de DOM (só no navegador) ----
  if (typeof document === 'undefined') return;

  function $(id) { return document.getElementById(id); }
  function rebuildSelect(sel, names, placeholder) {
    if (!sel) return;
    var cur = sel.value;
    sel.innerHTML = '';
    var op0 = document.createElement('option'); op0.value = ''; op0.textContent = placeholder; sel.appendChild(op0);
    names.forEach(function (n) { var o = document.createElement('option'); o.value = n; o.textContent = n; sel.appendChild(o); });
    sel.value = cur;
  }

  async function refreshLists(selectName) {
    try {
      if (window.scenarios && $('scnList')) { var s = await window.scenarios.list(); rebuildSelect($('scnList'), s.data || [], '— cenários —'); if (selectName) $('scnList').value = selectName; }
    } catch (e) {}
    try {
      if (window.trees && $('treeList')) { var t = await window.trees.list(); rebuildSelect($('treeList'), t.data || [], '— salvas —'); if (selectName) $('treeList').value = selectName; }
    } catch (e) {}
  }

  async function handleImport(file) {
    var text = await file.text();
    var obj; try { obj = JSON.parse(text); } catch (e) { alert('Arquivo não é um JSON válido.'); return; }
    var info = classify(file.name, obj);
    var backend = window.BRAI_STATIC_BACKEND;
    if (!backend || !backend.importFile) { alert('Backend estático indisponível.'); return; }
    backend.importFile(info.rel, text);
    await refreshLists(info.name);
    // Dispara o carregamento usando os botões já existentes da página.
    if (info.kind === 'scenario' && $('scnList') && $('btnScnLoad')) { $('scnList').value = info.name; $('btnScnLoad').click(); }
    else if (info.kind === 'tree' && $('treeList') && $('btnOpen')) { $('treeList').value = info.name; $('btnOpen').click(); }
    else { alert('Importado: ' + info.kind + '. Reabra o painel correspondente se necessário.'); }
  }

  function injectBar() {
    if ($('braiStaticBar')) return;
    var bar = document.createElement('div');
    bar.id = 'braiStaticBar'; bar.className = 'brai-static-bar';
    var label = document.createElement('label'); label.className = 'file';
    label.textContent = '📤 Importar arquivo';
    var input = document.createElement('input'); input.type = 'file'; input.accept = '.json,application/json';
    input.addEventListener('change', function () { if (input.files && input.files[0]) handleImport(input.files[0]); input.value = ''; });
    label.appendChild(input);
    var hint = document.createElement('span'); hint.className = 'muted';
    hint.textContent = ' carregar = upload · salvar = download (nada fica no navegador)';
    bar.appendChild(label); bar.appendChild(hint);
    document.body.insertBefore(bar, document.body.firstChild);
  }

  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', injectBar);
  else injectBar();
})(typeof globalThis !== 'undefined' ? globalThis : this);
