-- disabled_test.lua — nós desativados: são PULADOS (como se ausentes), não tocam filhos,
-- e o snapshot expõe disabled (flag própria) + off (efetivo). A semântica "pular" garante
-- paridade com o "Gerar Lua" (que remove os desativados). Uso: texlua tools/disabled_test.lua
local load = dofile("lua/bootstrap.lua")
local BRAI = load("lua")
local S, bt = BRAI.status, BRAI.bt
BRAI.ro.bind({ GetTick=function() return 0 end, TraceAI=function() end, GetV=function() return -1 end,
  GetActors=function() return {} end, GetMsg=function() return {} end, IsMonster=function() return 0 end,
  Move=function() end, Attack=function() end, SkillObject=function() end, SkillGround=function() end })

local pass, fail = 0, 0
local function check(c, n) if c then pass=pass+1 print("  ok  - "..n) else fail=fail+1 print("  FAIL- "..n) end end
local function eq(a,b,n) check(a==b, n.."  (esperado="..tostring(b)..", obtido="..tostring(a)..")") end

local bb = BRAI.Blackboard.new()
local ran
local function rec(tag, st) return bt.node("leaf", tag, function() ran[tag]=true; return st end) end

-- 1) nó desativado: FAILURE e NÃO executa o tickfn (quando ticado direto)
ran = {}
local a = rec("A", S.SUCCESS); a.disabled = true
eq(a:tick(bb), S.FAILURE, "nó desativado (ticado direto) retorna FAILURE")
eq(ran.A, nil, "nó desativado NÃO executa")

-- 2) composite desativado não executa filhos
ran = {}
local sub = bt.selector({ rec("G", S.SUCCESS) }); sub.disabled = true
eq(sub:tick(bb), S.FAILURE, "composite desativado retorna FAILURE")
eq(ran.G, nil, "filho de composite desativado NÃO executa")

-- 3) selector PULA o ramo desativado e cai no próximo
ran = {}
local off1 = rec("OFF", S.SUCCESS); off1.disabled = true
local selr = bt.selector({ off1, rec("ON", S.SUCCESS) })
eq(selr:tick(bb), S.SUCCESS, "selector pula ramo desativado e ainda dá SUCCESS")
eq(ran.OFF, nil, "ramo desativado NÃO executa")
eq(ran.ON, true, "selector cai no próximo ramo")

-- 4) sequence PULA passo desativado e conclui (parity com a poda — NÃO para no desativado)
ran = {}
local mid = rec("S2", S.SUCCESS); mid.disabled = true
local seq = bt.sequence({ rec("S1", S.SUCCESS), mid, rec("S3", S.SUCCESS) })
eq(seq:tick(bb), S.SUCCESS, "sequence pula passo desativado e conclui (SUCCESS)")
eq(ran.S1, true, "sequence: passo 1 roda")
eq(ran.S2, nil, "sequence: passo desativado NÃO roda")
eq(ran.S3, true, "sequence: passo 3 roda (não parou no desativado)")

-- 5) check com filho desativado vira condição-only (paridade com a poda)
ran = {}
BRAI.registry.conditions.AlwaysT = function() return true end
local cc = rec("CC", S.FAILURE); cc.disabled = true
local chk = bt.check("AlwaysT", {}, cc)
eq(chk:tick(bb), S.SUCCESS, "check c/ filho desativado = condição-only (SUCCESS)")
eq(ran.CC, nil, "filho desativado do check NÃO roda")

-- 6) tree.build carrega a flag do spec; ação desativada não roda
ran = {}
BRAI.registry.actions.RecA = function() ran.RA=true; return S.SUCCESS end
BRAI.registry.actions.RecB = function() ran.RB=true; return S.SUCCESS end
local tr = BRAI.tree.build({ type="selector", children={
  { type="action", name="RecA", disabled=true }, { type="action", name="RecB" } } })
eq(tr:tick(bb), S.SUCCESS, "árvore com ação desativada dá SUCCESS")
eq(ran.RA, nil, "ação desativada (RecA) NÃO roda")
eq(ran.RB, true, "ação seguinte (RecB) roda")

-- 7) snapshot: off propaga p/ descendentes (efetivo), mesmo flagando só o pai
local tr2 = BRAI.tree.build({ type="selector", disabled=true, children={ { type="action", name="RecB" } } })
tr2:tick(bb)
local snap = BRAI.tree.snapshot(tr2)
eq(snap[1].disabled, true, "snapshot: raiz com flag disabled")
eq(snap[1].off, true, "snapshot: raiz off (efetivo)")
eq(snap[2].disabled, false, "snapshot: filho sem flag própria")
eq(snap[2].off, true, "snapshot: filho off por herança")

print(string.format("\nRESULTADO: %d ok, %d falhas", pass, fail))
if fail > 0 then os.exit(1) end
