// migration_parse_test.js — parser de subconjunto Lua, símbolos e leitor de zip.
// Roda: node tools/migration_parse_test.js  (sai !=0 em falha; faz parte de test:node)
'use strict';
var assert = require('assert');
var path = require('path');
var M = path.join(__dirname, '..', 'desktop', 'shared', 'migration');
var luaParse = require(path.join(M, 'lua_parse.js'));
var symbols = require(path.join(M, 'symbols.js'));
var zipRead = require(path.join(M, 'zip_read.js'));
var zipWrite = require(path.join(__dirname, '..', 'desktop', 'zip.js'));

var n = 0; function ok(cond, msg) { n++; assert.ok(cond, msg); }
function eq(a, b, msg) { n++; assert.deepStrictEqual(a, b, msg); }

// ---- tokenizer/parser básico ----
(function () {
  var env = {};
  luaParse.parse([
    'AggroHP = 60',
    'Neg = -3',
    'Dec = .80',
    'Flag = true',
    'Off = false',
    'Nada = nil',
    'Str = "ola mundo"',
    'Hex = 0x10',
  ].join('\n'), env);
  eq(env.AggroHP, 60, 'int');
  eq(env.Neg, -3, 'negativo');
  eq(env.Dec, 0.8, 'decimal .80');
  eq(env.Flag, true, 'true'); eq(env.Off, false, 'false'); eq(env.Nada, null, 'nil');
  eq(env.Str, 'ola mundo', 'string');
  eq(env.Hex, 16, 'hex 0x10');
})();

// ---- comentários (linha e bloco) não quebram ----
(function () {
  var env = {};
  luaParse.parse('A = 1 -- comentario\n--[[ bloco\nmais ]]\nB = 2', env);
  eq(env.A, 1, 'valor antes de comentário de linha');
  eq(env.B, 2, 'valor depois de bloco');
})();

// ---- tabelas: array, [k]=v, nome=v, aninhada, esparsa ----
(function () {
  var env = {};
  luaParse.parse('T = {10, 20, 30}\nM = {[5]=50, x=1}\nNest = {{1,2},{3,4}}\nMyTact={}\nMyTact[1042]={1,-1,2}', env);
  eq(luaParse.toArray(env.T), [10, 20, 30], 'array 1-based');
  eq(env.M[5], 50, '[k]=v'); eq(env.M.x, 1, 'nome=v');
  eq(luaParse.toArray(env.Nest[1]), [1, 2], 'aninhada 1');
  eq(luaParse.toArray(env.MyTact[1042]), [1, -1, 2], 'tabela esparsa por índice');
})();

// ---- símbolos por referência (resolvidos via env pré-semeado) ----
(function () {
  var env = { TACT_ATTACK_L: 2, KITE_REACT: 1, ELEANOR: 52 };
  luaParse.parse('MyTact={}\nMyTact[1]={TACT_ATTACK_L, KITE_REACT}\nSkillList={}\nSkillList[ELEANOR]={[8028]=5}', env);
  eq(luaParse.toArray(env.MyTact[1]), [2, 1], 'símbolos no array');
  eq(env.SkillList[52][8028], 5, 'símbolo como chave de tabela');
})();

// ---- robustez: linha malformada vira aviso, não trava ----
(function () {
  var env = {};
  var r = luaParse.parse('A = 1\n@#$ lixo aqui\nB = 2\nfunction foo() return 9 end\nC = 3', env);
  eq(env.A, 1, 'antes do lixo'); eq(env.B, 2, 'depois do lixo'); eq(env.C, 3, 'depois de function');
  ok(Array.isArray(r.warnings), 'tem array de warnings');
})();

// ---- símbolos: FALLBACK + arquivos reais do USER_AI ----
(function () {
  var fs = require('fs');
  var dir = path.join(__dirname, '..', 'USER_AI');
  var files = {};
  ['Const_.lua', 'H_SkillList.lua'].forEach(function (f) { try { files[f] = fs.readFileSync(path.join(dir, f), 'latin1'); } catch (e) {} });
  var built = symbols.buildEnv(files, luaParse.parse);
  eq(built.env.ELEANOR, 52, 'ELEANOR via Const_');
  eq(built.env.MH_BLAST_FORGE, 8044, 'MH_BLAST_FORGE via H_SkillList');
  // fallback isolado (sem arquivos)
  var fb = symbols.buildFallback();
  eq(fb.TACT_ATTACK_TOP, 15, 'fallback TACT_ATTACK_TOP');
  eq(fb.DIETER, 51, 'fallback DIETER');
  eq(symbols.baseProfileType(9), 1, 'evolução LIF_H → base 1');
  eq(symbols.baseProfileType(52), 52, 'Homun S = ele mesmo');
  ok(symbols.isHomunS(50) && !symbols.isHomunS(3), 'isHomunS');
})();

// ---- zip: round-trip (escreve com desktop/zip.js, lê com zip_read) ----
(function () {
  var buf = zipWrite.zipBuffer([
    { name: 'H_Config.lua', data: 'AggroHP = 42\n' },
    { name: 'USER_AI/H_Tactics.lua', data: 'MyTact={}\nMyTact[0]={1}\n' },
  ]);
  var out = zipRead.readZipSync(buf);
  ok(out['H_Config.lua'].indexOf('AggroHP = 42') >= 0, 'zip lê H_Config');
  ok(out['H_Tactics.lua'] != null, 'zip ignora pasta-raiz (basename)');
})();

console.log('RESULTADO migration_parse: ' + n + ' asserções OK');
