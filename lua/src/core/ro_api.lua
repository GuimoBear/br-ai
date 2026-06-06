-- ro_api.lua — INTERFACE única com o cliente do RO.
-- No jogo: aponta para as globais nativas (GetV, Move, Attack, ...).
-- No simulador/testes: aponta para um backend mock (JS via Fengari, ou tabela Lua).
-- REGRA DURA: nenhum outro módulo da BT chama a API nativa direto; tudo passa por aqui.
BRAI = BRAI or {}

local ro = {}
local backend = nil

function ro.bind(b)
	backend = b
end

function ro.bound()
	return backend ~= nil
end

-- Sensores ------------------------------------------------------------------
-- getv repassa múltiplos retornos (V_POSITION devolve x,y).
function ro.getv(...)
	return backend.GetV(...)
end

function ro.getActors()
	return backend.GetActors()
end

function ro.getTick()
	return backend.GetTick()
end

function ro.getMsg(id)
	return backend.GetMsg(id)
end

function ro.getResMsg(id)
	if backend.GetResMsg then return backend.GetResMsg(id) end
	return nil
end

function ro.isMonster(id)
	return backend.IsMonster(id)
end

function ro.isBoss(id)
	if backend.IsBoss then return backend.IsBoss(id) end
	return 0
end

-- Atuadores -----------------------------------------------------------------
function ro.move(id, x, y)
	return backend.Move(id, x, y)
end

function ro.attack(id, target)
	return backend.Attack(id, target)
end

function ro.skillObject(id, level, skill, target)
	return backend.SkillObject(id, level, skill, target)
end

function ro.skillGround(id, level, skill, x, y)
	return backend.SkillGround(id, level, skill, x, y)
end

function ro.trace(msg)
	if backend and backend.TraceAI then backend.TraceAI(msg) end
end

-- Backend nativo (usado dentro do cliente do RO). Encapsula as globais.
-- Só referenciar as globais dentro das funções, para não quebrar no simulador
-- onde elas não existem.
ro.nativeBackend = {
	GetV         = function(...) return GetV(...) end,
	GetActors    = function() return GetActors() end,
	GetTick      = function() return GetTick() end,
	GetMsg       = function(id) return GetMsg(id) end,
	GetResMsg    = function(id) return GetResMsg(id) end,
	IsMonster    = function(id) return IsMonster(id) end,
	Move         = function(id, x, y) return Move(id, x, y) end,
	Attack       = function(id, t) return Attack(id, t) end,
	SkillObject  = function(id, l, s, t) return SkillObject(id, l, s, t) end,
	SkillGround  = function(id, l, s, x, y) return SkillGround(id, l, s, x, y) end,
	TraceAI      = function(m) return TraceAI(m) end,
}

BRAI.ro = ro
return ro
