-- skill_meta.lua — metadados de apresentação das skills (Renewal, ratemyserver):
-- nome iRO, categoria (single/aoe/buff/heal/special/passive) e descrição curta.
-- Os números (alcance/SP/área/nível) vêm de skills.lua (conferidos contra o Renewal).
-- BRAI.skillCatalog(homunType, baseType) monta a lista disponível p/ o editor.
--
-- `role` = papel na árvore (qual ação automática usa a skill). Usado pela tela
-- "Skills por homúnculo" p/ listar candidatos por papel:
--   mainAtk · aoeAtk · offBuff · defBuff · heal · ownerBuff · summon · castling
--   · styleChange · debuffAoE · combo · special · passive
BRAI = BRAI or {}
local S = BRAI.skills.id
local sys = BRAI.skillsys

-- cat: "single" dano alvo único · "aoe" dano em área · "buff" · "heal" · "special" · "passive"
local meta = {
	[S.HLIF_HEAL]          = { iro = "Healing Hands",       cat = "heal",    role = "heal",       desc = "Cura o HP do dono (estilo Heal do Acólito)." },
	[S.HLIF_AVOID]         = { iro = "Urgent Escape",       cat = "buff",    role = "defBuff",    desc = "Aumenta a velocidade de movimento de dono e homúnculo." },
	[S.HLIF_CHANGE]        = { iro = "Mental Charge",       cat = "buff",    role = "offBuff",    desc = "Troca HP/SP máx; ataques normais somam o MATK do Lif." },
	[S.HAMI_CASTLE]        = { iro = "Castling",            cat = "special", role = "castling",   desc = "Troca de posição com o dono (tira mobs de cima dele)." },
	[S.HAMI_DEFENCE]       = { iro = "Amistr Bulwark",      cat = "buff",    role = "defBuff",    desc = "Buff defensivo: aumenta muito a DEF por um tempo." },
	[S.HAMI_BLOODLUST]     = { iro = "Bloodlust",           cat = "buff",    role = "offBuff",    desc = "Buff ofensivo: ATK e chance de roubo de HP." },
	[S.HFLI_MOON]          = { iro = "Moonlight",           cat = "single",  role = "mainAtk",    desc = "Ataque corpo a corpo de alvo único." },
	[S.HFLI_FLEET]         = { iro = "Flitting",            cat = "buff",    role = "offBuff",    desc = "Buff ofensivo: FLEE/ATK/ASPD por um tempo." },
	[S.HFLI_SPEED]         = { iro = "Accelerated Flight",  cat = "buff",    role = "defBuff",    desc = "Buff defensivo: aumenta ASPD/esquiva." },
	[S.HFLI_SBR44]         = { iro = "S.B.R.44",            cat = "single",  role = "special",    desc = "Nuke de alvo único proporcional à intimidade (consome-a). Cuidado." },
	[S.HVAN_CAPRICE]       = { iro = "Caprice",             cat = "single",  role = "mainAtk",    desc = "Lança um Bolt aleatório no alvo (alcance 9)." },
	[S.HVAN_CHAOTIC]       = { iro = "Chaotic Blessings",   cat = "heal",    role = "heal",       desc = "Heal aleatório em dono, inimigo ou no próprio homúnculo." },
	[S.HVAN_SELFDESTRUCT]  = { iro = "Self Destruction",    cat = "aoe",     role = "special",    desc = "Autodestrói causando dano em área proporcional ao HP máx. Cuidado." },
	[S.MH_SUMMON_LEGION]   = { iro = "Summon Legion",       cat = "special", role = "summon",     desc = "Invoca insetos que atacam o alvo." },
	[S.MH_NEEDLE_OF_PARALYZE]={ iro = "Needle of Paralysis",cat = "single",  role = "mainAtk",    desc = "Dano de alvo único com chance de paralisia." },
	[S.MH_POISON_MIST]     = { iro = "Poison Mist",         cat = "aoe",     role = "aoeAtk",     desc = "Névoa no chão: dano em área e cegueira." },
	[S.MH_PAIN_KILLER]     = { iro = "Painkiller",          cat = "special", role = "ownerBuff",  desc = "Buff no dono: reduz dano recebido." },
	[S.MH_LIGHT_OF_REGENE] = { iro = "Ray of Regeneration", cat = "buff",    role = "special",    desc = "Permite reviver o homúnculo uma vez ao morrer." },
	[S.MH_OVERED_BOOST]    = { iro = "Overed Boost",        cat = "buff",    role = "offBuff",    desc = "Buff ofensivo: ASPD e FLEE altíssimos por um tempo." },
	[S.MH_ERASER_CUTTER]   = { iro = "Erase Cutter",        cat = "single",  role = "mainAtk",    desc = "Dano mágico de alvo único (alcance 7)." },
	[S.MH_XENO_SLASHER]    = { iro = "Xeno Slasher",        cat = "aoe",     role = "aoeAtk",     desc = "Dano mágico em área no chão (sangramento)." },
	[S.MH_SILENT_BREEZE]   = { iro = "Silent Breeze",       cat = "heal",    role = "heal",       desc = "Cura o alvo e remove silêncio." },
	[S.MH_STYLE_CHANGE]    = { iro = "Style Change",        cat = "special", role = "styleChange",desc = "Alterna entre modo Power e Defense (Eleanor)." },
	[S.MH_SONIC_CLAW]      = { iro = "Sonic Claw",          cat = "single",  role = "mainAtk",    desc = "Garra rápida de alvo único (gasta esferas)." },
	[S.MH_SILVERVEIN_RUSH] = { iro = "Silvervein Rush",     cat = "single",  role = "combo",      desc = "Combo após Sonic Claw (modo Power)." },
	[S.MH_MIDNIGHT_FRENZY] = { iro = "Midnight Frenzy",     cat = "single",  role = "combo",      desc = "Combo após Silvervein Rush (gasta esferas)." },
	[S.MH_STAHL_HORN]      = { iro = "Stahl Horn",          cat = "single",  role = "mainAtk",    desc = "Investida de alvo único (Bayeri)." },
	[S.MH_GOLDENE_FERSE]   = { iro = "Golden Ferse",        cat = "buff",    role = "offBuff",    desc = "Buff ofensivo: ASPD e FLEE." },
	[S.MH_STEINWAND]       = { iro = "Stein Wand",          cat = "buff",    role = "defBuff",    desc = "Barreira defensiva sobre dono e homúnculo." },
	[S.MH_HEILIGE_STANGE]  = { iro = "Heilige Stange",      cat = "aoe",     role = "aoeAtk",     desc = "Dano físico em área (alcance 9, Bayeri)." },
	[S.MH_ANGRIFFS_MODUS]  = { iro = "Angriff Modus",       cat = "buff",    role = "offBuff",    desc = "Buff ofensivo: ATK alto, reduz DEF/FLEE." },
	[S.MH_TINDER_BREAKER]  = { iro = "Tinder Breaker",      cat = "single",  role = "mainAtk",    desc = "Agarra o alvo e impede fuga (inicia combo grappler)." },
	[S.MH_CBC]             = { iro = "C.B.C.",              cat = "single",  role = "combo",      desc = "Combo do grappler após Tinder Breaker." },
	[S.MH_EQC]             = { iro = "E.Q.C.",              cat = "single",  role = "combo",      desc = "Finaliza o combo grappler (reduz DEF do alvo)." },
	[S.MH_MAGMA_FLOW]      = { iro = "Magma Flow",          cat = "buff",    role = "defBuff",    desc = "Reativo: dano em área ao ser atingido (Dieter)." },
	[S.MH_GRANITIC_ARMOR]  = { iro = "Granitic Armor",      cat = "buff",    role = "defBuff",    desc = "Buff defensivo: reduz dano recebido." },
	[S.MH_LAVA_SLIDE]      = { iro = "Lava Slide",          cat = "aoe",     role = "aoeAtk",     desc = "Lava no chão: dano em área e queimadura." },
	[S.MH_PYROCLASTIC]     = { iro = "Pyroclastic",         cat = "buff",    role = "offBuff",    desc = "Buff ofensivo forte de ATK (encanta a arma)." },
	[S.MH_VOLCANIC_ASH]    = { iro = "Volcanic Ash",        cat = "aoe",     role = "debuffAoE",  desc = "Cinzas em área: cega e reduz atributos (debuff)." },
	[S.MH_BLAST_FORGE]     = { iro = "Blast Forge",         cat = "aoe",     role = "aoeAtk",     desc = "Dano de fogo em área no chão." },
	[S.MH_TEMPERING]       = { iro = "Tempering",           cat = "buff",    role = "offBuff",    desc = "Buff ofensivo: aumenta dano de fogo / resistência." },
	[S.MH_BLAZING_AND_FURIOUS]={ iro = "Blazing and Furious", cat = "aoe",     role = "special",    desc = "Avança e dá dano físico em área (ignora DEF); consome TODAS as esferas." },
	[S.MH_THE_ONE_FIGHTER_RISES]={ iro = "The One Fighter Rises", cat = "aoe", role = "special",    desc = "Dano físico em área em volta da Eleanor (ignora DEF); enche as esferas ao máximo." },
}

local function targetName(skill)
	local m = sys.targetMode(skill)
	if m == 0 then return "self" elseif m == 2 then return "ground" else return "enemy" end
end

-- Lista de skills disponíveis para (homunType + baseType), com metadados p/ o editor.
function BRAI.skillCatalog(homunType, baseType)
	local seen, out = {}, {}
	local function addFrom(t)
		local lst = BRAI.skills.list[t]
		if not lst then return end
		for id, lvl in pairs(lst) do
			if not seen[id] then
				seen[id] = true
				local mt = meta[id] or { iro = sys.name(id), cat = "special", role = "special", desc = "" }
				local info = sys.info(id)
				out[#out + 1] = {
					id = id,
					name = sys.name(id),
					iro = mt.iro,
					cat = mt.cat,
					role = mt.role,                      -- papel na árvore (UseAoESkill, UseOffensiveBuff, ...)
					desc = mt.desc,
					target = targetName(id),
					maxLevel = lvl,                      -- nível que este homúnculo conhece
					sp = info and info[3] or {},          -- custo de SP por nível
					range = info and info[2] or {},       -- alcance por nível
					fixedCast = info and info[4] or {},   -- cast fixo (ms)
					varCast = info and info[5] or {},     -- cast variável (ms)
					delay = info and info[6] or {},       -- pós-conjuração / after-cast delay (ms)
					duration = info and info[8] or {},    -- duração do efeito/buff (ms)
					reuse = info and info[9] or {},       -- recarga / cooldown (ms)
					area = BRAI.skills.aoe[id] and BRAI.skills.aoe[id][1] or nil,
					effect = BRAI.skillFx and BRAI.skillFx[id] or nil,  -- efeito por nível (Renewal)
				}
			end
		end
	end
	addFrom(homunType)
	if baseType and baseType ~= 0 and baseType ~= homunType then addFrom(baseType) end
	-- ordena por categoria e nome (estável p/ o editor)
	table.sort(out, function(a, b)
		if a.cat ~= b.cat then return a.cat < b.cat end
		return a.iro < b.iro
	end)
	return out
end

-- Combos do Homunculus S (sequências de golpes no alvo).
-- power   = modo Combate (Eleanor): Sonic Claw -> Silvervein Rush -> Midnight Frenzy
-- grapple = modo Agarrão (Eleanor): Tinder Breaker -> C.B.C. -> E.Q.C.
BRAI.combos = {
	power   = { S.MH_SONIC_CLAW, S.MH_SILVERVEIN_RUSH, S.MH_MIDNIGHT_FRENZY },
	grapple = { S.MH_TINDER_BREAKER, S.MH_CBC, S.MH_EQC },
}
BRAI.comboStyle = { power = "power", grapple = "grapple" }  -- estilo exigido por cada combo

-- Dados dos combos p/ o editor (painel "Combos da Eleanor"): por elo, nome iRO,
-- custo de esfera, nivel maximo conhecido pela Eleanor; + defaults do no.
function BRAI.comboInfo()
	local C = BRAI.const
	local list = BRAI.skills.list[C.ELEANOR] or {}
	local out = { power = {}, grapple = {},
		labels = { power = "Combate (Power)", grapple = "Agarrao (Grapple)" } }
	for _, style in ipairs({ "power", "grapple" }) do
		local chain = BRAI.combos[style] or {}
		for i, sk in ipairs(chain) do
			local m = meta[sk]
			out[style][i] = {
				step = i, id = sk, name = sys.name(sk),
				iro = (m and m.iro) or sys.name(sk),
				cost = (BRAI.sphereCost and BRAI.sphereCost[sk]) or 0,
				maxLevel = list[sk] or 5,
				finisher = (i == #chain),
				bossForbidden = (sk == BRAI.skills.id.MH_EQC),
			}
		end
	end
	out.defaults = { style = "power", window = 2000, autoComboSpheres = 5,
		grappleThreatLimit = 1, minGap = 0, allowStyleSwitch = true }
	-- mescla o padrão salvo (comboChoiceFor usa 'comboSpheres') sobre os defaults (a UI usa 'autoComboSpheres')
	local saved = (BRAI.comboChoiceFor and BRAI.comboChoiceFor(C.ELEANOR)) or {}
	if saved.style ~= nil then out.defaults.style = saved.style end
	if saved.window ~= nil then out.defaults.window = saved.window end
	if saved.comboSpheres ~= nil then out.defaults.autoComboSpheres = saved.comboSpheres end
	if saved.grappleThreatLimit ~= nil then out.defaults.grappleThreatLimit = saved.grappleThreatLimit end
	if saved.minGap ~= nil then out.defaults.minGap = saved.minGap end
	if saved.allowStyleSwitch ~= nil then out.defaults.allowStyleSwitch = saved.allowStyleSwitch end
	out.savedLevels = saved.levels   -- níveis por elo salvos (a UI reflete)
	return out
end

BRAI.skillMeta = meta
return meta
