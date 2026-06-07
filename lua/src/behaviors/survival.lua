-- survival.lua — fuga simples (Fase 4 expandirá com kite/defensive buff/rescue).
BRAI = BRAI or {}

local reg = BRAI.registry
local S = BRAI.status
local util = BRAI.util

-- Foge na direção oposta ao agressor mais próximo (ou em direção ao dono).
reg.action("Flee", function(bb)
	local threat = nil
	local bestDist = nil
	for _, m in ipairs(bb.monsters) do
		if m.target == bb.self.id then
			if not bestDist or m.dist < bestDist then
				threat, bestDist = m, m.dist
			end
		end
	end
	local nx, ny
	if threat then
		-- passo no sentido contrário à ameaça
		local ax, ay = util.stepToward(bb.self.x, bb.self.y, threat.x, threat.y)
		nx = bb.self.x - (ax - bb.self.x)
		ny = bb.self.y - (ay - bb.self.y)
	elseif bb.owner.exists then
		nx, ny = util.stepToward(bb.self.x, bb.self.y, bb.owner.x, bb.owner.y)
	else
		return S.FAILURE
	end
	bb:setIntent("move", { x = nx, y = ny, reason = "flee" })
	return S.RUNNING
end, { desc = "Afasta-se do agressor mais próximo." })

return true
