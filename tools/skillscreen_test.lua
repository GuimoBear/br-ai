-- skillscreen_test.lua — F1: roleConfig enriquecido (4 papéis sempre + desc + nível) e o fio nível→cast.
-- Uso: texlua tools/skillscreen_test.lua
local boot = dofile("lua/sim_boot.lua")
local BRAI = boot("lua")
local json, C, SID = BRAI.json, BRAI.const, BRAI.skills.id

local pass, fail = 0, 0
local function check(c, n) if c then pass = pass + 1; print("  ok  - " .. n)
  else fail = fail + 1; print("  FAIL- " .. n) end end
local function disp(m, o) return json.decode(SIM_DISPATCH(m, o and json.encode(o) or "")) end
local function roleOf(rc, key) for _, r in ipairs(rc) do if r.key == key then return r end end end

print("== roleConfig: sempre os 4 papéis ==")
BRAI.setSkillChoice({})   -- limpa qualquer escolha
local rc = BRAI.roleConfig(C.DIETER)
check(#rc == 4, "Dieter: 4 papéis (#" .. #rc .. ")")
local keys = {}; for _, r in ipairs(rc) do keys[r.key] = true end
check(keys.mainAtk and keys.aoeAtk and keys.offBuff and keys.defBuff, "papéis: mainAtk/aoeAtk/offBuff/defBuff")
for _, t in ipairs({ C.LIF, C.AMISTR, C.FILIR, C.VANILMIRTH, C.EIRA, C.BAYERI, C.ELEANOR, C.SERA }) do
  check(#BRAI.roleConfig(t) == 4, "tipo " .. t .. ": 4 papéis")
end

print("== papel sem skill → candidatos vazios ==")
check(#roleOf(rc, "mainAtk").candidates == 0, "Dieter mainAtk: sem candidatos (papel vazio)")
check(#roleOf(BRAI.roleConfig(C.ELEANOR), "aoeAtk").candidates == 0, "Eleanor aoeAtk: sem candidatos")

print("== candidatos: desc + maxLevel + effectiveMaxLevel + defaults ==")
local aoe = roleOf(rc, "aoeAtk")
check(#aoe.candidates >= 2, "Dieter aoeAtk: 2+ candidatos (#" .. #aoe.candidates .. ")")
check(aoe.candidates[1].desc ~= "" and aoe.candidates[1].maxLevel and aoe.candidates[1].maxLevel > 0, "candidato traz desc + maxLevel")
check(aoe.effectiveMaxLevel and aoe.effectiveMaxLevel > 0, "papel traz effectiveMaxLevel (" .. tostring(aoe.effectiveMaxLevel) .. ")")
check(#aoe.defaultIds >= 1 and aoe.defaultDescs[1] ~= "", "aoeAtk: defaultIds + defaultDescs do perfil")

print("== escolha + nível salvos refletem no roleConfig ==")
BRAI.setSkillChoice({ choices = { ["51"] = { aoeAtk = SID.MH_BLAST_FORGE, aoeAtkLevel = 3 } } })
local aoe2 = roleOf(BRAI.roleConfig(C.DIETER), "aoeAtk")
check(aoe2.chosen == SID.MH_BLAST_FORGE, "chosen reflete a escolha (Blast Forge)")
check(aoe2.level == 3, "level reflete o nível salvo (3)")

print("== fio dado→capRole→ação: aoeAtkLevel rebaixa o cast ==")
local cluster = {
  { id = 1, kind = "owner", x = 20, y = 20, hp = 1000, maxhp = 1000 },
  { id = 100, kind = "homun", x = 20, y = 20, hp = 9000, maxhp = 9000, sp = 9000, maxsp = 9000, homunType = C.DIETER },
  { id = 200, kind = "monster", x = 22, y = 20, hp = 9000, maxhp = 9000, atkInterval = 100000, aggressive = false },
  { id = 201, kind = "monster", x = 22, y = 21, hp = 9000, maxhp = 9000, atkInterval = 100000, aggressive = false },
  { id = 202, kind = "monster", x = 23, y = 20, hp = 9000, maxhp = 9000, atkInterval = 100000, aggressive = false },
}
disp("setSkillChoice", { choices = { ["51"] = { aoeAtkLevel = 3 } } })   -- só o nível (skill = padrão Lava Slide)
disp("setTree", { type = "sequence", children = {
  { type = "succeeder", child = { type = "action", name = "AcquireTarget" } },
  { type = "action", name = "UseAoESkill" },
} })
disp("load", { grid = { w = 40, h = 40 }, dt = 50, homunId = 100, ownerId = 1, config = { AutoMobCount = 2 }, entities = cluster })
local lvl = nil; for i = 1, 4 do local s = disp("step"); if s.intent and s.intent.skill and s.intent.level then lvl = s.intent.level; break end end
check(lvl == 3, "aoeAtkLevel=3: AoE conjurada no nível 3 (lvl=" .. tostring(lvl) .. ")")
disp("setSkillChoice", {})   -- limpa p/ não vazar p/ outros testes

print("== M4: roleConfig.effective (lista ativa + nível por skill) ==")
BRAI.setSkillChoice({})
local aoeD = roleOf(BRAI.roleConfig(C.DIETER), "aoeAtk")
check(#aoeD.effective == 2, "Dieter aoeAtk: 2 skills efetivas (#" .. #aoeD.effective .. ")")
check(aoeD.effective[1].maxLevel and aoeD.effective[1].level == 0, "skill efetiva traz maxLevel e level (0=padrão)")
BRAI.setSkillChoice({ choices = { ["51"] = { skillLevels = { [tostring(SID.MH_LAVA_SLIDE)] = 3 } } } })
local aoeD2 = roleOf(BRAI.roleConfig(C.DIETER), "aoeAtk")
local lavaEff; for _, e in ipairs(aoeD2.effective) do if e.id == SID.MH_LAVA_SLIDE then lavaEff = e end end
check(lavaEff and lavaEff.level == 3, "effective reflete skillLevels (Lava Slide nível 3)")
BRAI.setSkillChoice({ choices = { ["51"] = { aoeAtk = { SID.MH_BLAST_FORGE } } } })
local aoeD3 = roleOf(BRAI.roleConfig(C.DIETER), "aoeAtk")
check(#aoeD3.effective == 1 and aoeD3.effective[1].id == SID.MH_BLAST_FORGE, "override por lista: efetiva = {Blast Forge}")
check(#roleOf(BRAI.roleConfig(C.VANILMIRTH), "mainAtk").effective == 1, "Vanilmirth mainAtk: 1 skill efetiva")
BRAI.setSkillChoice({})

print(string.format("RESULTADO: %d ok, %d falhas", pass, fail))
os.exit(fail == 0 and 0 or 1)
