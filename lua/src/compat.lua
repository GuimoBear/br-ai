-- compat.lua — helpers portáveis entre Lua 5.0 / 5.1 / 5.3
-- (o cliente do RO roda 5.0; testamos em 5.3 via texlua)
BRAI = BRAI or {}

local compat = {}

-- comprimento de array que funciona em 5.0 (table.getn), 5.1 (#/getn) e 5.2+ (rawlen)
function compat.len(t)
	if rawlen then return rawlen(t) end
	if table.getn then return table.getn(t) end
	return #t
end

-- append portável
function compat.push(t, v)
	t[compat.len(t) + 1] = v
	return t
end

-- map sobre array (ipairs é portável)
function compat.map(t, fn)
	local out = {}
	for i, v in ipairs(t) do out[i] = fn(v, i) end
	return out
end

-- arredondamento sem operador // (que não existe em 5.0/5.1)
function compat.round(x)
	return math.floor(x + 0.5)
end

BRAI.compat = compat
return compat
