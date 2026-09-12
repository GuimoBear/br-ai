-- eleanor_lvl200_test.lua — contrato das skills 200+ da Eleanor (não são elos de combo).
-- Cobre UseEleanorOffense (off / fillThenCombo / aoeDump), UseAoESkill (aoeAtk) e o
-- seletor com os dois nós. Uso: texlua tools/eleanor_lvl200_test.lua
local boot = dofile("lua/sim_boot.lua")
local BRAI = boot("lua")
local json, C, SID = BRAI.json, BRAI.const, BRAI.skills.id
local sys = BRAI.skillsys
local ST = BRAI.status

local pass, fail = 0, 0
local function check(c, n) if c then pass = pass + 1; print("  ok  - " .. n)
	else fail = fail + 1; print("  FAIL- " .. n) end end
local function disp(m, o) return json.decode(SIM_DISPATCH(m, o and json.encode(o) or "")) end

local ONE, BLAZE = SID.MH_THE_ONE_FIGHTER_RISES, SID.MH_BLAZING_AND_FURIOUS
local SONIC, SILVER = SID.MH_SONIC_CLAW, SID.MH_SILVERVEIN_RUSH

local function scen(opts)
	opts = opts or {}
	local nMons = opts.mobs or 1
	local ents = {
		{ id = 1, kind = "owner", x = 5, y = 20, hp = 100000, maxhp = 100000 },
		{ id = 100, kind = "homun", x = 20, y = 20, hp = 100000, maxhp = 100000,
		  sp = 9000, maxsp = 9000, atk = 900, homunType = C.ELEANOR, lvl = opts.lvl },
	}
	for i = 1, nMons do
		ents[#ents + 1] = { id = 200 + i, kind = "monster",
			x = 21 + ((i - 1) % 2), y = 20 + math.floor((i - 1) / 2),
			hp = 1e9, maxhp = 1e9, atk = 0, aggro = 12, aggressive = false,
			atkInterval = 100000, etype = 1042 }
	end
	return { grid = { w = 40, h = 40 }, dt = 50, homunId = 100, ownerId = 1,
		config = { BaseHomunType = 0, FleeHP = 0, AggroDist = 14, AutoMobCount = opts.amc or 2,
			AutoMobMode = opts.amm, UseAttackSkill = true },
		homunType = C.ELEANOR, entities = ents }
end

local function offenseTree(params)
	return { type = "sequence", children = {
		{ type = "succeeder", child = { type = "action", name = "AcquireTarget" } },
		{ type = "action", name = "UseEleanorOffense", params = params },
	} }
end
local function aoeTree(aoeParams)
	return { type = "sequence", children = {
		{ type = "succeeder", child = { type = "action", name = "AcquireTarget" } },
		{ type = "action", name = "UseAoESkill", params = aoeParams or {} },
	} }
end
local function bothTree(offParams)
	return { type = "sequence", children = {
		{ type = "succeeder", child = { type = "action", name = "AcquireTarget" } },
		{ type = "selector", children = {
			{ type = "action", name = "UseAoESkill", params = {} },
			{ type = "action", name = "UseEleanorOffense", params = offParams },
		} },
	} }
end

local function bootScen(s, tree, spheres)
	disp("setTree", tree)
	disp("load", s)
	if spheres and spheres ~= 0 then sys.addSpheres(BRAI.sim.bb, spheres) end
	return BRAI.sim.bb
end

local function skillsOf(n)
	local seq = {}
	for _ = 1, n do
		local st = disp("step")
		if st.intent and st.intent.kind == "skill" then seq[#seq + 1] = st.intent end
	end
	return seq
end
local function firstSkill(n)
	for _ = 1, (n or 8) do
		local st = disp("step")
		if st.intent and st.intent.kind == "skill" then return st.intent, st end
	end
	return nil, disp("snapshot")
end
local function nodeStatus(snap, name)
	for _, n in ipairs((snap and snap.tree) or {}) do
		if n.name == name then return n.status end
	end
end

disp("setSkillChoice", { choices = {} })

print("== UseEleanorOffense: lvl200Mode=off ==")
bootScen(scen({ mobs = 1, lvl = 230 }), offenseTree({ style = "power", comboSpheres = 0, window = 2000, lvl200Mode = "off" }), 10)
local seq = skillsOf(6)
local saw200, sawSonic = false, false
for _, it in ipairs(seq) do
	if it.skill == ONE or it.skill == BLAZE then saw200 = true end
	if it.skill == SONIC then sawSonic = true end
end
check(sawSonic, "off + lvl 230: inicia cadeia clássica (Sonic)")
check(not saw200, "off + lvl 230: nunca 8050/8051")

print("== UseEleanorOffense: fillThenCombo ==")
bootScen(scen({ mobs = 1, lvl = 230 }), offenseTree({ style = "power", comboSpheres = 0, window = 2000,
	lvl200Mode = "fillThenCombo", theOneWhenSpheresBelow = 3 }), 1)
local it = firstSkill(6)
check(it and it.skill == ONE, "fillThenCombo + 1 alvo + esferas baixas → The One")
check(it and it.combo == nil, "intent 8051 sem campo combo")
check(it and it.mode == 0, "The One: mode == 0 (self)")
check(sys.spheres(BRAI.sim.bb) == 10, "The One enche esferas ao máximo")
it = firstSkill(8)
check(it and it.skill == SONIC and it.combo == "power", "depois do fill: Power com esferas cheias")

bootScen(scen({ mobs = 1, lvl = 230 }), offenseTree({ style = "power", comboSpheres = 0, window = 2000,
	lvl200Mode = "fillThenCombo" }), 10)
local seq2 = skillsOf(4)
local sawBlaze, sawSonic2, sawOne = false, false, false
for _, x in ipairs(seq2) do
	if x.skill == BLAZE then sawBlaze = true end
	if x.skill == SONIC then sawSonic2 = true end
	if x.skill == ONE then sawOne = true end
end
check(sawSonic2, "fillThenCombo + 1 alvo + esferas altas → inicia combo")
check(not sawBlaze and not sawOne, "fillThenCombo + 1 alvo + esferas altas → não Blazing/The One")

print("== UseEleanorOffense: aoeDump ==")
bootScen(scen({ mobs = 3, lvl = 230 }), offenseTree({ style = "power", comboSpheres = 0, window = 2000,
	lvl200Mode = "aoeDump", blazingMinSpheres = 5 }), 3)
local iOne, iBlaze, sphAfterBlaze
for _ = 1, 10 do
	local st = disp("step")
	local x = st.intent
	if x and x.kind == "skill" then
		if x.skill == ONE and not iOne then iOne = x end
		if x.skill == BLAZE and not iBlaze then
			iBlaze = x
			sphAfterBlaze = sys.spheres(BRAI.sim.bb)
			break
		end
	end
end
check(iOne ~= nil, "aoeDump + 3 mobs → The One")
check(iBlaze ~= nil, "aoeDump + 3 mobs → Blazing depois")
check(iOne and iOne.combo == nil and iBlaze and iBlaze.combo == nil, "intents 8050/8051 sem campo combo")
check(iBlaze and iBlaze.mode == 1, "Blazing: mode == 1 (inimigo)")
check(sphAfterBlaze == 0, "aoeDump: esferas 10→0 após Blazing")

print("== combo no meio da janela não é interrompido ==")
bootScen(scen({ mobs = 3, lvl = 230 }), offenseTree({ style = "power", comboSpheres = 0, window = 2000,
	lvl200Mode = "fillThenCombo" }), 10)
local bb = BRAI.sim.bb
bb.target = 201
BRAI.perception.update(bb, 100)
bb.target = 201
bb.persist.combo = { key = "power", step = 1, at = bb:now(), targetId = 201 }
bb.persist.style = "power"
check(BRAI.eleanor.tryLvl200(bb, { lvl200Mode = "fillThenCombo" }, 2) == false, "tryLvl200(step=2) recusa")
it = firstSkill(4)
check(it and it.skill == SILVER, "step 2 da janela → Silvervein, não 8051")
check(not (it and (it.skill == ONE or it.skill == BLAZE)), "meio da cadeia não aborta p/ 200+")

print("== interruptCombo: elo 1 da próxima janela (não o meio) ==")
bootScen(scen({ mobs = 3, lvl = 230 }), offenseTree({ style = "power", comboSpheres = 0, window = 2000,
	lvl200Mode = "fillThenCombo", interruptCombo = true }), 10)
it = firstSkill(4)
check(it and it.skill == ONE, "interruptCombo + cluster no elo 1 → The One (não o meio)")

print("== nível do homúnculo (learned) ==")
bootScen(scen({ mobs = 3, lvl = 200 }), offenseTree({ style = "power", comboSpheres = 0, window = 2000,
	lvl200Mode = "aoeDump" }), 10)
seq = skillsOf(6)
saw200 = false
for _, x in ipairs(seq) do if x.skill == ONE or x.skill == BLAZE then saw200 = true end end
check(not saw200, "lvl 200: não emite 8050/8051 (não aprendidas)")

bootScen(scen({ mobs = 3, lvl = 215 }), offenseTree({ style = "power", comboSpheres = 0, window = 2000,
	lvl200Mode = "aoeDump" }), 10)
seq = skillsOf(6)
local sawOne215, sawBlaze215 = false, false
for _, x in ipairs(seq) do
	if x.skill == ONE then sawOne215 = true end
	if x.skill == BLAZE then sawBlaze215 = true end
end
check(not sawOne215, "lvl 215: The One ainda não")
check(sawBlaze215, "lvl 215: Blazing possível")

print("== Blazing com 0 esferas ==")
bootScen(scen({ mobs = 3, lvl = 230 }), offenseTree({ style = "power", comboSpheres = 0, window = 2000,
	lvl200Mode = "aoeDump", blazingMinSpheres = 5 }), 0)
bb = BRAI.sim.bb
bb.persist.skillReadyAt = bb.persist.skillReadyAt or {}
bb.persist.skillReadyAt[ONE] = bb:now() + 100000   -- The One em CD, sem fill
check(sys.spheres(bb) < 1, "cenário começa com 0 esferas")
check(not BRAI.eleanor.aoeUsable(bb, BLAZE), "aoeUsable(Blazing) falso com 0 esferas")
seq = skillsOf(6)
sawBlaze = false
for _, x in ipairs(seq) do if x.skill == BLAZE then sawBlaze = true end end
check(not sawBlaze, "0 esferas + The One em CD → não emite Blazing")

print("== UseAoESkill (sem combar) ==")
bootScen(scen({ mobs = 3, lvl = 230 }), aoeTree(), 5)
it = firstSkill(4)
check(it and it.skill == ONE, "AoE + 3 mobs + lvl 230 → The One se ready")
check(it and it.mode == 0, "AoE The One: mode == 0")
it = firstSkill(6)
check(it and it.skill == BLAZE, "The One em CD → Blazing")
check(it and it.mode == 1, "AoE Blazing: mode == 1")
check(it and it.combo == nil, "AoE 8050 sem campo combo")

bootScen(scen({ mobs = 1, lvl = 230 }), aoeTree({ AutoMobCount = 2 }), 10)
seq = skillsOf(6)
saw200 = false
for _, x in ipairs(seq) do if x.skill == ONE or x.skill == BLAZE then saw200 = true end end
check(not saw200, "1 mob + AutoMobCount=2: UseAoESkill FAILURE (Eleanor tem mainAtk)")

bootScen(scen({ mobs = 3, lvl = 230 }), aoeTree(), 0)
bb = BRAI.sim.bb
bb.persist.skillReadyAt = bb.persist.skillReadyAt or {}
bb.persist.skillReadyAt[ONE] = bb:now() + 100000
seq = skillsOf(6)
sawBlaze = false
for _, x in ipairs(seq) do if x.skill == BLAZE then sawBlaze = true end end
check(not sawBlaze, "0 esferas + The One em CD: gate consumeAll pula Blazing")

disp("setSkillChoice", { choices = { ["52"] = { aoeAtk = { BLAZE } } } })
bootScen(scen({ mobs = 3, lvl = 230 }), aoeTree(), 10)
it = firstSkill(4)
check(it and it.skill == BLAZE, "override aoeAtk={8050} → só Blazing")
check(not (it and it.skill == ONE), "override não emite The One")

disp("setSkillChoice", { choices = { ["52"] = { aoeAtk = {} } } })
local eaoe = BRAI.actionSkills({ self = { homunType = C.ELEANOR }, config = { BaseHomunType = 0 } }, "UseAoESkill")
check(eaoe and eaoe.state == "none", "override aoeAtk={} → estado none")
bootScen(scen({ mobs = 3, lvl = 230 }), aoeTree(), 10)
it = firstSkill(4)
check(not (it and (it.skill == ONE or it.skill == BLAZE)), "aoeAtk vazio: não dispara")
disp("setSkillChoice", { choices = {} })

bootScen(scen({ mobs = 3, lvl = 230, amm = 0 }), aoeTree(), 10)
it = firstSkill(4)
check(not (it and (it.skill == ONE or it.skill == BLAZE)), "AutoMobMode=0 → não dispara")

print("== CD The One nv10 = 2000ms ==")
disp("setSkillChoice", { choices = { ["52"] = { aoeAtk = { ONE } } } })
bootScen(scen({ mobs = 3, lvl = 230 }), aoeTree(), 10)
it = firstSkill(4)
check(it and it.skill == ONE, "primeiro The One")
check(sys.reuse(ONE, 10) == 2000, "reuse nv10 = 2000ms")
check(not sys.ready(BRAI.sim.bb, ONE), "segundo cast recusado enquanto reuse não passou")
local t0 = BRAI.sim.bb:now()
local recastAt = nil
for _ = 1, 50 do
	local st = disp("step")
	if st.intent and st.intent.skill == ONE then recastAt = BRAI.sim.bb:now(); break end
end
check(recastAt ~= nil, "recastou The One depois do reuse")
check(recastAt and (recastAt - t0) >= 2000, "intervalo até o 2º cast ≥ 2000ms")
disp("setSkillChoice", { choices = {} })

print("== seletor UseAoESkill acima de UseEleanorOffense ==")
bootScen(scen({ mobs = 3, lvl = 230 }), bothTree({ style = "power", comboSpheres = 0, window = 2000,
	lvl200Mode = "fillThenCombo" }), 10)
local snap
it, snap = firstSkill(6)
check(it and it.skill == ONE, "cluster: The One")
check(nodeStatus(snap, "UseAoESkill") == ST.SUCCESS, "cluster: UseAoESkill come o tick")
check(nodeStatus(snap, "UseEleanorOffense") ~= ST.SUCCESS, "cluster: UseEleanorOffense não dispara no mesmo tick")

bootScen(scen({ mobs = 1, lvl = 230 }), bothTree({ style = "power", comboSpheres = 0, window = 2000,
	lvl200Mode = "fillThenCombo" }), 10)
it, snap = firstSkill(6)
check(it and it.skill == SONIC, "1 alvo + esferas altas: guarda-chuva faz combo")
check(nodeStatus(snap, "UseAoESkill") == ST.FAILURE, "1 alvo: AoE falha (AutoMobCount)")
check(nodeStatus(snap, "UseEleanorOffense") == ST.SUCCESS, "1 alvo: UseEleanorOffense vence")

bootScen(scen({ mobs = 1, lvl = 230 }), bothTree({ style = "power", comboSpheres = 0, window = 2000,
	lvl200Mode = "fillThenCombo", theOneWhenSpheresBelow = 3 }), 1)
it = firstSkill(6)
check(it and it.skill == ONE, "1 alvo + esferas baixas: fillThenCombo no guarda-chuva")

print("== parse / comboInfo / schema ==")
check(BRAI.eleanor.lvl200ModeOf({ lvl200Mode = "fillThenCombo" }) == "fillThenCombo", "lvl200ModeOf fillThenCombo")
check(BRAI.eleanor.lvl200ModeOf({}) == "off", "ausente = off (árvores antigas)")
check(BRAI.eleanor.lvl200ModeOf({ lvl200Mode = "banana" }) == "off", "inválido = off")
local ci = BRAI.comboInfo()
check(ci.lvl200 and ci.lvl200.theOne.id == ONE and ci.lvl200.blazing.id == BLAZE, "comboInfo.lvl200 ids")
check(ci.lvl200.theOne.sphereOp == "fillMax" and ci.lvl200.blazing.sphereOp == "consumeAll", "comboInfo sphereOp")
check(ci.lvl200.theOne.maxLevel == 10 and ci.lvl200.blazing.reqLevel == 215, "comboInfo maxLevel/reqLevel")
local meta = disp("registry")["UseEleanorOffense"]
check(meta and meta.params and meta.params.lvl200Mode == "string", "registry expõe lvl200Mode")
check(sys.delay(ONE, 10) == 500 and sys.reuse(ONE, 1) == 3800, "timings The One (delay 500, reuse 3800→2000)")

print(string.format("RESULTADO: %d ok, %d falhas", pass, fail))
os.exit(fail == 0 and 0 or 1)
