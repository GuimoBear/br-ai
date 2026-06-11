-- skill_effects.lua — efeitos por nível das skills (dados Renewal, ratemyserver).
-- Modelo REPRESENTATIVO: o simulador não modela todos os atributos de RO, então o
-- dano é calculado a partir do ATK/MATK do homúnculo × o % da skill (não é o número
-- exato do servidor, mas é fiel ao caráter da skill — burst, DoT, cura, status).
--
-- BRAI.skillFx[id] = {
--   kind   = "physical"|"magic"|"heal"|"buff"|"status"|"special"|"summon",
--   dmg    = { % por nível } (× ATK se physical, × MATK se magic; p/ DoT é o % por tick),
--   dmgFlat= { dano fixo por nível } (skills de dano fixo: Tinder/CBC/EQC),
--   hpPct  = { % do HP MÁX do conjurador por nível } (Self Destruct),
--   dot    = { interval = ms entre ticks, dur = { ms por nível } } (dano ao longo do tempo),
--   heal   = { who = "owner"|"self"|"random", pct = { % do HP máx do alvo por nível } },
--   status = { name = "...", chance = { % por nível }, dur = { ms por nível } },
--   desc   = { "texto curto Lv1", ... },   -- exibido no editor por nível
--   note   = "resumo curto",
-- }
BRAI = BRAI or {}
local S = BRAI.skills.id

local function seq(a, b, n)   -- {a, a+b, a+2b, ...} com n termos
	local t = {}
	for i = 0, n - 1 do t[i + 1] = a + b * i end
	return t
end

local fx = {}

-- ===== LIF =====
fx[S.HLIF_HEAL]   = { kind = "heal", heal = { who = "owner", pct = {25,28,31,34,37} },
	note = "Cura o HP do dono (estilo Heal do Acólito).",
	desc = {"cura o dono","cura o dono","cura o dono","cura o dono","cura o dono"} }
fx[S.HLIF_AVOID]  = { kind = "buff", note = "Aumenta a velocidade de movimento (dono + homúnculo).",
	desc = {"MoveSpd +10%, 40s","+20%, 35s","+30%, 30s","+40%, 25s","+50%, 20s"} }
fx[S.HLIF_CHANGE] = { kind = "buff", note = "Troca HP/SP máx; ataques normais somam o MATK do Lif.",
	desc = {"duração 1min","3min","5min"} }

-- ===== AMISTR =====
fx[S.HAMI_CASTLE]    = { kind = "special", note = "Troca de posição com o dono (chance por nível).",
	desc = {"20% de sucesso","40%","60%","80%","100%"} }
fx[S.HAMI_DEFENCE]   = { kind = "buff", note = "Buff defensivo: aumenta a DEF por um tempo.",
	desc = {"DEF +2, 40s","+4, 35s","+6, 30s","+8, 25s","+10, 20s"} }
fx[S.HAMI_BLOODLUST] = { kind = "buff", note = "Buff ofensivo: ATK e leech de HP.",
	desc = {"ATK +130%, 1min","+140%, 3min","+150%, 5min"} }

-- ===== FILIR =====
fx[S.HFLI_MOON]  = { kind = "physical", dmg = {220,330,440,550,660},
	note = "Ataque físico de alvo único (1–3 golpes).",
	desc = {"1 golpe, 220% ATK","2 golpes, 330%","2 golpes, 440%","2 golpes, 550%","3 golpes, 660%"} }
fx[S.HFLI_FLEET] = { kind = "buff", note = "Buff: aumenta a esquiva (FLEE).",
	desc = {"FLEE +20, 60s","+30","+40","+50","+60"} }
fx[S.HFLI_SPEED] = { kind = "buff", note = "Buff ofensivo: ASPD e ATK.",
	desc = {"ASPD+3 ATK+110%","ASPD+6 +115%","ASPD+9 +120%","ASPD+12 +125%","ASPD+15 +130%"} }
fx[S.HFLI_SBR44] = { kind = "physical", dmg = {1000,2000,3000},
	note = "Nuke de alvo único proporcional à intimidade (consome-a). Valor depende da intimidade.",
	desc = {"100×intimidade","200×intimidade","300×intimidade"} }

-- ===== VANILMIRTH =====
fx[S.HVAN_CAPRICE]    = { kind = "magic", dmg = {100,200,300,400,500},
	note = "Lança um Bolt aleatório (nível = nível da skill).",
	desc = {"Bolt Lv1","Bolt Lv2","Bolt Lv3","Bolt Lv4","Bolt Lv5"} }
fx[S.HVAN_CHAOTIC]    = { kind = "heal", heal = { who = "random", pct = {30,30,32,32,34} },
	note = "Heal aleatório em dono, inimigo ou no próprio homúnculo.",
	desc = {"Heal Lv1 (alvo aleatório)","Lv1~2","Lv1~3","Lv1~4","Lv1~5"} }
fx[S.HVAN_SELFDESTRUCT]= { kind = "physical", hpPct = {100,150,200},
	note = "Autodestrói: dano em área = % do HP máx (ignora DEF). Cuidado.",
	desc = {"dano = HP máx ×1","×1,5","×2"} }

-- ===== SERA =====
fx[S.MH_SUMMON_LEGION]    = { kind = "summon", note = "Invoca insetos que atacam o alvo.",
	desc = {"Hornet 20s","Giant Hornet 30s","Giant Hornet 40s","Luciola 50s","Luciola 60s"} }
fx[S.MH_NEEDLE_OF_PARALYZE]= { kind = "physical", dmg = seq(450,450,10),
	status = { name = "Paralisia", chance = {35,40,45,50,55,60,65,70,75,80}, dur = {12000,12000,12000,14000,14000,14000,16000,16000,16000,18000} },
	note = "Dano físico de alvo único (ignora DEF) com chance de Paralisia.",
	desc = {"450% ATK · 35% paralisia","900% · 40%","1350% · 45%","1800% · 50%","2250% · 55%","2700% · 60%","3150% · 65%","3600% · 70%","4050% · 75%","4500% · 80%"} }
fx[S.MH_POISON_MIST]      = { kind = "magic", dmg = {200,400,600,800,1000},
	dot = { interval = 1000, dur = {3000,6000,9000,12000,15000} },
	status = { name = "Envenenado/Cego", chance = {100,100,100,100,100}, dur = {4000,6000,8000,10000,12000} },
	note = "Névoa no chão: dano mágico por segundo na área e cegueira.",
	desc = {"200% MATK/s por 3s","400%/s 6s","600%/s 9s","800%/s 12s","1000%/s 15s"} }
fx[S.MH_PAIN_KILLER]      = { kind = "buff", note = "Buff no dono: reduz o dano recebido.",
	desc = {"330s","360s","390s","420s","450s","480s","510s","540s","570s","600s"} }

-- ===== EIRA =====
fx[S.MH_LIGHT_OF_REGENE]= { kind = "buff", note = "Permite reviver o dono uma vez (sacrifica o homúnculo).",
	desc = {"6min","7min","8min","9min","10min"} }
fx[S.MH_OVERED_BOOST]   = { kind = "buff", note = "Buff: FLEE e ASPD altíssimos (reduz DEF).",
	desc = {"FLEE440/ASPD182","480/184","520/186","560/188","600/190"} }
fx[S.MH_ERASER_CUTTER]  = { kind = "magic", dmg = seq(450,450,10),
	note = "Dano mágico de alvo único (alcance 7, ignora MDEF).",
	desc = {"450% MATK","900%","1350%","1800%","2250%","2700%","3150%","3600%","4050%","4500%"} }
fx[S.MH_XENO_SLASHER]   = { kind = "magic", dmg = seq(350,350,10),
	note = "Dano mágico em área no chão (Vento, alcance 7).",
	desc = {"350% MATK · 3x3","700% · 3x3","1050% · 3x3","1400% · 5x5","1750% · 5x5","2100% · 5x5","2450% · 7x7","2800% · 7x7","3150% · 7x7","3500% · 9x9"} }
fx[S.MH_SILENT_BREEZE]  = { kind = "heal", heal = { who = "owner", pct = {28,31,34,37,40} },
	status = { name = "Silêncio (no alvo)", chance = {100,100,100,100,100}, dur = {9000,12000,15000,18000,21000} },
	note = "Cura o alvo e aplica/remove silêncio.",
	desc = {"cura · silêncio 9s","12s","15s","18s","21s"} }

-- ===== BAYERI =====
fx[S.MH_STAHL_HORN]   = { kind = "physical", dmg = seq(1800,300,10),
	status = { name = "Atordoamento", chance = seq(22,2,10), dur = {3000,3000,3000,3000,3000,3000,3000,3000,3000,3000} },
	note = "Investida física de alvo único com chance de Stun.",
	desc = {"1800% ATK · 22% stun","2100% · 24%","2400% · 26%","2700% · 28%","3000% · 30%","3300% · 32%","3600% · 34%","3900% · 36%","4200% · 38%","4500% · 40%"} }
fx[S.MH_GOLDENE_FERSE]= { kind = "buff", note = "Buff: FLEE e ASPD; ataques podem virar Sagrado.",
	desc = {"FLEE+20/ASPD+10%","+30/+14%","+40/+18%","+50/+22%","+60/+26%"} }
fx[S.MH_STEINWAND]    = { kind = "buff", note = "Barreira: DEF/MDEF sobre dono e homúnculo.",
	desc = {"DEF+100/MDEF+30","+200/+60","+300/+90","+400/+120","+500/+150"} }
fx[S.MH_HEILIGE_STANGE]= { kind = "magic", dmg = seq(1750,250,10),
	note = "Dano mágico Sagrado em área (alcance 9).",
	desc = {"1750% MATK · 3x3","2000% · 3x3","2250% · 3x3","2500% · 3x3","2750% · 5x5","3000% · 5x5","3250% · 5x5","3500% · 5x5","3750% · 7x7","4000% · 7x7"} }
fx[S.MH_ANGRIFFS_MODUS]= { kind = "buff", note = "Buff ofensivo: +ATK, mas reduz DEF/FLEE.",
	desc = {"ATK+70 (DEF/FLEE-)","+90","+110","+130","+150"} }

-- ===== DIETER =====
fx[S.MH_MAGMA_FLOW]    = { kind = "buff", note = "Reativo: chance de dano em área (Fogo) ao ser atingido.",
	desc = {"100% ATK / 3% proc","200%/6%","300%/9%","400%/12%","500%/15%"} }
fx[S.MH_GRANITIC_ARMOR]= { kind = "buff", note = "Buff defensivo: reduz dano recebido (custa HP ao fim).",
	desc = {"-2% dano","-4%","-6%","-8%","-10%"} }
fx[S.MH_LAVA_SLIDE]    = { kind = "physical", dmg = seq(50,50,10),
	dot = { interval = 1000, dur = seq(6000,1000,10) },
	note = "Lava no chão: dano físico de Fogo por segundo na área.",
	desc = {"50% ATK/s por 6s","100%/s 7s","150%/s 8s","200%/s 9s","250%/s 10s","300%/s 11s","350%/s 12s","400%/s 13s","450%/s 14s","500%/s 15s"} }
fx[S.MH_PYROCLASTIC]   = { kind = "buff", note = "Buff ofensivo forte de ATK (encanta a arma, Fogo).",
	desc = {"330s","360s","390s","420s","450s","480s","510s","540s","570s","600s"} }
fx[S.MH_VOLCANIC_ASH]  = { kind = "status", status = { name = "Cinzas (debuff)", chance = {100,100,100,100,100}, dur = {8000,16000,24000,32000,40000} },
	note = "Cinzas em área: -HIT, +falha de cast, +dano de Fogo (sem dano direto).",
	desc = {"cinzas 8s","16s","24s","32s","40s"} }
fx[S.MH_TEMPERING]     = { kind = "buff", note = "Buff: aumenta o P.ATK do dono.",
	desc = {"P.ATK+6, 45s","+7","+8","+9","+10","+11","+12","+13","+14","+15"} }
fx[S.MH_BLAST_FORGE]   = { kind = "physical", dmg = seq(70,70,10),
	dot = { interval = 500, dur = {5000,5000,5000,5000,5000,5000,5000,5000,5000,5000} },
	note = "Fornalha no chão: dano físico de Fogo 2×/s por 5s na área (ignora DEF).",
	desc = {"70% ATK/golpe · 3x3","140% · 3x3","210% · 3x3","280% · 3x3","350% · 5x5","420% · 5x5","490% · 5x5","560% · 5x5","630% · 7x7","700% · 7x7"} }

-- ===== ELEANOR =====
fx[S.MH_STYLE_CHANGE]  = { kind = "special", note = "Alterna entre modo Power (Fighter) e Grapple (Grappler).",
	desc = {"alterna o estilo"} }
fx[S.MH_SONIC_CLAW]    = { kind = "physical", dmg = {60,120,180,240,300},
	note = "Garra rápida de alvo único (golpes = nº de esferas; modo Power).",
	desc = {"60% ATK","120%","180%","240%","300%"} }
fx[S.MH_SILVERVEIN_RUSH]= { kind = "physical", dmg = seq(250,250,10),
	note = "Combo após Sonic Claw (modo Power).",
	desc = {"250% ATK","500%","750%","1000%","1250%","1500%","1750%","2000%","2250%","2500%"} }
fx[S.MH_MIDNIGHT_FRENZY]= { kind = "physical", dmg = seq(450,450,10),
	note = "Combo após Silvervein Rush (consome esfera).",
	desc = {"450% ATK","900%","1350%","1800%","2250%","2700%","3150%","3600%","4050%","4500%"} }
fx[S.MH_TINDER_BREAKER]= { kind = "physical", dmgFlat = {2500,5000,7500,10000,12500},
	status = { name = "Agarrado (FLEE -50%)", chance = {100,100,100,100,100}, dur = {5000,5000,5000,5000,5000} },
	note = "Agarra o alvo (dano fixo) e impede a fuga; inicia o combo grappler.",
	desc = {"2500 de dano","5000","7500","10000","12500"} }
fx[S.MH_CBC]           = { kind = "physical", dmgFlat = {4000,8000,12000,16000,20000},
	note = "Combo do grappler após Tinder Breaker (dano fixo).",
	desc = {"4000 de dano","8000","12000","16000","20000"} }
fx[S.MH_EQC]           = { kind = "physical", dmgFlat = {6000,12000,18000,24000,30000},
	note = "Finaliza o combo grappler (dano fixo; reduz DEF do alvo).",
	desc = {"6000 de dano","12000","18000","24000","30000"} }

fx[S.MH_BLAZING_AND_FURIOUS]= { kind = "physical", dmg = seq(80,80,10),
	note = "Avança e dá dano físico em área (ignora DEF); consome todas as esferas (golpes = nº de esferas).",
	desc = {"80% ATK · 3x3","160% · 3x3","240% · 3x3","320% · 3x3","400% · 5x5","480% · 5x5","560% · 5x5","640% · 5x5","720% · 7x7","800% · 7x7"} }
fx[S.MH_THE_ONE_FIGHTER_RISES]= { kind = "physical", dmg = seq(580,580,10),
	note = "Dano físico em área em volta da Eleanor (ignora DEF); enche as esferas ao máximo.",
	desc = {"580% ATK · 3x3","1160% · 3x3","1740% · 3x3","2320% · 3x3","2900% · 5x5","3480% · 5x5","4060% · 5x5","4640% · 5x5","5220% · 7x7","5800% · 7x7"} }

-- ===== LVL 200+ (Renewal/LATAM; dados conferidos no divine-pride servidor LATAM) =====
fx[S.MH_TWISTER_CUTTER] = { kind = "magic", dmg = seq(480,480,10),
	note = "Dano mágico de Vento de alvo único (alcance 7, ignora MDEF).",
	desc = {"480% MATK","960%","1.440%","1.920%","2.400%","2.880%","3.360%","3.840%","4.320%","4.800%"} }
fx[S.MH_ABSOLUTE_ZEPHYR] = { kind = "magic", dmg = seq(1450,450,10),
	note = "Dano mágico Neutro em área ao redor do alvo (ignora MDEF).",
	desc = {"1.450% MATK · 3x3","1.900% · 3x3","2.350% · 3x3","2.800% · 5x5","3.250% · 5x5","3.700% · 5x5","4.150% · 7x7","4.600% · 7x7","5.050% · 7x7","5.500% · 9x9"} }
fx[S.MH_TOXIN_OF_MANDARA] = { kind = "physical", dmg = seq(850,450,10),
	note = "Dano físico em área ao redor do alvo (ignora DEF); aplica Neurotoxina (RES-, efeito só in-game).",
	desc = {"850% ATK · 3x3","1.300% · 3x3","1.750% · 3x3","2.200% · 5x5","2.650% · 5x5","3.100% · 5x5","3.550% · 7x7","4.000% · 7x7","4.450% · 7x7","4.900% · 9x9"} }
fx[S.MH_NEEDLE_STINGER] = { kind = "physical", dmg = seq(700,500,10),
	note = "Dano físico de Veneno a distância (alcance 7, ignora DEF).",
	desc = {"700% ATK","1.200%","1.700%","2.200%","2.700%","3.200%","3.700%","4.200%","4.700%","5.200%"} }
fx[S.MH_GLANZEN_SPIES] = { kind = "physical", dmg = seq(750,450,10),
	note = "Dano físico Sagrado corpo a corpo de alvo único (ignora DEF).",
	desc = {"750% ATK","1.200%","1.650%","2.100%","2.550%","3.000%","3.450%","3.900%","4.350%","4.800%"} }
fx[S.MH_HEILIGE_PFERD] = { kind = "magic", dmg = seq(1550,350,10),
	note = "Dano mágico Sagrado em área em volta do Bayeri (ignora MDEF).",
	desc = {"1.550% MATK · 3x3","1.900% · 3x3","2.250% · 3x3","2.600% · 3x3","2.950% · 5x5","3.300% · 5x5","3.650% · 5x5","4.000% · 5x5","4.350% · 7x7","4.700% · 7x7"} }
fx[S.MH_GOLDENE_TONE] = { kind = "buff",
	note = "Buff no dono: aumenta RES e RESM (conjurado em si mesmo).",
	desc = {"RES/RESM +3, 30s","+6, 40s","+9, 50s","+12, 60s","+15, 70s","+18, 80s","+21, 90s","+24, 100s","+27, 110s","+30, 120s"} }

BRAI.skillFx = fx
return fx
