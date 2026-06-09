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
	local function asList(v) if v == nil then return {} elseif type(v) == "table" then return v else return { v } end end
	for _, sk in ipairs(asList(p.mainAtk)) do consider(sk) end   -- papel pode ter LISTA de skills (alcance = o maior)
	for _, sk in ipairs(asList(p.aoeAtk)) do consider(sk) end
	return r
end

return true
