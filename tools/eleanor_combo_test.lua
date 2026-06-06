-- eleanor_combo_test.lua — Fase 2: nó UseEleanorOffense (combo + estilo + barragem).
-- Cobre C1..C15 (PLANO-COMBOS-ELEANOR.md §9.4). Guards de regressão: R1, R3, R4, R5, R6.
-- Uso: texlua tools/eleanor_combo_test.lua
local boot = dofile("lua/sim_boot.lua")
local BRAI = boot("lua")
local json, C, SID = BRAI.json, BRAI.const, BRAI.skills.id
local sys = BRAI.skillsys

local pass, fail = 0, 0
local function check(c, n) if c then pass = pass + 1; print("  ok  - " .. n)
	else fail = fail + 1; print("  FAIL- " .. n) end end
local function disp(m, o) return json.decode(SIM_DISPATCH(m, o and json.encode(o) or "")) end

-- cenário Eleanor + monstro(s). mons = lista de {x,y,hp,atk}
local function scen(mons, homAtk)
	local ents = {
		{ id = 1, kind = "owner", x = 5, y = 20, hp = 100000, maxhp = 100000 },
		{ id = 100, kind = "homun", x = 20, y = 20, hp = 100000, maxhp = 100000,
		  sp = 9000, maxsp = 9000, atk = homAtk or 900, homunType = C.ELEANOR },
	}
	for i, m in ipairs(mons or {}) do
		ents[#ents + 1] = { id = 200 + i, kind = "monster", x = m.x, y = m.y,
			hp = m.hp or 1000000, maxhp = m.hp or 1000000, atk = m.atk or 0,
			aggro = 12, aggressive = m.aggressive or false, atkInterval = 100000, etype = 1042 }
	end
	return { grid = { w = 40, h = 40 }, dt = 50, homunId = 100, ownerId = 1,
		config = { BaseHomunType = 0, FleeHP = 0, AggroDist = 14 }, homunType = C.ELEANOR, entities = ents }
end

local function offenseTree(style, barragem, allowSwitch)
	local params = { style = style, comboSpheres = barragem, window = 2000 }
	if allowSwitch ~= nil then params.allowStyleSwitch = allowSwitch end
	return { type = "sequence", children = {
		{ type = "succeeder", child = { type = "action", name = "AcquireTarget" } },
		{ type = "selector", children = {
			{ type = "action", name = "UseEleanorOffense", params = params },
			{ type = "check", name = "InAttackRange", child = { type = "action", name = "AttackTarget" } },
			{ type = "action", name = "ChaseTarget", params = { dist = 1 } },
		} },
	} }
end
-- coleta a sequência de skills de combo emitidas em N passos
local function comboSeq(n)
	local seq = {}
	for _ = 1, n do
		local s = disp("step")
		if s.intent and s.intent.kind == "skill" and s.intent.combo then seq[#seq + 1] = s.intent.skill end
	end
	return seq
end

print("== C1: cadeia power na ordem (Sonic -> Silvervein -> Midnight) ==")
disp("load", scen({ { x = 21, y = 20, hp = 1e9 } })); disp("setTree", offenseTree("power", 3))
sys.addSpheres(BRAI.sim.bb, 10)
local seq = comboSeq(6)
check(seq[1] == SID.MH_SONIC_CLAW,      "C1a: passo 1 = Sonic Claw")
check(seq[2] == SID.MH_SILVERVEIN_RUSH, "C1b: passo 2 = Silvervein Rush")
check(seq[3] == SID.MH_MIDNIGHT_FRENZY, "C1c: passo 3 = Midnight Frenzy")

print("== C2/C9: cadeia grapple com Style Change antes (Tinder -> CBC -> EQC) ==")
disp("load", scen({ { x = 21, y = 20, hp = 1e9 } })); disp("setTree", offenseTree("grapple", 3))
sys.addSpheres(BRAI.sim.bb, 10)
local first = disp("step")   -- deve trocar de estilo primeiro
check(first.intent and first.intent.skill == SID.MH_STYLE_CHANGE, "C9: Style Change emitido antes do combo grapple")
seq = comboSeq(6)
check(seq[1] == SID.MH_TINDER_BREAKER, "C2a: passo 1 = Tinder Breaker")
check(seq[2] == SID.MH_CBC,            "C2b: passo 2 = C.B.C.")
check(seq[3] == SID.MH_EQC,            "C2c: passo 3 = E.Q.C.")

print("== C3/C4: barragem (AutoComboSpheres) ==")
disp("load", scen({ { x = 21, y = 20, hp = 1e9 } })); disp("setTree", offenseTree("power", 5))
sys.addSpheres(BRAI.sim.bb, 2)   -- abaixo da barragem 5
local s = disp("step")
check(not (s.intent and s.intent.combo), "C3: barragem bloqueia início abaixo do limiar")
disp("load", scen({ { x = 21, y = 20, hp = 1e9 } })); disp("setTree", offenseTree("power", 5))
sys.addSpheres(BRAI.sim.bb, 5)   -- atinge a barragem
s = disp("step")
check(s.intent and s.intent.skill == SID.MH_SONIC_CLAW, "C4: barragem atingida -> inicia combo")

print("== C6: comboStep reseta por janela/finisher (unidade) ==")
disp("load", scen({ { x = 21, y = 20, hp = 1e9 } })); local bb = BRAI.sim.bb
bb.target = 201
bb.persist.combo = { key = "power", step = 1, at = bb:now(), targetId = 201 }
check(BRAI.eleanor.comboStep(bb, "power", 2000) == 2, "C6a: dentro da janela -> avança (step 2)")
bb.persist.combo = { key = "power", step = 1, at = bb:now() - 3000, targetId = 201 }
check(BRAI.eleanor.comboStep(bb, "power", 2000) == 1, "C6b: janela expirada -> reset step 1")
bb.persist.combo = { key = "power", step = 3, at = bb:now(), targetId = 201 }
check(BRAI.eleanor.comboStep(bb, "power", 2000) == 1, "C6c: finisher concluído (#chain) -> reset step 1")

print("== C8: reset ao TROCAR DE ALVO (R6, unidade) ==")
bb.target = 201
bb.persist.combo = { key = "power", step = 2, at = bb:now(), targetId = 201 }
check(BRAI.eleanor.comboStep(bb, "power", 2000) == 3, "C8a: mesmo alvo -> avança (step 3)")
bb.target = 202   -- alvo diferente
check(BRAI.eleanor.comboStep(bb, "power", 2000) == 1, "C8b: alvo diferente -> reset step 1 (R6)")

print("== C7: alvo morre no meio -> reset, sem golpe no alvo nulo (R1) ==")
disp("load", scen({ { x = 21, y = 20, hp = 50 } })); disp("setTree", offenseTree("power", 0))
sys.addSpheres(BRAI.sim.bb, 10)
local emittedAfterDeath, sawCombo, dead = false, false, false
for _ = 1, 8 do
	local st = disp("step")
	if st.intent and st.intent.combo then
		sawCombo = true
		if dead then emittedAfterDeath = true end   -- combo emitido após a morte = bug R1
	end
	-- monstro 201 morreu/sumiu?
	local mon = nil
	for _, e in ipairs(st.entities or {}) do if e.id == 201 then mon = e end end
	if (not mon) or (mon and mon.hp <= 0) then dead = true end
end
check(sawCombo, "C7a: combo chegou a disparar antes da morte")
check(not emittedAfterDeath, "C7b: nenhum golpe de combo após o alvo morrer (R1)")

print("== C10: anti-loop de estilo (R4) ==")
disp("load", scen({ { x = 21, y = 20, hp = 1e9 } })); disp("setTree", offenseTree("grapple", 3))
sys.addSpheres(BRAI.sim.bb, 10)
local nSC = 0
for _ = 1, 8 do local st = disp("step"); if st.intent and st.intent.skill == SID.MH_STYLE_CHANGE then nSC = nSC + 1 end end
check(nSC == 1, "C10a: Style Change emitido só 1x (sem oscilar)")
-- unidade: dentro da janela de lock, não troca de novo mesmo com crença divergente
disp("load", scen({})); bb = BRAI.sim.bb
local r1 = BRAI.eleanor.ensureStyle(bb, "grapple", true)
bb.persist.style = "power"   -- força divergência logo após trocar
local r2 = BRAI.eleanor.ensureStyle(bb, "grapple", true)
check(r1 == "switched" and r2 == "locked", "C10b: lock impede nova troca dentro de STYLE_LOCK_MS")

print("== C11: allowStyleSwitch=false -> usa estilo atual, sem Style Change ==")
disp("load", scen({ { x = 21, y = 20, hp = 1e9 } })); disp("setTree", offenseTree("grapple", 3, false))
sys.addSpheres(BRAI.sim.bb, 10)
local anySC, allPower = false, true
for _ = 1, 6 do
	local st = disp("step")
	if st.intent and st.intent.skill == SID.MH_STYLE_CHANGE then anySC = true end
	if st.intent and st.intent.combo then
		if st.intent.skill ~= SID.MH_SONIC_CLAW and st.intent.skill ~= SID.MH_SILVERVEIN_RUSH
		   and st.intent.skill ~= SID.MH_MIDNIGHT_FRENZY then allPower = false end
	end
end
check(not anySC, "C11a: nunca emite Style Change com allowStyleSwitch=false")
check(allPower, "C11b: roda a cadeia do estilo atual (power)")

print("== C12: fora de alcance -> FAILURE -> ChaseTarget ==")
disp("load", scen({ { x = 30, y = 20, hp = 1e9 } })); disp("setTree", offenseTree("power", 0))
sys.addSpheres(BRAI.sim.bb, 10)
s = disp("step")
check(s.intent and s.intent.kind == "move", "C12: alvo longe -> persegue (sem combo)")

print("== C13: SP insuficiente -> cai no ataque básico ==")
local sc13 = scen({ { x = 21, y = 20, hp = 1e9 } }); sc13.entities[2].sp = 5; sc13.entities[2].maxsp = 5
disp("load", sc13); disp("setTree", offenseTree("power", 0))
sys.addSpheres(BRAI.sim.bb, 10)
s = disp("step")
check(s.intent and s.intent.kind == "attack", "C13: sem SP -> ataque normal (sem combo)")

print("== C14: elo em recarga -> não dispara (espera) ==")
disp("load", scen({ { x = 21, y = 20, hp = 1e9 } })); bb = BRAI.sim.bb
sys.addSpheres(bb, 10)
bb.persist.skillReadyAt[SID.MH_SONIC_CLAW] = bb:now() + 5000   -- Sonic em recarga
disp("setTree", offenseTree("power", 0))
s = disp("step")
check(not (s.intent and s.intent.combo == "power" and s.intent.skill == SID.MH_SONIC_CLAW),
	"C14: Sonic em recarga não dispara (fall-through)")

print("== C15: elo só dispara no estilo correto (R3) ==")
local grappleSet = { [SID.MH_TINDER_BREAKER] = true, [SID.MH_CBC] = true, [SID.MH_EQC] = true }
disp("load", scen({ { x = 21, y = 20, hp = 1e9 } })); disp("setTree", offenseTree("power", 3))
sys.addSpheres(BRAI.sim.bb, 10)
local leaked = false
for _ = 1, 8 do local st = disp("step"); if st.intent and st.intent.combo and grappleSet[st.intent.skill] then leaked = true end end
check(not leaked, "C15: no estilo power, nenhuma skill grapple vaza (R3)")

print("== C16: modulação de lag (minGap espaça os golpes) ==")
disp("load", scen({ { x = 21, y = 20, hp = 1e9 } }))
disp("setTree", { type = "sequence", children = {
	{ type = "succeeder", child = { type = "action", name = "AcquireTarget" } },
	{ type = "selector", children = {
		{ type = "action", name = "UseEleanorOffense", params = { style = "power", comboSpheres = 0, window = 5000, minGap = 300 } },
		{ type = "check", name = "InAttackRange", child = { type = "action", name = "AttackTarget" } },
	} },
} })
sys.addSpheres(BRAI.sim.bb, 10)
local castTicks, seenSk = {}, {}
for _ = 1, 24 do
	local s = disp("step")
	if s.intent and s.intent.combo then castTicks[#castTicks + 1] = s.tick; seenSk[s.intent.skill] = true end
end
check(#castTicks >= 3, "C16a: combo completa (>=3 golpes) mesmo com minGap")
local okGap = true
for i = 2, #castTicks do if (castTicks[i] - castTicks[i - 1]) < 300 then okGap = false end end
check(okGap, "C16b: golpes do combo espaçados >= minGap (300ms)")
check(seenSk[SID.MH_SONIC_CLAW] and seenSk[SID.MH_MIDNIGHT_FRENZY], "C16c: cadeia completa (Sonic..Midnight)")

print(string.format("RESULTADO: %d ok, %d falhas", pass, fail))
os.exit(fail == 0 and 0 or 1)
