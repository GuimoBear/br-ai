-- lvl200_skills_test.lua — skills lvl 200+ dos homúns S (Twister/Zephyr, Toxin/Stinger,
-- Glanzen/Pferd/Goldene Tone): dados, catálogo/papéis e comportamento (Goldene Tone é
-- self-cast que vale p/ o dono; Heilige Pferd é AoE centrada no caster). As passivas
-- 8046/8049/8052/8055 ficam fora de propósito (entram só como stats, não como ações).
-- Uso: texlua tools/lvl200_skills_test.lua
local boot = dofile("lua/sim_boot.lua")
local BRAI = boot("lua")
local json = BRAI.json
local C = BRAI.const
local SID = BRAI.skills.id
local sys = BRAI.skillsys

local pass, fail = 0, 0
local function check(c, n) if c then pass = pass + 1; print("  ok  - " .. n)
	else fail = fail + 1; print("  FAIL- " .. n) end end
local function disp(method, obj)
	return json.decode(SIM_DISPATCH(method, obj and json.encode(obj) or ""))
end
local function runUntil(pred, n)
	for _ = 1, (n or 8) do
		local s = disp("step")
		if pred(s.intent) then return s end
	end
	return disp("snapshot")
end

print("== dados ==")
check(SID.MH_TWISTER_CUTTER == 8047 and SID.MH_ABSOLUTE_ZEPHYR == 8048, "ids Eira 8047/8048")
check(SID.MH_TOXIN_OF_MANDARA == 8053 and SID.MH_NEEDLE_STINGER == 8054, "ids Sera 8053/8054")
check(SID.MH_GLANZEN_SPIES == 8056 and SID.MH_HEILIGE_PFERD == 8057 and SID.MH_GOLDENE_TONE == 8058, "ids Bayeri 8056-8058")
check(SID.MH_CLASSY_FLUTTER == nil and SID.MH_BRUSHUP_CLAW == nil, "passivas ficam fora (decisao de design)")
check(sys.spCost(SID.MH_ABSOLUTE_ZEPHYR, 10) == 185, "Zephyr SP nv10 = 185")
check(sys.aoeSize(SID.MH_ABSOLUTE_ZEPHYR, 1) == 3 and sys.aoeSize(SID.MH_ABSOLUTE_ZEPHYR, 10) == 9, "Zephyr AoE cresce 3x3 -> 9x9")
check(sys.aoeSize(SID.MH_TOXIN_OF_MANDARA, 4) == 5, "Toxin AoE nv4 = 5x5")
check(sys.aoeSize(SID.MH_HEILIGE_PFERD, 10) == 7 and sys.aoeCenter(SID.MH_HEILIGE_PFERD) == 1, "Pferd AoE 7x7 nv10, centrada no caster")
check(sys.targetMode(SID.MH_GOLDENE_TONE) == 0 and sys.duration(SID.MH_GOLDENE_TONE, 10) == 120000, "Goldene Tone self, duracao 120s nv10")
check(BRAI.skills.list[C.EIRA][SID.MH_TWISTER_CUTTER] == 10, "Eira conhece Twister nv10")
check(BRAI.skills.list[C.SERA][SID.MH_NEEDLE_STINGER] == 10, "Sera conhece Stinger nv10")
check(BRAI.skills.list[C.BAYERI][SID.MH_GOLDENE_TONE] == 10, "Bayeri conhece Goldene Tone nv10")
check(BRAI.skillFx[SID.MH_TWISTER_CUTTER].dmg[10] == 4800, "fx Twister 4800% nv10")
check(BRAI.skillFx[SID.MH_HEILIGE_PFERD].dmg[10] == 4700, "fx Pferd 4700% nv10")

print("== catalogo / papeis ==")
local function roleOf(t, role)
	local rc = BRAI.roleConfig(t)
	for _, r in ipairs(rc) do if r.key == role then return r end end
end
local function hasId(lst, id) for _, e in ipairs(lst or {}) do if e.id == id then return true end end return false end
check(hasId(roleOf(C.EIRA, "mainAtk").candidates, SID.MH_TWISTER_CUTTER), "Twister candidato mainAtk da Eira")
check(hasId(roleOf(C.EIRA, "aoeAtk").candidates, SID.MH_ABSOLUTE_ZEPHYR), "Zephyr candidato aoeAtk da Eira")
check(hasId(roleOf(C.SERA, "aoeAtk").candidates, SID.MH_TOXIN_OF_MANDARA), "Toxin candidato aoeAtk da Sera")
check(hasId(roleOf(C.SERA, "mainAtk").candidates, SID.MH_NEEDLE_STINGER), "Stinger candidato mainAtk da Sera")
check(hasId(roleOf(C.BAYERI, "mainAtk").candidates, SID.MH_GLANZEN_SPIES), "Glanzen candidato mainAtk do Bayeri")
check(hasId(roleOf(C.BAYERI, "aoeAtk").candidates, SID.MH_HEILIGE_PFERD), "Pferd candidato aoeAtk do Bayeri")
local ob = roleOf(C.BAYERI, "ownerBuff")
check(ob and ob.fixed == true and hasId(ob.effective, SID.MH_GOLDENE_TONE), "Goldene Tone no papel fixo ownerBuff do Bayeri")
check(roleOf(C.EIRA, "mainAtk").defaultIds[1] == SID.MH_ERASER_CUTTER, "padrao mainAtk da Eira segue Eraser Cutter")
check(roleOf(C.BAYERI, "aoeAtk").defaultIds[1] == SID.MH_HEILIGE_STANGE, "padrao aoeAtk do Bayeri segue Heilige Stange")

print("== comportamento ==")
local function scenario(homun, mons, ownerXY)
	local o = ownerXY or { x = 5, y = 5 }
	local ents = {
		{ id = 1, kind = "owner", x = o.x, y = o.y, hp = 1000, maxhp = 1000 },
		{ id = 100, kind = "homun", x = 20, y = 20, hp = 800, maxhp = 800, sp = 800, maxsp = 800, homunType = homun },
	}
	for i, m in ipairs(mons or {}) do
		ents[#ents + 1] = { id = 200 + i, kind = "monster", x = m.x, y = m.y, hp = 300, maxhp = 300, atk = 1, aggro = 1 }
	end
	return { grid = { w = 40, h = 40 }, dt = 50, homunId = 100, ownerId = 1, entities = ents }
end
-- Goldene Tone: dono LONGE (15 celulas) nao bloqueia, pois o cast e em si mesmo
disp("setTree", { type = "action", name = "UseOwnerBuff", params = { UseOwnerBuff = true } })
disp("load", scenario(C.BAYERI))
local s = runUntil(function(it) return it and it.kind == "skill" and it.skill == SID.MH_GOLDENE_TONE end)
check(s.intent and s.intent.skill == SID.MH_GOLDENE_TONE, "UseOwnerBuff emite Goldene Tone")
check(s.intent and s.intent.mode == 0 and s.intent.target == 100, "Goldene Tone e self-cast (dono longe nao bloqueia)")
local recast = false
for _ = 1, 6 do local s2 = disp("step"); if s2.intent and s2.intent.kind == "skill" and s2.intent.skill == SID.MH_GOLDENE_TONE then recast = true end end
check(not recast, "nao recasta Goldene Tone enquanto ativo/conjurando")
-- Painkiller (Sera) segue a regra antiga: dono fora de alcance => nao casta
disp("setTree", { type = "action", name = "UseOwnerBuff", params = { UseOwnerBuff = true } })
disp("load", scenario(C.SERA))
local s3 = runUntil(function(it) return it and it.kind == "skill" end, 4)
check(not (s3.intent and s3.intent.kind == "skill"), "Painkiller segue exigindo dono em alcance (dono longe = nada)")
-- editor UseSkill: Heilige Pferd self-cast com mobs em volta do homun
disp("setTree", { type = "action", name = "UseSkill", params = { skill = SID.MH_HEILIGE_PFERD, level = 10 } })
disp("load", scenario(C.BAYERI, { { x = 21, y = 20 }, { x = 19, y = 21 } }))
local s4 = runUntil(function(it) return it and it.kind == "skill" and it.skill == SID.MH_HEILIGE_PFERD end)
check(s4.intent and s4.intent.skill == SID.MH_HEILIGE_PFERD and s4.intent.mode == 0, "UseSkill emite Heilige Pferd self-cast")

print("")
print(string.format("RESULTADO: %d ok, %d falhas", pass, fail))
os.exit(fail == 0 and 0 or 1)
