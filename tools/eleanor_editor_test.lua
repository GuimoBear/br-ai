-- eleanor_editor_test.lua — Fase 4: contrato de dados do painel "Combos da Eleanor".
-- Testa o que o editor consome (comboInfo) e escreve (levels por elo) + o schema do nó.
-- Uso: texlua tools/eleanor_editor_test.lua
local boot = dofile("lua/sim_boot.lua")
local BRAI = boot("lua")
local json, C, SID = BRAI.json, BRAI.const, BRAI.skills.id
local sys = BRAI.skillsys

local pass, fail = 0, 0
local function check(c, n) if c then pass = pass + 1; print("  ok  - " .. n)
	else fail = fail + 1; print("  FAIL- " .. n) end end
local function disp(m, o) return json.decode(SIM_DISPATCH(m, o and json.encode(o) or "")) end

local function eleanorScen()
	return { grid = { w = 40, h = 40 }, dt = 50, homunId = 100, ownerId = 1,
		config = { BaseHomunType = 0, FleeHP = 0 }, homunType = C.ELEANOR, entities = {
			{ id = 1, kind = "owner", x = 5, y = 20, hp = 100000, maxhp = 100000 },
			{ id = 100, kind = "homun", x = 20, y = 20, hp = 100000, maxhp = 100000,
			  sp = 9000, maxsp = 9000, atk = 900, homunType = C.ELEANOR },
			{ id = 200, kind = "monster", x = 21, y = 20, hp = 1e9, maxhp = 1e9,
			  atk = 0, aggressive = false, atkInterval = 100000, etype = 1042 },
		} }
end

print("== E1: comboInfo (dados que o painel consome) ==")
local ci = disp("comboInfo")
check(ci.power and #ci.power == 3 and ci.grapple and #ci.grapple == 3, "E1a: 3 elos em cada cadeia")
check(ci.power[1].cost == 0 and ci.power[2].cost == 1 and ci.power[3].cost == 2, "E1b: custos power 0/1/2")
check(ci.grapple[1].cost == 1 and ci.grapple[2].cost == 1 and ci.grapple[3].cost == 2, "E1c: custos grapple 1/1/2")
check(ci.power[1].iro == "Sonic Claw" and ci.grapple[1].iro == "Tinder Breaker", "E1d: nomes iRO dos iniciadores")
check(ci.power[3].finisher == true and ci.grapple[3].bossForbidden == true, "E1e: finisher + EQC proibido em boss")
check(ci.power[2].maxLevel == 10 and ci.power[1].maxLevel == 5, "E1f: nível máx por elo (Silvervein 10, Sonic 5)")
check(ci.defaults.autoComboSpheres == 5 and ci.defaults.window == 2000, "E1g: defaults (barragem 5, janela 2000)")

print("== E2: nível por elo (o que o painel escreve em params.levels) ==")
disp("setTree", { type = "sequence", children = {
	{ type = "succeeder", child = { type = "action", name = "AcquireTarget" } },
	{ type = "action", name = "UseEleanorOffense", params = { style = "power", comboSpheres = 0, levels = { power = { 1, 1, 1 } } } },
} })
disp("load", eleanorScen()); sys.addSpheres(BRAI.sim.bb, 10)
local lvl
for _ = 1, 4 do local s = disp("step"); if s.intent and s.intent.skill == SID.MH_SONIC_CLAW then lvl = s.intent.level; break end end
check(lvl == 1, "E2a: levels.power[1]=1 aplicado ao Sonic (padrão seria 5)")

disp("setTree", { type = "sequence", children = {
	{ type = "succeeder", child = { type = "action", name = "AcquireTarget" } },
	{ type = "action", name = "UseEleanorOffense", params = { style = "grapple", comboSpheres = 0, levels = { grapple = { 2, 2, 2 } } } },
} })
disp("load", eleanorScen()); sys.addSpheres(BRAI.sim.bb, 10)
local tlvl
for _ = 1, 8 do local s = disp("step"); if s.intent and s.intent.skill == SID.MH_TINDER_BREAKER then tlvl = s.intent.level; break end end
check(tlvl == 2, "E2b: levels.grapple[1]=2 aplicado ao Tinder (keyed por ESTILO)")

print("== E3: schema do nó (paleta/validação do editor) ==")
local meta = disp("registry")["UseEleanorOffense"]
check(meta ~= nil and meta.kind == "action", "E3a: UseEleanorOffense exportado no registry")
local pr = meta and meta.params or {}
check(pr.style and pr.comboSpheres and pr.window and pr.grappleThreatLimit and pr.allowStyleSwitch,
	"E3b: schema expõe style/comboSpheres/window/grappleThreatLimit/allowStyleSwitch")

print(string.format("RESULTADO: %d ok, %d falhas", pass, fail))
os.exit(fail == 0 and 0 or 1)
