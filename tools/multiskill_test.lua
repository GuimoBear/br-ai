-- multiskill_test.lua — múltiplas skills padrão por papel.
-- M1: buff-list (offBuff/defBuff são listas; UseOffensiveBuff mantém TODAS) + nível por papel.
-- M2: ataque lista-prioridade (UseAoESkill itera; 1ª utilizável; cai p/ a 2ª).
-- Uso: texlua tools/multiskill_test.lua
local boot = dofile("lua/sim_boot.lua")
local BRAI = boot("lua")
local json, C, SID = BRAI.json, BRAI.const, BRAI.skills.id

local pass, fail = 0, 0
local function check(c, n) if c then pass = pass + 1; print("  ok  - " .. n)
  else fail = fail + 1; print("  FAIL- " .. n) end end
local function disp(m, o) return json.decode(SIM_DISPATCH(m, o and json.encode(o) or "")) end

local function bayeriIdle(cfg)
  return { grid = { w = 40, h = 40 }, dt = 50, homunId = 100, ownerId = 1, config = cfg or {}, entities = {
    { id = 1, kind = "owner", x = 20, y = 20, hp = 1000, maxhp = 1000 },
    { id = 100, kind = "homun", x = 20, y = 20, hp = 9000, maxhp = 9000, sp = 9000, maxsp = 9000, homunType = C.BAYERI },
  } }
end
local function castLevels(steps)
  local seen = {}
  for i = 1, (steps or 12) do local s = disp("step"); if s.intent and s.intent.skill then seen[s.intent.skill] = s.intent.level or true end end
  return seen
end

print("== buff-list: Bayeri mantém os DOIS buffs ofensivos num só nó ==")
disp("setSkillChoice", {})
disp("setTree", { type = "action", name = "UseOffensiveBuff" })
disp("load", bayeriIdle())
local seen = castLevels(12)
check(seen[SID.MH_GOLDENE_FERSE], "UseOffensiveBuff conjura Golden Ferse")
check(seen[SID.MH_ANGRIFFS_MODUS], "UseOffensiveBuff conjura Angriff Modus (mesmo nó)")

print("== offBuffLevel capa o nível de AMBOS os buffs ==")
disp("setSkillChoice", { choices = { ["49"] = { offBuffLevel = 1 } } })
disp("setTree", { type = "action", name = "UseOffensiveBuff" })
disp("load", bayeriIdle())
local seen2 = castLevels(12)
check(seen2[SID.MH_GOLDENE_FERSE] == 1, "Golden Ferse no nível 1 (offBuffLevel)")
check(seen2[SID.MH_ANGRIFFS_MODUS] == 1, "Angriff Modus no nível 1 (offBuffLevel)")
disp("setSkillChoice", {})

print("== escolher uma skill reduz o papel para ela só ==")
disp("setSkillChoice", { choices = { ["49"] = { offBuff = SID.MH_ANGRIFFS_MODUS } } })
disp("setTree", { type = "action", name = "UseOffensiveBuff" })
disp("load", bayeriIdle())
local seen3 = castLevels(12)
check(seen3[SID.MH_ANGRIFFS_MODUS], "escolhido: conjura Angriff Modus")
check(not seen3[SID.MH_GOLDENE_FERSE], "escolhido: NÃO conjura Golden Ferse (lista reduzida a 1)")
disp("setSkillChoice", {})

print("== ataque lista-prioridade: Dieter usa Lava Slide (1a) e cai p/ Blast Forge ==")
local function dieterCluster()
  return { grid = { w = 40, h = 40 }, dt = 50, homunId = 100, ownerId = 1, config = { AutoMobCount = 2 }, entities = {
    { id = 1, kind = "owner", x = 20, y = 20, hp = 1000, maxhp = 1000 },
    { id = 100, kind = "homun", x = 20, y = 20, hp = 9000, maxhp = 9000, sp = 9000, maxsp = 9000, homunType = C.DIETER },
    { id = 200, kind = "monster", x = 22, y = 20, hp = 999999, maxhp = 999999, atkInterval = 100000, aggressive = false },
    { id = 201, kind = "monster", x = 22, y = 21, hp = 999999, maxhp = 999999, atkInterval = 100000, aggressive = false },
    { id = 202, kind = "monster", x = 23, y = 20, hp = 999999, maxhp = 999999, atkInterval = 100000, aggressive = false },
  } }
end
local aoeTree = { type = "sequence", children = {
  { type = "succeeder", child = { type = "action", name = "AcquireTarget" } },
  { type = "action", name = "UseAoESkill" } } }
disp("setSkillChoice", {})
disp("setTree", aoeTree); disp("load", dieterCluster())
local first, seenA = nil, {}
for i = 1, 30 do local s = disp("step")
  if s.intent and (s.intent.skill == SID.MH_LAVA_SLIDE or s.intent.skill == SID.MH_BLAST_FORGE) then
    if not first then first = s.intent.skill end; seenA[s.intent.skill] = true
  end
end
check(first == SID.MH_LAVA_SLIDE, "1a AoE conjurada = Lava Slide (prioridade)")
check(seenA[SID.MH_BLAST_FORGE], "cai p/ Blast Forge quando a 1a esta em recarga (fallback)")

print("== nível POR SKILL: skillLevels rebaixa só aquela skill ==")
disp("setSkillChoice", { choices = { ["51"] = { skillLevels = { [tostring(SID.MH_LAVA_SLIDE)] = 3 } } } })
disp("setTree", aoeTree); disp("load", dieterCluster())
local lv = {}
for i = 1, 30 do local s = disp("step"); if s.intent and s.intent.skill and s.intent.level then lv[s.intent.skill] = s.intent.level end end
check(lv[SID.MH_LAVA_SLIDE] == 3, "Lava Slide no nível 3 (skillLevels)")
check(lv[SID.MH_BLAST_FORGE] == 10, "Blast Forge intacto no nível conhecido (10)")
disp("setSkillChoice", {})

local function roleOf(rc, k) for _, r in ipairs(rc) do if r.key == k then return r end end end
local function vanScen()
  return { grid = { w = 40, h = 40 }, dt = 50, homunId = 100, ownerId = 1, config = {}, entities = {
    { id = 1, kind = "owner", x = 20, y = 20, hp = 1000, maxhp = 1000 },
    { id = 100, kind = "homun", x = 20, y = 20, hp = 9000, maxhp = 9000, sp = 9000, maxsp = 9000, homunType = C.VANILMIRTH },
    { id = 200, kind = "monster", x = 23, y = 20, hp = 999999, maxhp = 999999, atkInterval = 100000, aggressive = false },
  } }
end
local function castsAny(steps)
  for i = 1, (steps or 12) do local s = disp("step"); if s.intent and s.intent.skill then return true end end; return false
end

print("== lista VAZIA = nenhuma skill (override [] nos papéis) ==")
disp("setSkillChoice", { choices = { ["51"] = { aoeAtk = {} } } })
disp("setTree", aoeTree); disp("load", dieterCluster())
check(not castsAny(12), "aoeAtk=[] (Dieter): UseAoESkill NÃO conjura nada")
disp("setSkillChoice", { choices = { ["4"] = { mainAtk = {} } } })
disp("setTree", { type = "sequence", children = { { type = "succeeder", child = { type = "action", name = "AcquireTarget" } }, { type = "action", name = "UseMainSkill" } } })
disp("load", vanScen())
check(not castsAny(8), "mainAtk=[] (Vanilmirth): UseMainSkill NÃO conjura")
disp("setSkillChoice", { choices = { ["49"] = { offBuff = {} } } })
disp("setTree", { type = "action", name = "UseOffensiveBuff" }); disp("load", bayeriIdle())
check(not castsAny(12), "offBuff=[] (Bayeri): UseOffensiveBuff NÃO conjura")
disp("setSkillChoice", { choices = { ["49"] = { defBuff = {} } } })
disp("setTree", { type = "action", name = "UseDefensiveBuff" }); disp("load", bayeriIdle())
check(not castsAny(12), "defBuff=[] (Bayeri): UseDefensiveBuff NÃO conjura")
disp("setSkillChoice", {})

print("== roleConfig.overridden + effective (vazio / lista / padrão) ==")
BRAI.setSkillChoice({ choices = { ["51"] = { aoeAtk = {} } } })
local a0 = roleOf(BRAI.roleConfig(C.DIETER), "aoeAtk")
check(a0.overridden == true and #a0.effective == 0, "aoeAtk=[] → overridden=true, effective vazio")
BRAI.setSkillChoice({ choices = { ["51"] = { aoeAtk = { SID.MH_BLAST_FORGE } } } })
local a1 = roleOf(BRAI.roleConfig(C.DIETER), "aoeAtk")
check(#a1.effective == 1 and a1.effective[1].id == SID.MH_BLAST_FORGE, "aoeAtk=[Blast Forge] → 1 efetiva")
BRAI.setSkillChoice({})
local a2 = roleOf(BRAI.roleConfig(C.DIETER), "aoeAtk")
check(a2.overridden == false and #a2.effective == 2, "sem override → overridden=false, padrão (2)")

print(string.format("RESULTADO: %d ok, %d falhas", pass, fail))
os.exit(fail == 0 and 0 or 1)
