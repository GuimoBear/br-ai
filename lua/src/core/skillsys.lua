-- skillsys.lua — consultas e contabilidade de skills/buffs (alcance, SP, cooldown, AoE).
-- Equivalente enxuto aos helpers do AzzyAI (AttackRange/GetSkillInfo/GetMobCount/DoSkill timers).
BRAI = BRAI or {}
local util = BRAI.util
local len = BRAI.compat.len
local C = BRAI.const

local sys = {}

local function lvlval(arr, level)
	if type(arr) ~= "table" then return arr or 0 end
	return arr[level] or arr[len(arr)] or 0
end

function sys.info(skill) return BRAI.skills.info[skill] end
function sys.name(skill) local i = sys.info(skill); return i and i[1] or ("skill " .. tostring(skill)) end
function sys.range(skill, level)   local i = sys.info(skill); return i and lvlval(i[2], level) or 0 end
function sys.spCost(skill, level)  local i = sys.info(skill); return i and lvlval(i[3], level) or 0 end
function sys.delay(skill, level)   local i = sys.info(skill); return i and lvlval(i[6], level) or 0 end
function sys.targetMode(skill)     local i = sys.info(skill); return i and i[7] or 1 end
function sys.duration(skill, level)local i = sys.info(skill); return i and i[8] and lvlval(i[8], level) or 0 end
function sys.reuse(skill, level)   local i = sys.info(skill); return i and i[9] and lvlval(i[9], level) or 0 end

function sys.aoeSize(skill, level)
	local a = BRAI.skills.aoe[skill]
	if not a then return 0 end
	return lvlval(a[1], level)
end
function sys.aoeCenter(skill) -- 0=no inimigo, 1=no caster
	local a = BRAI.skills.aoe[skill]
	return a and a[2] or 0
end

-- nivel que este homunculo conhece para esta skill (do SkillList do tipo)
function sys.knownLevel(bb, skill)
	local lst = BRAI.skills.list[bb.self.homunType]
	local lvl = lst and lst[skill]
	if lvl then return lvl end
	local base = bb.config.BaseHomunType   -- Homunculus S mantem as skills da forma base
	if base and base ~= 0 then
		local bl = BRAI.skills.list[base]
		if bl then return bl[skill] end
	end
	return nil
end
function sys.knows(bb, skill) return sys.knownLevel(bb, skill) ~= nil end

-- cooldown
function sys.ready(bb, skill)
	return bb:now() >= (bb.persist.skillReadyAt[skill] or 0)
end
function sys.enoughSP(bb, skill, level, reserve)
	return (bb.self.sp - (reserve or 0)) >= sys.spCost(skill, level)
end

-- alcance: skill em alcance do alvo atual? (self/ground-no-caster => sempre)
function sys.inRange(bb, skill, level)
	local mode = sys.targetMode(skill)
	if mode == 0 then return true end
	if mode == 2 and sys.aoeCenter(skill) == 1 then return true end
	if not bb.targetInfo then return false end
	return bb.targetInfo.dist <= sys.range(skill, level)
end

-- contagem de monstros no AoE da skill (em torno do alvo ou do caster)
function sys.mobCount(bb, skill, level)
	local size = sys.aoeSize(skill, level)
	if size <= 0 then return bb.targetInfo and 1 or 0 end
	local half = math.floor(size / 2)
	local cx, cy
	if sys.aoeCenter(skill) == 1 then cx, cy = bb.self.x, bb.self.y
	elseif bb.targetInfo then cx, cy = bb.targetInfo.x, bb.targetInfo.y
	else return 0 end
	local n = 0
	for _, m in ipairs(bb.monsters) do
		if util.chebyshev(cx, cy, m.x, m.y) <= half then n = n + 1 end
	end
	return n
end

-- registra o uso (cooldown + duracao de buff)
function sys.markUsed(bb, skill, level)
	local now = bb:now()
	local reuse = sys.reuse(skill, level)
	local delay = sys.delay(skill, level)
	local cd = reuse
	if cd <= 0 then cd = delay end
	if cd <= 0 then cd = 300 end
	bb.persist.skillReadyAt[skill] = now + cd
	bb.persist.skillCdTotal[skill] = cd
	local dur = sys.duration(skill, level)
	if dur > 0 then
		bb.persist.buffUntil[skill] = now + dur
		bb.persist.buffTotal[skill] = dur
	end
	-- Legião invocada (Sera): registra a janela de duração ao invocar, p/ o
	-- estimador decidir re-summon por TIMER (não por perda de visão). Plano §2.
	if BRAI.summons and BRAI.summons[skill] then
		local lg = bb.persist.legion or { expiresAt = 0, level = 0, hist = {} }
		bb.persist.legion = lg
		lg.expiresAt = now + (dur > 0 and dur or 0)
		lg.level = level
	end
	-- p/ o intervalo customizado por nó (cooldown configurável independente do jogo)
	bb.persist.skillUsedAt = bb.persist.skillUsedAt or {}
	bb.persist.skillUsedTarget = bb.persist.skillUsedTarget or {}
	bb.persist.skillUsedAt[skill] = now
	bb.persist.skillUsedTarget[skill] = bb.target
	-- Esferas (Eleanor): skills de combo sao ataques fisicos -> ganho (tentativa) + custo.
	if bb.self.homunType == C.ELEANOR then
		local op = BRAI.sphereOps and BRAI.sphereOps[skill]
		if op == "consumeAll" then
			sys.addSpheres(bb, -10)            -- Blazing and Furious: consome todas as esferas
		elseif op == "fillMax" then
			sys.addSpheres(bb, 10)             -- The One Fighter Rises: enche ao máximo (clamp 10)
		else
			local cost = BRAI.sphereCost and BRAI.sphereCost[skill]
			if cost ~= nil then
				sys.addSpheres(bb, 1 / ((bb.config and bb.config.SphereTrackFactor) or 2))
				if cost > 0 then sys.addSpheres(bb, -cost) end
			end
		end
	end
end

-- ===== Esferas Espirituais (Eleanor) — estimador (a API do cliente nao expoe) =====
-- Custo por skill vem de BRAI.sphereCost (data/combos.lua). Ganho = 1/SphereTrackFactor
-- por ataque fisico / dano recebido; teto 10, piso 0.
function sys.spheres(bb) return bb.persist.spheres or 0 end

function sys.addSpheres(bb, delta)
	local cur = (bb.persist.spheres or 0) + (delta or 0)
	if cur < 0 then cur = 0 elseif cur > 10 then cur = 10 end
	bb.persist.spheres = cur
	if bb.self then bb.self.spheres = cur end
	return cur
end

function sys.sphereCostOf(skill)
	return (BRAI.sphereCost and BRAI.sphereCost[skill]) or 0
end

-- ataque fisico normal despachado: +0.5 (somente Eleanor)
function sys.noteAttack(bb)
	if bb.self.homunType == C.ELEANOR then
		sys.addSpheres(bb, 1 / ((bb.config and bb.config.SphereTrackFactor) or 2))
	end
end

-- fail-safe: cast rejeitado pelo servidor -> pune a estimativa (-1) p/ ressincronizar
function sys.noteCastFailed(bb)
	if bb.self.homunType == C.ELEANOR then sys.addSpheres(bb, -1) end
end

-- chamado pela percepcao a cada tick: ganha por dano recebido (delta de HP) e
-- espelha a estimativa em bb.self.spheres. Para nao-Eleanor, mantem 0.
function sys.estimateOnTick(bb)
	local s = bb.self
	if s.homunType ~= C.ELEANOR then
		s.spheres = 0
		bb.persist.lastHp = s.hp
		return
	end
	if bb.persist.spheres == nil then bb.persist.spheres = (bb.config.SphereStartCount or 0) end
	local last = bb.persist.lastHp
	if last ~= nil and s.hp ~= nil and s.hp < last then
		sys.addSpheres(bb, 1 / ((bb.config and bb.config.SphereTrackFactor) or 2))
	end
	bb.persist.lastHp = s.hp
	s.spheres = bb.persist.spheres
end

-- ===== Legião invocada (Sera) — estimador (a API do cliente não expõe a contagem
-- nem o dono dos atores). count suavizado (max numa janela, anti-flicker de visão)
-- + alive por timer (now < expiresAt, registrado no markUsed). Plano §2.
function sys.estimateLegion(bb, summons)
	local s = bb.self
	local lg = bb.persist.legion or { expiresAt = 0, level = 0, hist = {} }
	bb.persist.legion = lg
	lg.hist = lg.hist or {}
	local raw, ids = 0, {}
	for _, e in ipairs(summons) do raw = raw + 1; ids[raw] = e.id end
	local win = (bb.config and bb.config.LegionSmoothTicks) or 3
	if win < 1 then win = 1 end
	local h = lg.hist
	h[#h + 1] = raw
	while #h > win do table.remove(h, 1) end
	local smooth = 0
	for _, v in ipairs(h) do if v > smooth then smooth = v end end
	local alive = (raw > 0) or (bb:now() < (lg.expiresAt or 0))
	s.legion = {
		count = smooth, raw = raw, alive = alive,
		expiresAt = lg.expiresAt or 0, level = lg.level or 0, ids = ids,
	}
	return s.legion
end

function sys.buffActive(bb, skill)
	return bb:now() < (bb.persist.buffUntil[skill] or 0)
end

-- emite a intencao de skill conforme o modo de alvo
function sys.castIntent(bb, skill, level, center)
	local mode = sys.targetMode(skill)
	if mode == 0 then
		bb:setIntent("skill", { skill = skill, level = level, target = bb.self.id, mode = 0, reason = sys.name(skill) })
	elseif mode == 2 then
		local x, y = bb.self.x, bb.self.y
		if sys.aoeCenter(skill) == 0 and bb.targetInfo then x, y = bb.targetInfo.x, bb.targetInfo.y end
		if center then x, y = center.x, center.y end   -- override do centro (ex.: AoEMaximizeTargets)
		bb:setIntent("skill", { skill = skill, level = level, x = x, y = y, mode = 2, reason = sys.name(skill) })
	else
		bb:setIntent("skill", { skill = skill, level = level, target = bb.target, mode = 1, reason = sys.name(skill) })
	end
end

BRAI.skillsys = sys
return sys
