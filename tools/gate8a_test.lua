-- gate8a_test.lua — Fase 8a: gates de config nos nós Kite/DanceAttack e trava de estilo da Eleanor.
-- Uso: texlua tools/gate8a_test.lua
local boot = dofile("lua/sim_boot.lua")
local BRAI = boot("lua")
local json, C, SID = BRAI.json, BRAI.const, BRAI.skills.id

local pass, fail = 0, 0
local function check(c, n) if c then pass = pass + 1; print("  ok  - " .. n)
  else fail = fail + 1; print("  FAIL- " .. n) end end
local function disp(m, o) return json.decode(SIM_DISPATCH(m, o and json.encode(o) or "")) end
local function ent(s, id) for _, e in ipairs(s.entities) do if e.id == id then return e end end end
local function cheb(a, b) return math.max(math.abs(a.x - b.x), math.abs(a.y - b.y)) end

-- cenário: monstro PASSIVO colado (dist 1) no homún
local function scen(cfg, homun)
  return { grid = { w = 40, h = 40 }, dt = 50, homunId = 100, ownerId = 1, config = cfg or {}, entities = {
    { id = 1, kind = "owner", x = 20, y = 20, hp = 1000, maxhp = 1000 },
    { id = 100, kind = "homun", x = 20, y = 20, hp = 9000, maxhp = 9000, sp = 9000, maxsp = 9000, homunType = homun or C.VANILMIRTH },
    { id = 200, kind = "monster", x = 21, y = 20, hp = 100000, maxhp = 100000, atk = 0, aggro = 1, atkInterval = 100000, aggressive = false },
  } }
end
local function kiteTree() return { type = "sequence", children = {
  { type = "succeeder", child = { type = "action", name = "AcquireTarget" } },
  { type = "action", name = "Kite", params = { gate = "KiteMonsters" } },
} } end
local function farMaxDist(steps)
  local d0, dN; for i = 1, (steps or 8) do local s = disp("step"); local h, m = ent(s, 100), ent(s, 200); if h and m then if i == 1 then d0 = cheb(h, m) end; dN = cheb(h, m) end end
  return d0, dN
end

print("== Kite: gate por config.KiteMonsters ==")
disp("setTree", kiteTree()); disp("load", scen({ KiteMonsters = false }))
local d0, dN = farMaxDist(8)
check(dN == d0, "gate OFF: KiteMonsters=false NAO kita (dist estavel em " .. tostring(dN) .. ")")
disp("setTree", kiteTree()); disp("load", scen({ KiteMonsters = true }))
d0, dN = farMaxDist(8)
check(dN > d0, "gate ON: KiteMonsters=true kita (" .. tostring(d0) .. " -> " .. tostring(dN) .. ")")

print("== Kite: distancia vem de config.KiteDist ==")
disp("setTree", kiteTree()); disp("load", scen({ KiteMonsters = true, KiteDist = 7 }))
d0, dN = farMaxDist(12)
check(dN >= 7, "Kite respeita config.KiteDist=7 (chegou a " .. tostring(dN) .. ")")

print("== DanceAttack: gate + DanceMinSP ==")
local function danceTree() return { type = "sequence", children = {
  { type = "succeeder", child = { type = "action", name = "AcquireTarget" } },
  { type = "action", name = "DanceAttack", params = { gate = "UseDanceAttack" } },
} } end
local function danced(steps)
  local saw = false; for i = 1, (steps or 6) do local s = disp("step"); if s.intent and s.intent.reason == "dance" then saw = true end end; return saw
end
disp("setTree", danceTree()); disp("load", scen({ UseDanceAttack = false }))
check(not danced(6), "gate OFF: UseDanceAttack=false NAO dança")
disp("setTree", danceTree()); disp("load", scen({ UseDanceAttack = true }))
check(danced(6), "gate ON: UseDanceAttack=true dança (passo lateral)")
disp("setTree", danceTree()); disp("load", scen({ UseDanceAttack = true, DanceMinSP = 999999 }))
check(not danced(6), "DanceMinSP alto: sem SP suficiente, não dança")

print("== Eleanor: EleanorDoNotSwitchMode trava o Style Change ==")
local function eleTree() return { type = "sequence", children = {
  { type = "succeeder", child = { type = "action", name = "AcquireTarget" } },
  { type = "action", name = "UseEleanorOffense", params = { style = "grapple" } },
} } end
local function sawStyleChange(steps)
  local saw = false; for i = 1, (steps or 4) do local s = disp("step"); if s.intent and s.intent.skill == SID.MH_STYLE_CHANGE then saw = true end end; return saw
end
disp("setTree", eleTree()); disp("load", scen({ GrappleThreatLimit = 1 }, C.ELEANOR))
check(sawStyleChange(4), "sem trava: Eleanor isolada troca p/ grapple (Style Change)")
disp("setTree", eleTree()); disp("load", scen({ GrappleThreatLimit = 1, EleanorDoNotSwitchMode = true }, C.ELEANOR))
check(not sawStyleChange(4), "EleanorDoNotSwitchMode=true: NÃO conjura Style Change")

print(string.format("RESULTADO: %d ok, %d falhas", pass, fail))
os.exit(fail == 0 and 0 or 1)
