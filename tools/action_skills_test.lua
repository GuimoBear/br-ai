-- action_skills_test.lua — fonte única das skills por ação (PLANO-SKILLS-NO-NO S0).
-- Cobre BRAI.actionSkills/roleSkillsFor: estados ok/none/missing, multi-skill, papel de perfil
-- (cura/castling) com herança do base, activeId via bb.intent e retrocompat.
-- Uso: texlua tools/action_skills_test.lua
local boot = dofile("lua/sim_boot.lua")
local BRAI = boot("lua")
local C, S = BRAI.const, BRAI.skills.id
local pass, fail = 0, 0
local function check(c, n) if c then pass = pass + 1; print("  ok  - " .. n)
  else fail = fail + 1; print("  FAIL- " .. n) end end
local function bbFor(homun, base, intentSkill)
  return { self = { homunType = homun }, config = { BaseHomunType = base or 0, UseBaseSkills = (base ~= nil and base ~= 0) },
    intent = intentSkill and { kind = "skill", skill = intentSkill } or nil }
end

BRAI.setSkillChoice({ choices = {} })   -- sem override (padrão dos perfis)

-- ===== (1) mapa ação->papel =====
print("== mapa ação->papel ==")
check(BRAI.actionRole.UseAoESkill == "aoeAtk", "UseAoESkill -> aoeAtk")
check(BRAI.actionRole.UseCastling == "castling", "UseCastling -> castling")
check(BRAI.actionSkills(bbFor(C.DIETER), "AcquireTarget") == nil, "ação NÃO de skill -> nil")

-- ===== (2) Dieter AoE: 2 skills padrão (Lava Slide + Blast Forge), estado ok =====
print("== Dieter AoE (multi-skill) ==")
local aoe = BRAI.actionSkills(bbFor(C.DIETER), "UseAoESkill")
check(aoe and aoe.state == "ok", "Dieter AoE: estado ok")
check(aoe and #aoe.skills == 2, "Dieter AoE: 2 skills (multi-linha)")
check(aoe and aoe.skills[1].id == S.MH_LAVA_SLIDE and aoe.skills[2].id == S.MH_BLAST_FORGE, "Dieter AoE: Lava Slide + Blast Forge na ordem do perfil")

-- ===== (3) Dieter ataque principal: papel NÃO existe -> missing =====
print("== Dieter mainAtk (missing) ==")
local mn = BRAI.actionSkills(bbFor(C.DIETER), "UseMainSkill")
check(mn and mn.state == "missing" and #mn.skills == 0, "Dieter UseMainSkill: missing (tipo não tem o papel)")

-- ===== (4) override esvaziando o papel: tem candidatos, nada selecionado -> none =====
print("== AoE esvaziada (none) ==")
BRAI.setSkillChoice({ choices = { [tostring(C.DIETER)] = { aoeAtk = {} } } })
local em = BRAI.actionSkills(bbFor(C.DIETER), "UseAoESkill")
check(em and em.state == "none" and #em.skills == 0, "Dieter AoE esvaziada: none (tem candidatos, nada selecionado)")
-- override de 1 skill só: ok com 1
BRAI.setSkillChoice({ choices = { [tostring(C.DIETER)] = { aoeAtk = { S.MH_BLAST_FORGE } } } })
local one = BRAI.actionSkills(bbFor(C.DIETER), "UseAoESkill")
check(one and one.state == "ok" and #one.skills == 1 and one.skills[1].id == S.MH_BLAST_FORGE, "Dieter AoE só Blast Forge: ok, 1 skill")
BRAI.setSkillChoice({ choices = {} })

-- ===== (5) papéis de perfil (cura/castling): ok vs missing =====
print("== papéis de perfil (cura/castling) ==")
check(BRAI.actionSkills(bbFor(C.LIF), "UseHealOwner").state == "ok", "Lif cura do dono: ok")
check(BRAI.actionSkills(bbFor(C.FILIR), "UseHealOwner").state == "missing", "Filir cura do dono: missing (não cura)")
check(BRAI.actionSkills(bbFor(C.AMISTR), "UseCastling").state == "ok", "Amistr castling: ok")
check(BRAI.actionSkills(bbFor(C.FILIR), "UseCastling").state == "missing", "Filir castling: missing")

-- ===== (6) Homun S herda cura/castling do tipo base =====
print("== herança do base (Homun S) ==")
-- Homun S sem castling próprio nem no base -> missing; com base que tem (Amistr) -> ok:
check(BRAI.actionSkills(bbFor(C.DIETER, C.AMISTR), "UseCastling").state == "base", "Dieter+base Amistr: castling herdado (estado via base)")
check(BRAI.actionSkills(bbFor(C.DIETER), "UseCastling").state == "missing", "Dieter sem base: castling missing")

-- ===== (7) activeId: skill disparada no tick acende =====
print("== activeId (destaque ao vivo) ==")
local act = BRAI.actionSkills(bbFor(C.DIETER, 0, S.MH_BLAST_FORGE), "UseAoESkill")
check(act and act.activeId == S.MH_BLAST_FORGE, "activeId casa bb.intent.skill (Blast Forge)")
local noact = BRAI.actionSkills(bbFor(C.DIETER), "UseAoESkill")
check(noact and noact.activeId == nil, "sem intent -> activeId nil")

-- ===== (8) roleSkillsFor direto =====
print("== roleSkillsFor ==")
local rs = BRAI.roleSkillsFor(C.DIETER, 0, "offBuff")
check(#rs == 1 and rs[1].id == S.MH_PYROCLASTIC, "roleSkillsFor Dieter offBuff = Pyroclastic")
check(#BRAI.roleSkillsFor(C.DIETER, 0, "mainAtk") == 0, "roleSkillsFor Dieter mainAtk vazio")

-- ===== (9) feature "usar skills da base": estado 'base' + fromBase + opt-in =====
print("== usar skills da base (opt-in) ==")
local sb = BRAI.actionSkills(bbFor(C.SERA, C.VANILMIRTH), "UseHealOwner")
check(sb and sb.state == "base" and sb.fromBase == true, "Sera+base Vanil cura: estado 'base' (via base)")
check(sb and #sb.skills == 1 and sb.skills[1].id == S.HVAN_CHAOTIC and sb.skills[1].fromBase, "Sera+base: cura = Chaotic marcada fromBase")
local sboff = BRAI.actionSkills({ self = { homunType = C.SERA }, config = { BaseHomunType = C.VANILMIRTH, UseBaseSkills = false } }, "UseHealOwner")
check(sboff and sboff.state == "missing", "Sera+base com flag OFF: cura missing (opt-in)")
local edef = BRAI.actionSkills(bbFor(C.ELEANOR, C.FILIR), "UseDefensiveBuff")
check(edef and edef.state == "base" and edef.skills[1].id == S.HFLI_SPEED, "Eleanor+base Filir defBuff: via base (Accelerated Flight)")
local eoff = BRAI.actionSkills(bbFor(C.EIRA, C.LIF), "UseOffensiveBuff")
check(eoff and eoff.state == "ok" and eoff.fromBase == false, "Eira+base: offBuff proprio (ok, nao via base)")

print(string.format("RESULTADO: %d ok, %d falhas", pass, fail))
if fail > 0 then os.exit(1) end
