-- skill_range.lua — alcance efetivo do homunculo (melee ou alcance da skill ofensiva).
-- Usado pela perseguicao para parar na distancia certa (ex.: Caprice 9, Lava Slide 7).
BRAI = BRAI or {}
local sys = BRAI.skillsys

function BRAI.effectiveRange(bb)
	local r = bb.config.AttackRange
	if not bb.config.UseAttackSkill then return r end
	local p = BRAI.profileFor(bb)
	local function consider(skill)
		if skill and sys.knows(bb, skill) then
			local lvl = sys.knownLevel(bb, skill)
			-- so estende alcance se a skill mira o inimigo (nao buff/self)
			if sys.targetMode(skill) ~= 0 then
				local rng = sys.range(skill, lvl)
				if rng > r then r = rng end
			end
		end
	end
	consider(p.mainAtk)
	consider(p.aoeAtk)
	return r
end

return true
