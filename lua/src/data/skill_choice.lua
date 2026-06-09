-- skill_choice.lua — escolha global de skill por papel e por tipo de homunculo.
-- Alguns Homunculus S tem mais de uma skill no mesmo papel (ex.: Dieter tem
-- Lava Slide e Blast Forge em AoE; Pyroclastic e Tempering como buff ofensivo).
-- Esta tabela escolhe QUAL skill cada acao automatica usa. Persistida em
-- homun_skills.json (igual ao monsters.json) e aplicada em BRAI.profileFor.
BRAI = BRAI or {}

-- [homunType] = { mainAtk=id, aoeAtk=id, offBuff=id, defBuff=id } (so papeis sobrescritos)
BRAI.skillChoice = BRAI.skillChoice or {}

local ROLE_KEYS = { mainAtk = true, aoeAtk = true, offBuff = true, defBuff = true }
-- nível por papel (migrado da AzzyAI): mainAtkLevel/aoeAtkLevel/offBuffLevel/defBuffLevel
local LEVEL_KEYS = { mainAtkLevel = "mainAtk", aoeAtkLevel = "aoeAtk", offBuffLevel = "offBuff", defBuffLevel = "defBuff" }

-- Padrão de COMBO por homúnculo (só Eleanor por ora; estrutura genérica por homunType).
-- Chaves iguais às dos params do nó UseEleanorOffense (precedência node>padrão é trivial).
local COMBO_STYLE = { power = true, grapple = true, auto = true }
local function parseCombo(c)
	if type(c) ~= "table" then return nil end
	local o = {}
	if type(c.style) == "string" and COMBO_STYLE[c.style] then o.style = c.style end
	local function num(k, lo, hi) local v = tonumber(c[k]); if v and (not lo or v >= lo) and (not hi or v <= hi) then return v end end
	local w = num("window", 0);                       if w then o.window = w end
	local b = num("comboSpheres", 0, 10) or num("autoComboSpheres", 0, 10); if b then o.comboSpheres = b end
	local g = num("grappleThreatLimit", 0);           if g then o.grappleThreatLimit = g end
	local mg = num("minGap", 0);                       if mg then o.minGap = mg end
	if type(c.allowStyleSwitch) == "boolean" then o.allowStyleSwitch = c.allowStyleSwitch end
	if type(c.levels) == "table" then
		o.levels = {}
		for _, st in ipairs({ "power", "grapple" }) do
			if type(c.levels[st]) == "table" then
				o.levels[st] = {}
				for i, lv in ipairs(c.levels[st]) do local n = tonumber(lv); if n and n >= 1 then o.levels[st][i] = math.floor(n) end end
			end
		end
	end
	return next(o) and o or nil
end

-- Define o override global. Aceita { choices = { ["51"]={aoeAtk=8044}, ... } } (do JSON)
-- ou o mapa direto { [51]={...} }. Chaves string viram numero; papeis/ids invalidos sao ignorados.
function BRAI.setSkillChoice(tbl)
	local out = {}
	if type(tbl) == "table" then
		local src = tbl.choices or tbl
		if type(src) == "table" then
			for k, roles in pairs(src) do
				local t = tonumber(k)
				if t and type(roles) == "table" then
					local r = {}
					for rk, sid in pairs(roles) do
						if rk == "combo" then
							local cc = parseCombo(sid); if cc then r.combo = cc end
						elseif rk == "skillLevels" and type(sid) == "table" then
							r.skillLevels = {}
							for k2, v2 in pairs(sid) do
								local id2, lv2 = tonumber(k2), tonumber(v2)
								if id2 and id2 > 0 and lv2 and lv2 >= 1 and lv2 <= 10 then r.skillLevels[id2] = math.floor(lv2) end
							end
						elseif ROLE_KEYS[rk] and type(sid) == "table" then
							local lst = {}
							for _, v in ipairs(sid) do local i = tonumber(v); if i and i > 0 then lst[#lst + 1] = i end end
							r[rk] = lst   -- preserva LISTA VAZIA (= nenhuma skill); chave ausente = padrão do perfil
						else
							local id = tonumber(sid)
							if ROLE_KEYS[rk] and id and id > 0 then r[rk] = id
							elseif LEVEL_KEYS[rk] and id and id > 0 then
								r.levels = r.levels or {}; r.levels[LEVEL_KEYS[rk]] = id
							end
						end
					end
					out[t] = r
				end
			end
		end
	end
	BRAI.skillChoice = out
	return out
end

-- Aplica o override sobre o perfil efetivo `m` (chamado por BRAI.profileFor).
-- offBuff/defBuff viram lista de 1 (substitui a lista do perfil). mainAtk/aoeAtk: id direto.
function BRAI.applySkillChoice(homunType, m)
	local ch = BRAI.skillChoice[homunType]
	if not ch then return m end
	if ch.mainAtk ~= nil then m.mainAtk = ch.mainAtk end
	if ch.aoeAtk  ~= nil then m.aoeAtk  = ch.aoeAtk  end
	if ch.offBuff ~= nil then m.offBuff = (type(ch.offBuff) == "table") and ch.offBuff or { ch.offBuff } end
	if ch.defBuff ~= nil then m.defBuff = (type(ch.defBuff) == "table") and ch.defBuff or { ch.defBuff } end
	if ch.levels then  -- nível por papel (migrado): consumido pelas ações automáticas em skills.lua
		m.roleLevels = m.roleLevels or {}
		for k, v in pairs(ch.levels) do m.roleLevels[k] = v end
	end
	if ch.skillLevels then  -- nível POR SKILL (precede o por papel em capSkill)
		m.skillLevels = m.skillLevels or {}
		for k, v in pairs(ch.skillLevels) do m.skillLevels[k] = v end
	end
	return m
end

-- Padrão de combo salvo p/ um homúnculo (vazio = sem padrão; UseEleanorOffense cai no config/hardcoded).
function BRAI.comboChoiceFor(homunType)
	local ch = BRAI.skillChoice[tonumber(homunType) or 0]
	return (ch and ch.combo) or {}
end

-- Papeis da tela "Skills por homunculo": 4 EDITAVEIS (escolha de skill) + 4 FIXOS (cura/buff do
-- dono/castling, so leitura, vindos do perfil/base) — casa com os 8 papeis do modal de Parametros.
local ROLES = {
	{ key = "mainAtk", single = true },
	{ key = "aoeAtk",  single = true },
	{ key = "offBuff", single = false },
	{ key = "defBuff", single = false },
	{ key = "healSelf",  single = true,  fixed = true },
	{ key = "healOwner", single = true,  fixed = true },
	{ key = "ownerBuff", single = false, fixed = true },
	{ key = "castling",  single = true,  fixed = true },
}

-- Skill unica de cura/ownerBuff/castling de um perfil (MESMA regra de paramConfig/action_skills).
local function roleSkillOf(pr, role)
	if role == "healSelf" then if pr.healSelf and pr.heal then return pr.heal end
	elseif role == "healOwner" then if pr.healOwner and pr.heal then return pr.heal end
	elseif role == "ownerBuff" then return pr.ownerBuff
	elseif role == "castling" then return pr.castling end
	return nil
end

-- roleConfig(homunType[, baseType]): dados p/ a tela "Skills por homunculo" (1 dispatch). 8 papeis;
-- os fixos resolvem a skill propria ou herdada do tipo base (Homunculus S).
-- Por papel: candidatos (skills DESTE tipo nesse papel), o padrao (do perfil) e a escolha atual.
function BRAI.roleConfig(homunType, baseType)
	homunType = tonumber(homunType) or 0
	baseType = tonumber(baseType) or 0
	local prof = BRAI.getProfile(homunType) or {}
	-- forma base do Homunculus S (cura/ownerBuff/castling herdam dela), como em profileFor
	local base = (baseType ~= 0 and baseType ~= homunType and BRAI.getProfile and BRAI.getProfile(baseType)) or nil
	local cat = BRAI.skillCatalog(homunType, baseType)
	local byRole, descById, maxById, nameById, catById = {}, {}, {}, {}, {}
	for _, s in ipairs(cat) do
		descById[s.id] = s.desc or ""
		maxById[s.id] = s.maxLevel or 1
		nameById[s.id] = s.iro
		catById[s.id] = s
		if s.role then
			byRole[s.role] = byRole[s.role] or {}
			local b = byRole[s.role]
			b[#b + 1] = { id = s.id, name = s.iro, iro = s.iro, desc = s.desc or "", maxLevel = s.maxLevel or 1,
				cat = s.cat, target = s.target, sp = s.sp, range = s.range, area = s.area,
				fixedCast = s.fixedCast, varCast = s.varCast, delay = s.delay, reuse = s.reuse,
				duration = s.duration, effect = s.effect }   -- info p/ o card on-hover (igual ao UseSkill)
		end
	end
	local ch = BRAI.skillChoice[homunType] or {}
	local lvls = ch.levels or {}
	-- monta a entrada de UMA skill (com os campos do card on-hover) a partir do catalogo
	local function catEntry(id)
		local s = catById[id]
		if not s then return { id = id, name = nameById[id] or ("#" .. id), iro = nameById[id] or ("#" .. id), desc = descById[id] or "", maxLevel = maxById[id] or 1, level = 0 } end
		return { id = id, name = s.iro, iro = s.iro, desc = s.desc or "", maxLevel = s.maxLevel or 1, level = 0,
			cat = s.cat, target = s.target, sp = s.sp, range = s.range, area = s.area,
			fixedCast = s.fixedCast, varCast = s.varCast, delay = s.delay, reuse = s.reuse,
			duration = s.duration, effect = s.effect }
	end
	local out = {}
	for _, r in ipairs(ROLES) do
		if r.fixed then
			-- papel FIXO (cura/buff do dono/castling): skill propria ou herdada do base; so leitura
			local id = roleSkillOf(prof, r.key) or (base and roleSkillOf(base, r.key))
			local eff = id and { catEntry(id) } or {}
			out[#out + 1] = { key = r.key, fixed = true, candidates = eff, defaultIds = (id and { id } or {}), defaultDescs = {}, chosen = 0, overridden = false, level = 0, effectiveMaxLevel = (id and (maxById[id] or 1)) or 1, effective = eff }
		else
		local cands = byRole[r.key] or {}
		local defIds, defDescs = {}, {}
		local pv = prof[r.key]   -- aceita LISTA (vários padrões) OU id único (qualquer papel)
		if type(pv) == "table" then for _, id in ipairs(pv) do defIds[#defIds + 1] = id end
		elseif pv then defIds[1] = pv end
		for _, id in ipairs(defIds) do defDescs[#defDescs + 1] = descById[id] or "" end
		local chRole = ch[r.key]
		local chosen = (type(chRole) == "number") and chRole or 0   -- só single conta como "escolhido" no combo
		-- lista EFETIVA de skills do papel: override (lista|id) senão o padrão do perfil
		local effIds
		if type(chRole) == "table" then effIds = chRole
		elseif type(chRole) == "number" and chRole > 0 then effIds = { chRole }
		else effIds = defIds end
		local skLevels = ch.skillLevels or {}
		local effective = {}
		for _, id in ipairs(effIds) do
			effective[#effective + 1] = { id = id, name = nameById[id] or ("#" .. id),
				desc = descById[id] or "", maxLevel = maxById[id] or 1, level = skLevels[id] or 0 }
		end
		local effId = effIds[1] or (cands[1] and cands[1].id) or 0
		out[#out + 1] = {
			key = r.key,
			candidates = cands,
			defaultIds = defIds,
			defaultDescs = defDescs,        -- descrição do(s) skill(s) padrão do perfil
			chosen = chosen, overridden = (chRole ~= nil),  -- override explícito (lista, incl. vazia) vs padrão
			level = lvls[r.key] or 0,        -- 0 = nível padrão (por papel; compat)
			effectiveMaxLevel = maxById[effId] or 1,
			effective = effective,           -- M4: skills ativas (perfil/override) + nível por skill (UI)
		}
		end
	end
	return out
end

-- allSkillChoices(raw): escolha EFETIVA por papel p/ os 9 homuns, derivada dos perfis
-- (defaults) mesclados com os overrides do usuario (raw = homun_skills.json cru). Saida no
-- formato consumido por generateSkillChoice: { ["<type>"] = { mainAtk={ids}, aoeAtk={ids},
-- offBuff={ids}, defBuff={ids}, <papel>Level=n, skillLevels={[id]=lv}, combo={...} } }.
-- Torna o pacote AUTO-DESCRITIVO (todas as skills padrao explicitas) e IDENTICO a tela "Skills"
-- (mesma fonte: roleConfig.effective). Preserva override vazio (papel esvaziado de proposito).
-- [PLANO-GERACAO-LUA #3]
function BRAI.allSkillChoices(raw)
	local C = BRAI.const
	local TYPES = { C.LIF, C.AMISTR, C.FILIR, C.VANILMIRTH, C.EIRA, C.BAYERI, C.SERA, C.DIETER, C.ELEANOR }
	local saved = BRAI.skillChoice
	if raw ~= nil then BRAI.setSkillChoice(raw) end          -- aplica os overrides do usuario temporariamente
	local out = {}
	for _, t in ipairs(TYPES) do
		local rc = BRAI.roleConfig(t)
		local entry, skillLevels = {}, {}
		for _, role in ipairs(rc) do
			local ids = {}
			for _, e in ipairs(role.effective) do
				ids[#ids + 1] = e.id
				if e.level and e.level > 0 then skillLevels[e.id] = e.level end
			end
			-- exporta a lista quando ha skills OU quando o usuario sobrescreveu (incl. lista vazia)
			if (not role.fixed) and (#ids > 0 or role.overridden) then entry[role.key] = ids end
			if (not role.fixed) and role.level and role.level > 0 then entry[role.key .. "Level"] = role.level end
		end
		if next(skillLevels) then entry.skillLevels = skillLevels end
		local combo = BRAI.comboChoiceFor(t)
		if combo and next(combo) then entry.combo = combo end
		out[tostring(t)] = entry
	end
	BRAI.skillChoice = saved                                 -- restaura o estado global
	return out
end

return true
