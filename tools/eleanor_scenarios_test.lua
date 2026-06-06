-- eleanor_scenarios_test.lua — Fase 6: regressão dos 5 cenários de demonstração.
-- Carrega a árvore real (trees/Eleanor - Filir) + cada cenário (scenarios/Eleanor - *)
-- e afirma o comportamento. Guards: R1 (alvo morre), R7 (multidão), R8 (boss).
-- Uso: texlua tools/eleanor_scenarios_test.lua
local boot = dofile("lua/sim_boot.lua")
local BRAI = boot("lua")
local json, SID = BRAI.json, BRAI.skills.id
local sys = BRAI.skillsys

local pass, fail = 0, 0
local function check(c, n) if c then pass = pass + 1; print("  ok  - " .. n)
	else fail = fail + 1; print("  FAIL- " .. n) end end
local function disp(m, o) return json.decode(SIM_DISPATCH(m, o and json.encode(o) or "")) end
local function readFile(path) local f = assert(io.open(path, "r")); local s = f:read("*a"); f:close(); return s end

-- carrega a ÁRVORE real (a do vídeo) uma vez
local tree = json.decode(readFile("trees/Eleanor - Filir/tree.json"))
disp("setTree", tree.spec)

-- carrega um cenário pelo arquivo (passa o JSON cru direto p/ o load) e semeia esferas
local function loadScenario(path)
	json.decode(SIM_DISPATCH("load", readFile(path)))
	sys.addSpheres(BRAI.sim.bb, 10)   -- pula a fase de acúmulo (determinismo do teste)
end
-- roda N passos coletando: skills de combo, Style Change, e estado do alvo 201
local function run(n)
	local r = { sk = {}, sc = false, comboAfterDeath = false, dead = false, aliveEnd = false }
	for _ = 1, n do
		local s = disp("step")
		local it = s.intent
		if it then
			if it.skill == SID.MH_STYLE_CHANGE then r.sc = true end
			if it.combo then r.sk[it.skill] = true; if r.dead then r.comboAfterDeath = true end end
		end
		local m
		for _, e in ipairs(s.entities or {}) do if e.id == 201 then m = e end end
		if (not m) or (m.hp <= 0) then r.dead = true else r.aliveEnd = true end
		r.aliveEnd = (m ~= nil and m.hp > 0)
	end
	return r
end

print("== D1: Combate em multidão (auto -> Power) ==")
loadScenario("scenarios/Eleanor - 1 Combate em multidao (Power).json")
check(BRAI.perception.threatCount(BRAI.sim.bb, 3) >= 2, "D1a: multidão detectada (threat > limite)")
local r = run(12)
check(r.sk[SID.MH_SONIC_CLAW], "D1b: usa a cadeia Power (Sonic Claw)")
check(not r.sk[SID.MH_TINDER_BREAKER] and not r.sc, "D1c: NÃO entra no Agarrão (sem Tinder/Style Change)")

print("== D2: Agarrão em alvo isolado (auto -> Grapple, cadeia completa) ==")
loadScenario("scenarios/Eleanor - 2 Agarrao em alvo isolado (Grapple).json")
r = run(12)
check(r.sc, "D2a: Style Change p/ entrar no Agarrão")
check(r.sk[SID.MH_TINDER_BREAKER] and r.sk[SID.MH_CBC], "D2b: Tinder Breaker -> C.B.C.")
check(r.sk[SID.MH_EQC], "D2c: E.Q.C. dispara (alvo isolado, não-boss, vivo)")

print("== D3: Multidão bloqueia o Agarrão (R7) ==")
loadScenario("scenarios/Eleanor - 3 Multidao bloqueia o Agarrao.json")
check(BRAI.perception.threatCount(BRAI.sim.bb, 3) >= 2, "D3a: ameaça acima do limite")
r = run(12)
check(not r.sk[SID.MH_TINDER_BREAKER] and not r.sc, "D3b: Agarrão bloqueado (sem Tinder/Style Change)")
check(r.sk[SID.MH_SONIC_CLAW], "D3c: cai p/ o Combate (Power) com segurança")

print("== D4: Alvo morre no meio do combo (R1) ==")
loadScenario("scenarios/Eleanor - 4 Alvo morre no meio do combo.json")
r = run(16)
check(r.sk[SID.MH_TINDER_BREAKER], "D4a: combo engajou (Tinder)")
check(r.dead, "D4b: o alvo morreu durante o combo")
check(not r.comboAfterDeath, "D4c: nenhum golpe de combo após a morte (sem stutter / R1)")
check(not r.sk[SID.MH_EQC], "D4d: E.Q.C. não saiu (alvo já morto)")

print("== D5: Boss bloqueia EQC (R8) ==")
loadScenario("scenarios/Eleanor - 5 Boss bloqueia EQC.json")
r = run(16)
check(r.sk[SID.MH_TINDER_BREAKER] and r.sk[SID.MH_CBC], "D5a: Tinder e C.B.C. no boss")
check(not r.sk[SID.MH_EQC], "D5b: E.Q.C. NUNCA dispara no boss (R8)")
check(r.aliveEnd, "D5c: o boss segue vivo (sem finalizador)")

print(string.format("RESULTADO: %d ok, %d falhas", pass, fail))
os.exit(fail == 0 and 0 or 1)
