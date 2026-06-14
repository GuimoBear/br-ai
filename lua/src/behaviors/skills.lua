-- skills.lua — comportamentos de skill/buff/cura/especiais (adaptativo por perfil).
-- Acoes puras: emitem intent de "skill" (via skillsys.castIntent) e devolvem status.
BRAI = BRAI or {}
local reg = BRAI.registry
local S = BRAI.status
local sys = BRAI.skillsys
local util = BRAI.util

local function prof(bb) return BRAI.profileFor(bb) end
local function asList(v) if v == nil then return {} elseif type(v) == "table" then return v else return { v } end end
local function usable(bb, skill, reserve)
	if not skill or not sys.knows(bb, skill) then return nil end
	local lvl = sys.knownLevel(bb, skill)
	if not sys.ready(bb, skill) then return nil end
	if not sys.enoughSP(bb, skill, lvl, reserve) then return nil end
	return lvl
end

-- Nível por papel (migrado da AzzyAI, via skill_choice → m.roleLevels). Só REBAIXA o nível
-- de cast (nunca acima do conhecido); ausente => mantém o nível resolvido. Aditivo/retrocompatível.
-- Nível efetivo de cast: skillLevels[skill] (por skill) > roleLevels[role] (por papel) > conhecido.
-- Só REBAIXA (nunca acima do conhecido). Aditivo/retrocompatível.
local function capSkill(bb, role, skill, lvl)
	local p = prof(bb)
	local want = (p.skillLevels and skill and p.skillLevels[skill]) or (p.roleLevels and p.roleLevels[role])
	if want and want >= 1 and want < lvl then return want end
	return lvl
end

------------------------------------------------------------------ override de config por nó (#4)
-- Precedência: param do nó (p) > param por homún/papel (skillParams) > Config global > default.
-- Booleanos via `~= nil` (NÃO usar `or`, que confunde false com ausente). role = papel da ação
-- (aoeAtk/mainAtk/offBuff/defBuff/healSelf/healOwner/ownerBuff/castling). [PLANO-GERACAO-LUA #4 / PLANO-CONFIG-SKILLS C0]
local function effRole(p, bb, role, key)
	if p and p[key] ~= nil then return p[key] end
	local v = BRAI.skillParamFor and BRAI.skillParamFor(bb.self.homunType, role, key)
	if v ~= nil then return v end
	return bb.config[key]
end

------------------------------------------------------------------ ofensivas
-- tenta conjurar UMA skill de AoE (a ação itera a lista de prioridade do papel)
local function tryCastAoE(bb, sk, mobNeeded, p)
	local lvl = usable(bb, sk, effRole(p, bb, "aoeAtk", "AttackSkillReserveSP"))
	if not lvl then return false end
	lvl = capSkill(bb, "aoeAtk", sk, lvl)
	local fixed = effRole(p, bb, "aoeAtk", "AoEFixedLevel")
	if fixed and fixed > 0 then
		lvl = math.min(fixed, sys.knownLevel(bb, sk) or lvl)
	end
	if not sys.inRange(bb, sk, lvl) then return false end
	local center, count = nil, sys.mobCount(bb, sk, lvl)
	if effRole(p, bb, "aoeAtk", "AoEMaximizeTargets") and sys.aoeCenter(sk) == 0 then
		local half = math.floor(sys.aoeSize(sk, lvl) / 2)
		if half >= 1 then
			local rng, best, bestN = sys.range(sk, lvl), nil, count
			for _, c in ipairs(bb.monsters) do
				if (c.dist or 0) <= rng then
					local n = 0
					for _, m in ipairs(bb.monsters) do if util.chebyshev(c.x, c.y, m.x, m.y) <= half then n = n + 1 end end
					if n > bestN then best, bestN = c, n end
				end
			end
			if best then center, count = { x = best.x, y = best.y }, bestN end
		end
	end
	if count < mobNeeded then return false end
	sys.castIntent(bb, sk, lvl, center)
	return true
end
reg.action("UseAoESkill", function(bb, p)
	if not effRole(p, bb, "aoeAtk", "UseAttackSkill") then return S.FAILURE end
	if effRole(p, bb, "aoeAtk", "AutoMobMode") == 0 then return S.FAILURE end      -- AutoMobMode=0: sem AoE automática
	-- Limiar de alvos: se o homún NÃO tem ataque single-target (mainAtk vazio — ex.: Dieter),
	-- a AoE É a ofensiva principal e dispara com ≥1 alvo (limiar 1). Quem TEM mainAtk mantém
	-- o AutoMobCount (economia de SP). Knobs aceitam override por nó (#4). [PLANO-GERACAO-LUA #1/#4]
	local mobNeeded = effRole(p, bb, "aoeAtk", "AutoMobCount")
	if #asList(prof(bb).mainAtk) == 0 then mobNeeded = 1 end
	for _, sk in ipairs(asList(prof(bb).aoeAtk)) do                  -- lista de prioridade: conjura a 1ª utilizável
		if tryCastAoE(bb, sk, mobNeeded, p) then return S.SUCCESS end
	end
	return S.FAILURE
end, { desc = "Usa a 1ª AoE utilizável da lista (prioridade). Sem mainAtk (Dieter), a AoE é a ofensiva principal e dispara com ≥1 alvo; com mainAtk exige AutoMobCount alvos. AutoMobMode=0 desliga; AoEFixedLevel fixa o nível; AoEMaximizeTargets mira no aglomerado. Knobs: override por nó > Config global.",
	params = { UseAttackSkill = "boolean", AutoMobMode = "number", AutoMobCount = "number", AttackSkillReserveSP = "number", AoEFixedLevel = "number", AoEMaximizeTargets = "boolean" },
	optional = { "UseAttackSkill", "AutoMobMode", "AutoMobCount", "AttackSkillReserveSP", "AoEFixedLevel", "AoEMaximizeTargets" } })

-- tenta conjurar UMA skill principal (a ação itera a lista de prioridade do papel)
local function tryCastMain(bb, sk, p)
	local lvl = usable(bb, sk, effRole(p, bb, "mainAtk", "AttackSkillReserveSP"))
	if not lvl then return false end
	lvl = capSkill(bb, "mainAtk", sk, lvl)
	if not sys.inRange(bb, sk, lvl) then return false end
	if bb.targetInfo then
		local inMelee = bb.targetInfo.dist <= effRole(p, bb, "mainAtk", "AttackRange")
		if inMelee and effRole(p, bb, "mainAtk", "UseHomunSSkillAttack") == false then return false end
		if (not inMelee) and effRole(p, bb, "mainAtk", "UseHomunSSkillChase") == false then return false end
	end
	sys.castIntent(bb, sk, lvl)
	return true
end
reg.action("UseMainSkill", function(bb, p)
	if not effRole(p, bb, "mainAtk", "UseAttackSkill") then return S.FAILURE end
	for _, sk in ipairs(asList(prof(bb).mainAtk)) do                 -- lista de prioridade: conjura a 1ª utilizável
		if tryCastMain(bb, sk, p) then return S.SUCCESS end
	end
	return S.FAILURE
end, { desc = "Usa a 1ª skill single-target utilizável da lista (prioridade). Gates: UseHomunSSkillAttack (em alcance) / UseHomunSSkillChase (aproximando). Knobs: override por nó > Config global.",
	params = { UseAttackSkill = "boolean", AttackSkillReserveSP = "number", AttackRange = "number", UseHomunSSkillAttack = "boolean", UseHomunSSkillChase = "boolean" },
	optional = { "UseAttackSkill", "AttackSkillReserveSP", "AttackRange", "UseHomunSSkillAttack", "UseHomunSSkillChase" } })

------------------------------------------------------------------ buffs (self)
local function tryBuffList(bb, listed, enabled, role)
	if not enabled or not listed then return S.FAILURE end
	for _, sk in ipairs(listed) do
		if not sys.buffActive(bb, sk) then
			local lvl = usable(bb, sk, 0)
			if lvl then
				lvl = capSkill(bb, role, sk, lvl)
				sys.castIntent(bb, sk, lvl); return S.SUCCESS
			end
		end
	end
	return S.FAILURE
end
reg.action("UseOffensiveBuff", function(bb, p)
	return tryBuffList(bb, prof(bb).offBuff, effRole(p, bb, "offBuff", "UseOffensiveBuff"), "offBuff")
end, { desc = "Recasta auto-buffs ofensivos expirados (Bloodlust, Flitting, Pyroclastic, ...). Knob UseOffensiveBuff: override por nó > Config global.",
	params = { UseOffensiveBuff = "boolean" }, optional = { "UseOffensiveBuff" } })
reg.action("UseDefensiveBuff", function(bb, p)
	return tryBuffList(bb, prof(bb).defBuff, effRole(p, bb, "defBuff", "UseDefensiveBuff"), "defBuff")
end, { desc = "Recasta auto-buffs defensivos expirados (Amistr Bulwark, Granitic Armor, ...). Knob UseDefensiveBuff: override por nó > Config global.",
	params = { UseDefensiveBuff = "boolean" }, optional = { "UseDefensiveBuff" } })

------------------------------------------------------------------ cura
reg.action("UseHealSelf", function(bb, np)
	if not effRole(np, bb, "healSelf", "UseAutoHeal") then return S.FAILURE end
	local p = prof(bb)
	local sk = p.healSelfSkill
	if not sk then return S.FAILURE end
	if bb.self.hpPct >= effRole(np, bb, "healSelf", "HealSelfHP") then return S.FAILURE end
	local lvl = usable(bb, sk, 0); if not lvl then return S.FAILURE end
	bb:setIntent("skill", { skill = sk, level = lvl, target = bb.self.id, mode = 0, reason = sys.name(sk), heal = "self" })
	return S.SUCCESS
end, { desc = "Cura a si quando HP% < HealSelfHP (Chaotic Blessing)." })

reg.action("UseHealOwner", function(bb, np)
	if not effRole(np, bb, "healOwner", "UseAutoHeal") then return S.FAILURE end
	local p = prof(bb)
	local sk = p.healOwnerSkill
	if not (sk and bb.owner.exists) then return S.FAILURE end
	if bb.owner.hpPct == nil or bb.owner.hpPct >= effRole(np, bb, "healOwner", "HealOwnerHP") then return S.FAILURE end
	local lvl = usable(bb, sk, 0); if not lvl then return S.FAILURE end
	if bb.owner.dist > sys.range(sk, lvl) and sys.range(sk, lvl) > 0 then return S.FAILURE end
	bb:setIntent("skill", { skill = sk, level = lvl, target = bb.owner.id, mode = 1, reason = sys.name(sk), heal = "owner" })
	return S.SUCCESS
end, { desc = "Cura o dono quando HP% < HealOwnerHP (Healing Hands/Silent Breeze/Chaotic)." })

------------------------------------------------------------------ buff no dono
reg.action("UseOwnerBuff", function(bb, np)
	local p = prof(bb)
	if not (effRole(np, bb, "ownerBuff", "UseOwnerBuff") and p.ownerBuff and bb.owner.exists) then return S.FAILURE end
	if sys.buffActive(bb, p.ownerBuff) then return S.FAILURE end
	local lvl = usable(bb, p.ownerBuff, 0); if not lvl then return S.FAILURE end
	if sys.targetMode(p.ownerBuff) == 0 then
		-- self-cast cujo efeito vale p/ o dono (Goldene Tone do Bayeri): sem checagem de alcance
		bb:setIntent("skill", { skill = p.ownerBuff, level = lvl, target = bb.self.id, mode = 0, reason = sys.name(p.ownerBuff) })
		return S.SUCCESS
	end
	if bb.owner.dist > sys.range(p.ownerBuff, lvl) then return S.FAILURE end
	bb:setIntent("skill", { skill = p.ownerBuff, level = lvl, target = bb.owner.id, mode = 1, reason = sys.name(p.ownerBuff) })
	return S.SUCCESS
end, { desc = "Mantém o buff no dono (skills self-cast como Goldene Tone valem p/ o dono)." })

------------------------------------------------------------------ invocação (Sera — Legião)
-- Decisão pura de (re)invocar a Legião. Usa o ESTIMADOR (Fase 1: perception/skillsys),
-- não o hack de buff. Política de re-summon configurável (resummon: onExpire|keepFull|
-- minCount). Peças expostas em BRAI.sera p/ teste de unidade.
local function legionAlive(bb)
	local lg = bb.self.legion
	return lg ~= nil and lg.alive == true
end
local function legionCount(bb)
	local lg = bb.self.legion
	return (lg and lg.count) or 0
end
-- nível efetivo: clamp ao conhecido; nível inválido NÃO desliga em silêncio (bug A1)
local function summonLevel(bb, skill, p)
	local known = sys.knownLevel(bb, skill)
	if not known then return nil end
	local want = p and p.level
	if want and want >= 1 and want <= known then return want end
	return known
end
-- nº de inimigos no alcance (a própria legião já está fora de bb.monsters)
local function enemiesInRange(bb, range)
	local hx, hy = bb.self.x, bb.self.y
	local n = 0
	for _, m in ipairs(bb.monsters) do
		if util.chebyshev(hx, hy, m.x, m.y) <= range then n = n + 1 end
	end
	return n
end
-- a legião já está "suficiente" segundo a política? (true => não precisa invocar)
local function legionSufficient(bb, p, skill, level)
	local policy = (p and p.resummon) or "onExpire"
	if policy == "keepFull" then
		local def = BRAI.summons and BRAI.summons[skill]
		local maxc = def and def.perLevel and def.perLevel[level] and def.perLevel[level].count or 0
		return maxc > 0 and legionCount(bb) >= maxc
	elseif policy == "minCount" then
		return legionCount(bb) >= ((p and p.minCount) or 3)
	else -- onExpire (padrão, fiel à AzzyAI): só re-invoca quando expira/zera
		return legionAlive(bb)
	end
end

-- mescla params da invocação: nó (p) > config global (homun_summons.json) > padrão
local function mergeSummonParams(bb, p)
	local cfg = (BRAI.summonChoiceFor and BRAI.summonChoiceFor(bb.self.homunType)) or {}
	p = p or {}
	local out = {
		level = p.level or cfg.level,
		resummon = p.resummon or cfg.resummon,
		minCount = p.minCount or cfg.minCount,
		minMobCount = p.minMobCount or cfg.minMobCount,
		vsBossOnly = cfg.vsBossOnly,
	}
	if p.vsBossOnly ~= nil then out.vsBossOnly = p.vsBossOnly end
	return out
end

local function seraDecide(bb, p)
	if not bb.config.UseSummon then return S.FAILURE end
	local skill = prof(bb).summon
	if not (skill and bb.target) then return S.FAILURE end
	p = mergeSummonParams(bb, p)
	local level = summonLevel(bb, skill, p)
	if not level then return S.FAILURE end
	if legionSufficient(bb, p, skill, level) then return S.FAILURE end       -- não desperdiça SP
	if p and p.vsBossOnly and not BRAI.perception.targetIsBoss(bb) then return S.FAILURE end
	local minMob = (p and p.minMobCount) or 1
	if enemiesInRange(bb, sys.range(skill, level)) < minMob then return S.FAILURE end
	if not sys.ready(bb, skill) then return S.FAILURE end                    -- anti-stutter (delay de cast)
	if not sys.enoughSP(bb, skill, level, 0) then return S.FAILURE end
	if not sys.inRange(bb, skill, level) then return S.FAILURE end
	sys.castIntent(bb, skill, level)
	return S.SUCCESS
end

reg.action("UseSeraLegion", function(bb, p) return seraDecide(bb, p) end, {
	desc = "Sera: invoca/mantém a Legião (Summon Legion). resummon: onExpire|keepFull|minCount; level 1-5; vsBossOnly; minMobCount.",
	params = { level = "number", resummon = "string", minCount = "number", minMobCount = "number", vsBossOnly = "boolean" },
	optional = { "level", "resummon", "minCount", "minMobCount", "vsBossOnly" } })

-- alias compatível com a árvore gerada (tree_homun.lua usa "UseSummon") — params padrão
reg.action("UseSummon", function(bb) return seraDecide(bb, nil) end,
	{ desc = "Invoca a Legião com config padrão (alias de UseSeraLegion). Summon Legion (Sera)." })

BRAI.sera = { decide = seraDecide, legionAlive = legionAlive, legionCount = legionCount,
	summonLevel = summonLevel, legionSufficient = legionSufficient, enemiesInRange = enemiesInRange, mergeSummonParams = mergeSummonParams }

------------------------------------------------------------------ castling (Amistr)
reg.action("UseCastling", function(bb, np)
	local p = prof(bb)
	if not (effRole(np, bb, "castling", "UseCastling") and p.castling and bb.owner.exists) then return S.FAILURE end
	-- conta monstros no dono
	local n = 0
	for _, m in ipairs(bb.monsters) do if m.target == bb.owner.id then n = n + 1 end end
	if n < effRole(np, bb, "castling", "CastleDefendThreshold") then return S.FAILURE end
	local lvl = usable(bb, p.castling, 0); if not lvl then return S.FAILURE end
	bb:setIntent("skill", { skill = p.castling, level = lvl, target = bb.owner.id, mode = 0, reason = "Castling", castling = true })
	return S.SUCCESS
end, { desc = "Castling p/ tirar mobs do dono quando ele está cercado (Amistr)." })

------------------------------------------------------------------ skills específicas (editor)
-- Diagnóstico: registra (uma vez por motivo) por que uma skill do editor não saiu.
-- Aparece no log do simulador (TraceAI) e no console do RO, ajudando a depurar.
-- motivos "duros" (configuração errada) vs transitórios (estado normal de combate)
local HARD_REASON = {
	["sem skill definida no no"] = true,
	["homunculo atual nao conhece esta skill"] = true,
}
local function traceSkill(bb, action, skill, reason)
	bb.persist.tracedSkill = bb.persist.tracedSkill or {}
	local key = action .. "|" .. tostring(skill) .. "|" .. reason
	if bb.persist.tracedSkill[key] then return end
	bb.persist.tracedSkill[key] = true
	local nm = skill and (BRAI.skillsys.name(skill) .. " #" .. tostring(skill)) or "(sem skill)"
	-- [FALHA] (vermelho) = precisa corrigir; [skip] = estado normal (recarga/alcance/etc.)
	local tag = HARD_REASON[reason] and "[FALHA] " or "[skip] "
	BRAI.ro.trace(tag .. action .. ": nao usou " .. nm .. " — " .. reason)
end

-- Prontidão comum: conhece a skill, resolve o nível, checa cooldown e SP.
-- Em falha, devolve (nil, motivo) para o chamador registrar via traceSkill.
local function prepSkill(bb, p)
	local skill = p and p.skill
	if not skill then return nil, "sem skill definida no no" end
	if not sys.knows(bb, skill) then return nil, "homunculo atual nao conhece esta skill" end
	local known = sys.knownLevel(bb, skill)
	local level = (p and p.level) or known
	if level > known then level = known end
	if not sys.ready(bb, skill) then return nil, "em recarga (cooldown)" end
	if not sys.enoughSP(bb, skill, level, 0) then return nil, "SP insuficiente" end
	return skill, level
end

-- Intervalo customizado entre execuções (cooldown do nó, independente do jogo).
-- p.interval em ms (0 = sem intervalo). p.reset = ignora o intervalo quando o alvo muda.
local function intervalReady(bb, skill, p)
	local interval = (p and p.interval) or 0
	if interval <= 0 then return true end
	local lastAt = bb.persist.skillUsedAt and bb.persist.skillUsedAt[skill]
	if not lastAt then return true end
	if p.reset and bb.persist.skillUsedTarget and bb.persist.skillUsedTarget[skill] ~= bb.target then return true end
	return (bb:now() - lastAt) >= interval
end

-- BUFF em si mesmo (ex.: Tempering do Dieter). Não recasta enquanto ativo. (separado)
reg.action("UseSkillBuff", function(bb, p)
	local skill, level = prepSkill(bb, p)
	if not skill then traceSkill(bb, "UseSkillBuff", p and p.skill, level); return S.FAILURE end
	if (p and p.interval and p.interval > 0) then
		if not intervalReady(bb, skill, p) then return S.FAILURE end   -- intervalo customizado manda
	elseif sys.buffActive(bb, skill) then
		return S.FAILURE                                              -- senao, nao recasta enquanto ativo
	end
	bb:setIntent("skill", { skill = skill, level = level, target = bb.self.id, mode = 0, reason = sys.name(skill) })
	return S.SUCCESS
end, { desc = "Usa um buff em si mesmo (não recasta enquanto o efeito durar).", params = { skill = "number", level = "number" } })

-- Skill de DANO (unificada): alvo único (mode 1) ou área/solo (mode 2).
-- 'on' (só para área) escolhe o centro do cast: "enemy" (monstro-alvo) ou "owner" (dono).
-- Faz internamente as checagens de cooldown (prepSkill) e de alcance.
reg.action("UseSkill", function(bb, p)
	local skill, level = prepSkill(bb, p)
	if not skill then traceSkill(bb, "UseSkill", p and p.skill, level); return S.FAILURE end
	if not intervalReady(bb, skill, p) then traceSkill(bb, "UseSkill", skill, "aguardando intervalo configurado"); return S.FAILURE end
	local mode = sys.targetMode(skill)
	if mode == 1 then                                   -- dano em alvo único
		if not bb.target then traceSkill(bb, "UseSkill", skill, "sem alvo (precisa adquirir um monstro antes)"); return S.FAILURE end
		if not sys.inRange(bb, skill, level) then traceSkill(bb, "UseSkill", skill, "alvo fora de alcance"); return S.FAILURE end
		bb:setIntent("skill", { skill = skill, level = level, target = bb.target, mode = 1, reason = sys.name(skill) })
	elseif mode == 2 then                               -- dano em área (solo)
		local on = (p and p.on) or "enemy"
		local x, y
		if on == "owner" then
			if not bb.owner.exists then traceSkill(bb, "UseSkill", skill, "dono ausente"); return S.FAILURE end
			local r = sys.range(skill, level)
			if r > 0 and (bb.owner.dist or 1e9) > r then traceSkill(bb, "UseSkill", skill, "dono fora de alcance"); return S.FAILURE end
			x, y = bb.owner.x, bb.owner.y
		elseif sys.aoeCenter(skill) == 1 then           -- área centrada no próprio caster
			x, y = bb.self.x, bb.self.y
		else                                            -- centrada no monstro-alvo
			if not bb.targetInfo then traceSkill(bb, "UseSkill", skill, "sem alvo para mirar no solo"); return S.FAILURE end
			if not sys.inRange(bb, skill, level) then traceSkill(bb, "UseSkill", skill, "alvo fora de alcance"); return S.FAILURE end
			x, y = bb.targetInfo.x, bb.targetInfo.y
		end
		bb:setIntent("skill", { skill = skill, level = level, x = x, y = y, mode = 2, reason = sys.name(skill), on = on })
	else                                                -- mode 0 (self): compatibilidade
		bb:setIntent("skill", { skill = skill, level = level, target = bb.self.id, mode = 0, reason = sys.name(skill) })
	end
	return S.SUCCESS
end, { desc = "Usa uma skill de dano: alvo único ou área. 'on' define o centro das skills de área.", params = { skill = "number", level = "number", on = "string" } })

------------------------------------------------------------------ Homunculus S: estilo e combos
-- SetStyle: garante o estilo desejado (Eleanor), conjurando Style Change se necessário.
reg.action("SetStyle", function(bb, p)
	local want = (p and p.style) or "power"
	local cur = bb.persist.style or "power"          -- assume "power" (modo Combate) como inicial
	if cur == want then return S.FAILURE end          -- já está no estilo: nada a fazer
	local sk = BRAI.skills.id.MH_STYLE_CHANGE
	if not sys.knows(bb, sk) then return S.FAILURE end
	local lvl = sys.knownLevel(bb, sk)
	if not sys.ready(bb, sk) then return S.FAILURE end
	if not sys.enoughSP(bb, sk, lvl, 0) then return S.FAILURE end
	bb:setIntent("skill", { skill = sk, level = lvl, target = bb.self.id, mode = 0, reason = "Style Change" })
	bb.persist.style = want                           -- alterna o estilo rastreado
	return S.SUCCESS
end, { desc = "Garante o estilo (Eleanor): conjura Style Change se necessário. style: power|grapple.", params = { style = "string" } })

-- UseCombo: executa um combo (sequência de golpes) no alvo, passo a passo.
reg.action("UseCombo", function(bb, p)
	local key = p and p.combo
	local chain = key and BRAI.combos and BRAI.combos[key]
	if not chain or not bb.target then return S.FAILURE end
	local now = bb:now()
	local window = (p and p.window) or 2000           -- janela p/ encadear o próximo golpe (ms)
	local st = bb.persist.combo
	local step = 1
	if st and st.key == key and (now - st.at) <= window and st.step < #chain then
		step = st.step + 1                            -- avança no combo
	end
	local sk = chain[step]
	if not sys.knows(bb, sk) then return S.FAILURE end
	local lvl = sys.knownLevel(bb, sk)
	if not sys.ready(bb, sk) then return S.FAILURE end      -- passo em recarga: espera
	if not sys.enoughSP(bb, sk, lvl, 0) then return S.FAILURE end
	if not sys.inRange(bb, sk, lvl) then return S.FAILURE end
	bb:setIntent("skill", { skill = sk, level = lvl, target = bb.target, mode = 1, reason = sys.name(sk), combo = key, step = step })
	bb.persist.combo = { key = key, step = step, at = now }
	return S.SUCCESS
end, { desc = "Executa um combo no alvo (sequência de golpes). combo: power|grapple.", params = { combo = "string", window = "number" } })

------------------------------------------------------------------ Eleanor: nó guarda-chuva
-- UseEleanorOffense: orquestra ESTILO + ESFERAS + COMBO + BARRAGEM num só nó (decisão pura).
-- Emite UMA intenção por tick e devolve SUCCESS (emitiu) ou FAILURE (deixa o ramo seguir
-- p/ ataque/chase). As peças internas (desiredStyle/ensureStyle/comboStep) ficam expostas
-- em BRAI.eleanor para teste de unidade. Ameaça/boss (Fase 3) entram em desiredStyle depois.
local ELEANOR = BRAI.const.ELEANOR
local STYLE_LOCK_MS = 1000   -- anti-loop: não troca de estilo de novo dentro desta janela

-- mapa reverso skill -> estilo (de BRAI.combos), p/ reconciliar a crença de estilo ao castar
local comboStyleOf = {}
for style, chain in pairs(BRAI.combos or {}) do
	for _, sk in ipairs(chain) do comboStyleOf[sk] = style end
end

local function currentStyle(bb) return bb.persist.style or "power" end   -- Eleanor nasce em "power"

-- alvo é Boss/MVP? (flag de percepção OU grupo de boss do catálogo monsters.json)
local function isTargetBoss(bb) return BRAI.perception.targetIsBoss(bb) end

-- estilo desejado. grapple/auto exigem ISOLAMENTO (threat assessment); senão fallback p/ power.
local function desiredStyle(bb, p)
	local want = (p and p.style) or "power"
	if want == "power" then return "power" end
	local radius = (p and p.grappleRadius) or 3
	local limit  = (p and p.grappleThreatLimit) or bb.config.GrappleThreatLimit or 1
	if BRAI.perception.threatCount(bb, radius) <= limit then return "grapple" end
	return "power"
end

-- garante o estilo: "ok" (já está), "switched" (emitiu Style Change) ou "locked" (não pôde).
local function ensureStyle(bb, want, allowSwitch)
	if currentStyle(bb) == want then return "ok" end
	if allowSwitch == false then return "locked" end
	local now = bb:now()
	if (now - (bb.persist.styleSwitchAt or -1e9)) < ((bb.config and bb.config.StyleSwitchLockMs) or STYLE_LOCK_MS) then return "locked" end  -- anti-loop
	local sk = BRAI.skills.id.MH_STYLE_CHANGE
	if not sys.knows(bb, sk) then return "locked" end
	local lvl = sys.knownLevel(bb, sk)
	if not sys.ready(bb, sk) then return "locked" end
	if not sys.enoughSP(bb, sk, lvl, 0) then return "locked" end
	bb:setIntent("skill", { skill = sk, level = lvl, target = bb.self.id, mode = 0, reason = "Style Change" })
	bb.persist.style = want
	bb.persist.styleSwitchAt = now
	bb.persist.combo = nil   -- troca de cadeia => reinicia o combo
	bb.persist.grappleRooted = false
	return "switched"
end

-- passo do combo a tentar (1..#chain). Reseta ao step 1 se: sem combo, troca de estilo,
-- TROCA DE ALVO (R6), janela expirada (R1/janela) ou finisher concluído.
local function comboStep(bb, style, window)
	local chain = BRAI.combos and BRAI.combos[style]
	if not chain then return nil, nil end
	local st = bb.persist.combo
	local step = 1
	if st and st.key == style and st.targetId == bb.target
	   and (bb:now() - st.at) <= window and st.step < #chain then
		step = st.step + 1
	end
	return step, chain
end

-- Precedência dos params do combo: param do nó (p) > padrão salvo da tela (comboChoiceFor) > config/hardcoded.
local function mergeCombo(bb, p)
	local d = (BRAI.comboChoiceFor and BRAI.comboChoiceFor(bb.self.homunType)) or {}
	if not next(d) then return p end                     -- sem padrão salvo → comportamento atual
	local m = {}
	for k, v in pairs(d) do m[k] = v end
	if p then for k, v in pairs(p) do m[k] = v end end   -- o nó (árvore) vence o padrão
	return m
end

reg.action("UseEleanorOffense", function(bb, p)
	if bb.self.homunType ~= ELEANOR then return S.FAILURE end
	if not bb.target then bb.persist.combo = nil; bb.persist.grappleRooted = false; return S.FAILURE end   -- alvo morto/sumiu (R1)
	p = mergeCombo(bb, p)   -- aplica o padrão da tela; params do nó têm precedência

	local allowSwitch = not (p and p.allowStyleSwitch == false) and not bb.config.EleanorDoNotSwitchMode  -- trava de estilo (migrada)
	local es = ensureStyle(bb, desiredStyle(bb, p), allowSwitch)
	if es == "switched" then return S.SUCCESS end                       -- gastou o tick trocando
	local style = (es == "ok") and desiredStyle(bb, p) or currentStyle(bb)

	local window = (p and p.window) or 2000
	local step, chain = comboStep(bb, style, window)
	if not chain then return S.FAILURE end

	local barragem = (p and p.comboSpheres) or bb.config.AutoComboSpheres or 0
	if step == 1 and sys.spheres(bb) < barragem then return S.FAILURE end   -- barragem (R5)

	local sk = chain[step]
	if sk == BRAI.skills.id.MH_EQC and isTargetBoss(bb) then return S.FAILURE end   -- boss guard (R8): EQC proibido em Boss/MVP
	if not sys.knows(bb, sk) then return S.FAILURE end
	local lvl = (p and p.levels and p.levels[style] and p.levels[style][step]) or sys.knownLevel(bb, sk)
	if not sys.ready(bb, sk) then return S.FAILURE end                     -- elo em recarga
	if not sys.enoughSP(bb, sk, lvl, 0) then return S.FAILURE end
	if not sys.inRange(bb, sk, lvl) then return S.FAILURE end
	if sys.spheres(bb) < sys.sphereCostOf(sk) then return S.FAILURE end    -- gate por elo (R5)
	local minGap = (p and p.minGap) or 0
	if minGap > 0 and (bb:now() - (bb.persist.lastComboCastAt or -1e9)) < minGap then return S.FAILURE end  -- modulação de lag

	bb:setIntent("skill", { skill = sk, level = lvl, target = bb.target, mode = 1,
		reason = sys.name(sk), combo = style, step = step })
	bb.persist.combo = { key = style, step = step, at = bb:now(), targetId = bb.target }
	bb.persist.lastComboCastAt = bb:now()
	bb.persist.style = comboStyleOf[sk] or style   -- reconcilia a crença de estilo (R3/R4)
	-- enraizado durante Tinder/CBC (Flee=0); E.Q.C. libera; power nunca enraíza.
	bb.persist.grappleRooted = (sk == BRAI.skills.id.MH_TINDER_BREAKER or sk == BRAI.skills.id.MH_CBC)
	return S.SUCCESS
end, { desc = "Eleanor: combo + estilo + barragem (esferas) num só nó. style: power|grapple|auto.",
	params = { style = "string", comboSpheres = "number", window = "number", grappleThreatLimit = "number", minGap = "number", allowStyleSwitch = "boolean" } })

-- expõe as peças internas p/ teste de unidade (PLANO §9.1)
BRAI.eleanor = { currentStyle = currentStyle, desiredStyle = desiredStyle,
	ensureStyle = ensureStyle, comboStep = comboStep, isTargetBoss = isTargetBoss,
	threatCount = function(bb, r) return BRAI.perception.threatCount(bb, r) end }

return true
