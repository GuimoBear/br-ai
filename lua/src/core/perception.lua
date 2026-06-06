-- perception.lua — lê a API do cliente UMA vez por tick e popula o blackboard.
-- Espelha o "info gathering" da AI() do AzzyAI, porém isolado e testável.
BRAI = BRAI or {}

local C = BRAI.const
local ro = BRAI.ro
local util = BRAI.util

local perception = {}

local function pct(cur, max)
	if not max or max <= 0 then return 0 end
	return (cur / max) * 100
end

-- Atualiza bb.self, bb.owner, bb.actors, bb.monsters para o homúnculo `myid`.
function perception.update(bb, myid)
	bb:resetCounters()
	bb:clearIntent()
	bb.flags.berserk = false   -- recalculado a cada tick (condição Mobbed)
	bb._tick = bb._tick + 1

	-- Self
	local sx, sy = ro.getv(C.V_POSITION, myid)
	local s = bb.self
	s.id        = myid
	s.x, s.y    = sx, sy
	s.hp        = ro.getv(C.V_HP, myid)
	s.sp        = ro.getv(C.V_SP, myid)
	s.maxhp     = ro.getv(C.V_MAXHP, myid)
	s.maxsp     = ro.getv(C.V_MAXSP, myid)
	s.hpPct     = pct(s.hp, s.maxhp)
	s.spPct     = pct(s.sp, s.maxsp)
	s.motion    = ro.getv(C.V_MOTION, myid)
	s.homunType = ro.getv(C.V_HOMUNTYPE, myid)
	BRAI.skillsys.estimateOnTick(bb)   -- esferas (Eleanor): ganho por dano recebido + espelho em bb.self

	-- Owner
	local oid = ro.getv(C.V_OWNER, myid)
	local o = bb.owner
	o.id = oid
	if oid and oid ~= 0 and oid ~= -1 then
		local ox, oy = ro.getv(C.V_POSITION, oid)
		o.exists = (ox ~= -1)
		o.x, o.y = ox, oy
		o.hp = ro.getv(C.V_HP, oid)
		o.maxhp = ro.getv(C.V_MAXHP, oid)
		o.hpPct = pct(o.hp, o.maxhp)
		o.motion = ro.getv(C.V_MOTION, oid)
		o.dist = util.chebyshev(sx, sy, ox, oy)
	else
		o.exists = false
	end

	-- Atores → monstros
	bb.actors = ro.getActors()
	-- Contexto de invocação: o perfil efetivo tem skill de summon? (genérico; hoje só Sera).
	-- A legião é reconhecida pelo TIPO de mob do ator (V_HOMUNTYPE em types), pois o
	-- cliente NÃO expõe o dono/mestre de um ator invocado.
	local summonTypeSet
	do
		local prof = BRAI.profileFor and BRAI.profileFor(bb)
		local ssk = prof and prof.summon
		local sdef = ssk and BRAI.summons and BRAI.summons[ssk]
		summonTypeSet = sdef and sdef.typeSet
	end
	local monsters, summons = {}, {}
	for _, id in ipairs(bb.actors) do
		if id ~= myid and id ~= oid and ro.isMonster(id) == 1 then
			local mx, my = ro.getv(C.V_POSITION, id)
			if mx ~= -1 then
				local motion = ro.getv(C.V_MOTION, id)
				if motion ~= C.MOTION_DEAD then
					local mhp, mmax = ro.getv(C.V_HP, id), ro.getv(C.V_MAXHP, id)
					local e = {
						id = id,
						x = mx, y = my,
						motion = motion,
						target = ro.getv(C.V_TARGET, id),
						type = ro.getv(C.V_TYPE, id),
						dist = util.chebyshev(sx, sy, mx, my),
						hp = mhp, maxhp = mmax, hpPct = pct(mhp, mmax),
						boss = (ro.isBoss(id) == 1),
					}
					local mc = summonTypeSet and ro.getv(C.V_HOMUNTYPE, id)
					if mc and summonTypeSet[mc] then
						e.isSummon = true; e.mobClass = mc
						BRAI.compat.push(summons, e)
					else
						BRAI.compat.push(monsters, e)
					end
				end
			end
		end
	end
	bb.monsters = monsters
	bb.summons = summons

	-- Anti-KS: monstro "reivindicado" mira em outro ator (não eu, não o dono, não outro monstro)
	local mset = {}
	for _, m in ipairs(monsters) do mset[m.id] = true end
	for _, m in ipairs(monsters) do
		local t = m.target
		m.claimed = (t ~= nil and t ~= 0 and t ~= myid and t ~= oid and not mset[t])
	end

	-- Estimador de legião (Sera): contagem por tipo (suavizada) + alive por timer.
	if summonTypeSet then
		BRAI.skillsys.estimateLegion(bb, summons)
	else
		s.legion = nil
	end

	-- Validade do alvo atual
	if bb.target then
		local found = nil
		for _, m in ipairs(monsters) do
			if m.id == bb.target then found = m break end
		end
		if not found then bb.target = nil end
		bb.targetInfo = found
	else
		bb.targetInfo = nil
	end
end

-- Quem está mirando no dono (para Resgate / React).
function perception.ownerUnderAttack(bb)
	if not bb.owner.exists then return false end
	for _, m in ipairs(bb.monsters) do
		if m.target == bb.owner.id then return true end
	end
	return false
end

-- Quantos monstros miram no ator 'id' (mobbed / GetAggroCount do AzzyAI).
function perception.aggroCount(bb, id)
	local n = 0
	for _, m in ipairs(bb.monsters) do if m.target == id then n = n + 1 end end
	return n
end

-- nº de monstros num raio (chebyshev) do homúnculo. Usado pelo threat assessment do
-- Agarrão (Eleanor): Tinder Breaker zera o Flee, então multidão perto = armadilha mortal.
function perception.threatCount(bb, radius)
	radius = radius or 3
	local hx, hy = bb.self.x, bb.self.y
	local n = 0
	for _, m in ipairs(bb.monsters) do
		if util.chebyshev(hx, hy, m.x, m.y) <= radius then n = n + 1 end
	end
	return n
end

-- O alvo atual é Boss/MVP? Usa a flag de percepção (ro.isBoss: sim/flag ou API do jogo)
-- OU um grupo de boss do catálogo (config.BossGroup, do monsters.json). EQC e outras
-- decisões podem consultar isto.
function perception.targetIsBoss(bb)
	local ti = bb.targetInfo
	if not ti then return false end
	if ti.boss then return true end
	local bg = bb.config and bb.config.BossGroup
	if bg and bg ~= 0 and BRAI.monsterGroups and BRAI.monsterGroups.contains(bg, ti.type) then return true end
	return false
end

-- Quem está mirando no homúnculo.
function perception.selfUnderAttack(bb)
	for _, m in ipairs(bb.monsters) do
		if m.target == bb.self.id then return true end
	end
	return false
end

BRAI.perception = perception
return perception
