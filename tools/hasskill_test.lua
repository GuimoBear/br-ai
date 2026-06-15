-- hasskill_test.lua — F2: condição "Possui a skill" (HasSkill) no combobox de percepções.
-- Avalia BRAI.skillsys.learned; negação via 'inverter'. Uso: texlua tools/hasskill_test.lua
local boot = dofile("lua/sim_boot.lua")
local BRAI = boot("lua")
local C, S, bt = BRAI.const, BRAI.status, BRAI.bt
local SID = BRAI.skills.id
local pass, fail = 0, 0
local function check(c, n) if c then pass = pass + 1; print("  ok  - " .. n)
  else fail = fail + 1; print("  FAIL- " .. n) end end
local function eq(a, b, n) check(a == b, n .. " (esperado " .. tostring(b) .. ", obtido " .. tostring(a) .. ")") end

-- mock do cliente: SÓ Blast Forge "aprendida" (GetV(V_SKILLATTACKRANGE)>=0)
BRAI.ro.bind({ GetTick = function() return 0 end, TraceAI = function() end,
  GetV = function(v, id, skill)
    if v == C.V_SKILLATTACKRANGE then return (skill == SID.MH_BLAST_FORGE) and 1 or -1 end
    return -1
  end })

print("== registro e rótulo ==")
check(BRAI.registry.conditions.HasSkill ~= nil, "HasSkill em registry.conditions (aparece no combobox)")
check(BRAI.registry.meta.HasSkill.title == "Possui a skill", "rótulo legível 'Possui a skill'")
check(BRAI.registry.meta.HasSkill.group == "Skills", "grupo 'Skills'")

print("== avaliação ==")
local bb = BRAI.Blackboard.new(); bb.self.id = 100
check(BRAI.registry.conditions.HasSkill(bb, { skill = SID.MH_BLAST_FORGE }) == true, "possui Blast Forge -> true")
check(BRAI.registry.conditions.HasSkill(bb, { skill = SID.MH_LAVA_SLIDE }) == false, "NAO possui Lava Slide -> false")
check(BRAI.registry.conditions.HasSkill(bb, {}) == false, "sem skill definida -> false (neutra)")

print("== na arvore (check + inverter) ==")
local function leaf(st) return bt.node("leaf", "leaf", function() return st end) end
eq(bt.check("HasSkill", { skill = SID.MH_BLAST_FORGE }, leaf(S.SUCCESS)):tick(bb), S.SUCCESS, "tem skill -> executa filho")
eq(bt.check("HasSkill", { skill = SID.MH_LAVA_SLIDE }, leaf(S.SUCCESS)):tick(bb), S.FAILURE, "nao tem -> FAILURE (nao executa)")
-- "NAO possui X" = inverter(check HasSkill X)
eq(bt.inverter(bt.check("HasSkill", { skill = SID.MH_LAVA_SLIDE }, nil)):tick(bb), S.SUCCESS, "inverter: NAO possui Lava Slide -> SUCCESS")
eq(bt.inverter(bt.check("HasSkill", { skill = SID.MH_BLAST_FORGE }, nil)):tick(bb), S.FAILURE, "inverter: possui Blast Forge -> FAILURE")

print(string.format("\nRESULTADO: %d ok, %d falhas", pass, fail))
if fail > 0 then os.exit(1) end
