-- skillactions_test.lua — testa as acoes de skill do editor divididas por tipo:
-- UseSkill (alvo unico), UseSkill (solo: on=owner|enemy) e UseSkillBuff (self).
-- Uso: texlua tools/skillactions_test.lua
local boot = dofile("lua/sim_boot.lua")
local BRAI = boot("lua")
local json = BRAI.json
local C = BRAI.const
local SID = BRAI.skills.id

local pass, fail = 0, 0
local function check(c, n) if c then pass = pass + 1; print("  ok  - " .. n)
	else fail = fail + 1; print("  FAIL- " .. n) end end

local function disp(method, obj)
	return json.decode(SIM_DISPATCH(method, obj and json.encode(obj) or ""))
end

-- monta um cenario simples: dono, homun e monstros
local function scenario(homun, mons, ownerXY)
	local o = ownerXY or { x = 10, y = 10 }
	local ents = {
		{ id = 1, kind = "owner", x = o.x, y = o.y, hp = 1000, maxhp = 1000 },
		{ id = 100, kind = "homun", x = 20, y = 20, hp = 800, maxhp = 800, sp = 800, maxsp = 800, homunType = homun },
	}
	for i, m in ipairs(mons or {}) do
		ents[#ents + 1] = { id = 200 + i, kind = "monster", x = m.x, y = m.y, hp = 300, maxhp = 300, atk = 1, aggro = 1 }
	end
	return { grid = { w = 40, h = 40 }, dt = 50, homunId = 100, ownerId = 1, entities = ents }
end

-- roda ate N ticks e devolve o primeiro snapshot cujo intent casa com pred
local function runUntil(pred, n)
	for _ = 1, (n or 8) do
		local s = disp("step")
		if pred(s.intent) then return s end
	end
	return disp("snapshot")
end

-- arvore: garante alvo (succeeder sobre aquisicao) e entao executa a acao dada
local function combatTree(name, params)
	return {
		type = "sequence", label = "t",
		children = {
			{ type = "succeeder", child = { type = "action", name = "AcquireTarget" } },
			{ type = "action", name = name, params = params },
		},
	}
end

print("== acoes de skill divididas por tipo ==")

-- 1) UseSkill: Sera + Needle of Paralysis (alvo unico) num monstro adjacente
disp("setTree", combatTree("UseSkill", { skill = SID.MH_NEEDLE_OF_PARALYZE, level = 5 }))
disp("load", scenario(C.SERA, { { x = 21, y = 20 } }))
local s = runUntil(function(it) return it and it.kind == "skill" and it.skill == SID.MH_NEEDLE_OF_PARALYZE end)
check(s.intent and s.intent.skill == SID.MH_NEEDLE_OF_PARALYZE, "single: emite skill Needle of Paralysis")
check(s.intent and s.intent.mode == 1, "single: mode 1 (alvo unico)")
check(s.intent and s.intent.target == 201, "single: alvo e o monstro (id 201)")

-- 2) UseSkill on=enemy: Sera + Poison Mist centrada no monstro-alvo
disp("setTree", combatTree("UseSkill", { skill = SID.MH_POISON_MIST, level = 3, on = "enemy" }))
disp("load", scenario(C.SERA, { { x = 22, y = 20 } }))
s = runUntil(function(it) return it and it.kind == "skill" and it.skill == SID.MH_POISON_MIST end)
check(s.intent and s.intent.mode == 2, "ground/enemy: mode 2 (solo)")
check(s.intent and s.intent.x == 22 and s.intent.y == 20, "ground/enemy: centrada na posicao do monstro (22,20)")
check(s.intent and s.intent.on == "enemy", "ground/enemy: campo on=enemy")

-- 3) UseSkill on=owner: Poison Mist centrada no dono (sem precisar de alvo)
--    Coloca o dono perto do homun (alcance da skill = 5).
disp("setTree", { type = "action", name = "UseSkill", params = { skill = SID.MH_POISON_MIST, level = 3, on = "owner" } })
disp("load", scenario(C.SERA, {}, { x = 22, y = 22 }))
s = runUntil(function(it) return it and it.kind == "skill" and it.skill == SID.MH_POISON_MIST end)
check(s.intent and s.intent.mode == 2, "ground/owner: mode 2 (solo)")
check(s.intent and s.intent.x == 22 and s.intent.y == 22, "ground/owner: centrada na posicao do dono (22,22)")
check(s.intent and s.intent.on == "owner", "ground/owner: campo on=owner")

-- 4) UseSkill on=owner deve FALHAR se o dono estiver fora de alcance
disp("setTree", { type = "action", name = "UseSkill", params = { skill = SID.MH_POISON_MIST, level = 3, on = "owner" } })
disp("load", scenario(C.SERA, {}, { x = 1, y = 1 }))   -- dono longe
s = runUntil(function(it) return it and it.kind == "skill" end, 4)
check(not (s.intent and s.intent.kind == "skill"), "ground/owner: nao lanca com dono fora de alcance")

-- 5) UseSkillBuff: Dieter + Tempering (self), sem alvo
disp("setTree", { type = "action", name = "UseSkillBuff", params = { skill = SID.MH_TEMPERING, level = 1 } })
disp("load", scenario(C.DIETER, {}))
s = runUntil(function(it) return it and it.kind == "skill" and it.skill == SID.MH_TEMPERING end)
check(s.intent and s.intent.mode == 0, "buff: mode 0 (self)")
check(s.intent and s.intent.target == 100, "buff: alvo e o proprio homun (id 100)")

-- 6) UseSkillBuff nao recasta enquanto o buff esta ativo (segundo cast falha)
local before = s.tick
local s2 = runUntil(function(it) return it and it.kind == "skill" and it.skill == SID.MH_TEMPERING end, 3)
check(s2.tick == before or not (s2.intent and s2.intent.skill == SID.MH_TEMPERING and s2.tick > before),
	"buff: nao recasta enquanto ativo")

-- 7) Diagnóstico: skill de outro homúnculo gera log explicativo (não falha calado)
disp("setTree", combatTree("UseSkill", { skill = SID.MH_NEEDLE_OF_PARALYZE, level = 5 }))
disp("load", scenario(C.VANILMIRTH, { { x = 21, y = 20 } }))   -- Vanilmirth nao conhece Needle
local logged = false
for _ = 1, 6 do
	local sn = disp("step")
	for _, l in ipairs(sn.log or {}) do
		if l:find("UseSkill", 1, true) and l:find("nao conhece", 1, true) then logged = true end
	end
end
check(logged, "diagnostico: registra no log que o homunculo nao conhece a skill")

-- 8) UseSkill sem alvo registra 'sem alvo'
disp("setTree", { type = "action", name = "UseSkill", params = { skill = SID.MH_NEEDLE_OF_PARALYZE, level = 5 } })
disp("load", scenario(C.SERA, {}))   -- Sera conhece, mas sem monstros
local noTarget = false
for _ = 1, 4 do
	local sn = disp("step")
	for _, l in ipairs(sn.log or {}) do if l:find("sem alvo", 1, true) then noTarget = true end end
end
check(noTarget, "diagnostico: registra 'sem alvo' quando nao ha alvo")

-- 9/10) cooldown só é consumido quando o intent da skill é REALMENTE aplicado.
-- Cenário do usuário: Dieter base Amistr + Blast Forge (alcance 1) com monstro adjacente.
local function combatRoot(innerType)
	return { type="selector", children={
		{ type="check", name="HasValidTarget", child={ type=innerType, children={
			{ type="action", name="UseSkill", params={ skill=SID.MH_BLAST_FORGE, level=10 } },
			{ type="check", name="InAttackRange", child={ type="action", name="AttackTarget" } },
		} } },
		{ type="check", name="CanEngage", child={ type="action", name="AcquireTarget" } },
		{ type="action", name="Idle" },
	} }
end
local function dieterScen()
	return { grid={w=40,h=40}, dt=50, homunId=100, ownerId=1, config={ BaseHomunType=C.AMISTR }, entities={
		{ id=1, kind="owner", x=18, y=20, hp=1000, maxhp=1000 },
		{ id=100, kind="homun", x=20, y=20, hp=900, maxhp=900, sp=900, maxsp=900, homunType=C.DIETER },
		{ id=200, kind="monster", x=21, y=20, hp=900, maxhp=900, atk=1, aggro=1, atkInterval=100000 },
	} }
end
local function cdCount(snap) return snap.skills and snap.skills.cooldowns and #snap.skills.cooldowns or 0 end

-- SEQUENCE: a skill seta o intent, mas AttackTarget o sobrescreve -> skill NUNCA aplica,
-- logo o cooldown NÃO pode ser consumido (era o bug).
disp("setTree", combatRoot("sequence"))
disp("load", dieterScen())
local castedSeq, cdSeq = false, 0
for _=1,12 do local sn=disp("step"); if sn.intent and sn.intent.skill==SID.MH_BLAST_FORGE then castedSeq=true end; cdSeq=math.max(cdSeq, cdCount(sn)) end
check(not castedSeq, "sequence: Blast Forge nao chega a ser aplicada (sobrescrita pelo ataque)")
check(cdSeq == 0, "sequence: cooldown NAO e consumido sem aplicar a skill (bug corrigido)")

-- SELECTOR: a skill vence e o intent sobrevive -> ela aplica e o cooldown passa a valer.
disp("setTree", combatRoot("selector"))
disp("load", dieterScen())
local castedSel, cdSel = false, 0
for _=1,12 do local sn=disp("step"); if sn.intent and sn.intent.skill==SID.MH_BLAST_FORGE then castedSel=true end; cdSel=math.max(cdSel, cdCount(sn)) end
check(castedSel, "selector: Blast Forge e realmente lancada")
check(cdSel >= 1, "selector: cooldown passa a valer depois do cast aplicado")

-- 11) Checagem de ALCANCE interna (UseSkill modo solo): nao lanca com alvo longe; lanca perto.
local function dieterMon(mx)
	return { grid={w=40,h=40}, dt=50, homunId=100, ownerId=1, entities={
		{ id=1, kind="owner", x=18, y=20, hp=1000, maxhp=1000 },
		{ id=100, kind="homun", x=20, y=20, hp=900, maxhp=900, sp=900, maxsp=900, homunType=C.DIETER },
		{ id=200, kind="monster", x=mx, y=20, hp=900, maxhp=900, atk=0, aggro=1, atkInterval=100000 },  -- passivo
	} }
end
disp("setTree", combatTree("UseSkill", { skill = SID.MH_BLAST_FORGE, level = 10 }))
disp("load", dieterMon(26))   -- alvo a 6 celulas (Blast Forge tem alcance 1)
local farCast=false
for _=1,5 do local sn=disp("step"); if sn.intent and sn.intent.kind=="skill" then farCast=true end end
check(not farCast, "UseSkill(solo): nao lanca com alvo fora de alcance (checagem interna)")

disp("setTree", combatTree("UseSkill", { skill = SID.MH_BLAST_FORGE, level = 10 }))
disp("load", dieterMon(21))   -- alvo adjacente
local nearCast=false
for _=1,6 do local sn=disp("step"); if sn.intent and sn.intent.skill==SID.MH_BLAST_FORGE then nearCast=true end end
check(nearCast, "UseSkill(solo): lanca quando o alvo esta no alcance")

-- 12) Checagem de COOLDOWN interna: apos lancar, fica em recarga (nao relanca no tick seguinte).
disp("setTree", combatTree("UseSkill", { skill = SID.MH_NEEDLE_OF_PARALYZE, level = 5 }))
disp("load", scenario(C.SERA, { { x = 21, y = 20 } }))
local firstCast, blockedAfter = false, false
for _=1,8 do
	local sn=disp("step")
	local isCast = sn.intent and sn.intent.skill==SID.MH_NEEDLE_OF_PARALYZE
	if firstCast and not isCast then blockedAfter=true end
	if isCast then firstCast=true end
end
check(firstCast and blockedAfter, "cooldown interno: apos lancar, fica em recarga (nao relanca todo tick)")

print(string.format("RESULTADO: %d ok, %d falhas", pass, fail))
os.exit(fail == 0 and 0 or 1)
