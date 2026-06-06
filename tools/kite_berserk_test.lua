-- kite_berserk_test.lua — B1 (kiting) e C1 (berserk/Mobbed).
-- Uso: texlua tools/kite_berserk_test.lua
local boot = dofile("lua/sim_boot.lua")
local BRAI = boot("lua")
local json, C = BRAI.json, BRAI.const

local pass, fail = 0, 0
local function check(c, n) if c then pass = pass + 1; print("  ok  - " .. n)
	else fail = fail + 1; print("  FAIL- " .. n) end end
local function disp(m, o) return json.decode(SIM_DISPATCH(m, o and json.encode(o) or "")) end
local function ent(s, id) for _, e in ipairs(s.entities) do if e.id == id then return e end end end
local function cheb(a, b) return math.max(math.abs(a.x - b.x), math.abs(a.y - b.y)) end

print("== B1: kiting ==")
-- monstro PASSIVO colado no homún; Kite deve afastar até manter a distância 'dist'
disp("setTree", { type = "sequence", children = {
	{ type = "succeeder", child = { type = "action", name = "AcquireTarget" } },
	{ type = "action", name = "Kite", params = { dist = 5, step = 2 } },
} })
disp("load", { grid = { w = 40, h = 40 }, dt = 50, homunId = 100, ownerId = 1, entities = {
	{ id = 1, kind = "owner", x = 20, y = 20, hp = 1000, maxhp = 1000 },
	{ id = 100, kind = "homun", x = 20, y = 20, hp = 900, maxhp = 900, sp = 900, maxsp = 900, homunType = C.VANILMIRTH },
	{ id = 200, kind = "monster", x = 22, y = 20, hp = 500, maxhp = 500, atk = 0, aggro = 1, atkInterval = 100000, aggressive = false },
} })
local d0, dN
for i = 1, 8 do
	local s = disp("step")
	local h, m = ent(s, 100), ent(s, 200)
	if i == 1 then d0 = cheb(h, m) end
	dN = cheb(h, m)
end
check(dN > d0, "kiting: o homún se afasta do alvo (" .. d0 .. " -> " .. dN .. ")")
check(dN >= 5, "kiting: mantém pelo menos a distância pedida (dist=5; chegou a " .. dN .. ")")

-- Kite não foge além do limite do dono (bounds)
disp("setTree", { type = "sequence", children = {
	{ type = "succeeder", child = { type = "action", name = "AcquireTarget" } },
	{ type = "action", name = "Kite", params = { dist = 30, step = 2, bounds = 2 } },
} })
disp("load", { grid = { w = 40, h = 40 }, dt = 50, homunId = 100, ownerId = 1, entities = {
	{ id = 1, kind = "owner", x = 20, y = 20, hp = 1000, maxhp = 1000 },
	{ id = 100, kind = "homun", x = 20, y = 20, hp = 900, maxhp = 900, sp = 900, maxsp = 900, homunType = C.VANILMIRTH },
	{ id = 200, kind = "monster", x = 22, y = 20, hp = 500, maxhp = 500, atk = 0, aggro = 1, atkInterval = 100000, aggressive = false },
} })
local maxFromOwner = 0
for i = 1, 10 do
	local s = disp("step")
	local h, o = ent(s, 100), ent(s, 1)
	maxFromOwner = math.max(maxFromOwner, cheb(h, o))
end
check(maxFromOwner <= 2, "kiting: respeita o limite do dono (bounds=2; máx afastamento " .. maxFromOwner .. ")")

print("== C1: berserk (Mobbed) ==")
-- 3 monstros agressivos colados no homún -> Mobbed(3) verdadeiro -> flag berserk
local function mobScen(n)
	local ents = {
		{ id = 1, kind = "owner", x = 5, y = 5, hp = 1000, maxhp = 1000 },
		{ id = 100, kind = "homun", x = 20, y = 20, hp = 100000, maxhp = 100000, sp = 900, maxsp = 900, homunType = C.VANILMIRTH },
	}
	local cells = { { 21, 20 }, { 19, 20 }, { 20, 21 }, { 20, 19 } }
	for i = 1, n do
		ents[#ents + 1] = { id = 200 + i, kind = "monster", x = cells[i][1], y = cells[i][2],
			hp = 5000, maxhp = 5000, atk = 1, aggro = 12, atkInterval = 100000 }
	end
	return { grid = { w = 40, h = 40 }, dt = 50, homunId = 100, ownerId = 1, entities = ents }
end
disp("setTree", { type = "check", name = "Mobbed", params = { count = 3 }, child = { type = "action", name = "Idle" } })
disp("load", mobScen(3))
local s; for i = 1, 3 do s = disp("step") end
check(s.bb.flags.berserk == true, "Mobbed(3): 3 monstros atacando -> berserk ligado")

disp("setTree", { type = "check", name = "Mobbed", params = { count = 3 }, child = { type = "action", name = "Idle" } })
disp("load", mobScen(2))
for i = 1, 3 do s = disp("step") end
check(not s.bb.flags.berserk, "Mobbed(3): apenas 2 monstros -> berserk desligado")

print(string.format("RESULTADO: %d ok, %d falhas", pass, fail))
os.exit(fail == 0 and 0 or 1)
