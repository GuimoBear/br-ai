-- skill_choice.lua — escolha global de skill por papel e por tipo de homunculo.
-- Alguns Homunculus S tem mais de uma skill no mesmo papel (ex.: Dieter tem
-- Lava Slide e Blast Forge em AoE; Pyroclastic e Tempering como buff ofensivo).
-- Esta tabela escolhe QUAL skill cada acao automatica usa. Persistida em
-- homun_skills.json (igual ao monsters.json) e aplicada em BRAI.profileFor.
BRAI = BRAI or {}

-- [homunType] = { mainAtk=id, aoeAtk=id, offBuff=id, defBuff=id } (so papeis sobrescritos)
BRAI.skillChoice = BRAI.skillChoice or {}

local ROLE_KEYS = { mainAtk = true, aoeAtk = true, offBuff = true, defBuff = true }

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
						local id = tonumber(sid)
						if ROLE_KEYS[rk] and id and id > 0 then r[rk] = id end
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
	if ch.mainAtk then m.mainAtk = ch.mainAtk end
	if ch.aoeAtk  then m.aoeAtk  = ch.aoeAtk  end
	if ch.offBuff then m.offBuff = { ch.offBuff } end
	if ch.defBuff then m.defBuff = { ch.defBuff } end
	return m
end

-- Papeis configuraveis na tela (os 4 citados: main, AoE, buff ofensivo, buff defensivo).
local ROLES = {
	{ key = "mainAtk", single = true },
	{ key = "aoeAtk",  single = true },
	{ key = "offBuff", single = false },
	{ key = "defBuff", single = false },
}

-- roleConfig(homunType): dados p/ a tela "Skills por homunculo" (1 dispatch).
-- Por papel: candidatos (skills DESTE tipo nesse papel), o padrao (do perfil) e a escolha atual.
function BRAI.roleConfig(homunType)
	homunType = tonumber(homunType) or 0
	local prof = BRAI.getProfile(homunType) or {}
	local cat = BRAI.skillCatalog(homunType, 0)
	local byRole = {}
	for _, s in ipairs(cat) do
		if s.role then
			byRole[s.role] = byRole[s.role] or {}
			local b = byRole[s.role]
			b[#b + 1] = { id = s.id, name = s.iro }
		end
	end
	local ch = BRAI.skillChoice[homunType] or {}
	local out = {}
	for _, r in ipairs(ROLES) do
		local cands = byRole[r.key] or {}
		local defIds = {}
		if r.single then
			if prof[r.key] then defIds[1] = prof[r.key] end
		else
			local arr = prof[r.key]
			if type(arr) == "table" then for _, id in ipairs(arr) do defIds[#defIds + 1] = id end end
		end
		out[#out + 1] = {
			key = r.key,
			candidates = cands,
			defaultIds = defIds,
			chosen = ch[r.key] or 0,   -- 0 = usar o padrao do perfil
		}
	end
	return out
end

return true
