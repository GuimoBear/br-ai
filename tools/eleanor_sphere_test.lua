-- eleanor_sphere_test.lua — Fase 1: subsistema de esferas (estimador estilo AzzyAI).
-- Cobre S1..S9 do catálogo (PLANO-COMBOS-ELEANOR.md §9.3).
-- Uso: texlua tools/eleanor_sphere_test.lua
local boot = dofile("lua/sim_boot.lua")
local BRAI = boot("lua")
local json, C, SID = BRAI.json, BRAI.const, BRAI.skills.id
local sys = BRAI.skillsys

local pass, fail = 0, 0
local function check(c, n) if c then pass = pass + 1; print("  ok  - " .. n)
	else fail = fail + 1; print("  FAIL- " .. n) end end
local function disp(m, o) return json.decode(SIM_DISPATCH(m, o and json.encode(o) or "")) end
local function near(a, b) return math.abs((a or -999) - (b or -999)) < 1e-9 end
local function spheres(s) return (s and s.bb and s.bb.self and s.bb.self.spheres) or 0 end

-- cenário Eleanor (52) + 1 monstro. mon.atk=0/passivo isola o ganho por ataque.
local function scen(o)
	o = o or {}; local m = o.mon or {}
	return { grid = { w = 40, h = 40 }, dt = 50, homunId = 100, ownerId = 1,
		config = { BaseHomunType = o.base or 0, FleeHP = 0 },
		homunType = o.htype or C.ELEANOR, baseType = o.base or 0,
		entities = {
			{ id = 1, kind = "owner", x = 5, y = 20, hp = 100000, maxhp = 100000 },
			{ id = 100, kind = "homun", x = 20, y = 20, hp = o.hp or 100000, maxhp = o.hp or 100000,
			  sp = 9000, maxsp = 9000, homunType = o.htype or C.ELEANOR },
			{ id = 200, kind = "monster", x = m.x or 21, y = m.y or 20,
			  hp = m.hp or 1000000, maxhp = m.hp or 1000000, atk = m.atk or 0,
			  aggro = m.aggro or 12, aggressive = m.aggressive or false,
			  atkInterval = m.atkInterval or 100000, etype = 1042 },
		} }
end

local attackTree = { type = "sequence", children = {
	{ type = "succeeder", child = { type = "action", name = "AcquireTarget" } },
	{ type = "selector", children = {
		{ type = "check", name = "InAttackRange", child = { type = "action", name = "AttackTarget" } },
		{ type = "action", name = "ChaseTarget", params = { dist = 1 } },
	} },
} }
local idleTree  = { type = "action", name = "Idle" }
local sonicTree = { type = "sequence", children = {
	{ type = "succeeder", child = { type = "action", name = "AcquireTarget" } },
	{ type = "action", name = "UseSkill", params = { skill = SID.MH_SONIC_CLAW, level = 5 } },
} }

print("== S1: ganho por ataque físico (+0.5/ataque) ==")
disp("load", scen({ mon = { x = 21, atk = 0 } })); disp("setTree", attackTree)
local s1 = disp("step"); local s2 = disp("step")
check(near(spheres(s1), 0.5), "S1a: 1 ataque -> 0.5 esfera")
check(near(spheres(s2), 1.0), "S1b: 2 ataques -> 1.0 esfera")

print("== S3: teto em 10 ==")
disp("load", scen({ mon = { x = 21, atk = 0 } })); disp("setTree", attackTree)
local s; for _ = 1, 30 do s = disp("step") end
check(near(spheres(s), 10), "S3: muitos ataques -> clamp em 10")

print("== S2: ganho por dano recebido (+0.5/dano) ==")
disp("load", scen({ hp = 100000, mon = { x = 21, atk = 50, aggressive = true, atkInterval = 50 } }))
disp("setTree", idleTree)
local d1 = disp("step"); local d2 = disp("step")
check(near(spheres(d1), 0), "S2a: 1º tick ainda sem ganho (dano detectado no próximo)")
check(near(spheres(d2), 0.5), "S2b: dano recebido gera +0.5")

print("== S4: piso em 0 ==")
disp("load", scen({})); local bb = BRAI.sim.bb
sys.addSpheres(bb, -100)
check(near(sys.spheres(bb), 0), "S4: addSpheres(-100) -> clamp em 0")

print("== S5: custo por skill (corrige bug R2 do EQC) + markUsed net ==")
check(sys.sphereCostOf(SID.MH_SONIC_CLAW) == 0,      "S5a: Sonic Claw custa 0")
check(sys.sphereCostOf(SID.MH_SILVERVEIN_RUSH) == 1, "S5b: Silvervein custa 1")
check(sys.sphereCostOf(SID.MH_MIDNIGHT_FRENZY) == 2, "S5c: Midnight custa 2")
check(sys.sphereCostOf(SID.MH_TINDER_BREAKER) == 1,  "S5d: Tinder custa 1")
check(sys.sphereCostOf(SID.MH_CBC) == 1,             "S5e: C.B.C. custa 1")
check(sys.sphereCostOf(SID.MH_EQC) == 2,             "S5f: E.Q.C. custa 2 (R2: AzzyAI não deduzia)")
disp("load", scen({})); bb = BRAI.sim.bb
sys.addSpheres(bb, 5)                                   -- base 5 (sem clamp)
sys.markUsed(bb, SID.MH_MIDNIGHT_FRENZY, 10)           -- ganho +0.5, custo -2 => 3.5
check(near(sys.spheres(bb), 3.5), "S5g: markUsed(Midnight) 5 -> 3.5 (ganho 0.5, custo 2)")
sys.markUsed(bb, SID.MH_SONIC_CLAW, 5)                 -- ganho +0.5, custo 0 => 4.0
check(near(sys.spheres(bb), 4.0), "S5h: markUsed(Sonic) 3.5 -> 4.0 (ganho 0.5, custo 0)")

print("== S6: fail-safe (cast rejeitado -> -1) ==")
disp("load", scen({})); bb = BRAI.sim.bb
sys.addSpheres(bb, 5); sys.noteCastFailed(bb)
check(near(sys.spheres(bb), 4), "S6a: noteCastFailed pune -1 (5 -> 4)")
-- integração: failNextCast no simulador penaliza e não aplica custo/ganho do cast
disp("load", scen({ mon = { x = 21, atk = 0 } })); disp("setTree", sonicTree)
sys.addSpheres(BRAI.sim.bb, 5)
disp("failNextCast")
local sf = disp("step")
check(near(spheres(sf), 4), "S6b: failNextCast -> esfera -1 e sem efeito de cast (5 -> 4)")

print("== S7: reset ao reinvocar ==")
local sc7 = scen({ mon = { x = 21, atk = 0 } })
disp("load", sc7); disp("setTree", attackTree); disp("step"); disp("step")
disp("load", sc7)                                       -- recarrega -> nova bb
check(near(spheres(disp("snapshot")), 0), "S7: recarregar zera a estimativa")

print("== S8: não-Eleanor não acumula ==")
disp("load", scen({ htype = C.FILIR, mon = { x = 21, atk = 0 } })); disp("setTree", attackTree)
for _ = 1, 5 do s = disp("step") end
check(near(spheres(s), 0), "S8: Filir (não-Eleanor) não acumula esferas")

print("== S9: invariante 0<=esferas<=10 (fuzz) ==")
disp("load", scen({}))
local bb2 = BRAI.Blackboard.new(); bb2.self.homunType = C.ELEANOR; bb2.self.hp = 1000
local deltas, okInv = { -2, -1, -0.5, 0.5, 1, 2 }, true
math.randomseed(12345)
for _ = 1, 1000 do
	sys.addSpheres(bb2, deltas[math.random(#deltas)])
	local v = sys.spheres(bb2)
	if v < 0 or v > 10 then okInv = false; break end
end
check(okInv, "S9: 0<=esferas<=10 sob 1000 deltas aleatórios")

print("== S10/S11: snapshot expõe bloco 'eleanor' (p/ a visualização do simulador) ==")
disp("load", scen({ mon = { x = 21, atk = 0 } })); disp("setTree", attackTree)
sys.addSpheres(BRAI.sim.bb, 3)
local snp = disp("step")
check(snp.eleanor ~= nil, "S10a: snapshot.eleanor presente p/ Eleanor")
check(type(snp.eleanor.spheres) == "number" and snp.eleanor.style == "power", "S10b: traz spheres (number) e style")
disp("load", scen({ htype = C.FILIR, mon = { x = 21, atk = 0 } }))
check(disp("step").eleanor == nil, "S11: snapshot.eleanor ausente p/ não-Eleanor (Filir)")

print(string.format("RESULTADO: %d ok, %d falhas", pass, fail))
os.exit(fail == 0 and 0 or 1)
