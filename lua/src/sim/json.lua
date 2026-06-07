-- json.lua — JSON encode/decode minimalista e portável (5.0/5.1/5.3).
-- Sem patterns dependentes de versão; varredura manual com string.sub/byte.
-- Suficiente para o transporte de dados entre o runtime Lua e o host JS.
BRAI = BRAI or {}

local json = {}

----------------------------------------------------------------------
-- DECODE
----------------------------------------------------------------------
local function skipws(s, i)
	while i <= #s do
		local c = string.sub(s, i, i)
		if c == " " or c == "\t" or c == "\n" or c == "\r" then i = i + 1 else break end
	end
	return i
end

local decode_value  -- fwd

local function decode_string(s, i)
	-- assume s[i] == '"'
	i = i + 1
	local out = {}
	while i <= #s do
		local c = string.sub(s, i, i)
		if c == '"' then
			return table.concat(out), i + 1
		elseif c == "\\" then
			local n = string.sub(s, i + 1, i + 1)
			if n == "n" then out[#out + 1] = "\n"
			elseif n == "t" then out[#out + 1] = "\t"
			elseif n == "r" then out[#out + 1] = "\r"
			elseif n == "/" then out[#out + 1] = "/"
			elseif n == "\\" then out[#out + 1] = "\\"
			elseif n == '"' then out[#out + 1] = '"'
			elseif n == "u" then
				-- \uXXXX -> ignora acima de 127, usa byte simples p/ ASCII
				local hex = string.sub(s, i + 2, i + 5)
				local code = tonumber(hex, 16) or 63
				if code < 128 then out[#out + 1] = string.char(code) else out[#out + 1] = "?" end
				i = i + 4
			else out[#out + 1] = n end
			i = i + 2
		else
			out[#out + 1] = c
			i = i + 1
		end
	end
	error("json: string nao terminada")
end

local function decode_number(s, i)
	local j = i
	while j <= #s do
		local c = string.sub(s, j, j)
		if string.find("0123456789+-.eE", c, 1, true) then j = j + 1 else break end
	end
	local numstr = string.sub(s, i, j - 1)
	return tonumber(numstr), j
end

local function decode_array(s, i)
	i = i + 1
	local arr = {}
	i = skipws(s, i)
	if string.sub(s, i, i) == "]" then return arr, i + 1 end
	while true do
		local v
		v, i = decode_value(s, i)
		arr[#arr + 1] = v
		i = skipws(s, i)
		local c = string.sub(s, i, i)
		if c == "," then i = skipws(s, i + 1)
		elseif c == "]" then return arr, i + 1
		else error("json: esperado ',' ou ']'") end
	end
end

local function decode_object(s, i)
	i = i + 1
	local obj = {}
	i = skipws(s, i)
	if string.sub(s, i, i) == "}" then return obj, i + 1 end
	while true do
		i = skipws(s, i)
		local key
		key, i = decode_string(s, i)
		i = skipws(s, i)
		if string.sub(s, i, i) ~= ":" then error("json: esperado ':'") end
		i = skipws(s, i + 1)
		local v
		v, i = decode_value(s, i)
		obj[key] = v
		i = skipws(s, i)
		local c = string.sub(s, i, i)
		if c == "," then i = i + 1
		elseif c == "}" then return obj, i + 1
		else error("json: esperado ',' ou '}'") end
	end
end

decode_value = function(s, i)
	i = skipws(s, i)
	local c = string.sub(s, i, i)
	if c == '"' then return decode_string(s, i)
	elseif c == "{" then return decode_object(s, i)
	elseif c == "[" then return decode_array(s, i)
	elseif c == "t" then return true, i + 4
	elseif c == "f" then return false, i + 5
	elseif c == "n" then return nil, i + 4
	else return decode_number(s, i) end
end

function json.decode(s)
	local v = decode_value(s, 1)
	return v
end

----------------------------------------------------------------------
-- ENCODE
----------------------------------------------------------------------
local encode_value  -- fwd

local function encode_string(s)
	local out = { '"' }
	for k = 1, #s do
		local c = string.sub(s, k, k)
		if c == '"' then out[#out + 1] = '\\"'
		elseif c == "\\" then out[#out + 1] = "\\\\"
		elseif c == "\n" then out[#out + 1] = "\\n"
		elseif c == "\t" then out[#out + 1] = "\\t"
		elseif c == "\r" then out[#out + 1] = "\\r"
		else out[#out + 1] = c end
	end
	out[#out + 1] = '"'
	return table.concat(out)
end

local function is_array(t)
	local n = 0
	for _ in pairs(t) do n = n + 1 end
	local m = 0
	for _ in ipairs(t) do m = m + 1 end
	return n == m, m
end

encode_value = function(v)
	local tp = type(v)
	if v == nil then return "null"
	elseif tp == "boolean" then return v and "true" or "false"
	elseif tp == "number" then
		-- evita notacao estranha; inteiros sem .0
		if v == math.floor(v) and v < 1e15 and v > -1e15 then
			return string.format("%d", v)
		end
		return string.format("%.6g", v)
	elseif tp == "string" then return encode_string(v)
	elseif tp == "table" then
		local arr, m = is_array(v)
		local out = {}
		if arr then
			for k = 1, m do out[k] = encode_value(v[k]) end
			return "[" .. table.concat(out, ",") .. "]"
		else
			local parts = {}
			for key, val in pairs(v) do
				parts[#parts + 1] = encode_string(tostring(key)) .. ":" .. encode_value(val)
			end
			return "{" .. table.concat(parts, ",") .. "}"
		end
	end
	return "null"
end

function json.encode(v)
	return encode_value(v)
end

BRAI.json = json
return json
