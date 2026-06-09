-- idle.lua — seguir o dono e ociosidade.
BRAI = BRAI or {}

local reg = BRAI.registry
local S = BRAI.status
local util = BRAI.util

-- Segue o dono até ficar a FollowStayBack células. RUNNING enquanto anda.
reg.action("MoveToOwner", function(bb)
	if not bb.owner.exists then return S.FAILURE end
	if bb.config.MoveStickyFight and bb.targetInfo then return S.FAILURE end   -- sticky-fight: não retorna ao dono com alvo ativo
	local stay = bb.config.FollowStayBack
	if bb.config.MoveSticky then stay = stay + (bb.config.StickyMargin or 0) end -- sticky: deadband maior (menos jitter)
	if bb.owner.dist <= stay then
		return S.SUCCESS
	end
	local nx, ny = util.stepToward(bb.self.x, bb.self.y, bb.owner.x, bb.owner.y)
	bb:setIntent("move", { x = nx, y = ny, reason = "follow" })
	return S.RUNNING
end, { desc = "Aproxima-se do dono até FollowStayBack (+StickyMargin se MoveSticky). MoveStickyFight: não segue com alvo ativo." })

-- Perambular ocioso (anti-AFK): anda em volta do dono dentro de IdleWalkDistance, só com SP suficiente.
reg.action("IdleWalk", function(bb)
	if not bb.config.UseIdleWalk then return S.FAILURE end
	if not bb.owner.exists then return S.FAILURE end
	if bb.self.spPct ~= nil and bb.self.spPct < (bb.config.IdleWalkSP or 0) then return S.FAILURE end
	local r = bb.config.IdleWalkDistance or 2; if r < 1 then r = 1 end
	-- ponto de perambulação determinístico: gira por 4 offsets ao redor do dono, trocando a cada ~0.5s
	local st = bb.persist.idleWalk or { i = 0, nextAt = 0 }
	if bb:now() >= (st.nextAt or 0) then st.i = (st.i % 4) + 1; st.nextAt = bb:now() + 500 end
	bb.persist.idleWalk = st
	local offs = { { r, 0 }, { 0, r }, { -r, 0 }, { 0, -r } }
	local o = offs[st.i]
	local tx, ty = bb.owner.x + o[1], bb.owner.y + o[2]
	if bb.self.x == tx and bb.self.y == ty then return S.SUCCESS end   -- já no ponto: ocioso
	local nx, ny = util.stepToward(bb.self.x, bb.self.y, tx, ty)
	bb:setIntent("move", { x = nx, y = ny, reason = "idlewalk" })
	return S.RUNNING
end, { desc = "Perambula perto do dono quando ocioso (UseIdleWalk), dentro de IdleWalkDistance e só com SP% acima de IdleWalkSP." })

-- Nada a fazer.
reg.action("Idle", function(bb)
	bb:setIntent("idle", {})
	return S.SUCCESS
end, { desc = "Ocioso (sem ação)." })

return true
