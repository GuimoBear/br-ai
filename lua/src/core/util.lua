-- util.lua — utilitários de geometria (grid do RO).
BRAI = BRAI or {}

local util = {}

-- Distância de grid (Chebyshev) — é como o RO mede alcance/movimento.
function util.chebyshev(x1, y1, x2, y2)
	local dx = math.abs(x1 - x2)
	local dy = math.abs(y1 - y2)
	if dx > dy then return dx end
	return dy
end

-- Um passo de (x,y) em direção a (tx,ty) (8 direções).
function util.stepToward(x, y, tx, ty)
	local sx, sy = 0, 0
	if tx > x then sx = 1 elseif tx < x then sx = -1 end
	if ty > y then sy = 1 elseif ty < y then sy = -1 end
	return x + sx, y + sy
end

-- Célula adjacente ao alvo, do lado de quem se aproxima (melee simples).
function util.cellNextTo(fromx, fromy, tx, ty)
	local sx, sy = 0, 0
	if fromx > tx then sx = 1 elseif fromx < tx then sx = -1 end
	if fromy > ty then sy = 1 elseif fromy < ty then sy = -1 end
	return tx + sx, ty + sy
end

-- Célula a 'step' da posição, na direção OPOSTA ao alvo (para kiting).
function util.awayFrom(sx, sy, tx, ty, step)
	step = step or 1
	local dx = (sx > tx) and 1 or (sx < tx) and -1 or 0
	local dy = (sy > ty) and 1 or (sy < ty) and -1 or 0
	if dx == 0 and dy == 0 then dx = 1 end   -- mesma célula: escolhe uma direção
	return sx + dx * step, sy + dy * step
end

-- Célula adjacente ao alvo (≠ atual) para "dançar"; prefere o lado do dono.
local OFFS = { {1,0},{1,1},{0,1},{-1,1},{-1,0},{-1,-1},{0,-1},{1,-1} }
function util.sidestep(sx, sy, tx, ty, ox, oy)
	local best, bestScore
	for _, d in ipairs(OFFS) do
		local cx, cy = tx + d[1], ty + d[2]
		if not (cx == sx and cy == sy) then
			local score
			if ox then score = -util.chebyshev(cx, cy, ox, oy)   -- mais perto do dono = melhor
			else score = -(math.abs(cx - sx) + math.abs(cy - sy)) end
			if not bestScore or score > bestScore then best, bestScore = { cx, cy }, score end
		end
	end
	if best then return best[1], best[2] end
	return sx, sy
end

BRAI.util = util
return util
