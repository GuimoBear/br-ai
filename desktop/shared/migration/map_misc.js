// map_misc.js — listas auxiliares (A_Friends, Mob_ID) → notas informativas no relatório.
// O BR-AI ainda não tem sistema de amigos/PVP; aqui só relatamos (honestidade > silêncio).
(function (root) {
  'use strict';
  var NAMES = { 13: 'ALLY', 12: 'KOS', 11: 'ENEMY', 10: 'NEUTRAL', 2: 'RETAINER', 1: 'FRIEND', 3: 'PKFRIEND' };

  function mapMisc(friends, mobid) {
    var rows = [], notes = [], consumed = {};
    var counts = {}, total = 0;
    if (friends && typeof friends === 'object') {
      for (var k in friends) if (friends.hasOwnProperty(k)) {
        var n = Number(k); if (isNaN(n)) continue;
        var v = friends[k]; var label = NAMES[Number(v)] || (v === true ? 'FRIEND' : String(v));
        counts[label] = (counts[label] || 0) + 1; total++;
      }
    }
    if (total) {
      var parts = Object.keys(counts).map(function (c) { return counts[c] + '×' + c; }).join(', ');
      notes.push(total + ' entradas de amigos/PVP detectadas (' + parts + '). O BR-AI ainda não tem sistema de amigos — registre manualmente se for usar PVP.');
      rows.push({ from: 'A_Friends (' + total + ' entradas)', to: 'não migrado (sem sistema de amigos no BR-AI)', status: 'note' });
    }
    if (mobid && typeof mobid === 'object') {
      var mc = Object.keys(mobid).length;
      if (mc) { notes.push(mc + ' IDs customizados em Mob_ID — informativo.'); rows.push({ from: 'Mob_ID (' + mc + ')', to: 'informativo', status: 'note' }); }
    }
    return { rows: rows, notes: notes, consumed: consumed };
  }

  var api = { mapMisc: mapMisc };
  if (typeof module !== 'undefined' && module.exports) module.exports = api;
  if (typeof window !== 'undefined') window.BRAI_MIG_MAP_MISC = api;
})(typeof globalThis !== 'undefined' ? globalThis : this);
