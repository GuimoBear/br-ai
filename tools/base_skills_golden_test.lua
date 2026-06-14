-- base_skills_golden_test.lua — GOLDEN de regressao da resolucao de perfil efetivo
-- (BRAI.profileFor) na matriz Homunculus-S x base x papel x flag UseBaseSkills.
-- Rede de seguranca da feature "usar skills da base": qualquer mudanca no merge S+base
-- aparece como DIFF aqui. Atualize o EXPECTED de proposito se a politica mudar.
-- Politica travada: opt-in (flag off => sem base); S prioritario; off/def fallback ESTRITO.
-- Uso: texlua tools/base_skills_golden_test.lua
local boot = dofile("lua/sim_boot.lua")
local BRAI = boot("lua")
local C = BRAI.const
local pass, fail = 0, 0
local function check(c, n) if c then pass = pass + 1 else fail = fail + 1; print("  FAIL- " .. n) end end

local function val(v)
  if type(v) == "table" then local o = {} for _, x in ipairs(v) do o[#o + 1] = tostring(x) end return "[" .. table.concat(o, ",") .. "]" end
  return v and tostring(v) or "-"
end

local EXPECTED = [==[
ub=off Eira/none: main=8024 aoe=8025 off=[8023] def=[] owner=- healO=8026 healS=- cast=- sum=- combo=- style=- dbuff=-
ub=off Eira/Lif: main=8024 aoe=8025 off=[8023] def=[] owner=- healO=8026 healS=- cast=- sum=- combo=- style=- dbuff=-
ub=off Eira/Amistr: main=8024 aoe=8025 off=[8023] def=[] owner=- healO=8026 healS=- cast=- sum=- combo=- style=- dbuff=-
ub=off Eira/Filir: main=8024 aoe=8025 off=[8023] def=[] owner=- healO=8026 healS=- cast=- sum=- combo=- style=- dbuff=-
ub=off Eira/Vanil: main=8024 aoe=8025 off=[8023] def=[] owner=- healO=8026 healS=- cast=- sum=- combo=- style=- dbuff=-
ub=off Bayeri/none: main=8031 aoe=8034 off=[8032,8035] def=[8033] owner=8058 healO=- healS=- cast=- sum=- combo=- style=- dbuff=-
ub=off Bayeri/Lif: main=8031 aoe=8034 off=[8032,8035] def=[8033] owner=8058 healO=- healS=- cast=- sum=- combo=- style=- dbuff=-
ub=off Bayeri/Amistr: main=8031 aoe=8034 off=[8032,8035] def=[8033] owner=8058 healO=- healS=- cast=- sum=- combo=- style=- dbuff=-
ub=off Bayeri/Filir: main=8031 aoe=8034 off=[8032,8035] def=[8033] owner=8058 healO=- healS=- cast=- sum=- combo=- style=- dbuff=-
ub=off Bayeri/Vanil: main=8031 aoe=8034 off=[8032,8035] def=[8033] owner=8058 healO=- healS=- cast=- sum=- combo=- style=- dbuff=-
ub=off Sera/none: main=8019 aoe=8020 off=[] def=[] owner=8021 healO=- healS=- cast=- sum=8018 combo=- style=- dbuff=-
ub=off Sera/Lif: main=8019 aoe=8020 off=[] def=[] owner=8021 healO=- healS=- cast=- sum=8018 combo=- style=- dbuff=-
ub=off Sera/Amistr: main=8019 aoe=8020 off=[] def=[] owner=8021 healO=- healS=- cast=- sum=8018 combo=- style=- dbuff=-
ub=off Sera/Filir: main=8019 aoe=8020 off=[] def=[] owner=8021 healO=- healS=- cast=- sum=8018 combo=- style=- dbuff=-
ub=off Sera/Vanil: main=8019 aoe=8020 off=[] def=[] owner=8021 healO=- healS=- cast=- sum=8018 combo=- style=- dbuff=-
ub=off Dieter/none: main=- aoe=[8041,8044] off=[8042] def=[8040] owner=- healO=- healS=- cast=- sum=- combo=- style=- dbuff=8043
ub=off Dieter/Lif: main=- aoe=[8041,8044] off=[8042] def=[8040] owner=- healO=- healS=- cast=- sum=- combo=- style=- dbuff=8043
ub=off Dieter/Amistr: main=- aoe=[8041,8044] off=[8042] def=[8040] owner=- healO=- healS=- cast=- sum=- combo=- style=- dbuff=8043
ub=off Dieter/Filir: main=- aoe=[8041,8044] off=[8042] def=[8040] owner=- healO=- healS=- cast=- sum=- combo=- style=- dbuff=8043
ub=off Dieter/Vanil: main=- aoe=[8041,8044] off=[8042] def=[8040] owner=- healO=- healS=- cast=- sum=- combo=- style=- dbuff=8043
ub=off Eleanor/none: main=8028 aoe=- off=[] def=[] owner=- healO=- healS=- cast=- sum=- combo=[8028,8029,8030] style=8027 dbuff=-
ub=off Eleanor/Lif: main=8028 aoe=- off=[] def=[] owner=- healO=- healS=- cast=- sum=- combo=[8028,8029,8030] style=8027 dbuff=-
ub=off Eleanor/Amistr: main=8028 aoe=- off=[] def=[] owner=- healO=- healS=- cast=- sum=- combo=[8028,8029,8030] style=8027 dbuff=-
ub=off Eleanor/Filir: main=8028 aoe=- off=[] def=[] owner=- healO=- healS=- cast=- sum=- combo=[8028,8029,8030] style=8027 dbuff=-
ub=off Eleanor/Vanil: main=8028 aoe=- off=[] def=[] owner=- healO=- healS=- cast=- sum=- combo=[8028,8029,8030] style=8027 dbuff=-
ub=on Eira/none: main=8024 aoe=8025 off=[8023] def=[] owner=- healO=8026 healS=- cast=- sum=- combo=- style=- dbuff=-
ub=on Eira/Lif: main=8024 aoe=8025 off=[8023] def=[8002] owner=- healO=8026 healS=- cast=- sum=- combo=- style=- dbuff=-
ub=on Eira/Amistr: main=8024 aoe=8025 off=[8023] def=[8006] owner=- healO=8026 healS=- cast=8005 sum=- combo=- style=- dbuff=-
ub=on Eira/Filir: main=8024 aoe=8025 off=[8023] def=[8011] owner=- healO=8026 healS=- cast=- sum=- combo=- style=- dbuff=-
ub=on Eira/Vanil: main=8024 aoe=8025 off=[8023] def=[] owner=- healO=8026 healS=8014 cast=- sum=- combo=- style=- dbuff=-
ub=on Bayeri/none: main=8031 aoe=8034 off=[8032,8035] def=[8033] owner=8058 healO=- healS=- cast=- sum=- combo=- style=- dbuff=-
ub=on Bayeri/Lif: main=8031 aoe=8034 off=[8032,8035] def=[8033] owner=8058 healO=8001 healS=- cast=- sum=- combo=- style=- dbuff=-
ub=on Bayeri/Amistr: main=8031 aoe=8034 off=[8032,8035] def=[8033] owner=8058 healO=- healS=- cast=8005 sum=- combo=- style=- dbuff=-
ub=on Bayeri/Filir: main=8031 aoe=8034 off=[8032,8035] def=[8033] owner=8058 healO=- healS=- cast=- sum=- combo=- style=- dbuff=-
ub=on Bayeri/Vanil: main=8031 aoe=8034 off=[8032,8035] def=[8033] owner=8058 healO=8014 healS=8014 cast=- sum=- combo=- style=- dbuff=-
ub=on Sera/none: main=8019 aoe=8020 off=[] def=[] owner=8021 healO=- healS=- cast=- sum=8018 combo=- style=- dbuff=-
ub=on Sera/Lif: main=8019 aoe=8020 off=[8004] def=[8002] owner=8021 healO=8001 healS=- cast=- sum=8018 combo=- style=- dbuff=-
ub=on Sera/Amistr: main=8019 aoe=8020 off=[8008] def=[8006] owner=8021 healO=- healS=- cast=8005 sum=8018 combo=- style=- dbuff=-
ub=on Sera/Filir: main=8019 aoe=8020 off=[8010] def=[8011] owner=8021 healO=- healS=- cast=- sum=8018 combo=- style=- dbuff=-
ub=on Sera/Vanil: main=8019 aoe=8020 off=[] def=[] owner=8021 healO=8014 healS=8014 cast=- sum=8018 combo=- style=- dbuff=-
ub=on Dieter/none: main=- aoe=[8041,8044] off=[8042] def=[8040] owner=- healO=- healS=- cast=- sum=- combo=- style=- dbuff=8043
ub=on Dieter/Lif: main=- aoe=[8041,8044] off=[8042] def=[8040] owner=- healO=8001 healS=- cast=- sum=- combo=- style=- dbuff=8043
ub=on Dieter/Amistr: main=- aoe=[8041,8044] off=[8042] def=[8040] owner=- healO=- healS=- cast=8005 sum=- combo=- style=- dbuff=8043
ub=on Dieter/Filir: main=8009 aoe=[8041,8044] off=[8042] def=[8040] owner=- healO=- healS=- cast=- sum=- combo=- style=- dbuff=8043
ub=on Dieter/Vanil: main=8013 aoe=[8041,8044] off=[8042] def=[8040] owner=- healO=8014 healS=8014 cast=- sum=- combo=- style=- dbuff=8043
ub=on Eleanor/none: main=8028 aoe=- off=[] def=[] owner=- healO=- healS=- cast=- sum=- combo=[8028,8029,8030] style=8027 dbuff=-
ub=on Eleanor/Lif: main=8028 aoe=- off=[8004] def=[8002] owner=- healO=8001 healS=- cast=- sum=- combo=[8028,8029,8030] style=8027 dbuff=-
ub=on Eleanor/Amistr: main=8028 aoe=- off=[8008] def=[8006] owner=- healO=- healS=- cast=8005 sum=- combo=[8028,8029,8030] style=8027 dbuff=-
ub=on Eleanor/Filir: main=8028 aoe=- off=[8010] def=[8011] owner=- healO=- healS=- cast=- sum=- combo=[8028,8029,8030] style=8027 dbuff=-
ub=on Eleanor/Vanil: main=8028 aoe=- off=[] def=[] owner=- healO=8014 healS=8014 cast=- sum=- combo=[8028,8029,8030] style=8027 dbuff=-
]==]
local exp = {}
for line in EXPECTED:gmatch("[^\n]+") do exp[#exp + 1] = line end

local S = { {C.EIRA,"Eira"},{C.BAYERI,"Bayeri"},{C.SERA,"Sera"},{C.DIETER,"Dieter"},{C.ELEANOR,"Eleanor"} }
local B = { {0,"none"},{C.LIF,"Lif"},{C.AMISTR,"Amistr"},{C.FILIR,"Filir"},{C.VANILMIRTH,"Vanil"} }
local got = {}
for _, ub in ipairs({ false, true }) do
  for _, s in ipairs(S) do for _, b in ipairs(B) do
    local bb = { self = { homunType = s[1] }, config = { BaseHomunType = b[1], UseBaseSkills = ub } }
    local m = BRAI.profileFor(bb)
    got[#got + 1] = string.format("ub=%s %s/%s: main=%s aoe=%s off=%s def=%s owner=%s healO=%s healS=%s cast=%s sum=%s combo=%s style=%s dbuff=%s",
      ub and "on" or "off", s[2], b[2], val(m.mainAtk), val(m.aoeAtk), val(m.offBuff), val(m.defBuff),
      val(m.ownerBuff), val(m.healOwnerSkill), val(m.healSelfSkill), val(m.castling),
      val(m.summon), val(m.combo), val(m.styleChange), val(m.debuffAoE))
  end end
end

print("== GOLDEN base-skills: matriz S x base x papel x flag ==")
check(#got == #exp, "linhas esperadas (" .. #exp .. ") vs obtidas (" .. #got .. ")")
for i = 1, math.max(#got, #exp) do
  if got[i] ~= exp[i] then
    check(false, "linha " .. i)
    print("    exp: " .. tostring(exp[i]))
    print("    got: " .. tostring(got[i]))
  else
    check(true, exp[i])
  end
end

print(string.format("\nRESULTADO: %d ok, %d falhas", pass, fail))
if fail > 0 then os.exit(1) end
