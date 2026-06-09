# Referência de Nós

Catálogo de todos os nós disponíveis para montar árvores. As condições e ações vêm do **registry** (`lua/src/registry.lua`) — é a mesma fonte que o editor lê para montar a paleta e validar. Os tipos estruturais (composites, decorators, check) vêm do motor de BT (`lua/src/bt/`).

Descrições e schemas de parâmetro aqui são os definidos no próprio código, então refletem exatamente o que o jogo e o simulador executam.

## Status

Todo nó retorna um destes a cada avaliação:

- **SUCCESS** — cumpriu o objetivo neste tick.
- **FAILURE** — não se aplica ou não conseguiu agir.
- **RUNNING** — ação em andamento; continua no próximo tick.

## Composites

Aceitam vários filhos. São **reativos** (sem memória): a árvore reavalia tudo a cada tick.

| Nó | Campos | Semântica |
|---|---|---|
| **selector** | `children`, `label?` | OR de prioridade. Tica os filhos em ordem; vence o primeiro com SUCCESS ou RUNNING; falha só se todos falharem. A **ordem dos filhos é a prioridade**. |
| **sequence** | `children`, `label?` | AND. Tica em ordem; para no primeiro FAILURE ou RUNNING; sucesso só se todos passarem. |
| **parallel** | `children`, `policy`, `label?` | Tica todos os filhos. `policy = "all"` → sucesso se todos; `policy = "any"` → sucesso se ao menos um. |

## Decorators

Aceitam **um** filho.

| Nó | Campos | Semântica |
|---|---|---|
| **inverter** | `child` | Troca SUCCESS↔FAILURE; RUNNING passa. |
| **succeeder** | `child` | Força SUCCESS (exceto quando RUNNING). Torna um ramo opcional. |
| **cooldown** | `ms`, `child` | Bloqueia (FAILURE) por `ms` milissegundos após o filho ter SUCCESS. Mantém estado. |
| **limiter** | `max`, `child`, `key?` | Permite no máximo `max` sucessos do filho; depois falha. Reseta em `bb:resetCounters()`. |

## Check

`check` é um condicional com **um filho opcional**.

| Nó | Campos | Semântica |
|---|---|---|
| **check** | `name`, `params?`, `child?` | Avalia a condição `name`. Se verdadeira e há `child`, executa-o e devolve o status dele; se verdadeira e não há `child`, devolve SUCCESS. Se falsa, devolve FAILURE sem executar o filho. |

Na prática, `check` é como a árvore padrão amarra "se condição X, então faça Y" num único nó (ex.: `check HasOwnerCommand → action HandleOwnerCommand`).

## MonsterCheck — condicional por monstro alvo

`monsterCheck` executa seu **único filho** dependendo de **qual monstro é o alvo atual**. Diferente das condições gerais, ele olha a *classe* do monstro alvo (o `V_TYPE` do jogo) e a compara com um monstro específico e/ou um grupo cadastrados no catálogo (veja [guia-editor.md](guia-editor.md#monstros-e-grupos)).

| Nó | Campos | Semântica |
|---|---|---|
| **monsterCheck** | `monster` (id, 0 = nenhum), `group` (id, 0 = nenhum), `negate` (bool), `child` | Casa quando o alvo **é** o monstro `monster` **ou** **está** no grupo `group`. Com `negate`, casa quando **não é e não está**. Se casa e há `child`, executa-o e devolve o status dele; se casa sem `child`, devolve SUCCESS; se não casa, FAILURE. **Sem alvo atual, sempre FAILURE** (mesmo negado). |

Exemplos de uso: usar uma skill diferente contra chefes (`group = "Chefes"`), fugir de um monstro específico, ou aplicar um comportamento padrão a tudo **exceto** um grupo (`negate = true`). O catálogo de monstros e grupos é global (`monsters.json`) e, ao "Gerar Lua", vira um `monsters.lua` carregado pelo cliente; sem ele, esses nós nunca casam.

## Folhas: condições

Uma `condition` referencia uma destas pelo `name`. As que têm parâmetros recebem-nos em `params`.

| Condição | Parâmetros | Descrição |
|---|---|---|
| `HasOwnerCommand` | — | Há comando do dono pendente neste tick. |
| `HpBelow` | `pct` (number) | HP% do homúnculo abaixo de `pct`. |
| `HpAbove` | `pct` (number) | HP% do homúnculo ≥ `pct`. |
| `SpAbove` | `pct` (number) | SP% do homúnculo ≥ `pct`. |
| `BeingAttacked` | — | Algum monstro mira no homúnculo. |
| `OwnerUnderAttack` | `count` (number, opcional) | O dono está sendo atacado por **pelo menos** `count` monstros (padrão 1 = qualquer um). |
| `HasValidTarget` | — | Existe alvo válido (em vista, vivo, alcançável). |
| `InAttackRange` | — | Alvo atual dentro do alcance de ataque normal. |
| `TooFarFromOwner` | `dist` (number) | Distância do dono acima do limite. |
| `CanEngage` | — | Condições gerais para buscar alvo (HP/SP, não SuperPassive, não standby). |
| `ShouldFlee` | — | HP abaixo de FleeHP e sob ataque. |
| `OwnerHpBelow` | `pct` (number) | HP% do dono abaixo de `pct` (ex.: curar o dono). |
| `OwnerHpAbove` | `pct` (number) | HP% do dono ≥ `pct`. |
| `Mobbed` | `count` (number) | Pelo menos `count` monstros atacando o homúnculo (marca berserk). |
| `StyleIs` | `style` (string: `power`\|`grapple`) | O estilo atual (Eleanor) é o pedido. |
| `SafeToGrapple` | `radius` (number), `limit` (number) | Seguro p/ Agarrão: nº de monstros no raio ≤ `limit` (Tinder Breaker zera o Flee → multidão é fatal). |
| `TargetIsBoss` | — | O monstro alvo é Boss/MVP — pela flag de percepção (`ro.isBoss`) ou por um grupo de boss do catálogo (`BossGroup`). Útil p/ proibir skills em boss (ex.: E.Q.C.) ou trocar de tática. |

## Folhas: ações

Uma `action` referencia uma destas pelo `name`.

### Combate e movimento

| Ação | Parâmetros | Descrição |
|---|---|---|
| `AcquireTarget` | `by` (string: `nearest`\|`lowestHp`\|`ownerAttacker`) | Seleciona o alvo por prioridade, respeitando o modo de KS. |
| `ReacquireIfBetter` | `by` (string: `nearest`\|`lowestHp`\|`ownerAttacker`) | Mantém o alvo atual; troca por um melhor se aparecer (oportunista). |
| `AcquireOwnerAttacker` | — | Mira no monstro que está atacando o dono (resgate). |
| `ChaseTarget` | `dist` (number), `giveUp` (number) | Persegue até a distância `dist`; com `giveUp`, desiste (marca inalcançável) se não houver progresso. |
| `DanceAttack` | — | Ataca enquanto reposiciona: alterna golpe e passo lateral perto do alvo. |
| `Kite` | `dist` (number), `step` (number), `bounds` (number) | Afasta-se para manter a distância `dist` (kiting), respeitando os `bounds` do dono. |
| `AttackTarget` | — | Ataque normal no alvo atual. |
| `Flee` | — | Afasta-se do agressor mais próximo. |

### Comandos e ocioso

| Ação | Parâmetros | Descrição |
|---|---|---|
| `HandleOwnerCommand` | — | Executa o comando pendente do dono (move/attack/follow). |
| `MoveToOwner` | — | Aproxima-se do dono até FollowStayBack. |
| `Idle` | — | Ocioso (sem ação). |

### Skills automáticas (dirigidas pelo perfil do homúnculo)

Estas ações resolvem qual skill usar a partir do perfil do tipo de homúnculo (e config), sem você indicar IDs.

> No **editor**, o rótulo dessas ações mostra **quais skills** o homúnculo do contexto resolve (uma por linha, com o nível). No **simulador**, as mesmas skills aparecem como **filhos** do nó e a usada no tick acende. Quando o tipo não tem skill do papel (ex.: Dieter sem ataque principal) ou você esvaziou o papel na tela *Skills*, o nó recebe um aviso discreto (⚠) e a ação é ignorada. Ver «Skills de cada ação» no guia do simulador.

| Ação | Descrição |
|---|---|
| `UseMainSkill` | Usa a skill ofensiva single-target no alvo. |
| `UseAoESkill` | Usa a skill de AoE da lista de prioridade. Sem `mainAtk` (ex.: Dieter), a AoE é a ofensiva principal e dispara com ≥1 alvo; com `mainAtk`, exige `AutoMobCount` alvos. `AutoMobMode=0` desliga; `AoEFixedLevel` fixa o nível; `AoEMaximizeTargets` mira no aglomerado. |
| `UseOffensiveBuff` | Recasta auto-buffs ofensivos expirados (Bloodlust, Flitting, Pyroclastic, ...). |
| `UseDefensiveBuff` | Recasta auto-buffs defensivos expirados (Amistr Bulwark, Granitic Armor, ...). |
| `UseHealSelf` | Cura a si quando HP% < HealSelfHP (Chaotic Blessing). |
| `UseHealOwner` | Cura o dono quando HP% < HealOwnerHP (Healing Hands/Silent Breeze/Chaotic). |
| `UseOwnerBuff` | Mantém buff no dono (Painkiller da Sera). |
| `UseSummon` | Invoca minions contra o alvo (Summon Legion). |
| `UseCastling` | Castling para tirar mobs do dono quando ele está cercado (Amistr). |

### Skills explícitas (você escolhe a skill)

Use estas para montar comportamentos customizados apontando uma skill específica. No editor, o campo `skill` é preenchido pelo seletor de skills por categoria.

| Ação | Parâmetros | Descrição |
|---|---|---|
| `UseSkill` | `skill` (number), `level` (number), `on` (string: `enemy`\|`owner`) | Usa uma skill de dano em alvo único ou área. `on` define o centro das skills de área. |
| `UseSkillBuff` | `skill` (number), `level` (number) | Usa um buff em si mesmo (não recasta enquanto o efeito durar). |
| `SetStyle` | `style` (string: `power`\|`grapple`) | Garante o estilo (Eleanor): conjura Style Change se necessário. |
| `UseCombo` | `combo` (string: `power`\|`grapple`), `window` (number) | Executa um combo no alvo (sequência de golpes). |
| `UseEleanorOffense` | `style` (`power`\|`grapple`\|`auto`), `comboSpheres`, `window`, `grappleThreatLimit`, `minGap` (number), `allowStyleSwitch` (bool), `levels` | **Eleanor:** combo + estilo + esferas + segurança do Agarrão num só nó. Edite pelo painel **"Combos da Eleanor"**. |

## Como os nós de skill se adaptam por homúnculo

A mesma árvore atende os 9 tipos de homúnculo. As ações automáticas (`UseMainSkill`, `UseAoESkill`, `UseHealOwner`, etc.) resolvem a skill concreta pelo **perfil** do tipo, obtido de `V_HOMUNTYPE` (e, para Homunculus S, do tipo base configurado). Por exemplo, `UseMainSkill` vira Caprice no Vanilmirth, Moonlight no Filir, Stahl Horn no Bayeri; `UseHealOwner` só faz algo no Lif; `UseCastling` só no Amistr. Os perfis ficam em `lua/src/data/profiles.lua` e a resolução do tipo base em `lua/src/data/profile_resolve.lua`. Veja a seção 15 do [`DESIGN.md`](../DESIGN.md) para a cobertura validada por tipo.

## Homunculus S: combos da Eleanor

A Eleanor é o caso mais complexo: dano de alvo único em **dois estilos mutuamente exclusivos** — Combate (Power: Sonic Claw → Silvervein Rush → Midnight Frenzy) e Agarrão (Grapple: Tinder Breaker → C.B.C. → E.Q.C.) — alternados por Style Change. Tudo é encapsulado no nó **`UseEleanorOffense`** (decisão pura: uma intenção por tick), configurável pelo painel **"Combos da Eleanor"** do editor.

**Esferas Espirituais (estimadas).** Os golpes consomem esferas, mas a API do cliente não expõe a contagem. A IA **estima** (`bb.self.spheres`): +0,5 por ataque físico e +0,5 por dano recebido (teto 10), decrementa pelo custo de cada golpe (Silvervein/Tinder/C.B.C. = 1; Midnight/E.Q.C. = 2; Sonic = 0) e tem um *fail-safe* (−1) quando um cast é rejeitado. A **barragem** (`comboSpheres` / `AutoComboSpheres`) só inicia um combo quando há esferas estimadas para fechar o finalizador — evitando o "stutter" de disparar um finalizador sem recurso.

**Segurança do Agarrão.** O Tinder Breaker zera o Flee da Eleanor; em multidão isso é fatal. O `UseEleanorOffense` (e a condição `SafeToGrapple`) só liberam o Agarrão quando há no máximo `grappleThreatLimit` monstros no raio; caso contrário, recuam para o Combate. O finalizador **E.Q.C. é podado em Boss/MVP** (proibido pelo servidor), via flag de percepção ou um grupo de boss do catálogo (`BossGroup`).

**Robustez.** O combo reinicia ao **trocar/perder o alvo** (não herda golpes no alvo errado) e ao estourar a `window`. A troca de estilo tem trava anti-loop (`StyleSwitchLockMs`). `minGap` espaça os golpes para não floodar pacotes em servidores lotados. Implementação: `lua/src/behaviors/skills.lua` (`UseEleanorOffense`), `lua/src/core/skillsys.lua` (esferas) e `lua/src/data/combos.lua` (custos). Testes: `tools/eleanor_{sphere,combo,grapple,editor}_test.lua`.

## Exemplo de spec

Trecho da árvore padrão mostrando `check`, `selector`, `sequence` e folhas:

```json
{
  "type": "selector",
  "label": "root",
  "children": [
    { "type": "check", "name": "HasOwnerCommand", "label": "comando",
      "child": { "type": "action", "name": "HandleOwnerCommand" } },
    { "type": "check", "name": "ShouldFlee", "label": "sobrevivencia",
      "child": { "type": "action", "name": "Flee" } },
    { "type": "sequence", "label": "Engajar", "children": [
        { "type": "selector", "label": "Definir alvo", "children": [
            { "type": "check", "name": "OwnerUnderAttack",
              "child": { "type": "action", "name": "AcquireOwnerAttacker" } },
            { "type": "check", "name": "HasValidTarget" },
            { "type": "check", "name": "CanEngage",
              "child": { "type": "action", "name": "AcquireTarget" } } ] },
        { "type": "selector", "label": "combate-acao", "children": [
            { "type": "action", "name": "UseSummon" },
            { "type": "action", "name": "UseAoESkill" },
            { "type": "action", "name": "UseMainSkill" },
            { "type": "check", "name": "InAttackRange",
              "child": { "type": "action", "name": "AttackTarget" } },
            { "type": "action", "name": "ChaseTarget" } ] } ] }
  ]
}
```
