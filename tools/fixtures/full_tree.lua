-- full_tree.lua — FIXTURE de teste: árvore de REFERÊNCIA completa (comando, fuga,
-- cura urgente, castling, combate single/AoE/summon, idle). Os testes de comportamento
-- (base/homun/bt/skillinfo) fixam BRAI.treeSpec nesta árvore para não dependerem da
-- árvore default que é EMPACOTADA/EDITÁVEL pelo usuário (que pode mudar legitimamente).
-- dofile aqui reatribui BRAI.treeSpec e devolve a spec.
BRAI = BRAI or {}

BRAI.treeSpec = {
	type = "selector",
	label = "root",
	children = {
		{
			type = "check",
			name = "HasOwnerCommand",
			label = "comando",
			child = {
				type = "action",
				name = "HandleOwnerCommand"
			}
		},
		{
			type = "check",
			name = "ShouldFlee",
			label = "sobrevivencia",
			child = {
				type = "action",
				name = "Flee"
			}
		},
		{
			type = "selector",
			label = "cura-urgente",
			children = {
				{
					type = "action",
					name = "UseHealSelf"
				},
				{
					type = "action",
					name = "UseHealOwner"
				}
			}
		},
		{
			type = "action",
			name = "UseCastling"
		},
		{
			type = "action",
			name = "UseOwnerBuff"
		},
		{
			type = "sequence",
			label = "Engajar",
			children = {
				{
					type = "selector",
					label = "Definir alvo",
					children = {
						{
							type = "check",
							name = "OwnerUnderAttack",
							params = {},
							label = "Dono sob ataque",
							child = {
								type = "action",
								name = "AcquireOwnerAttacker",
								params = {}
							}
						},
						{
							type = "check",
							name = "HasValidTarget",
							params = {},
							label = "Tem alvo"
						},
						{
							type = "check",
							name = "CanEngage",
							params = {},
							label = "Pode engajar",
							child = {
								type = "action",
								name = "AcquireTarget",
								params = {}
							}
						}
					}
				},
				{
					type = "selector",
					label = "combate-acao",
					children = {
						{
							type = "action",
							name = "UseSummon"
						},
						{
							type = "action",
							name = "UseAoESkill"
						},
						{
							type = "action",
							name = "UseMainSkill"
						},
						{
							type = "check",
							name = "InAttackRange",
							child = {
								type = "action",
								name = "AttackTarget"
							}
						},
						{
							type = "action",
							name = "ChaseTarget"
						}
					}
				}
			}
		},
		{
			type = "selector",
			label = "ocioso",
			children = {
				{
					type = "check",
					name = "TooFarFromOwner",
					params = {
						dist = 3
					},
					child = {
						type = "action",
						name = "MoveToOwner"
					}
				},
				{
					type = "action",
					name = "UseOffensiveBuff"
				},
				{
					type = "action",
					name = "UseDefensiveBuff"
				},
				{
					type = "action",
					name = "Idle"
				}
			}
		}
	}
}

return BRAI.treeSpec
