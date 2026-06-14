-- base_skills_flag_test.lua — feature "usar skills da base" (opt-in) no MOTOR.
-- Verifica BRAI.effectiveProfile / BRAI.profileFor: flag off ignora a base; flag on faz
-- fallback (S prioritario) com off/def ESTRITO (nao soma). Uso: texlua tools/base_skills_flag_test.lua
local boot = dofile("lua/sim_boot.lua")
local BRAI = boot("lua")
local C = BRAI.const
local SID = BRAI.skills.id
local pass, fail = 0, 0
local function check(c, n) if c then pass = pass + 1; print("  ok  - " .. n)
  else fail = fail + 1; print("  FAIL- " .. n) end end
local function eff(s, b, ub) return BRAI.effectiveProfile(s, b, ub) end

print("== flag OFF: base ignorada ==")
local m = eff(C.SERA, C.VANILMIRTH, false)
check(m.healOwnerSkill == nil, "OFF: Sera base Vanil NAO herda cura")
check(#m.offBuff == 0 and #m.defBuff == 0, "OFF: sem buffs herdados da base")
check(m.mainAtk == SID.MH_NEEDLE_OF_PARALYZE, "OFF: mainAtk do proprio S intacto")

print("== flag ON: fallback single (exemplo do usuario) ==")
m = eff(C.SERA, C.VANILMIRTH, true)
check(m.healOwnerSkill == SID.HVAN_CHAOTIC, "ON: Sera base Vanil herda cura no dono (Chaotic)")
check(m.mainAtk == SID.MH_NEEDLE_OF_PARALYZE, "ON: S prioritario mantem o proprio mainAtk")
check(m.ownerBuff == SID.MH_PAIN_KILLER, "ON: ownerBuff do proprio S preservado")

print("== flag ON: off/def fallback ESTRITO (nao soma) ==")
m = eff(C.EIRA, C.LIF, true)
check(#m.offBuff == 1 and m.offBuff[1] == SID.MH_OVERED_BOOST, "ON: Eira mantem SO o proprio offBuff (base nao soma)")
check(#m.defBuff == 1 and m.defBuff[1] == SID.HLIF_AVOID, "ON: Eira (sem defBuff) HERDA o da base (Lif)")
m = eff(C.ELEANOR, C.FILIR, true)
check(#m.offBuff == 1 and m.offBuff[1] == SID.HFLI_FLEET, "ON: Eleanor herda offBuff (Flitting) da base Filir")
check(#m.defBuff == 1 and m.defBuff[1] == SID.HFLI_SPEED, "ON: Eleanor herda defBuff (Accelerated Flight) da base Filir")

print("== profileFor le a flag do bb.config ==")
local function pf(ub, withKey)
  local cfg = { BaseHomunType = C.VANILMIRTH }
  if withKey then cfg.UseBaseSkills = ub end
  return BRAI.profileFor({ self = { homunType = C.SERA }, config = cfg })
end
check(pf(true, true).healOwnerSkill == SID.HVAN_CHAOTIC, "profileFor UseBaseSkills=true herda cura")
check(pf(false, true).healOwnerSkill == nil, "profileFor UseBaseSkills=false NAO herda")
check(pf(nil, false).healOwnerSkill == nil, "profileFor SEM a flag = opt-in OFF (default)")

print(string.format("\nRESULTADO: %d ok, %d falhas", pass, fail))
if fail > 0 then os.exit(1) end
