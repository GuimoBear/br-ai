-- sim_boot.lua — carrega a BT + runtime do simulador. Usado pelo host JS e pelos testes.
-- Uso: local BRAI = dofile(".../sim_boot.lua")(base)
local function boot(base)
	local load = dofile(base .. "/bootstrap.lua")
	local BRAI = load(base)
	dofile(base .. "/src/sim/json.lua")
	dofile(base .. "/src/sim/skill_req_level.lua")
	dofile(base .. "/src/sim/runtime.lua")
	return BRAI
end
return boot
