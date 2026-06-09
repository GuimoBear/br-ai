// lua_parse.js — parser de um SUBCONJUNTO de Lua p/ ler os arquivos de config da AzzyAI.
// Suporta o que os arquivos-alvo (H_Config, H_Tactics, H_SkillList, Const_) realmente usam:
//   • atribuições  Nome = valor   e   Tabela[idx] = valor   (idx numérico, string ou símbolo)
//   • construtores de tabela  {a, b, c}  e  { [k]=v, nome=v }  aninhados
//   • números (int, decimal, .80, negativos), strings "..."/'...', true/false/nil
//   • referência a símbolos já definidos (resolvidos via `env` — ex.: TACT_ATTACK_L, ELEANOR)
// NÃO executa funções nem aritmética. É TOLERANTE: erros viram avisos e o parse continua.
// Uso (Node e navegador):  var { parse } = require('./lua_parse');  var r = parse(src, env);
//   → r.env (mutado in-place) e r.warnings[]. Tabelas viram objetos JS comuns ({1:..,2:..} p/ arrays).
(function (root) {
  'use strict';

  // ------------------------------------------------------------------ tokenizer
  function tokenize(src) {
    var toks = [], i = 0, n = src.length, line = 1;
    function push(t, v) { toks.push({ t: t, v: v, line: line }); }
    var NAME0 = /[A-Za-z_]/, NAMEN = /[A-Za-z0-9_]/;
    while (i < n) {
      var c = src[i];
      if (c === '\n') { line++; i++; continue; }
      if (c === ' ' || c === '\t' || c === '\r' || c === '\f' || c === '\v') { i++; continue; }
      // comentários
      if (c === '-' && src[i + 1] === '-') {
        if (src[i + 2] === '[' && src[i + 3] === '[') {           // bloco --[[ ... ]]
          i += 4;
          while (i < n && !(src[i] === ']' && src[i + 1] === ']')) { if (src[i] === '\n') line++; i++; }
          i += 2; continue;
        }
        i += 2; while (i < n && src[i] !== '\n') i++; continue;   // linha --
      }
      // strings
      if (c === '"' || c === "'") {
        var q = c, s = ''; i++;
        while (i < n && src[i] !== q) {
          if (src[i] === '\\') {
            var e = src[i + 1];
            s += (e === 'n') ? '\n' : (e === 't') ? '\t' : (e === 'r') ? '\r' : e;
            i += 2; continue;
          }
          if (src[i] === '\n') line++;
          s += src[i]; i++;
        }
        i++; push('str', s); continue;
      }
      // números (decimal/.80). O sinal negativo é tratado no parser de valor.
      if ((c >= '0' && c <= '9') || (c === '.' && src[i + 1] >= '0' && src[i + 1] <= '9')) {
        var j = i, num = '';
        // hexadecimal 0x...
        if (c === '0' && (src[i + 1] === 'x' || src[i + 1] === 'X')) {
          j = i + 2; var hex = '';
          while (j < n && /[0-9a-fA-F]/.test(src[j])) { hex += src[j]; j++; }
          push('num', parseInt(hex, 16)); i = j; continue;
        }
        while (j < n && /[0-9.]/.test(src[j])) { num += src[j]; j++; }
        push('num', parseFloat(num)); i = j; continue;
      }
      // nomes / palavras-chave
      if (NAME0.test(c)) {
        var k = i, name = '';
        while (k < n && NAMEN.test(src[k])) { name += src[k]; k++; }
        push('name', name); i = k; continue;
      }
      // pontuação
      if ('{}[]=,();'.indexOf(c) >= 0) { push('p', c); i++; continue; }
      if (c === '-') { push('p', '-'); i++; continue; }
      i++; // caractere desconhecido: ignora
    }
    push('eof', null);
    return toks;
  }

  // ------------------------------------------------------------------ parser
  function parse(src, env, opts) {
    env = env || {};
    opts = opts || {};
    var warnings = [];
    var toks = tokenize(String(src || ''));
    var pos = 0;
    function peek() { return toks[pos]; }
    function next() { return toks[pos++]; }
    function isP(v) { var tk = toks[pos]; return tk.t === 'p' && tk.v === v; }
    function eat(v) { if (isP(v)) { pos++; return true; } return false; }

    function resolveName(nm) {
      if (nm === 'true') return true;
      if (nm === 'false') return false;
      if (nm === 'nil') return null;
      if (Object.prototype.hasOwnProperty.call(env, nm)) return env[nm];
      warnings.push('símbolo não resolvido: ' + nm);
      return { __unresolved: nm };
    }
    function normKey(k) {
      if (k && typeof k === 'object' && k.__unresolved != null) return k.__unresolved;
      return k; // número ou string (JS coage número p/ chave de objeto)
    }

    function parseValue(depth) {
      depth = depth || 0;
      if (depth > 60) { return null; }
      var tk = peek();
      if (tk.t === 'p' && tk.v === '-') { next(); var v = parseValue(depth + 1); return (typeof v === 'number') ? -v : v; }
      if (tk.t === 'num') { next(); return tk.v; }
      if (tk.t === 'str') { next(); return tk.v; }
      if (tk.t === 'name') { next(); return resolveName(tk.v); }
      if (tk.t === 'p' && tk.v === '{') { return parseTable(depth + 1); }
      if (tk.t === 'p' && tk.v === '(') { next(); var inner = parseValue(depth + 1); eat(')'); return inner; }
      next(); return null; // token inesperado: consome p/ não travar
    }

    function parseTable(depth) {
      eat('{');
      var out = {}, nextIndex = 1, guard = 0;
      while (true) {
        if (++guard > 100000) break;
        var tk = peek();
        if (!tk || tk.t === 'eof') break;
        if (tk.t === 'p' && tk.v === '}') { next(); break; }
        if (tk.t === 'p' && (tk.v === ',' || tk.v === ';')) { next(); continue; }
        if (tk.t === 'p' && tk.v === '[') {                  // [chave] = valor
          next(); var key = parseValue(depth + 1); eat(']'); eat('=');
          out[normKey(key)] = parseValue(depth + 1); continue;
        }
        if (tk.t === 'name' && toks[pos + 1] && toks[pos + 1].t === 'p' && toks[pos + 1].v === '=') {
          var nm = next().v; next();                         // nome = valor
          out[nm] = parseValue(depth + 1); continue;
        }
        out[nextIndex++] = parseValue(depth + 1);            // posicional (array 1-based)
      }
      Object.defineProperty(out, '__table', { value: true, enumerable: false });
      return out;
    }

    function assignPath(path, val) {
      var o = env;
      for (var k = 0; k < path.length - 1; k++) {
        var key = path[k];
        if (typeof o[key] !== 'object' || o[key] === null) o[key] = {};
        o = o[key];
      }
      o[path[path.length - 1]] = val;
    }

    // pula function/if/for/while/do ... end (heurística; os arquivos-alvo quase não têm)
    function skipBlock() {
      var depth = 0, guard = 0;
      while (peek().t !== 'eof') {
        if (++guard > 1000000) break;
        var tk = next();
        if (tk.t === 'name') {
          if (tk.v === 'function' || tk.v === 'if' || tk.v === 'for' || tk.v === 'while' || tk.v === 'do') depth++;
          else if (tk.v === 'end') { depth--; if (depth <= 0) return; }
        }
      }
    }

    var sguard = 0;
    while (peek().t !== 'eof') {
      if (++sguard > 1000000) break;
      var tk = peek();
      if (tk.t === 'name' && tk.v === 'function') { next(); skipBlock(); continue; }
      if (tk.t === 'name' && (tk.v === 'if' || tk.v === 'for' || tk.v === 'while' || tk.v === 'do' || tk.v === 'repeat')) { next(); skipBlock(); continue; }
      if (tk.t === 'name' && tk.v === 'return') { next(); if (peek().t !== 'eof' && !(peek().t === 'name' && peek().v === 'end')) parseValue(0); continue; }
      if (tk.t === 'name' && tk.v === 'local') { next(); continue; } // segue p/ a atribuição
      if (tk.t === 'name') {
        var base = next().v;
        var path = [base];
        var pg = 0;
        while (isP('[') && ++pg < 50) { next(); var ik = parseValue(0); eat(']'); path.push(normKey(ik)); }
        // acesso por ponto Nome.campo (raro nos dados) — trata como string-chave
        while (isP('.')) { next(); if (peek().t === 'name') path.push(next().v); }
        if (isP('=')) {
          next();
          var val = parseValue(0);
          assignPath(path, val);
          eat(';');
          continue;
        }
        // não é atribuição (ex.: chamada de função): ignora o que restar até quebrar
        eat('('); // consome possível '(' de chamada; o resto vira tokens soltos ignorados
        continue;
      }
      next(); // token solto
    }

    return { env: env, warnings: warnings };
  }

  // Converte uma "tabela" (objeto com chaves 1..N) num array JS, se for densa. Senão devolve igual.
  function toArray(tbl) {
    if (!tbl || typeof tbl !== 'object') return tbl;
    var out = [], i = 1;
    while (Object.prototype.hasOwnProperty.call(tbl, i)) { out.push(tbl[i]); i++; }
    return out;
  }

  var api = { parse: parse, tokenize: tokenize, toArray: toArray };
  if (typeof module !== 'undefined' && module.exports) module.exports = api;
  if (typeof window !== 'undefined') window.BRAI_LUA_PARSE = api;
})(typeof globalThis !== 'undefined' ? globalThis : this);
