-- registry.lua — registro central de folhas (condições e ações).
-- É a ÚNICA fonte que jogo, simulador e editor compartilham sobre "o que cada nó faz".
-- O editor lê os metadados (nome, descrição, schema) para montar a paleta e validar.
BRAI = BRAI or {}

local registry = {
	conditions = {},
	actions = {},
	meta = {},  -- nome -> { kind, desc, params = {campo = "tipo"} }
}

function registry.condition(name, fn, meta)
	registry.conditions[name] = fn
	registry.meta[name] = { kind = "condition", desc = (meta and meta.desc) or "", params = (meta and meta.params) or {}, optional = (meta and meta.optional) or {} }
end

function registry.action(name, fn, meta)
	registry.actions[name] = fn
	registry.meta[name] = { kind = "action", desc = (meta and meta.desc) or "", params = (meta and meta.params) or {}, optional = (meta and meta.optional) or {} }
end

-- Exporta os metadados como dado puro (para o editor gerar a paleta).
function registry.export()
	return registry.meta
end

BRAI.registry = registry
return registry
