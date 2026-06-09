-- bootstrap.lua — carrega todos os modulos da BT em ordem, sob o namespace global BRAI.
-- Reutilizado pelo cliente (AI.lua) e pelos testes/simulador, variando so `base`.
-- Uso: local BRAI = dofile(".../bootstrap.lua")(base)   onde base = pasta "lua".

local function load(base)
	BRAI = BRAI or {}
	local function f(rel) return dofile(base .. "/" .. rel) end

	f("src/compat.lua")
	f("src/core/const.lua")
	f("src/core/util.lua")
	f("src/core/ro_api.lua")

	f("src/data/skills.lua")
	f("src/data/combos.lua")
	f("src/data/summons.lua")
	f("src/data/profiles.lua")
	f("src/data/profile_resolve.lua")
	f("src/data/monsters.lua")
	f("src/core/skillsys.lua")
	f("src/core/skill_range.lua")
	f("src/data/skill_meta.lua")
	f("src/data/skill_choice.lua")
	f("src/data/summon_choice.lua")
	f("src/data/skill_params.lua")
	f("src/data/action_skills.lua")
	f("src/data/skill_effects.lua")

	f("src/bt/status.lua")
	f("src/bt/node.lua")
	f("src/bt/composites.lua")
	f("src/bt/decorators.lua")

	f("src/core/blackboard.lua")
	f("src/core/perception.lua")
	f("src/registry.lua")

	f("src/behaviors/conditions.lua")
	f("src/behaviors/combat.lua")
	f("src/behaviors/idle.lua")
	f("src/behaviors/survival.lua")
	f("src/behaviors/commands.lua")
	f("src/behaviors/skills.lua")
	f("src/data/leaf_meta.lua")   -- nomes legíveis + grupos das folhas (UI)
	f("src/data/param_meta.lua")  -- rótulos legíveis dos parâmetros (UI)

	f("src/bt/tree.lua")
	f("src/tree_homun.lua")

	return BRAI
end

return load
