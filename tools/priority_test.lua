-- priority_test.lua — A5 (prioridade de alvo) e A4 (troca oportunista).
-- Uso: texlua tools/priority_test.lua
local boot = dofile("lua/sim_boot.lua")
local BRAI = boot("lua")
local json, C = BRAI.json, BRAI.const

local pass, fail = 0, 0
local function check(c, n) if c then pass = pass + 1; print("  ok  - " .. n)
	else fail = fail + 1; print("  FAIL- " .. n) end end
local function disp(m, o) return json.decode(SIM_DISPATCH(m, o and json.encode(o) or "")) end

local function homunBase()
	return {
		{ id = 1, kind = "owner", x = 20, y = 18, hp = 1000, maxhp = 1000 },
		{ id = 100, kind = "homun", x = 20, y = 20, hp = 900, maxhp = 900, sp = 900, maxsp = 900, homunType = C.VANILMIRTH },
	}
end
local function load(ents, cfg)
	disp("load", { grid = { w = 40, h = 40 }, dt = 50, homunId = 100, ownerId = 1, config = cfg, entities = ents })
end
local function mon(id, x, y, hp, maxhp, aggressive)
	return { id = id, kind = "monster", x = x, y = y, hp = hp, maxhp = maxhp or hp, atk = 1, aggro = 12, atkInterval = 100000, aggressive = aggressive ~= false }
end

print("== A5: prioridade de alvo ==")
-- nearest: pega o mais próximo
disp("setTree", { type = "action", name = "AcquireTarget", params = { by = "nearest" } })
local e = homunBase(); e[#e+1] = mon(201, 23, 20, 500, 500, false); e[#e+1] = mon(202, 26, 20, 500, 500, false)
load(e)
local s = disp("step")
check(s.target == 201, "nearest: escolhe o monstro mais próximo (201)")

-- lowestHp: pega o de menor HP%, mesmo mais longe
disp("setTree", { type = "action", name = "AcquireTarget", params = { by = "lowestHp" } })
e = homunBase(); e[#e+1] = mon(201, 23, 20, 500, 500, false); e[#e+1] = mon(202, 26, 20, 50, 500, false)
load(e)
s = disp("step")
check(s.target == 202, "lowestHp: escolhe o de menor HP% (202, 10%) mesmo mais longe")

-- ownerAttacker: prioriza quem ataca o dono, mesmo mais longe
disp("setTree", { type = "action", name = "Idle" })
e = homunBase()
e[#e+1] = mon(201, 22, 20, 500, 500, false)              -- perto do homún, passivo
e[#e+1] = mon(202, 20, 17, 500, 500, true)               -- colado no dono (20,18), agressivo
load(e)
disp("step")                                              -- deixa 202 mirar o dono
disp("setTree", { type = "action", name = "AcquireTarget", params = { by = "ownerAttacker" } })
s = disp("step")
check(s.target == 202, "ownerAttacker: prioriza o atacante do dono (202)")

print("== A4: troca oportunista ==")
-- começa mirando o de menor HP (mais longe); ReacquireIfBetter(nearest) troca p/ o mais próximo
disp("setTree", { type = "action", name = "AcquireTarget", params = { by = "lowestHp" } })
e = homunBase(); e[#e+1] = mon(201, 23, 20, 500, 500, false); e[#e+1] = mon(202, 27, 20, 50, 500, false)
load(e)
s = disp("step")
check(s.target == 202, "setup: começa mirando o de menor HP (202, longe)")
disp("setTree", { type = "action", name = "ReacquireIfBetter", params = { by = "nearest" } })
s = disp("step")
check(s.target == 201, "ReacquireIfBetter(nearest): troca para o mais próximo (201)")

-- já no melhor alvo: não troca (mantém)
disp("setTree", { type = "action", name = "ReacquireIfBetter", params = { by = "nearest" } })
s = disp("step")
check(s.target == 201, "ReacquireIfBetter: já no melhor -> mantém o alvo (201)")

print(string.format("RESULTADO: %d ok, %d falhas", pass, fail))
os.exit(fail == 0 and 0 or 1)
