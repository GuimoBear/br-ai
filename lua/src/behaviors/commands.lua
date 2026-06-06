-- commands.lua — traduz comando do dono (bb.command) em intenção.
-- bb.command é preenchido em AI.lua a partir de GetMsg. (Fase 4 expande: standby, skill, patrol.)
BRAI = BRAI or {}

local reg = BRAI.registry
local S = BRAI.status
local C = BRAI.const

reg.action("HandleOwnerCommand", function(bb)
	local cmd = bb.command
	if not cmd then return S.FAILURE end

	if cmd.kind == C.MOVE_CMD then
		bb.target = nil
		bb:setIntent("move", { x = cmd.x, y = cmd.y, reason = "command" })
		return S.RUNNING
	elseif cmd.kind == C.ATTACK_OBJECT_CMD then
		bb.target = cmd.target
		bb.flags.berserk = bb.config.UseBerserkAttack and true or bb.flags.berserk
		bb:setIntent("attack", { target = cmd.target, reason = "command" })
		return S.RUNNING
	elseif cmd.kind == C.FOLLOW_CMD then
		bb:setIntent("idle", { reason = "follow-cmd" })
		return S.SUCCESS
	end
	return S.FAILURE
end, { desc = "Executa o comando pendente do dono (move/attack/follow)." })

return true
