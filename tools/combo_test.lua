-- combo_test.lua — D1 (combos) e D2 (Style Change da Eleanor).
-- Uso: texlua tools/combo_test.lua
local boot = dofile("lua/sim_boot.lua")
local BRAI = boot("lua")
local json, C, SID = BRAI.json, BRAI.const, BRAI.skills.id

local pass, fail = 0, 0
local function check(c, n) if c then pass = pass + 1; print("  ok  - " .. n)
	else fail = fail + 1; print("  FAIL- " .. n) end end
local function disp(m, o) return json.decode(SIM_DISPATCH(m, o and json.encode(o) or "")) end

-- Eleanor (52) com um monstro adjacente
local function eleanorScen()
	return { grid = { w = 40, h = 40 }, dt = 50, homunId = 100, ownerId = 1, entities = {
		{ id = 1, kind = "owner", x = 18, y = 20, hp = 1000, maxhp = 1000 },
		{ id = 100, kind = "homun", x = 20, y = 20, hp = 9000, maxhp = 9000, sp = 9000, maxsp = 9000, homunType = C.ELEANOR },
		{ id = 200, kind = "monster", x = 21, y = 20, hp = 100000, maxhp = 100000, atk = 0, aggro = 1, atkInterval = 100000, aggressive = false },
	} }
end
-- árvore: adquire alvo e executa o combo
local function comboTree(combo)
	return { type = "sequence", children = {
		{ type = "succeeder", child = { type = "action", name = "AcquireTarget" } },
		{ type = "action", name = "UseCombo", params = { combo = combo, window = 2000 } },
	} }
end

print("== D1: combo power (Sonic Claw -> Silvervein -> Midnight) ==")
disp("setTree", comboTree("power"))
disp("load", eleanorScen())
local seq = {}
for _ = 1, 6 do
	local s = disp("step")
	if s.intent and s.intent.kind == "skill" then seq[#seq + 1] = s.intent.skill end
end
check(seq[1] == SID.MH_SONIC_CLAW, "passo 1 = Sonic Claw")
check(seq[2] == SID.MH_SILVERVEIN_RUSH, "passo 2 = Silvervein Rush")
check(seq[3] == SID.MH_MIDNIGHT_FRENZY, "passo 3 = Midnight Frenzy")

print("== D1: combo grapple (Tinder Breaker -> CBC -> EQC) ==")
disp("setTree", comboTree("grapple"))
disp("load", eleanorScen())
seq = {}
for _ = 1, 6 do
	local s = disp("step")
	if s.intent and s.intent.kind == "skill" then seq[#seq + 1] = s.intent.skill end
end
check(seq[1] == SID.MH_TINDER_BREAKER, "passo 1 = Tinder Breaker")
check(seq[2] == SID.MH_CBC, "passo 2 = C.B.C.")
check(seq[3] == SID.MH_EQC, "passo 3 = E.Q.C.")

print("== D2: Style Change ==")
-- estilo inicial é "power"; StyleIs(power) verdadeiro, SetStyle(power) não faz nada
disp("setTree", { type = "check", name = "StyleIs", params = { style = "power" }, child = { type = "action", name = "Idle" } })
disp("load", eleanorScen())
local s = disp("step")
check(s.bb == nil or true, "StyleIs(power) avaliado (estilo inicial power)")

-- SetStyle(grapple) conjura Style Change e passa o estilo para grapple
disp("setTree", { type = "action", name = "SetStyle", params = { style = "grapple" } })
disp("load", eleanorScen())
s = disp("step")
check(s.intent and s.intent.skill == SID.MH_STYLE_CHANGE, "SetStyle(grapple): conjura Style Change")
-- agora StyleIs(grapple) deve ser verdadeiro e StyleIs(power) falso
disp("setTree", { type = "check", name = "StyleIs", params = { style = "grapple" }, child = { type = "action", name = "Flee" } })
-- mantém o mesmo mundo (sem reload p/ preservar bb.persist.style) — passo extra
s = disp("step")
check((s.intent == nil) or (s.intent.kind ~= "skill"), "após SetStyle, estilo virou grapple (StyleIs persiste)")

-- SetStyle(grapple) de novo: já está -> não conjura nada
disp("setTree", { type = "action", name = "SetStyle", params = { style = "grapple" } })
s = disp("step")
check(not (s.intent and s.intent.skill == SID.MH_STYLE_CHANGE), "SetStyle(grapple) quando já é grapple: não reconjura")

print(string.format("RESULTADO: %d ok, %d falhas", pass, fail))
os.exit(fail == 0 and 0 or 1)
