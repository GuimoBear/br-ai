-- blackboard.lua — contexto compartilhado por tick + estado persistente.
-- A árvore lê o blackboard e escreve UMA intenção (decisão pura, sem efeitos).
-- A aplicação da intenção (chamar ro.move/attack/skill) acontece em AI.lua / no simulador.
BRAI = BRAI or {}

local Blackboard = {}
Blackboard.__index = Blackboard

function Blackboard.new(config)
	local bb = setmetatable({}, Blackboard)
	bb.config = config or BRAI.defaultConfig()
	bb.counters = {}        -- contadores por-tick (limiter de skill, etc.)
	bb.persist = {}         -- estado que sobrevive entre ticks (ex.: target travado, unreachable)
	bb.persist.unreachable = {}
	bb.persist.skillReadyAt = {}  -- skill id -> tick em que pode reusar (cooldown)
	bb.persist.skillCdTotal = {}  -- skill id -> duração total do cooldown (ms)
	bb.persist.buffUntil = {}     -- skill id -> tick em que o buff expira
	bb.persist.buffTotal = {}     -- skill id -> duração total do buff (ms)
	bb.persist.skillUsedAt = {}     -- skill id -> tick do último uso (intervalo customizado)
	bb.persist.skillUsedTarget = {} -- skill id -> alvo no último uso (reset ao trocar de alvo)
	bb.persist.spheres = (bb.config.SphereStartCount or 0)  -- estimativa de esferas (Eleanor)
	bb.persist.lastHp = nil                                  -- p/ detectar dano recebido (delta de HP)
	bb.intent = nil         -- decisão deste tick
	bb.self = {}
	bb.owner = {}
	bb.actors = {}
	bb.monsters = {}
	bb.target = nil
	bb.flags = { berserk = false, standby = false }
	bb._tick = 0
	return bb
end

-- Relógio (ms). No jogo vem de GetTick; no simulador, do relógio determinístico.
function Blackboard:now()
	return BRAI.ro.getTick()
end

-- Contadores por-tick (zerados no início de cada tick) ----------------------
function Blackboard:counter(key)
	return self.counters[key] or 0
end
function Blackboard:incCounter(key)
	self.counters[key] = (self.counters[key] or 0) + 1
end
function Blackboard:resetCounters()
	self.counters = {}
end

-- Intenção (saída da árvore) ------------------------------------------------
function Blackboard:setIntent(kind, data)
	data = data or {}
	data.kind = kind
	self.intent = data
end
function Blackboard:clearIntent()
	self.intent = nil
end

-- Estado persistente entre ticks --------------------------------------------
function Blackboard:markUnreachable(id)
	self.persist.unreachable[id] = self:now()
end
local UNREACH_TIMEOUT = 5000   -- ms até um alvo "inalcançável" poder ser tentado de novo
function Blackboard:isUnreachable(id)
	local t = self.persist.unreachable[id]
	if not t then return false end
	if (self:now() - t) >= UNREACH_TIMEOUT then self.persist.unreachable[id] = nil; return false end
	return true
end
function Blackboard:clearUnreachable(id)
	self.persist.unreachable[id] = nil
end

BRAI.Blackboard = Blackboard

-- Configuração padrão (subconjunto de H_Config, mapeado p/ a BT) -------------
function BRAI.defaultConfig()
	return {
		AggroDist       = 12,   -- distância p/ engajar monstros
		AggroHP         = 60,   -- só engaja com HP% acima disso
		AggroSP         = 0,    -- só engaja com SP% acima disso
		FollowStayBack  = 3,    -- fica N células atrás do dono
		MoveBounds      = 14,   -- distância máx do dono antes de largar tudo p/ voltar
		FleeHP          = 0,    -- foge abaixo deste HP% (0 = desabilitado)
		AttackRange     = 1,    -- alcance de ataque normal (melee)
		SuperPassive    = false,
		KSMode          = "polite", -- anti-KS: "polite" (respeita) ou "always" (free-for-all)
		-- skills / buffs / heal
		BaseHomunType       = 0,     -- forma base do Homunculus S (OldHomunType); 0 = N/A
		UseAttackSkill      = true,  -- usar skills ofensivas
		AutoMobCount        = 2,     -- nº mínimo de alvos p/ usar AoE
		AttackSkillReserveSP= 0,     -- reserva de SP p/ skills ofensivas
		UseOffensiveBuff    = true,
		UseDefensiveBuff    = true,
		UseAutoHeal         = true,
		HealSelfHP          = 40,    -- cura a si abaixo deste HP%
		HealOwnerHP         = 50,    -- cura o dono abaixo deste HP%
		UseOwnerBuff        = true,  -- painkiller no dono (Sera)
		UseSummon           = true,
		LegionSmoothTicks   = 3,     -- suavização anti-flicker da contagem da legião (Sera)
		UseCastling         = true,
		CastleDefendThreshold = 3,   -- nº de monstros no dono p/ Castling
		-- Esferas / combos (Eleanor)
		SphereTrackFactor   = 2,     -- ganho de esfera = 1/fator por evento (=> 0.5)
		AutoComboSpheres    = 5,     -- barragem: mín. de esferas estimadas p/ iniciar um combo
		SphereStartCount    = 0,     -- esferas estimadas ao invocar
		GrappleThreatLimit  = 1,     -- máx. de monstros no raio p/ liberar o Agarrão (Flee=0)
		BossGroup           = 0,     -- grupo (monsters.json) tratado como Boss/MVP (EQC proibido)
		StyleSwitchLockMs   = 1000,  -- anti-loop: tempo mínimo entre trocas de estilo (Eleanor)
		EleanorDoNotSwitchMode = false, -- trava o estilo da Eleanor (não conjura Style Change)
		-- Kite (fuga ativa mantendo distância) — migrado do H_Config
		KiteMonsters        = false, -- kitar qualquer alvo em combate (ramo global)
		ForceKite           = false, -- kitar mesmo sem ameaça (variante agressiva)
		KiteDist            = 5,     -- distância a manter do alvo ao kitar
		KiteStep            = 2,     -- células por passo ao kitar
		KiteBounds          = 10,    -- distância máx. do dono ao kitar
		-- Dance attack (golpe + passo lateral) — migrado do H_Config
		UseDanceAttack      = false, -- ataca dançando (alterna golpe e reposicionamento)
		DanceMinSP          = 0,     -- só dança com SP acima disto (0 = sempre)
		-- Proteção do dono + estratégia de mira (8b) — migrado do H_Config
		RescueOwnerLowHP        = 0,     -- vai ao lado do dono quando HP% do dono < isto (0 = desligado)
		DefensiveBuffOwnerMobbed = false, -- buffa o dono quando ele está cercado
		OpportunisticTargeting  = false, -- troca p/ um alvo melhor se aparecer (liga o ReacquireIfBetter)
		UseSkillOnly            = false, -- só usa skills; bloqueia o ataque normal (AttackTarget)
		-- Perambular ocioso, movimento sticky, AoE e skill-S em chase/attack (8c) — migrado do H_Config
		UseIdleWalk          = false, -- perambula perto do dono quando ocioso
		IdleWalkSP           = 0,     -- só perambula com SP% acima disto
		IdleWalkDistance     = 2,     -- raio (do dono) p/ perambular
		MoveSticky           = false, -- deadband maior ao seguir o dono (menos jitter)
		StickyMargin         = 2,     -- células extras de tolerância quando sticky
		MoveStickyFight      = false, -- não retorna ao dono enquanto há alvo
		AutoMobMode          = 2,     -- 0 = sem AoE automática; >0 = usa (via AutoMobCount)
		AoEFixedLevel        = 0,     -- nível fixo da AoE (0 = automático/máximo conhecido)
		AoEMaximizeTargets   = false, -- mira a AoE no aglomerado mais denso (ground, centro no inimigo)
		UseHomunSSkillChase  = true,  -- pode usar a skill principal enquanto se aproxima (fora do alcance de ataque)
		UseHomunSSkillAttack = true,  -- pode usar a skill principal dentro do alcance de ataque
	}
end

return Blackboard
