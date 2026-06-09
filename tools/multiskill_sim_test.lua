-- multiskill_sim_test.lua — N6: matriz no SIMULADOR (homúnculo × papel × {0,1,N}).
-- Para cada papel com candidatos: override [] não conjura; [1] conjura; [N] conjura conforme a
-- semântica (ataque = prioridade/1ª utilizável; buff = mantém todas). Roda a árvore real via SIM.
-- Uso: texlua tools/multiskill_sim_test.lua
local boot = dofile("lua/sim_boot.lua")
local BRAI = boot("lua")
local json, C = BRAI.json, BRAI.const

local pass, fail = 0, 0
local function check(c, n) if c then pass = pass + 1; print("  ok  - " .. n)
  else fail = fail + 1; print("  FAIL- " .. n) end end
local function disp(m, o) return json.decode(SIM_DISPATCH(m, o and json.encode(o) or "")) end
local function roleOf(rc, k) for _, r in ipairs(rc) do if r.key == k then return r end end end

local ACTION = { mainAtk = "UseMainSkill", aoeAtk = "UseAoESkill", offBuff = "UseOffensiveBuff", defBuff = "UseDefensiveBuff" }
local function isAttack(role) return role == "mainAtk" or role == "aoeAtk" end

local function scenFor(homun, role)
  local ents = {
    { id = 1, kind = "owner", x = 20, y = 20, hp = 1000, maxhp = 1000 },
    { id = 100, kind = "homun", x = 20, y = 20, hp = 9000, maxhp = 9000, sp = 9000, maxsp = 9000, homunType = homun },
  }
  if role == "mainAtk" then
    ents[#ents + 1] = { id = 200, kind = "monster", x = 21, y = 20, hp = 999999, maxhp = 999999, atkInterval = 100000, aggressive = false }
  elseif role == "aoeAtk" then   -- aglomerado COLADO (dist 1) p/ AoEs de alcance curto (Blast Forge=1) também valerem
    ents[#ents + 1] = { id = 200, kind = "monster", x = 21, y = 20, hp = 999999, maxhp = 999999, atkInterval = 100000, aggressive = false }
    ents[#ents + 1] = { id = 201, kind = "monster", x = 21, y = 21, hp = 999999, maxhp = 999999, atkInterval = 100000, aggressive = false }
    ents[#ents + 1] = { id = 202, kind = "monster", x = 20, y = 21, hp = 999999, maxhp = 999999, atkInterval = 100000, aggressive = false }
  end
  local cfg = (role == "aoeAtk") and { AutoMobCount = 2 } or {}
  return { grid = { w = 40, h = 40 }, dt = 50, homunId = 100, ownerId = 1, config = cfg, entities = ents }
end
local function treeFor(role)
  local act = { type = "action", name = ACTION[role] }
  if isAttack(role) then
    return { type = "sequence", children = { { type = "succeeder", child = { type = "action", name = "AcquireTarget" } }, act } }
  end
  return act
end
-- conjura: conjunto de skills emitidas (override aplicado)
local function castSet(homun, role, override, steps)
  disp("setSkillChoice", { choices = { [tostring(homun)] = { [role] = override } } })
  disp("setTree", treeFor(role)); disp("load", scenFor(homun, role))
  local seen = {}; for i = 1, (steps or 16) do local s = disp("step"); if s.intent and s.intent.skill then seen[s.intent.skill] = true end end
  disp("setSkillChoice", {})
  return seen
end
local function count(t) local n = 0; for _ in pairs(t) do n = n + 1 end; return n end

local MATRIX = {
  { C.VANILMIRTH, "mainAtk" },
  { C.EIRA, "mainAtk" }, { C.EIRA, "aoeAtk" },
  { C.BAYERI, "mainAtk" }, { C.BAYERI, "aoeAtk" }, { C.BAYERI, "offBuff" }, { C.BAYERI, "defBuff" },
  { C.DIETER, "aoeAtk" }, { C.DIETER, "offBuff" }, { C.DIETER, "defBuff" },
}
local HN = { [C.VANILMIRTH] = "Vanilmirth", [C.EIRA] = "Eira", [C.BAYERI] = "Bayeri", [C.DIETER] = "Dieter" }

for _, mc in ipairs(MATRIX) do
  local homun, role = mc[1], mc[2]
  local cands = roleOf(BRAI.roleConfig(homun), role).candidates or {}
  local ids = {}; for _, c in ipairs(cands) do ids[#ids + 1] = c.id end
  local tag = (HN[homun] or homun) .. "/" .. role
  if #ids >= 1 then
    check(count(castSet(homun, role, {})) == 0, tag .. " [0]: NÃO conjura (lista vazia)")
    check(castSet(homun, role, { ids[1] })[ids[1]], tag .. " [1]: conjura a skill única")
    if #ids >= 2 then
      local sN = castSet(homun, role, ids)
      if isAttack(role) then
        check(sN[ids[1]], tag .. " [N]: conjura (prioridade: 1ª da lista)")
      else
        check(sN[ids[1]] and sN[ids[2]], tag .. " [N]: mantém TODAS (buff)")
      end
    end
  end
end

print(string.format("RESULTADO: %d ok, %d falhas", pass, fail))
os.exit(fail == 0 and 0 or 1)
