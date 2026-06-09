-- allskills_test.lua — BRAI.allSkillChoices: exporta a escolha EFETIVA por papel p/ os 9
-- homuns (auto-descritivo no pacote). Bate com roleConfig.effective; preserva overrides
-- (incl. vazio); round-trip pelo skill_choice. [PLANO-GERACAO-LUA #3]
-- Uso: texlua tools/allskills_test.lua
local boot = dofile("lua/sim_boot.lua")
local BRAI = boot("lua")
local C, S = BRAI.const, BRAI.skills.id
local pass, fail = 0, 0
local function check(c, n) if c then pass = pass + 1; print("  ok  - " .. n)
  else fail = fail + 1; print("  FAIL- " .. n) end end
local function sz(t) local n = 0; for _ in pairs(t) do n = n + 1 end; return n end
local function sameList(a, b) a = a or {}; b = b or {}; if #a ~= #b then return false end
  for i = 1, #a do if a[i] ~= b[i] then return false end end; return true end
local function effIds(rc, key)
  for _, r in ipairs(rc) do if r.key == key then local o = {}; for _, e in ipairs(r.effective) do o[#o + 1] = e.id end; return o end end
  return {} end

local TYPES = { C.LIF, C.AMISTR, C.FILIR, C.VANILMIRTH, C.EIRA, C.BAYERI, C.SERA, C.DIETER, C.ELEANOR }

print("== BRAI.allSkillChoices ==")

-- 1) cobre os 9 homuns
local all = BRAI.allSkillChoices({})
check(sz(all) == 9, "cobre os 9 homuns")

-- 2) cada papel efetivo (nao-vazio) bate com roleConfig.effective
local okAll = true
for _, t in ipairs(TYPES) do
  local rc = BRAI.roleConfig(t)
  local e = all[tostring(t)] or {}
  for _, key in ipairs({ "mainAtk", "aoeAtk", "offBuff", "defBuff" }) do
    local exp = effIds(rc, key)
    if #exp > 0 and not sameList(e[key], exp) then okAll = false; print("    mismatch tipo " .. t .. " papel " .. key) end
  end
end
check(okAll, "cada papel efetivo == roleConfig.effective (os 9 homuns)")

-- 3) Dieter: aoeAtk = {Lava Slide, Blast Forge}; mainAtk omitido (papel vazio)
local D = all[tostring(C.DIETER)]
check(sameList(D.aoeAtk, { S.MH_LAVA_SLIDE, S.MH_BLAST_FORGE }), "Dieter aoeAtk = {Lava Slide, Blast Forge}")
check(D.mainAtk == nil, "Dieter sem mainAtk (papel vazio omitido)")

-- 4) Lif/Amistr (sem ataque): mainAtk e aoeAtk omitidos; buffs presentes
check(all[tostring(C.LIF)].mainAtk == nil and all[tostring(C.LIF)].aoeAtk == nil, "Lif: ataques omitidos")
check(all[tostring(C.LIF)].offBuff ~= nil and all[tostring(C.LIF)].defBuff ~= nil, "Lif: offBuff/defBuff presentes")

-- 5) override reflete; demais homuns seguem default
local ov = BRAI.allSkillChoices({ choices = { [tostring(C.DIETER)] = { aoeAtk = { S.MH_BLAST_FORGE } } } })
check(sameList(ov[tostring(C.DIETER)].aoeAtk, { S.MH_BLAST_FORGE }), "override Dieter aoeAtk=[Blast Forge] reflete")
check(sameList(ov[tostring(C.BAYERI)].mainAtk, { S.MH_STAHL_HORN }), "demais seguem default (Bayeri Stahl Horn)")

-- 6) override VAZIO preservado (papel esvaziado de proposito)
local ov2 = BRAI.allSkillChoices({ choices = { [tostring(C.DIETER)] = { aoeAtk = {} } } })
check(ov2[tostring(C.DIETER)].aoeAtk ~= nil and #ov2[tostring(C.DIETER)].aoeAtk == 0, "override vazio (Dieter aoeAtk=[]) preservado")

-- 7) round-trip: setSkillChoice(all) -> allSkillChoices() reproduz as listas efetivas
BRAI.setSkillChoice({ choices = all })
local all2 = BRAI.allSkillChoices()
check(sameList(all2[tostring(C.DIETER)].aoeAtk, all[tostring(C.DIETER)].aoeAtk), "round-trip: Dieter aoeAtk estavel")
check(sameList(all2[tostring(C.BAYERI)].offBuff, all[tostring(C.BAYERI)].offBuff), "round-trip: Bayeri offBuff estavel")
check(sameList(all2[tostring(C.BAYERI)].mainAtk, all[tostring(C.BAYERI)].mainAtk), "round-trip: Bayeri mainAtk estavel")

print(string.format("\nRESULTADO: %d ok, %d falhas", pass, fail))
if fail > 0 then os.exit(1) end
