-- config_dispatch_test.lua — dispatch setConfig/defaultConfig do simulador (Fase 7).
-- setConfig aplica os knobs em SIM.bb.config e PERSISTE após reset; defaultConfig devolve o padrão.
-- Uso: texlua tools/config_dispatch_test.lua
local boot = dofile("lua/sim_boot.lua")
local BRAI = boot("lua")
local json, C = BRAI.json, BRAI.const

local pass, fail = 0, 0
local function check(c, n) if c then pass = pass + 1; print("  ok  - " .. n)
  else fail = fail + 1; print("  FAIL- " .. n) end end
local function disp(m, o) return json.decode(SIM_DISPATCH(m, o and json.encode(o) or "")) end

local scn = {
  grid = { w = 40, h = 40 }, dt = 50, homunId = 100, ownerId = 1, homunType = C.SERA, baseType = 0,
  entities = {
    { id = 1, kind = "owner", x = 2, y = 20, hp = 1000, maxhp = 1000 },
    { id = 100, kind = "homun", x = 20, y = 20, hp = 1000, maxhp = 1000, sp = 100, maxsp = 100, homunType = C.SERA },
  },
}

print("== setConfig: aplica + persiste no reset ==")
disp("load", scn)
local before = BRAI.sim.bb.config.AggroHP
disp("setConfig", { AggroHP = 99, HealOwnerHP = 41, UseAutoHeal = false })
check(BRAI.sim.bb.config.AggroHP == 99, "setConfig aplica AggroHP=99 (era " .. tostring(before) .. ")")
check(BRAI.sim.bb.config.HealOwnerHP == 41, "setConfig aplica HealOwnerHP=41")
check(BRAI.sim.bb.config.UseAutoHeal == false, "setConfig aplica UseAutoHeal=false")
disp("reset")
check(BRAI.sim.bb.config.AggroHP == 99, "persiste após reset (AggroHP=99)")
check(BRAI.sim.bb.config.HealOwnerHP == 41, "persiste após reset (HealOwnerHP=41)")

print("== defaultConfig: devolve a tabela padrão ==")
local dc = disp("defaultConfig")
check(type(dc) == "table" and dc.AggroHP ~= nil and dc.HealOwnerHP ~= nil, "defaultConfig tem os knobs padrão")
-- o config do cenário (scn.config) e o setConfig do editor convivem: editor vence
disp("load", { grid = { w = 10, h = 10 }, dt = 50, homunId = 100, ownerId = 1, homunType = C.SERA,
  config = { AggroHP = 10 }, entities = scn.entities })
check(BRAI.sim.bb.config.AggroHP == 99, "editor (setConfig) vence o scn.config no load")

print("RESULTADO: " .. pass .. " ok, " .. fail .. " falhas")
if fail > 0 then os.exit(1) end
