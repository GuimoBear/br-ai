-- interval_test.lua — intervalo customizado entre execuções de skill (cooldown do nó),
-- independente da duração e do cooldown do jogo, com reset opcional ao trocar de alvo.
-- Uso: texlua tools/interval_test.lua
local boot = dofile("lua/sim_boot.lua")
local BRAI = boot("lua")
local json, C, SID = BRAI.json, BRAI.const, BRAI.skills.id

local pass, fail = 0, 0
local function check(c, n) if c then pass = pass + 1; print("  ok  - " .. n)
	else fail = fail + 1; print("  FAIL- " .. n) end end
local function disp(m, o) return json.decode(SIM_DISPATCH(m, o and json.encode(o) or "")) end

-- árvore: adquire alvo e usa UseSkill (Needle, alvo único, cd de jogo ~300ms)
local function combat(params)
	return { type = "sequence", children = {
		{ type = "succeeder", child = { type = "action", name = "AcquireTarget" } },
		{ type = "action", name = "UseSkill", params = params },
	} }
end
local function scen(mons)
	local ents = {
		{ id = 1, kind = "owner", x = 19, y = 20, hp = 1000, maxhp = 1000 },
		{ id = 100, kind = "homun", x = 20, y = 20, hp = 900, maxhp = 900, sp = 9000, maxsp = 9000, homunType = C.SERA },
	}
	for i, m in ipairs(mons) do
		ents[#ents + 1] = { id = 200 + i, kind = "monster", x = m.x, y = m.y, hp = 100000, maxhp = 100000, atk = 0, aggro = 1, atkInterval = 100000 }
	end
	return { grid = { w = 40, h = 40 }, dt = 50, homunId = 100, ownerId = 1, entities = ents }
end

local function castTicks(params, steps)
	disp("setTree", combat(params))
	disp("load", scen({ { x = 21, y = 20 } }))
	local ticks = {}
	for _ = 1, (steps or 80) do
		local s = disp("step")
		if s.intent and s.intent.skill == SID.MH_NEEDLE_OF_PARALYZE then ticks[#ticks + 1] = s.tick end
	end
	return ticks
end
local function minGap(t) local g = 1e9; for i = 2, #t do g = math.min(g, t[i] - t[i - 1]) end; return g end

print("== intervalo customizado entre execuções ==")

-- sem intervalo: limitado só pelo cd do jogo (~300ms) -> casta com frequência alta
local t0 = castTicks({ skill = SID.MH_NEEDLE_OF_PARALYZE, level = 5 }, 40)
check(#t0 >= 3 and minGap(t0) < 1000, "sem intervalo: casts frequentes (gap < 1000ms; menor=" .. minGap(t0) .. ")")

-- intervalo 1s: casts espaçados em >= 1000ms, mesmo com cd de jogo curto
local t1 = castTicks({ skill = SID.MH_NEEDLE_OF_PARALYZE, level = 5, interval = 1000 }, 80)
check(#t1 >= 2 and minGap(t1) >= 1000, "intervalo 1s: casts espaçados em >= 1000ms (menor=" .. (minGap(t1) == 1e9 and "n/a" or minGap(t1)) .. ")")

-- intervalo 2s: espaçados em >= 2000ms
local t2 = castTicks({ skill = SID.MH_NEEDLE_OF_PARALYZE, level = 5, interval = 2000 }, 120)
check(#t2 >= 2 and minGap(t2) >= 2000, "intervalo 2s: casts espaçados em >= 2000ms (menor=" .. (minGap(t2) == 1e9 and "n/a" or minGap(t2)) .. ")")

print("== reset ao trocar de alvo ==")
-- intervalo 3s + reset: casta no alvo A; ao remover A (troca p/ B), casta de novo na hora
disp("setTree", combat({ skill = SID.MH_NEEDLE_OF_PARALYZE, level = 5, interval = 3000, reset = true }))
disp("load", scen({ { x = 21, y = 20 }, { x = 22, y = 20 } }))   -- 201 (perto), 202
local firstTick, firstTarget
for _ = 1, 6 do
	local s = disp("step")
	if s.intent and s.intent.skill == SID.MH_NEEDLE_OF_PARALYZE then firstTick = s.tick; firstTarget = s.intent.target; break end
end
check(firstTarget == 201, "reset: primeiro cast no alvo mais próximo (201)")
-- remove o alvo atual ANTES de passar o intervalo de 3s; o alvo muda p/ 202
disp("removeMonster", { id = firstTarget })
local reTick, reTarget
for _ = 1, 6 do
	local s = disp("step")
	if s.intent and s.intent.skill == SID.MH_NEEDLE_OF_PARALYZE and s.tick > (firstTick or 0) then reTick = s.tick; reTarget = s.intent.target; break end
end
check(reTarget == 202 and (reTick - firstTick) < 3000,
	"reset: troca de alvo zera o intervalo e casta logo no novo alvo (gap=" .. tostring(reTick and (reTick - firstTick)) .. "ms < 3000)")

-- sem reset: ao trocar de alvo dentro do intervalo, NÃO casta antes do tempo
disp("setTree", combat({ skill = SID.MH_NEEDLE_OF_PARALYZE, level = 5, interval = 3000, reset = false }))
disp("load", scen({ { x = 21, y = 20 }, { x = 22, y = 20 } }))
local ft, ftgt
for _ = 1, 6 do local s = disp("step"); if s.intent and s.intent.skill == SID.MH_NEEDLE_OF_PARALYZE then ft = s.tick; ftgt = s.intent.target; break end end
disp("removeMonster", { id = ftgt })
local castedEarly = false
for _ = 1, 20 do   -- ~1s
	local s = disp("step")
	if s.intent and s.intent.skill == SID.MH_NEEDLE_OF_PARALYZE and s.tick > ft then castedEarly = true; break end
end
check(not castedEarly, "sem reset: troca de alvo NÃO antecipa o cast (respeita o intervalo)")

print(string.format("RESULTADO: %d ok, %d falhas", pass, fail))
os.exit(fail == 0 and 0 or 1)
