-- idle.lua — seguir o dono e ociosidade.
BRAI = BRAI or {}

local reg = BRAI.registry
local S = BRAI.status
local util = BRAI.util

-- Segue o dono até ficar a FollowStayBack células. RUNNING enquanto anda.
reg.action("MoveToOwner", function(bb)
	if not bb.owner.exists then return S.FAILURE end
	if bb.owner.dist <= bb.config.FollowStayBack then
		return S.SUCCESS
	end
	local nx, ny = util.stepToward(bb.self.x, bb.self.y, bb.owner.x, bb.owner.y)
	bb:setIntent("move", { x = nx, y = ny, reason = "follow" })
	return S.RUNNING
end, { desc = "Aproxima-se do dono até FollowStayBack." })

-- Nada a fazer.
reg.action("Idle", function(bb)
	bb:setIntent("idle", {})
	return S.SUCCESS
end, { desc = "Ocioso (sem ação)." })

return true
