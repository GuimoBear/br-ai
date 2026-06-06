-- eleanor_newskills_test.lua — skills novas da Eleanor: Blazing and Furious (8050)
-- e The One Fighter Rises (8051). (Brushup Claw 8049 era passiva — removida, pois
-- nenhuma passiva é mapeada no projeto.) Tipo/target INFERIDOS da descrição (o RMS
-- estava errado): ambas são ATAQUE físico AoE — Blazing tem alvo INIMIGO (aproxima-se
-- de 1 alvo), The One é SELF (dano em volta da Eleanor). Cobre dados/meta/efeitos +
-- mecânica de esferas. Uso: texlua tools/eleanor_newskills_test.lua
local boot = dofile("lua/sim_boot.lua")
local BRAI = boot("lua")
local json, C, SID, sys = BRAI.json, BRAI.const, BRAI.skills.id, BRAI.skillsys

local pass, fail = 0, 0
local function check(c, n) if c then pass = pass + 1; print("  ok  - " .. n)
  else fail = fail + 1; print("  FAIL- " .. n) end end
local function disp(m, o) return json.decode(SIM_DISPATCH(m, o and json.encode(o) or "")) end
local function info(id) return BRAI.skills.info[id] end

print("== N0: Brushup Claw (passiva) foi removida ==")
check(SID.MH_BRUSHUP_CLAW == nil and BRAI.skills.list[C.ELEANOR][8049] == nil, "N0: 8049 não existe mais (sem passivas mapeadas)")

print("== N1: IDs + SkillInfo (números do divine-pride/RMS) ==")
check(SID.MH_BLAZING_AND_FURIOUS == 8050 and SID.MH_THE_ONE_FIGHTER_RISES == 8051, "N1a: ids 8050/8051")
check(info(SID.MH_BLAZING_AND_FURIOUS)[1] == "Blazing and Furious", "N1b: nome Blazing and Furious")
check(info(SID.MH_THE_ONE_FIGHTER_RISES)[1] == "The One Fighter Rises", "N1c: nome The One Fighter Rises")
check(sys.spCost(SID.MH_BLAZING_AND_FURIOUS, 1) == 103 and sys.spCost(SID.MH_BLAZING_AND_FURIOUS, 10) == 148, "N1d: Blazing SP 103..148")
check(sys.spCost(SID.MH_THE_ONE_FIGHTER_RISES, 1) == 100 and sys.spCost(SID.MH_THE_ONE_FIGHTER_RISES, 10) == 154, "N1e: The One SP 100..154")
local el = BRAI.skills.list[C.ELEANOR]
check(el[SID.MH_BLAZING_AND_FURIOUS] == 10 and el[SID.MH_THE_ONE_FIGHTER_RISES] == 10, "N1f: maxLvl 10 (conhecidas pela Eleanor)")

print("== N2: TIPO e TARGET inferidos (RMS estava errado) ==")
check(sys.targetMode(SID.MH_BLAZING_AND_FURIOUS) == 1, "N2a: Blazing = alvo INIMIGO (aproxima-se de 1 alvo)")
check(sys.targetMode(SID.MH_THE_ONE_FIGHTER_RISES) == 0, "N2b: The One = SELF (dano em volta da Eleanor)")
check(sys.aoeSize(SID.MH_BLAZING_AND_FURIOUS, 1) == 3 and sys.aoeSize(SID.MH_BLAZING_AND_FURIOUS, 5) == 5 and sys.aoeSize(SID.MH_BLAZING_AND_FURIOUS, 10) == 7, "N2c: Blazing AoE 3/5/7")
check(sys.aoeSize(SID.MH_THE_ONE_FIGHTER_RISES, 10) == 7 and sys.aoeCenter(SID.MH_THE_ONE_FIGHTER_RISES) == 1, "N2d: The One AoE 7, centrada na Eleanor")

print("== N3: meta (catálogo do editor) ==")
local cat = BRAI.skillCatalog(C.ELEANOR, 0)
local byId = {}; for _, s in ipairs(cat) do byId[s.id] = s end
check(byId[8049] == nil, "N3a: Brushup fora do catálogo")
check(byId[SID.MH_BLAZING_AND_FURIOUS] and byId[SID.MH_BLAZING_AND_FURIOUS].cat == "aoe" and byId[SID.MH_BLAZING_AND_FURIOUS].target == "enemy", "N3b: Blazing = AoE, target enemy")
check(byId[SID.MH_THE_ONE_FIGHTER_RISES] and byId[SID.MH_THE_ONE_FIGHTER_RISES].cat == "aoe" and byId[SID.MH_THE_ONE_FIGHTER_RISES].target == "self", "N3c: The One = AoE, target self")

print("== N4: efeitos (dano % por nível, ignora DEF) ==")
local fx = BRAI.skillFx
check(fx[SID.MH_BLAZING_AND_FURIOUS].kind == "physical" and fx[SID.MH_BLAZING_AND_FURIOUS].dmg[1] == 80 and fx[SID.MH_BLAZING_AND_FURIOUS].dmg[10] == 800, "N4a: Blazing físico 80..800% ATK")
check(fx[SID.MH_THE_ONE_FIGHTER_RISES].kind == "physical" and fx[SID.MH_THE_ONE_FIGHTER_RISES].dmg[1] == 580 and fx[SID.MH_THE_ONE_FIGHTER_RISES].dmg[10] == 5800, "N4b: The One físico 580..5800% ATK")
check(fx[8049] == nil, "N4c: Brushup fora dos efeitos")

print("== N5: mecânica de esferas ==")
disp("load", { grid = { w = 40, h = 40 }, dt = 50, homunId = 100, ownerId = 1, homunType = C.ELEANOR, baseType = 0, config = {},
  entities = { { id = 1, kind = "owner", x = 5, y = 20, hp = 1000, maxhp = 1000 },
    { id = 100, kind = "homun", x = 20, y = 20, hp = 100000, maxhp = 100000, sp = 9000, maxsp = 9000, homunType = C.ELEANOR } } })
local bb = BRAI.sim.bb
sys.addSpheres(bb, 7)
sys.markUsed(bb, SID.MH_BLAZING_AND_FURIOUS, 10)
check(sys.spheres(bb) == 0, "N5a: Blazing and Furious consome TODAS as esferas (7 -> 0)")
sys.addSpheres(bb, 2)
sys.markUsed(bb, SID.MH_THE_ONE_FIGHTER_RISES, 10)
check(sys.spheres(bb) == 10, "N5b: The One Fighter Rises enche ao máximo (2 -> 10)")
sys.addSpheres(bb, -5)                          -- 10 -> 5 (evita o teto no passo do ganho)
sys.markUsed(bb, SID.MH_MIDNIGHT_FRENZY, 10)    -- ganho +0.5, custo -2 => 3.5
check(math.abs(sys.spheres(bb) - 3.5) < 1e-9, "N5c: combo normal segue deduzindo o custo (5 -> 3.5)")
disp("load", { grid = { w = 40, h = 40 }, dt = 50, homunId = 100, ownerId = 1, homunType = C.SERA, baseType = 0, config = {},
  entities = { { id = 1, kind = "owner", x = 5, y = 20, hp = 1000, maxhp = 1000 },
    { id = 100, kind = "homun", x = 20, y = 20, hp = 100000, maxhp = 100000, sp = 9000, maxsp = 9000, homunType = C.SERA } } })
sys.markUsed(BRAI.sim.bb, SID.MH_THE_ONE_FIGHTER_RISES, 10)
check(sys.spheres(BRAI.sim.bb) == 0, "N5d: não-Eleanor não ganha/enche esferas (isolamento)")

print(string.format("RESULTADO: %d ok, %d falhas", pass, fail))
os.exit(fail == 0 and 0 or 1)
