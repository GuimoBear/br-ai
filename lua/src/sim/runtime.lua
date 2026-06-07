-- runtime.lua — runtime do SIMULADOR (Lua puro).
-- Implementa o backend do cliente sobre um "mundo" em memoria, aplica a intencao
-- decidida pela arvore e roda uma IA simples dos monstros. Exposto ao host JS por
-- um unico ponto de entrada: SIM_DISPATCH(method, argJson) -> jsonString.
BRAI = BRAI or {}

local C    = BRAI.const
local ro   = BRAI.ro
local util = BRAI.util
local json = BRAI.json

local SIM = { world = nil, bb = nil, tree = nil, scenario = nil }

----------------------------------------------------------------------
-- Backend do cliente sobre o mundo
----------------------------------------------------------------------

local backend = {
	GetV = function(v, id)
		local e = SIM.world.entities[id]
		if not e then return -1 end
		if v == C.V_POSITION then return e.x, e.y end
		if v == C.V_HP then return e.hp end
		if v == C.V_SP then return e.sp or 0 end
		if v == C.V_MAXHP then return e.maxhp end
		if v == C.V_MAXSP then return e.maxsp or 0 end
		if v == C.V_MOTION then return e.motion or C.MOTION_STAND end
		if v == C.V_HOMUNTYPE then return e.homunType or 0 end
		if v == C.V_OWNER then return e.owner or 0 end
		if v == C.V_TARGET then return e.target or 0 end
		if v == C.V_TYPE then return e.etype or 0 end
		if v == C.V_ATTACKRANGE then return 1 end
		return -1
	end,
	GetActors = function()
		local out = {}
		for i, v in ipairs(SIM.world.order) do out[i] = v end
		return out
	end,
	GetTick   = function() return SIM.world.tick end,
	GetMsg    = function() return SIM.world.msg end,
	IsMonster = function(id) local e = SIM.world.entities[id]; return (e and e.isMonster) and 1 or 0 end,
	IsBoss    = function(id) local e = SIM.world.entities[id]; return (e and e.boss) and 1 or 0 end,
	Move      = function() end,  -- efeitos sao aplicados via bb.intent em SIM.applyIntent
	Attack    = function() end,
	SkillObject = function() end,
	SkillGround = function() end,
	TraceAI   = function(m) SIM.log[#SIM.log + 1] = tostring(m) end,
}

----------------------------------------------------------------------
-- Construcao do mundo a partir de um cenario
----------------------------------------------------------------------
local function buildWorld(scn)
	local w = {
		tick = 0,
		dt = scn.dt or 50,
		grid = scn.grid or { w = 40, h = 40 },
		entities = {},
		order = {},
		msg = { C.NONE_CMD },
		homunId = scn.homunId,
		ownerId = scn.ownerId,
		groundFx = {},   -- skills de área lingering no solo
	}
	for _, e0 in ipairs(scn.entities) do
		local kind = e0.kind
		local e = {
			id = e0.id, kind = kind,
			x = e0.x, y = e0.y,
			hp = e0.hp or 100, maxhp = e0.maxhp or (e0.hp or 100),
			sp = e0.sp or 100, maxsp = e0.maxsp or (e0.sp or 100),
			motion = C.MOTION_STAND,
			etype = e0.etype or 0,
			homunType = e0.homunType,   -- classe do mob (p/ detectar invocações)
			atk = e0.atk or (kind == "monster" and 8 or 10),
			matk = e0.matk or (kind == "monster" and 0 or 10),
			aggro = e0.aggro or 10,
			target = 0,
		}
		if kind == "homun" then
			e.homunType = e0.homunType or C.VANILMIRTH
			e.owner = scn.ownerId
			e.failCasts = e0.failCasts or 0
		elseif kind == "monster" then
			e.isMonster = true
			e.atkInterval = e0.atkInterval or 1000   -- ms entre ataques
			e.aggressive = (e0.aggressive ~= false)  -- padrão: agressivo
			e.lastAtk = -1000000
			e.provoked = false
			e.boss = e0.boss or false
		end
		w.entities[e.id] = e
		w.order[#w.order + 1] = e.id
	end
	-- alvos que os monstros podem agredir (dono e aliados servem p/ testar anti-KS)
	w.aggroIds = { w.homunId, w.ownerId }
	for _, id in ipairs(w.order) do
		if w.entities[id].kind == "ally" then w.aggroIds[#w.aggroIds + 1] = id end
	end
	return w
end

----------------------------------------------------------------------
-- Aplicacao da intencao do homunculo + IA dos monstros
----------------------------------------------------------------------
local function alive(e) return e.hp > 0 and e.motion ~= C.MOTION_DEAD end

local function hit(attacker, victim)
	victim.hp = victim.hp - attacker.atk
	if victim.hp <= 0 then
		victim.hp = 0
		victim.motion = C.MOTION_DEAD
		victim.target = 0
		if victim.isMonster and SIM.log then SIM.log[#SIM.log + 1] = "derrotado: #" .. victim.id end
	else
		victim.motion = C.MOTION_DAMAGE
	end
	if victim.isMonster then victim.provoked = true end
end

local function hitAmount(victim, amt)
	victim.hp = victim.hp - amt
	if victim.hp <= 0 then
		victim.hp = 0; victim.motion = C.MOTION_DEAD; victim.target = 0
		if victim.isMonster and SIM.log then SIM.log[#SIM.log + 1] = "derrotado: #" .. victim.id end
	else victim.motion = C.MOTION_DAMAGE end
	if victim.isMonster then victim.provoked = true end
end

-- valor de um array de efeito no nível lv (cai no último se faltar)
local function fxAt(a, lv)
	if not a then return nil end
	if a[lv] ~= nil then return a[lv] end
	return a[#a]
end

-- dano REPRESENTATIVO de uma skill (Renewal): dmgFlat | %HP máx | % de ATK/MATK.
-- Sem dados de efeito, cai no antigo atk*2.
local function skillDamage(fx, lv, caster)
	if fx then
		if fx.dmgFlat then return fxAt(fx.dmgFlat, lv) or 0 end
		if fx.hpPct then return math.floor((caster.maxhp or 0) * (fxAt(fx.hpPct, lv) or 0) / 100) end
		if fx.dmg then
			local base = (fx.kind == "magic") and (caster.matk or caster.atk or 0) or (caster.atk or 0)
			return math.floor(base * (fxAt(fx.dmg, lv) or 0) / 100)
		end
	end
	return (caster.atk or 0) * 2
end

-- aplica um status (debuff) ao monstro, visível no painel/tooltip do simulador
local function applyStatus(victim, fx, lv, now)
	if not (fx and fx.status) then return end
	local dur = fxAt(fx.status.dur, lv) or 0
	victim.status = { name = fx.status.name, untilT = now + dur }
end

-- descrição curta da ação atual do homúnculo (para o log de eventos)
local function intentDesc(bb)
	local it = bb.intent
	if not it or it.kind == "idle" then return "ocioso" end
	if it.kind == "move" then
		if it.reason == "chase" then return "perseguindo o alvo"
		elseif it.reason == "follow" then return "seguindo o dono"
		elseif it.reason == "flee" then return "fugindo"
		elseif it.reason == "kite" then return "mantendo distância (kite)"
		elseif it.reason == "dance" then return "atacando em movimento (dança)"
		elseif it.reason == "command" then return "movendo (comando do dono)"
		else return "movendo" end
	elseif it.kind == "attack" then return "ataque normal no alvo"
	end
	return nil   -- skill já é logada no cast
end

local function healAmount(e, amt)
	e.hp = math.min(e.maxhp, e.hp + amt)
end

-- Invocação (Sera — Legião): cria os atores invocados em torno da Sera. Re-cast
-- substitui a legião anterior desta Sera (refresca). A skill NÃO dá dano direto no
-- alvo (A6) — quem trabalha é a swarm (SIM.stepSummons).
local function spawnLegion(w, h, skill, level)
	local def = BRAI.summons and BRAI.summons[skill]
	local pl = def and def.perLevel and def.perLevel[level]
	if not pl then return end
	local keep = {}
	for _, id in ipairs(w.order) do
		local e = w.entities[id]
		if e and e.summon and e.summonOf == h.id then w.entities[id] = nil
		else keep[#keep + 1] = id end
	end
	w.order = keep
	local maxid = 0
	for _, id in ipairs(w.order) do if id > maxid then maxid = id end end
	local ttl = BRAI.skillsys.duration(skill, level)
	for i = 1, (pl.count or 0) do
		local id = maxid + i
		local ang = (i / (pl.count or 1)) * 2 * math.pi
		local ox = math.max(0, math.min(w.grid.w - 1, math.floor(h.x + 1.5 * math.cos(ang) + 0.5)))
		local oy = math.max(0, math.min(w.grid.h - 1, math.floor(h.y + 1.5 * math.sin(ang) + 0.5)))
		w.entities[id] = {
			id = id, kind = "summon", isMonster = true, summon = true, summonOf = h.id,
			homunType = pl.mob, etype = pl.mob,
			x = ox, y = oy, hp = pl.hp or 2000, maxhp = pl.hp or 2000, sp = 0, maxsp = 0,
			atk = pl.atk or 100, matk = 0, aggro = pl.aggro or 9, atkInterval = pl.atkInterval or 800,
			lastAtk = -1000000, provoked = false, motion = C.MOTION_STAND, target = 0,
			bornAt = w.tick, ttl = ttl,
		}
		w.order[#w.order + 1] = id
	end
	if SIM.log then SIM.log[#SIM.log + 1] = "Legiao invocada: " .. (pl.count or 0) .. " x " .. ((def.names and def.names[pl.mob]) or "inseto") end
end

function SIM.applyIntent()
	local w = SIM.world
	local h = w.entities[w.homunId]
	if not h or not alive(h) then return end
	local it = SIM.bb.intent
	if not it or it.kind == "idle" then h.motion = C.MOTION_STAND; return end

	if it.kind == "move" then
		local nx, ny = util.stepToward(h.x, h.y, it.x, it.y)
		nx = math.max(0, math.min(w.grid.w - 1, nx))
		ny = math.max(0, math.min(w.grid.h - 1, ny))
		h.x, h.y = nx, ny
		h.motion = C.MOTION_MOVE
	elseif it.kind == "attack" then
		local t = w.entities[it.target]
		if t and alive(t) and util.chebyshev(h.x, h.y, t.x, t.y) <= 1 then
			h.motion = C.MOTION_ATTACK
			hit(h, t)
			BRAI.skillsys.noteAttack(SIM.bb)
		else
			h.motion = C.MOTION_STAND
		end
	elseif it.kind == "skill" then
		h.motion = C.MOTION_SKILL
		if h.failCasts and h.failCasts > 0 then
			h.failCasts = h.failCasts - 1
			BRAI.skillsys.noteCastFailed(SIM.bb)         -- fail-safe: servidor rejeitou o cast
			SIM.log[#SIM.log + 1] = "cast falhou (simulado) — esfera penalizada"
			return
		end
		BRAI.skillsys.markUsed(SIM.bb, it.skill, it.level or 1)  -- contabiliza cooldown/buff só ao aplicar
		do
			local sk, lv = it.skill, it.level or 1
			local nm = (BRAI.skillMeta[sk] and BRAI.skillMeta[sk].iro) or BRAI.skillsys.name(sk)
			local sp = BRAI.skillsys.spCost(sk, lv)
			local ru = BRAI.skillsys.reuse(sk, lv)
			SIM.log[#SIM.log + 1] = string.format("%s Lv%d - SP %d%s", nm, lv, sp,
				ru > 0 and (" - recarga " .. (ru / 1000) .. "s") or "")
		end
		-- Invocação: a skill de summon cria a legião (sem dano direto no alvo — A6)
		if BRAI.summons and BRAI.summons[it.skill] then spawnLegion(w, h, it.skill, it.level or 1) end
		local fx = BRAI.skillFx and BRAI.skillFx[it.skill]
		local lv = it.level or 1
		local sdmg = skillDamage(fx, lv, h)   -- dano representativo (Renewal) por ATK/MATK/%HP/fixo
		if it.heal == "self" then
			local pct = (fx and fx.heal and fxAt(fx.heal.pct, lv)) or 40
			healAmount(h, math.floor(h.maxhp * pct / 100))
		elseif it.heal == "owner" then
			local o = w.entities[w.ownerId]
			if o then
				local pct = (fx and fx.heal and fxAt(fx.heal.pct, lv)) or 30
				healAmount(o, math.floor(o.maxhp * pct / 100))
			end
		elseif it.castling then
			local o = w.entities[w.ownerId]
			if o then h.x, h.y, o.x, o.y = o.x, o.y, h.x, h.y end
		elseif it.mode == 2 then
			local size = BRAI.skillsys.aoeSize(it.skill, it.level)
			local half = math.floor(size / 2)
			local nm = (BRAI.skillMeta[it.skill] and BRAI.skillMeta[it.skill].iro) or BRAI.skillsys.name(it.skill)
			if fx and fx.dot then
				-- DANO POR SEGUNDO: a área persiste e aplica dano a cada 'interval' (Lava/Forge/Poison Mist)
				local dur = fxAt(fx.dot.dur, lv) or 3000
				w.groundFx[#w.groundFx + 1] = { skill = it.skill, name = nm, x = it.x, y = it.y, size = size,
					expire = w.tick + dur, total = dur,
					dot = { dmg = sdmg, interval = fx.dot.interval or 1000, nextAt = w.tick, status = fx.status, lv = lv } }
			else
				for _, id in ipairs(w.order) do
					local m = w.entities[id]
					if m.isMonster and alive(m) and util.chebyshev(it.x, it.y, m.x, m.y) <= half then
						hitAmount(m, sdmg)
						applyStatus(m, fx, lv, w.tick)
					end
				end
				local dur = BRAI.skillsys.duration(it.skill, it.level)
				if dur <= 0 then dur = 500 end   -- AoE instantâneo: flash breve
				w.groundFx[#w.groundFx + 1] = { skill = it.skill, name = nm, x = it.x, y = it.y, size = size, expire = w.tick + dur, total = dur }
			end
		elseif it.mode == 1 and it.target and not (BRAI.summons and BRAI.summons[it.skill]) then
			local t = w.entities[it.target]
			if t and t.isMonster and alive(t) then
				hitAmount(t, sdmg)
				applyStatus(t, fx, lv, w.tick)
			end
			-- mode 1 em nao-monstro (ex.: painkiller no dono) nao causa dano
		end
	end
end

-- IA da Legião (Sera): cada inseto copia o alvo da mestra; sem alvo, ataca a
-- própria Sera (dano real — modelagem); expira por TTL; morre com a mestra.
function SIM.stepSummons()
	local w = SIM.world
	local h = w.entities[w.homunId]
	local mt = SIM.bb and SIM.bb.target
	for _, id in ipairs(w.order) do
		local e = w.entities[id]
		if e and e.summon and alive(e) then
			if not (h and alive(h)) then
				e.hp = 0; e.motion = C.MOTION_DEAD; e.target = 0
			elseif w.tick - (e.bornAt or 0) >= (e.ttl or 0) then
				e.hp = 0; e.motion = C.MOTION_DEAD; e.target = 0
			else
				local t = e.target and w.entities[e.target]
				if not (t and t.isMonster and not t.summon and alive(t)) then
					t = mt and w.entities[mt]
					if not (t and t.isMonster and not t.summon and alive(t)) then t = nil end
				end
				if not t then t = h end
				e.target = t.id
				local d = util.chebyshev(e.x, e.y, t.x, t.y)
				if d <= 1 then
					if w.tick - (e.lastAtk or -1000000) >= (e.atkInterval or 800) then
						e.motion = C.MOTION_ATTACK; e.lastAtk = w.tick; hit(e, t)
						if t.isMonster and not t.summon then w.legionDamage = (w.legionDamage or 0) + (e.atk or 0) end
					else
						e.motion = C.MOTION_STAND
					end
				else
					local nx, ny = util.stepToward(e.x, e.y, t.x, t.y)
					e.x, e.y = nx, ny; e.motion = C.MOTION_MOVE
				end
			end
		end
	end
	local keep = {}
	for _, id in ipairs(w.order) do
		local e = w.entities[id]
		if e and e.summon and (e.hp <= 0 or e.motion == C.MOTION_DEAD) then
			w.entities[id] = nil
		else
			keep[#keep + 1] = id
		end
	end
	w.order = keep
end

function SIM.stepMonsters()
	local w = SIM.world
	for _, id in ipairs(w.order) do
		local m = w.entities[id]
		if m.isMonster and not m.summon and alive(m) then
			if not (m.aggressive or m.provoked) then
				m.target = 0; m.motion = C.MOTION_STAND   -- passivo: só reage se atingido
			else
				local best, bestD = nil, nil
				for _, tid in ipairs(w.aggroIds) do
					local t = w.entities[tid]
					if t and alive(t) then
						local d = util.chebyshev(m.x, m.y, t.x, t.y)
						if d <= m.aggro and (not bestD or d < bestD) then best, bestD = t, d end
					end
				end
				-- insetos invocados também são alvos válidos (monstros revidam)
				for _, sid in ipairs(w.order) do
					local se = w.entities[sid]
					if se and se.summon and alive(se) then
						local d = util.chebyshev(m.x, m.y, se.x, se.y)
						if d <= m.aggro and (not bestD or d < bestD) then best, bestD = se, d end
					end
				end
				if best then
					m.target = best.id
					if bestD <= 1 then
						if w.tick - (m.lastAtk or -1000000) >= (m.atkInterval or 1000) then
							m.motion = C.MOTION_ATTACK; m.lastAtk = w.tick; hit(m, best)
						else
							m.motion = C.MOTION_STAND       -- aguardando o intervalo
						end
					else
						local nx, ny = util.stepToward(m.x, m.y, best.x, best.y)
						m.x, m.y = nx, ny
						m.motion = C.MOTION_MOVE
					end
				else
					m.target = 0; m.motion = C.MOTION_STAND
				end
			end
		end
	end
end

----------------------------------------------------------------------
-- Loop de um tick (replica AI.lua, mas aplicando efeitos no mundo)
----------------------------------------------------------------------
local function readCommand()
	local msg = SIM.world.msg
	if not msg or msg[1] == nil or msg[1] == C.NONE_CMD then
		SIM.bb.command = nil; return
	end
	local k = msg[1]
	if k == C.MOVE_CMD then SIM.bb.command = { kind = k, x = msg[2], y = msg[3] }
	elseif k == C.ATTACK_OBJECT_CMD then SIM.bb.command = { kind = k, target = msg[2] }
	else SIM.bb.command = { kind = k } end
end

function SIM.tick()
	SIM.log = {}
	readCommand()
	BRAI.perception.update(SIM.bb, SIM.world.homunId)
	SIM.tree:tick(SIM.bb)
	SIM.applyIntent()
	if SIM.bb.target ~= SIM.lastTarget then
		if SIM.bb.target then SIM.log[#SIM.log + 1] = "alvo adquirido: #" .. SIM.bb.target end
		SIM.lastTarget = SIM.bb.target
	end
	local desc = intentDesc(SIM.bb)
	if desc and desc ~= SIM.lastDesc then
		SIM.log[#SIM.log + 1] = "-> " .. desc
		SIM.lastDesc = desc
	end
	SIM.stepSummons()
	SIM.stepMonsters()
	SIM.world.tick = SIM.world.tick + SIM.world.dt
	-- DoT: áreas de dano por segundo (Lava Slide, Blast Forge, Poison Mist) aplicam
	-- dano aos monstros dentro da área a cada 'interval' enquanto persistem.
	for _, fx in ipairs(SIM.world.groundFx or {}) do
		if fx.dot and fx.expire > SIM.world.tick then
			local half = math.floor(fx.size / 2)
			while SIM.world.tick >= fx.dot.nextAt do
				for _, id in ipairs(SIM.world.order) do
					local m = SIM.world.entities[id]
					if m.isMonster and alive(m) and util.chebyshev(fx.x, fx.y, m.x, m.y) <= half then
						hitAmount(m, fx.dot.dmg)
						if fx.dot.status then applyStatus(m, { status = fx.dot.status }, fx.dot.lv, SIM.world.tick) end
					end
				end
				fx.dot.nextAt = fx.dot.nextAt + (fx.dot.interval > 0 and fx.dot.interval or 1000)
			end
		end
	end
	local kept = {}
	for _, fx in ipairs(SIM.world.groundFx or {}) do
		if fx.expire > SIM.world.tick then kept[#kept + 1] = fx end
	end
	SIM.world.groundFx = kept
end

----------------------------------------------------------------------
-- Snapshot para o host (render + painel de arvore)
----------------------------------------------------------------------
local function activeList(tbl, totalTbl, now)
	local out = {}
	if not tbl then return out end
	for skill, untilT in pairs(tbl) do
		if untilT > now then
			local nm = (BRAI.skillMeta[skill] and BRAI.skillMeta[skill].iro) or BRAI.skillsys.name(skill)
			local rem = untilT - now
			local total = (totalTbl and totalTbl[skill]) or rem
			out[#out + 1] = { skill = skill, name = nm, remaining = rem, total = total }
		end
	end
	table.sort(out, function(a, b) return a.remaining > b.remaining end)
	return out
end

function SIM.snapshot()
	if not SIM.world then
		return { tick = 0, grid = { w = 40, h = 40 }, entities = {}, intent = nil, target = 0, bb = nil, tree = {}, log = {} }
	end
	local w = SIM.world
	local ents = {}
	for _, id in ipairs(w.order) do
		local e = w.entities[id]
		local state = nil
		if e.isMonster then
			if e.aggressive then state = "agressivo"
			elseif e.provoked then state = "provocado"
			else state = "passivo" end
		end
		ents[#ents + 1] = {
			id = e.id, kind = e.kind, x = e.x, y = e.y,
			hp = e.hp, maxhp = e.maxhp, sp = e.sp, maxsp = e.maxsp,
			motion = e.motion, target = e.target,
			atk = e.atk, atkInterval = e.atkInterval, aggressive = e.aggressive,
			aggro = e.aggro, state = state, etype = e.etype, matk = e.matk, boss = e.boss,
			status = (e.status and e.status.untilT > SIM.world.tick) and e.status.name or nil,
		}
	end
	local bb = SIM.bb
	local ground = {}
	for _, fx in ipairs(w.groundFx or {}) do
		if fx.expire > w.tick then
			ground[#ground + 1] = { skill = fx.skill, name = fx.name, x = fx.x, y = fx.y, size = fx.size, remaining = fx.expire - w.tick, total = fx.total }
		end
	end
	local intent = bb and bb.intent or nil
	local cfg = bb and bb.config or {}
	-- Estado da Eleanor p/ a visualização do simulador (só quando é Eleanor)
	local eleanor = nil
	if bb and bb.self.homunType == C.ELEANOR then
		local cb = bb.persist.combo
		eleanor = {
			spheres = bb.self.spheres or 0,
			style = bb.persist.style or "power",
			rooted = bb.persist.grappleRooted and true or false,
			step = (cb and cb.step) or 0,
			comboKey = (cb and cb.key) or nil,
			comboAt = (cb and cb.at) or nil,
		}
	end
	-- Estado da Legião da Sera p/ a visualização (só quando é Sera)
	local sera = nil
	if bb and bb.self.homunType == C.SERA then
		local lg = bb.self.legion or { count = 0, alive = false, expiresAt = 0, level = 0 }
		local sk = BRAI.profileFor(bb).summon
		local def = sk and BRAI.summons and BRAI.summons[sk]
		local lvl = ((lg.level and lg.level > 0) and lg.level) or (sk and BRAI.skillsys.knownLevel(bb, sk)) or 5
		local pl = def and def.perLevel and def.perLevel[lvl]
		local members = {}
		for _, id in ipairs(w.order) do
			local e = w.entities[id]
			if e and e.summon then
				members[#members + 1] = {
					id = e.id, x = e.x, y = e.y, mob = e.homunType, target = e.target,
					hp = e.hp, maxhp = e.maxhp,
					hpPct = (e.maxhp and e.maxhp > 0) and math.floor(100 * e.hp / e.maxhp) or 0,
					ttl = math.max(0, (e.ttl or 0) - (w.tick - (e.bornAt or 0))),
				}
			end
		end
		local spCost = (sk and BRAI.skillsys.spCost(sk, lvl)) or 0
		local spOk = (bb.self.sp or 0) >= spCost
		sera = {
			active = lg.alive and true or false,
			count = #members,
			max = (pl and pl.count) or 0,
			level = lvl,
			tier = (def and def.names and pl and def.names[pl.mob]) or "—",
			remaining = math.max(0, (lg.expiresAt or 0) - w.tick),
			total = (sk and BRAI.skillsys.duration(sk, lvl)) or 0,
			spOk = spOk,
			resummonReady = (not lg.alive) and spOk,
			damageDealt = w.legionDamage or 0,
			members = members,
		}
	end
	local bbview = nil
	if bb then
		bbview = {
			self = {
				hp = bb.self.hp, sp = bb.self.sp,
				hpPct = bb.self.hpPct, spPct = bb.self.spPct,
				x = bb.self.x, y = bb.self.y, motion = bb.self.motion,
				spheres = bb.self.spheres,
			},
			owner = { exists = bb.owner.exists, dist = bb.owner.dist, hpPct = bb.owner.hpPct },
			flags = bb.flags,
			monsters = #bb.monsters,
			config = {
				AggroDist = cfg.AggroDist, AggroHP = cfg.AggroHP, AggroSP = cfg.AggroSP,
				FollowStayBack = cfg.FollowStayBack, MoveBounds = cfg.MoveBounds,
				AttackRange = cfg.AttackRange, FleeHP = cfg.FleeHP,
			},
		}
	end
	return {
		tick = w.tick,
		grid = w.grid,
		entities = ents,
		intent = intent,
		target = bb and bb.target or 0,
		bb = bbview,
		ground = ground,
		tree = SIM.tree and BRAI.tree.snapshot(SIM.tree) or {},
		eleanor = eleanor,
		sera = sera,
		skills = bb and {
			cooldowns = activeList(bb.persist.skillReadyAt, bb.persist.skillCdTotal, w.tick),
			buffs = activeList(bb.persist.buffUntil, bb.persist.buffTotal, w.tick),
		} or { cooldowns = {}, buffs = {} },
		log = SIM.log or {},
	}
end

----------------------------------------------------------------------
-- Ponto de entrada unico para o host JS
----------------------------------------------------------------------
function SIM.load(scn)
	ro.bind(backend)
	SIM.scenario = scn
	SIM.world = buildWorld(scn)
	SIM.bb = BRAI.Blackboard.new()
	if scn.config then
		for k, v in pairs(scn.config) do SIM.bb.config[k] = v end
	end
	SIM.tree = BRAI.tree.build(SIM.customTree or BRAI.treeSpec)
	SIM.log = {}
	SIM.lastTarget = nil
	SIM.lastDesc = nil
	-- percepcao inicial para o frame 0 ja trazer self/owner/monstros
	BRAI.perception.update(SIM.bb, SIM.world.homunId)
end

-- method: "load" | "step" | "snapshot" | "command" | "reset"
function SIM_DISPATCH(method, argJson)
	local arg = nil
	if argJson and argJson ~= "" then arg = json.decode(argJson) end

	if method == "registry" then
		return json.encode(BRAI.registry.export())
	elseif method == "skillCatalog" then
		return json.encode(BRAI.skillCatalog(arg and arg.homunType or 0, arg and arg.baseType or 0))
	elseif method == "comboInfo" then
		return json.encode(BRAI.comboInfo())
	elseif method == "treeSpec" then
		return json.encode(SIM.customTree or BRAI.treeSpec)
	elseif method == "setTree" then
		SIM.customTree = arg
		if SIM.world then SIM.tree = BRAI.tree.build(arg) end
		return json.encode({ ok = true })
	elseif method == "clearTree" then
		SIM.customTree = nil
		if SIM.world then SIM.tree = BRAI.tree.build(BRAI.treeSpec) end
		return json.encode({ ok = true })
	elseif method == "load" then
		SIM.load(arg)
	elseif method == "reset" then
		SIM.load(SIM.scenario)
	elseif method == "step" then
		SIM.tick()
	elseif method == "setOwner" then
		if arg then
			local o = SIM.world.entities[SIM.world.ownerId]
			if o then o.x, o.y = arg.x, arg.y end
		end
	elseif method == "failNextCast" then
		if SIM.world then
			local h = SIM.world.entities[SIM.world.homunId]
			if h then h.failCasts = (arg and arg.count) or 1 end
		end
		return json.encode({ ok = true })
	elseif method == "addMonster" then
		if SIM.world then
			local w = SIM.world
			local maxid = 0
			for _, id in ipairs(w.order) do if id > maxid then maxid = id end end
			local id = maxid + 1
			local a = arg or {}
			w.entities[id] = {
				id = id, kind = "monster", isMonster = true,
				x = a.x or 20, y = a.y or 20,
				hp = a.hp or 300, maxhp = a.maxhp or a.hp or 300,
				atk = a.atk or 6, aggro = a.aggro or 10,
				atkInterval = a.atkInterval or 1000,
				aggressive = (a.aggressive ~= false),
				lastAtk = -1000000, provoked = false,
				motion = C.MOTION_STAND, etype = a.etype or 1042, target = 0,
				homunType = a.homunType,
			}
			w.order[#w.order + 1] = id
		end
	elseif method == "addAlly" then
		if SIM.world then
			local w = SIM.world
			local maxid = 0
			for _, id in ipairs(w.order) do if id > maxid then maxid = id end end
			local id = maxid + 1
			local a = arg or {}
			w.entities[id] = { id = id, kind = "ally", x = a.x or 20, y = a.y or 20,
				hp = a.hp or 1000, maxhp = a.maxhp or a.hp or 1000, sp = 0, maxsp = 0,
				motion = C.MOTION_STAND, target = 0 }
			w.order[#w.order + 1] = id
			w.aggroIds[#w.aggroIds + 1] = id
		end
	elseif method == "updateMonster" then
		if SIM.world and arg and arg.id then
			local m = SIM.world.entities[arg.id]
			if m then
				if arg.maxhp then m.maxhp = arg.maxhp end
				if arg.hp then m.hp = arg.hp end
				if m.hp > m.maxhp then m.hp = m.maxhp end
				if arg.atk then m.atk = arg.atk end
				if arg.atkInterval then m.atkInterval = arg.atkInterval end
				if arg.aggro then m.aggro = arg.aggro end
				if arg.aggressive ~= nil then
					m.aggressive = arg.aggressive
					if not arg.aggressive then m.provoked = false end
				end
				if arg.etype ~= nil then m.etype = arg.etype end
				if arg.matk ~= nil then m.matk = arg.matk end
				if arg.x then m.x = arg.x end
				if arg.y then m.y = arg.y end
			end
		end
	elseif method == "updateEntity" then
		-- edita HP/SP de qualquer entidade (homúnculo, dono, monstro)
		if SIM.world and arg and arg.id then
			local e = SIM.world.entities[arg.id]
			if e then
				if arg.maxhp then e.maxhp = arg.maxhp end
				if arg.maxsp then e.maxsp = arg.maxsp end
				if arg.atk ~= nil then e.atk = arg.atk end
				if arg.matk ~= nil then e.matk = arg.matk end
				if arg.hp then e.hp = arg.hp; if e.maxhp and arg.hp > e.maxhp then e.maxhp = arg.hp end end
				if arg.sp then e.sp = arg.sp; if e.maxsp and arg.sp > e.maxsp then e.maxsp = arg.sp end end
				if e.maxhp and e.hp and e.hp > e.maxhp then e.hp = e.maxhp end
				if e.maxsp and e.sp and e.sp > e.maxsp then e.sp = e.maxsp end
			end
		end
	elseif method == "removeMonster" then
		if SIM.world and arg and arg.id then
			SIM.world.entities[arg.id] = nil
			for i, id in ipairs(SIM.world.order) do
				if id == arg.id then table.remove(SIM.world.order, i); break end
			end
			if SIM.bb and SIM.bb.target == arg.id then SIM.bb.target = nil end
		end
	elseif method == "moveEntity" then
		if SIM.world and arg and arg.id then
			local e = SIM.world.entities[arg.id]
			if e then e.x = arg.x; e.y = arg.y end
		end
	elseif method == "command" then
		if arg and arg.cmd then
			SIM.world.msg = { arg.cmd, arg.a, arg.b }
		else
			SIM.world.msg = { C.NONE_CMD }
		end
	elseif method == "setMonsters" then
		-- carrega o catálogo de monstros/grupos do usuário (cadastro do editor)
		BRAI.monsterGroups.load(arg or { monsters = {}, groups = {} })
		return json.encode({ ok = true })
	elseif method == "setSkillChoice" then
		-- escolha global de skill por papel/homúnculo (homun_skills.json)
		BRAI.setSkillChoice(arg or {})
		return json.encode({ ok = true })
	elseif method == "roleConfig" then
		-- candidatos + padrão + escolha por papel (p/ a tela "Skills por homúnculo")
		return json.encode(BRAI.roleConfig(arg and arg.homunType or 0))
	elseif method == "summonInfo" then
		return json.encode(BRAI.summonInfo(arg and arg.homunType or 0))
	elseif method == "setSummonChoice" then
		BRAI.setSummonChoice(arg or {})
		return json.encode({ ok = true })
	elseif method == "snapshot" then
		-- no-op: cai no retorno do snapshot abaixo
	else
		return json.encode({ error = "metodo desconhecido: " .. tostring(method) })
	end

	return json.encode(SIM.snapshot())
end

BRAI.sim = SIM
return SIM
