-- combo_choice_test.lua — F3: padrão de combo no homun_skills.json (comboChoiceFor),
-- comboInfo mesclando o padrão, e a precedência param-do-nó > padrão > config no UseEleanorOffense.
-- Uso: texlua tools/combo_choice_test.lua
local boot = dofile("lua/sim_boot.lua")
local BRAI = boot("lua")
local json, C, SID = BRAI.json, BRAI.const, BRAI.skills.id

local pass, fail = 0, 0
local function check(c, n) if c then pass = pass + 1; print("  ok  - " .. n)
  else fail = fail + 1; print("  FAIL- " .. n) end end
local function disp(m, o) return json.decode(SIM_DISPATCH(m, o and json.encode(o) or "")) end

print("== setSkillChoice: parse/validação do bloco combo ==")
BRAI.setSkillChoice({ choices = { ["52"] = { combo = {
  style = "grapple", window = 3000, comboSpheres = 7, grappleThreatLimit = 2,
  minGap = 100, allowStyleSwitch = false, levels = { power = { 5, 4, 3 }, grapple = { 2, 2, 2 } } } } } })
local cc = BRAI.comboChoiceFor(52)
check(cc.style == "grapple", "style=grapple")
check(cc.window == 3000, "window=3000")
check(cc.comboSpheres == 7, "comboSpheres=7")
check(cc.grappleThreatLimit == 2, "grappleThreatLimit=2")
check(cc.minGap == 100, "minGap=100")
check(cc.allowStyleSwitch == false, "allowStyleSwitch=false")
check(cc.levels and cc.levels.power[1] == 5 and cc.levels.grapple[3] == 2, "levels por elo")

print("== valores inválidos são ignorados ==")
BRAI.setSkillChoice({ choices = { ["52"] = { combo = { style = "xyz", window = -5, comboSpheres = 99 } } } })
local bad = BRAI.comboChoiceFor(52)
check(bad.style == nil, "style inválido ignorado")
check(bad.window == nil, "window negativo ignorado")
check(bad.comboSpheres == nil, "comboSpheres fora de 0..10 ignorado")

print("== comboInfo mescla o padrão salvo ==")
BRAI.setSkillChoice({ choices = { ["52"] = { combo = { style = "grapple", window = 2500, comboSpheres = 8, levels = { power = { 5, 5, 5 } } } } } })
local ci = BRAI.comboInfo()
check(ci.defaults.style == "grapple", "comboInfo.defaults.style mesclado")
check(ci.defaults.window == 2500, "comboInfo.defaults.window mesclado")
check(ci.defaults.autoComboSpheres == 8, "comboSpheres → autoComboSpheres (UI)")
check(ci.savedLevels and ci.savedLevels.power[1] == 5, "comboInfo.savedLevels exposto")

print("== precedência: nó > padrão > config (via Style Change) ==")
local function eleScen(cfg)
  return { grid = { w = 40, h = 40 }, dt = 50, homunId = 100, ownerId = 1, config = cfg or {}, entities = {
    { id = 1, kind = "owner", x = 20, y = 20, hp = 1000, maxhp = 1000 },
    { id = 100, kind = "homun", x = 20, y = 20, hp = 9000, maxhp = 9000, sp = 9000, maxsp = 9000, homunType = C.ELEANOR },
    { id = 200, kind = "monster", x = 21, y = 20, hp = 100000, maxhp = 100000, atkInterval = 100000, aggressive = false },
  } }
end
local function sawStyleChange(steps)
  local saw = false; for i = 1, (steps or 4) do local s = disp("step"); if s.intent and s.intent.skill == SID.MH_STYLE_CHANGE then saw = true end end; return saw
end
local treeNoParams = { type = "sequence", children = {
  { type = "succeeder", child = { type = "action", name = "AcquireTarget" } },
  { type = "action", name = "UseEleanorOffense" } } }
local treePowerParam = { type = "sequence", children = {
  { type = "succeeder", child = { type = "action", name = "AcquireTarget" } },
  { type = "action", name = "UseEleanorOffense", params = { style = "power" } } } }

-- C) sem padrão e sem params → estilo power, não troca
disp("setSkillChoice", { choices = {} })
disp("setTree", treeNoParams); disp("load", eleScen({ GrappleThreatLimit = 1 }))
check(not sawStyleChange(4), "baseline: sem padrão/sem params, isolada → NÃO troca p/ grapple")
-- A) padrão style=grapple, sem params → usa o padrão (troca p/ grapple)
disp("setSkillChoice", { choices = { ["52"] = { combo = { style = "grapple", allowStyleSwitch = true } } } })
disp("setTree", treeNoParams); disp("load", eleScen({ GrappleThreatLimit = 1 }))
check(sawStyleChange(4), "padrão grapple aplicado (sem params) → troca p/ grapple")
-- B) padrão grapple + param do nó style=power → o nó vence (não troca)
disp("setSkillChoice", { choices = { ["52"] = { combo = { style = "grapple", allowStyleSwitch = true } } } })
disp("setTree", treePowerParam); disp("load", eleScen({ GrappleThreatLimit = 1 }))
check(not sawStyleChange(4), "param do nó (power) sobrepõe o padrão (grapple) → NÃO troca")
disp("setSkillChoice", { choices = {} })

print(string.format("RESULTADO: %d ok, %d falhas", pass, fail))
os.exit(fail == 0 and 0 or 1)
