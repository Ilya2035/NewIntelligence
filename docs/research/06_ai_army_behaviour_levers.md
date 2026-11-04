# 06 — Levers to steer EU5 AI army behaviour (game 1.4.7, Caesar/Jomini)

Research note for the *Concentrated Warfare* mod (`cw_`). Everything below was read from the installed game files on 2026-11-04. Paths are relative to `C:\Program Files (x86)\Steam\steamapps\common\Europa Universalis V\` unless stated otherwise.

Legend used throughout:

- **VERIFIED** — seen verbatim in vanilla files or in one of the two reference workshop mods (Cheat Menu Pro `3600272327`, Simple Cheats `3634102315`).
- **INFERRED** — follows from a define comment, a localisation string or a consistent vanilla pattern, but the engine behaviour itself is not visible in script.
- **UNVERIFIED** — plausible, no file evidence; must be tested in-game (`logs/error.log`, observer game).

---

## 1. Architecture in one page (what is script, what is C++)

| Layer | Where it lives | Moddable? |
|---|---|---|
| Military **objective types** (`hunt_armies`, `carpet_siege`, `support_armies`, `defend_home_territory`, `transport_troops`, …) and the logic that assigns units to them | C++. Only names/descriptions exist in `game/main_menu/localization/english/interfaces_l_english.yml:2984-3160` | **No** (names fixed, no script hooks) |
| Numeric knobs of that logic | `game/loading_screen/common/defines/00_defines.txt`, block `NAI = {` lines 565-1608 | **Yes** (define override) |
| Per-country **objective priorities** (0-10) | `game/in_game/common/subject_military_stances/00_default.txt` (+ readme) | **Yes** (database; new stances allowed) |
| Who gets which stance | Player: generic action `change_military_stance`; AI: `ai_tick = never #handled in code` | Player side yes; AI side **C++** |
| Strategic AI temperament (war declaration, peace, budget valuation) | Modifier types flagged `ai=yes` in `game/main_menu/common/modifier_type_definitions/00_modifier_types.txt`; carried by personalities, ruler traits, societal values, static modifiers, difficulty/aggression game rules | **Yes** (any country modifier) |
| AI personalities | `game/in_game/common/ai_personalities/00_ai_personalities.txt` + on_actions | **Yes** |
| Expansion targets / scores / diplomatic objectives | `ai_scripted_expansion_target/`, `ai_scripted_expansion_score/`, `scripted_diplomatic_objectives/`, `join_war_rules/` | **Yes** (strategic only) |
| AI pressing scripted buttons | `scripted_guis` (`ai_is_valid`, `ai_chance`, `ai_frequency`), `unit_abilities` (`ai_will_do`), generic actions (`ai_tick`) | **Yes** |
| Battle formation of regiment categories | `game/in_game/common/unit_formation_preference/army.txt` | **Yes** |

Evidence that the army AI is a command-issuing C++ layer: `logs/ai.log` (this machine, 2026-11-04) is a stream of `[AI Warning] AI tried to execute invalid command: merge_army / split_unit / attach_unit / toggle_can_attach_to / detach_unit / embark_army / move_unit / set_unit_activity / asssume_siege_control` — these are the exact commands the AI issues; none of them is a script effect. (VERIFIED — the warnings are normal noise, see Pitfalls.)

---

## 2. (a) NAI defines — grouped table with proposed values

All values below are VERIFIED from `game/loading_screen/common/defines/00_defines.txt` (line numbers given). "Meaning" is the vanilla comment where one exists, otherwise INFERRED from the name. Proposed values target: *fewer, bigger stacks; keep allies together; wait for reinforcements; asymmetric war when outnumbered; still fight overseas*. Every proposal is a starting point for an observer test, not a final number.

### 2.1 Stack size, splitting, merging

```text
00_defines.txt:1025-1029
	AI_SUPPLY_LIMIT_TARGET = 0.95 # AI will try to make army stacks of this ratio of average supply limit in their country
	RATIO_OVER_SUPPLY_TARGET_TO_SPLIT = 1.3 # A stack has to be this much over the supply limit target to be split in half
	AI_GLOBAL_SUPPLY_LIMIT_UTILITY = 0.6 # AI score for global supply limit modifier
	AI_MINIMUM_AUXILIARY_RATIO = 0.15 # minimum ratio of auxiliaries that AI will keep in their armies regardless of country bonuses
	AI_UNIT_CATEGORY_WEIGHT_FROM_POWER = 10 # how much power modifiers to unit categories influence AI army composition
```

| Define (line) | Vanilla | Meaning | Proposed | Rationale | Risk |
|---|---|---|---|---|---|
| `AI_SUPPLY_LIMIT_TARGET` (1025) | 0.95 | target stack size = ratio × average supply limit | **1.05** | stacks slightly above supply = one big field army; the real lever is supply limit itself (see §3.4 `global_supply_limit_modifier`) | AI attrition rises in low-supply terrain; keep ≤1.1 |
| `RATIO_OVER_SUPPLY_TARGET_TO_SPLIT` (1026) | 1.3 | split in half only when this far over target | **1.8** | stops the "split at 130 %" churn that produces twin medium stacks | very large stacks starve in deserts/mountains |
| `AI_LAND_ARMY_MERGE_THRESHOLD` (1137) | 0.80 | idle armies below 80 % frontage fill merge with co-located armies | **0.95** | merge almost everything idle | fewer garrisons/rebel suppressors |
| `HUNT_ARMIES_WIN_CHANCE_SPLIT` (997) | 0.99 | split the hunting army if win chance above this | **1.0** | never split a hunting stack | one doomstack cannot catch several small raiders; pair with HQ penalty (raiders cannot siege anyway) |
| `HUNT_ARMIES_MAX_SPLINTERS` (998) | 6 | max splinters | **2** | belt and braces with the above | none if 1.0 above holds |
| `CARPET_SIEGE_MAX_ARMIES` (1021) | 10 | carpet siege will not split below this many armies | **4** | 4 siege detachments max → consistent with 1 main + ≤4 extra HQs | slower occupation, longer wars |
| `AI_CARPET_SIEGE_MAX_ARMIES_FACTOR` (1593) | 0.1 | armies used ≤ factor × locations to siege | **0.05** | same | same |
| `MAX_RECRUIT_DISTANCE` (1037) | 10 | how far from base the AI recruits | **6** | reinforcements appear next to the main army and merge sooner | AI with few towns near the front recruits slower |
| `AI_MINIMUM_AUXILIARY_RATIO` (1028) | 0.15 | min auxiliaries | keep | if the HQ regiment is an *auxiliary* category it will count toward this ratio — AI composition logic may then under-recruit real auxiliaries (INFERRED; check in the unit-type research) | — |

### 2.2 Objective assignment and churn

```text
00_defines.txt:1147-1149
	AI_MILITARY_ARMY_ASSIGNMENT_PROXIMITY_FACTOR = -1 # Negative score for army targets further away
	AI_MILITARY_NAVY_ASSIGNMENT_PROXIMITY_FACTOR = -0.1 # negative score for navy targets further away
	AI_MILITARY_ASSIGNMENT_PRIORITY_FACTOR = 100 # Positive score based on objective priority (1-10)
```

INFERRED formula: `assignment score ≈ priority × 100 − map_distance × 1`. One stance priority point ≈ 100 map-distance units. This is how the stance file (§5) connects to unit assignment.

| Define (line) | Vanilla | Meaning | Proposed | Rationale | Risk |
|---|---|---|---|---|---|
| `AI_REASSIGN_UNIT_THRESHOLD` (1403) | 1.33 | new objective needs 33 % more score to steal a unit | **1.6** | less objective flip-flopping = less marching back and forth | slower reaction to new threats |
| `AI_STICK_TO_SIEGE_TIME_FACTOR` (1134) | 0.003 | +score per day on a siege (score doubles per year) | **0.006** | sieges are finished, not abandoned | HQ-less splinters stuck on sieges they cannot win (see Pitfalls) |
| `MAXIMUM_ALLOWED_SIDE_OBJECTIVES` (1014) | 10 | max enemies focused per war | **6** | fewer fronts at once | big coalitions: some enemies ignored |
| `HUNT_ARMIES_AI_MAX_NUM_OBJECTIVES` (1004) | 5 | simultaneous hunt objectives (soft cap) | **3** | at most 3 hunting groups | — |
| `MAXIMUM_ALLOWED_NUMBER_OF_EACH_OBJECTIVE` (1013) | 20 | performance cap | keep | — | — |
| `AI_FOW_FORGET_CHASE_ARMY_CHANCE` (1119) | 0.33 | chance to forget a chased army in fog | **0.5** | fewer wild-goose chases | enemy raiders escape more |
| `AI_MILITARY_ARMY_ASSIGNMENT_PROXIMITY_FACTOR` (1147) | -1 | distance penalty | **-1.5** | prefer nearby objectives → concentrated theatre | distant subjects/allies get less help |

### 2.3 Hunting armies and the "confront factor"

```text
00_defines.txt:994-1000
	HUNT_ARMIES_MAX_RADIUS = 20
	HUNT_ARMIES_STAY_PRIO = 0.05 # This number works like a threshold for how important tasks should be for the AI to leave base
	HUNT_ARMIES_CONFRONT_FACTOR = 2.0 # This factor determines how likely the AI is to initiate a battle, as opposed to just staying close by 
	HUNT_ARMIES_WIN_CHANCE_SPLIT = 0.99 # Split up the army if it has more than this win chance
	HUNT_ARMIES_MAX_SPLINTERS = 6 # Don't split into more armies than this
	HUNT_ARMIES_PRESENCE_RADIUS = 3 # Consider armies this far away
	HUNT_ARMIES_DESIRED_STRENGTH_MULT = 1.5 # We want this number times the enemy strength
```

| Define (line) | Vanilla | Meaning | Proposed | Rationale | Risk |
|---|---|---|---|---|---|
| `HUNT_ARMIES_DESIRED_STRENGTH_MULT` (1000) | 1.5 | gather 1.5× enemy strength before hunting | **2.0** | "wait for reinforcements, then strike" | AI never reaches 2× vs a peer → passivity; keep the outnumbered logic (§2.7) as fallback |
| `HUNT_ARMIES_CONFRONT_FACTOR` (996) | 2.0 | eagerness to start battle vs shadowing | keep (2.0) | the main army should seek the decisive battle once assembled | — |
| `CARPET_SIEGE_CONFRONT_FACTOR` (1017) | 0.5 | same for siege stacks | **0.3** | siege detachments avoid battle, main army fights | sieges get relieved more easily |
| `AVOID_BATTLES_PATHFIND_CONFRONT_FACTOR` (1033) | 0.5 | same for "avoid battles" pathing | **0.3** | harassing stance = avoid | — |
| `HUNT_ARMIES_STAY_PRIO` (995) | 0.05 | threshold to leave base | keep | — | — |
| `HUNT_ARMIES_MAX_RADIUS` (994), `HUNT_ARMIES_AI_MAX_DISTANCE` (1002), `HUNT_ARMIES_AI_RADIUS_BUFFER` (1003) | 20 / 3 / 2 | hunting geometry | keep | geometry, not concentration | — |
| `HUNT_ARMIES_AI_WAR_GOAL_VALUE` / `_CAPITAL_VALUE` / `_PROVINCE_CAPITAL_VALUE` (1005-1007) | 1.0 each | value of hunt targets near war goal/capitals | capital **1.5** | hunt near capitals = matches the warscore rework (capital worth most) | — |
| `HUNT_ARMIES_AI_REACHABLE_FACTOR` (1009) | 10 | reachable targets weighted ×10 | keep | — | — |

The stance key `confront_factor` (`subject_military_stances/00_default.txt:188`, only in `siege_raider_military_stance`) is the per-stance version of these factors (INFERRED: 0.0 = "Never voluntarily move into a siege target that has enemy units present", per the vanilla comment at line 187).

### 2.4 Carpet siege, support armies, assaults

```text
00_defines.txt:1016-1023
	CARPET_SIEGE_REQUIRED_WIN_CHANCE = 0.8
	CARPET_SIEGE_CONFRONT_FACTOR = 0.5 # This factor determines how likely the AI is to initiate a battle, as opposed to just staying close by 
	CARPET_SIEGE_SEARCH_DEPTHS = { # How far away will units look when carpet sieging
		10 8 6 5 4 3 2 2 2 2 1 1 1 1 1 1 1 1 # First (biggest) units looks 10 steps away, smaller units get less allowance. ...
	}
	CARPET_SIEGE_MAX_ARMIES = 10 #carpet siege won't split down to more armies than this
	AI_NAVAL_INVASION_PORT_PREFERENCE = 5.0 #score bonus for choosing a port as naval invasion landing point (fleet can dock there)
	AI_NAVAL_INVASION_THREAT_WEIGHT = 0.001 #score penalty per unit of enemy combat strength at a candidate naval invasion landing point
```

```text
00_defines.txt:1591-1595
	AI_ENEMY_STRENGTH_NO_SUPPORT_ARMIES_FACTOR = 2		# AI will not add support armies objectives if their army is at least that much stronger than the enemies
	AI_SUPPORT_ARMIES_DESIRED_STRENGTH_FACTOR = 0.33	# AI will try to use that much of their armies to support sieges and other units
	AI_CARPET_SIEGE_MAX_ARMIES_FACTOR = 0.1				# AI will use that many armies at most times number of locations to siege when carpet sieging
	AI_SUPPORT_ARMIES_POWER_NEEDED_FACTOR = 0.5			# AI will want to have at least that much combat power of the strongest enemy unit in units helping each siege 
	AI_SUPPORT_ARMIES_POWER_DESIRED_FACTOR = 1			# AI will want to have ideally that much combat power of the strongest enemy unit in units helping each siege 
```

| Define (line) | Vanilla | Meaning | Proposed | Rationale | Risk |
|---|---|---|---|---|---|
| `CARPET_SIEGE_REQUIRED_WIN_CHANCE` (1016) | 0.8 | only carpet siege when win chance ≥ 80 % | **0.85** | siege only from a position of strength | fewer sieges in even wars → stalemates |
| `CARPET_SIEGE_SEARCH_DEPTHS` (1018-1020) | 10 8 6 … | search radius by unit size rank | keep | performance-tuned | — |
| `AI_SUPPORT_ARMIES_DESIRED_STRENGTH_FACTOR` (1592) | 0.33 | share of forces acting as covering force | **0.5** | the covering force *is* the concentrated main army standing near the sieges | less raw siege throughput |
| `AI_ENEMY_STRENGTH_NO_SUPPORT_ARMIES_FACTOR` (1591) | 2 | no covering force when ≥2× stronger | **3** | keep the main army together even when strong | — |
| `AI_SUPPORT_ARMIES_POWER_DESIRED_FACTOR` (1595) | 1 | covering force wants 1× strongest enemy unit | **1.5** | — | — |
| `AI_ASSAULT_FORT_NO_BREACH_STRENGTH_NEEDED` / `_BREACH_` (1446-1447) | 3 / 1.5 | strength ratio to assault | keep | assaults already need big stacks | — |
| `AI_ASSAULT_FORT_NEARBY_ENEMY_MAX_RADIUS` (1448) | 3 | no assault if enemy within 3 | keep | — | — |
| `AI_CARPET_SIEGE_FAILED_PATHFIND_RETRY_DAYS` (835) | 7 | retry failed siege path | keep | — | — |

### 2.5 Allies: attaching, waiting for reinforcements, reinforcing battles

```text
00_defines.txt:1131-1135
	AI_AWAIT_REINFORCING_ARMY_DISTANCE_MAX = 35 # above this map AI will wait for other collaborating armies before engaging their target
	AI_AWAIT_REINFORCING_ARMY_DISTANCE_MIN = 20 # below this map distance collaborating armies are considered closed enough to start moving again
	AI_REINFORCE_ONGOING_BATTLE_DISTANCE = 2 # How many locations away AI will try and look to move their arimes to reinforce ongoing combat
	AI_STICK_TO_SIEGE_TIME_FACTOR = 0.003 # extra score factor to prevent reassigning away from a sieging per day, 0.003 = 1/365 every year double score
	AI_WAIT_FOR_JOINING_UNIT_STRENGTH_THRESHOLD = 0.33 # AI will wait for joining units if they are at least this strong of the target
```

```text
00_defines.txt:1137-1140
	AI_LAND_ARMY_MERGE_THRESHOLD    = 0.80 # Idle armies below 80% frontage fill are candidates for merging with co-located armies
	AI_ATTACH_FRONTAGE_SCORE_WEIGHT = 0.5  # Score bonus per unit of free frontage when picking ally attach targets
	AI_ATTACH_MIN_FRONTAGE_ROOM     = 1.0  # Don't attach to an ally army that has less than 1 frontage unit free
	AI_FRONTAGE_FILL_TARGET         = 0.90 # Stop assigning allies to an objective once 90% of battle frontage is covered
```

| Define (line) | Vanilla | Meaning | Proposed | Rationale | Risk |
|---|---|---|---|---|---|
| `AI_AWAIT_REINFORCING_ARMY_DISTANCE_MAX` (1131) | 35 | wait for collaborators farther than this | **60** | wait for allies/subjects from further away | AI idles while allies crawl; cap at ~60 |
| `AI_AWAIT_REINFORCING_ARMY_DISTANCE_MIN` (1132) | 20 | resume moving when within this | **30** | consistent with the above | — |
| `AI_WAIT_FOR_JOINING_UNIT_STRENGTH_THRESHOLD` (1135) | 0.33 | wait for joiners ≥33 % of target | **0.20** | wait even for smaller reinforcements | slower reaction |
| `AI_PERFORMANCE_ATTACH_UNIT_MAX_DISTANCE` (838) | 200 | max travel to attach to an ally | **350** | allies actually reach each other on big maps | explicit perf cost in the comment |
| `AI_ATTACH_MIN_FRONTAGE_ROOM` (1139) | 1.0 | no attach when <1 frontage free | **0.5** | attach even as reserve depth | over-stacking attrition |
| `AI_FRONTAGE_FILL_TARGET` (1140) | 0.90 | stop assigning allies at 90 % frontage | **1.10** | allow full frontage + reserves (value may be clamped; UNVERIFIED) | if engine clamps to 1.0 nothing breaks |
| `AI_ATTACH_FRONTAGE_SCORE_WEIGHT` (1138) | 0.5 | preference for allies with free frontage | **1.0** | pick the big ally stack | — |
| `AI_REINFORCE_ONGOING_BATTLE_DISTANCE` (1133) | 2 | look 2 locations for battles to join | **4** | nearby armies pile into the decisive battle | marching into lost battles |
| `AI_REINFORCE_BATTLE_DISTANCE_LIMIT` (1587) | 3 | same, hard limit | **5** | — | — |
| `AI_REINFORCE_BATTLE_STRENGTH_TRESHOLD` (1589) | 0.55 | stop reinforcing when side ≥55 % of total | **0.70** | keep piling until decisive superiority | over-commitment |
| `AI_REINFORCE_BATTLE_STRENGTH_HELPER_TRESHOLD` (1590) | 0.1 | ignore helpers <10 % of battle | keep | — | — |
| `AI_REINFORCE_BATTLE_SIEGE_ACCUMULATION_LIMIT` (1586) | 0 | never leave a siege with progress to reinforce | keep | — | — |
| `AI_CALL_ALLY_STRENGTH_BALANCE_THRESHOLD` (1435) | 0.75 | do not call allies if balance > this | **0.85** | call allies more often → cooperation | more coalition-style wars |

### 2.6 Retreat and battle selection

```text
00_defines.txt:1121-1130
	AI_RECOVER_MORALE_THRESHOLD = 66 # AI will stop and rest armies when their morale is below this percentage
	AI_RETREAT_DICE_MARGIN = 3             # Retreat if enemy effective dice exceeds ours by this much while morale is low
	AI_RETREAT_DICE_MARGIN_SIEGE_RAIDER = 2 # Lower dice margin used when the active stance is siege-focused (retreat more readily)
	AI_RETREAT_DICE_MORALE_THRESHOLD = 0.45 # Morale threshold below which dice disadvantage triggers retreat
	AI_RETREAT_FLANK_MORALE_THRESHOLD = 0.40 # Morale threshold below which total flank exposure triggers retreat
	AI_TERRAIN_RETREAT_THRESHOLD = 0.80       # AI retreats from battle if CalcArmyTerrainEffectiveness returns below this (1.0 = neutral, 0.80 = 20% penalty)
	AI_NAVAL_RETREAT_STRENGTH_RATIO = 2.0     # AI naval fleet retreats if enemy total strength exceeds ours by this factor
	AI_NAVAL_RETREAT_MORALE_THRESHOLD = 1.5   # ...and our fleet morale has dropped below this value (50% of base naval morale 3.0)
	AI_FLANK_ADVANTAGE_FRONTAGE_RATIO = 1.25  # Terrain retreat is suppressed if our possible frontage exceeds enemy's by this ratio
	AI_TERRAIN_EFFECTIVENESS_FLOOR = 0.50     # Minimum terrain effectiveness multiplier applied to WinChance/Score during battle selection
```

Note line 1123: the engine already reads **"the active stance"** (siege-focused) when deciding retreats — proof that subject stances reach the tactical layer (VERIFIED comment, mechanism INFERRED).

| Define (line) | Vanilla | Meaning | Proposed | Rationale | Risk |
|---|---|---|---|---|---|
| `AI_RECOVER_MORALE_THRESHOLD` (1121) | 66 | rest below 66 % morale | **75** | fewer half-broken attacks; "waiting" behaviour | slower tempo |
| `AI_RETREAT_DICE_MARGIN` (1122) | 3 | retreat on dice gap | keep | — | — |
| `AI_TERRAIN_RETREAT_THRESHOLD` (1126) | 0.80 | retreat below 80 % terrain effectiveness | **0.85** | pick battles, refuse bad ground | more "no battle" wars |
| `BATTLE_WIN_CHANCE_ENEMY_BIAS` (1054) | 1.1 | enemy overestimated by 10 % in battle choice | **1.2** | cautious battle choice; waits for superiority | passivity in even wars |
| `BATTLE_WIN_CHANCE_SENSITIVITY` (1053) | 16 | steepness of win-chance curve | keep | — | — |
| `BATTLE_WIN_CHANCE_GENERAL_MIL_FACTOR` (1055) | 0.25 | 100 MIL ≈ 25 % bigger army | keep | general quality matters for the "offensive" stance read | — |
| `AI_FLANKING_COMBAT_STRENGTH_FACTOR` (1058) | 0.3 | flanking value | keep | — | — |

### 2.7 Outnumbered / asymmetric warfare

```text
00_defines.txt:1109-1114
	HEAVILY_OUTNUMBERED_RATIO = 0.40       # StrengthBalance below this activates outnumbered war behavior
	OUTNUMBERED_BATTLE_ADVANTAGE = 0.60    # when outnumbered, only chase stacks whose power is <= this fraction of our strength
	OUTNUMBERED_TERRAIN_BONUS_MIN = 0.05   # terrain impact must be >= this for a battle to count as terrain-advantaged when outnumbered
	OUTNUMBERED_ENTHUSIASM_WEIGHT = 2.0    # multiplier on (1 - enthusiasm) bonus to win_war_versus priority when outnumbered
	OUTNUMBERED_SEPARABLE_WEIGHT = 1.5     # additional priority multiplier for enemies that can be directly separate-peaced when outnumbered
	MAX_LOANS_FOR_MERCS = 3                # hard ceiling on total active loans before AI stops taking debt to hire mercenaries
```

This block *is* the hard-coded "harassing" mode. It is triggered by StrengthBalance, which the player can read in script as `relative_strength` (§3.5).

| Define (line) | Vanilla | Meaning | Proposed | Rationale | Risk |
|---|---|---|---|---|---|
| `HEAVILY_OUTNUMBERED_RATIO` (1109) | 0.40 | asymmetric mode below 40 % balance | **0.50** | enter harassing mode earlier (matches mod stage "harassing ≤0.5×") | weaker AIs stop contesting the field sooner |
| `OUTNUMBERED_BATTLE_ADVANTAGE` (1110) | 0.60 | chase only stacks ≤60 % of own | **0.50** | pick off detachments only | — |
| `OUTNUMBERED_TERRAIN_BONUS_MIN` (1111) | 0.05 | terrain advantage threshold | **0.10** | only clearly favourable ground | — |
| `OUTNUMBERED_ENTHUSIASM_WEIGHT` / `_SEPARABLE_WEIGHT` (1112-1113) | 2.0 / 1.5 | focus separable, war-weary enemies | keep | already good | — |
| `AI_ENEMY_LAND_SUPREMACY_THRESHOLD` (1402) | 3 | defensive war + enemy 3× land → hang back and defend | **2** | defensive crouch earlier | weak AI never sorties |
| `WAR_WIN_CHANCE_SENSITIVITY` (586) | 8 | strategic win-chance curve | keep | — | — |
| `MINIMUM_WIN_CHANCE_TO_CONSIDER_DEFEAT` (1210) | 0.25 | below → seek peace | keep | — | — |

### 2.8 Defend objectives

```text
00_defines.txt:1394-1397
	SAFE_THREAT_LEVEL_DEFEND_OBJECTIVE_KEEP = 0.60 #Threat level below that will cause defend objectives to be abandoned
	SAFE_WIN_CHANCE_DEFEND_OBJECTIVE_KEEP = 0.40 #Win chance above that will cause defend objectives to be abandoned
	SAFE_THREAT_LEVEL_DEFEND_OBJECTIVE = 0.60 #Threat level below that will cause defend objectives to be abandoned
	SAFE_WIN_CHANCE_DEFEND_OBJECTIVE = 0.40 #Win chance above that will cause defend objectives to be abandoned
```

Keep all four. They decide when `defend_home_territory`-type objectives are dropped; raising the win-chance values (e.g. 0.5) makes AIs stay home longer — the "defensive" stage — but also stops them from exploiting openings. `AI_UNIT_WAIT_FOR_WAR_DISTANCE_THRESHOLD = 100` (1405) is the "wait near the border, out of attrition" radius for the pre-war "waiting" state; keep.

### 2.9 Overseas, naval transport, naval invasion

```text
00_defines.txt:1313-1318
	# CCountry::HasAtLeastComparableNavyTo threshold. Replaces a strict-superiority navy check
	# in the AI's cross-water reachability filter. 0.5 means a country with half the enemy's
	# navy (or more) is still allowed to consider cross-water targets; the previous gate
	# required strict superiority and was hiding Bosphorus-style strait crossings entirely.
	NAVY_COMPARABILITY_RATIO = 0.5
```

| Define (line) | Vanilla | Meaning | Proposed | Rationale | Risk |
|---|---|---|---|---|---|
| `NAVY_COMPARABILITY_RATIO` (1318) | 0.5 | need ≥50 % of enemy navy to consider cross-water targets | keep (0.5) | lowering it makes navy-less AIs declare overseas wars they cannot fight | — |
| `AI_TRANSPORT_STRENGTH_THRESHOLD_PER_DISTANCE` (828) | 0.0004 | "2500 distance needs to have a 100% strength transport fleet" | **0.0003** | colonial powers ship troops with smaller transport fleets | lost convoys |
| `AI_HEAVY_SHIP_RATIO_FOR_TRANSPORTS` (989) | 0.25 | escorts in transport fleets | keep | — | — |
| `AI_NAVAL_INVASION_PORT_PREFERENCE` (1022) | 5.0 | prefer ports as landing points | keep | — | — |
| `AI_NAVAL_INVASION_THREAT_WEIGHT` (1023) | 0.001 | penalty per enemy strength at landing point | **0.0008** | slightly bolder landings | landings into waiting armies |
| `AI_NAVAL_TRANSPORT_FAILED_PATHFIND_RETRY_DAYS` (836) | 30 | retry after failed naval path | **20** | less idling of transports | perf |
| `AI_NAVAL_PERFORMANCE_PATHFIND_DISTANCE_THRESHOLD` (827) | 2500 | coarse naval pathing beyond this | keep | comment warns about Atlantic wind | — |
| `AI_CONQUER_DESIRE_NAVAL_DISTANCE_MULTIPLIER` (1430) | -0.5 | war-declaration penalty for sea distance ("smaller number means more likely") | keep or **-0.4** | strategic; only if colonial AIs stop declaring | more pointless overseas wars |
| `DISTANT_WAR_BORDER_DISTANCE` / `_CONQUEST_FACTOR` / `_SUBJUGATION_FACTOR` (1321-1323) | 100 / 0.1 / 0.33 | distant wars strongly discouraged | keep | — | — |
| `AI_PERFORMANCE_BLOCKADE_MAX_SEA_AREA_HOPS` (≈832) | 8 | blockade reach | keep | — | — |

Related, outside NAI (VERIFIED): `NLocation.OVERSEAS_DISTANCE = 150 # Provinces beyond this distance to capital are distant overseas` (line 1957); `NWar.PARTICIPATION_SCORE_OVERSEAS_MULT = 0.25 # How much less participation do you get if fighting overseas from war leader?` (line 2674). See §10.

### 2.10 Recruitment, composition, supply, budget

| Define (line) | Vanilla | Meaning | Proposed | Rationale | Risk |
|---|---|---|---|---|---|
| `AI_MAINTENANCE_BUDGET_RATIO` (1042) | 0.2 | share of income for army+navy upkeep | keep | — | — |
| `AI_ALLOWED_ARMY_CONSTRUCTIONS_TAX_BASE_DIVIDER` (984) | 100 | parallel army constructions | keep | — | — |
| `AI_REQUIRED_MANPOWER_SURPLUS_MARGIN` (992) | 0.333 | manpower reserved for reinforcement | keep | — | — |
| `AI_DESIRED_ARMY_MANPOWER_RECOVERY_MONTHS` (1571) | 48 | rebuild whole army in 48 months | keep | — | — |
| `LEVY_ARMY_PREFERENCE_FACTOR` / `MERCENARY_ARMY_PREFERENCE_FACTOR` (1259-1260) | 0.5 / 1.33 | reliance falls as war balance improves | keep | — | — |
| `AI_UNIT_CATEGORY_WEIGHT_FROM_POWER` (1029) | 10 | category power → composition | keep | combine with `ai_weight` in `unit_categories/*.txt` (e.g. `00_army_light_infantry.txt:36 ai_weight = 0.5`) | — |
| `AI_LOW_FOOD_PERCENTAGE_THRESHOLD` (1588), `AI_AVOID_ATTRITION_MAX_PATH_FIND_DISTANCE` (1051) | 0.25 / 7 | food & attrition avoidance | keep | big stacks need food; do not reduce | — |
| `AI_HOSTILE_BORDER_MIN_SUBUNITS` (1061) | 3 | raise fort maintenance when ≥3 hostile subunits near border | keep | — | — |
| `AI_EARLY_GAME_MONTHS` (779) | 36 | no recruitment in first 36 months | keep | — | — |

### 2.11 Strategic layer (declare / peace) — only what the stance work touches

| Define (line) | Vanilla | Meaning | Note |
|---|---|---|---|
| `DEFAULT_AGGRESSIVENESS` (1289) | -1.05 | "Higher = more aggressive" base | summed with `aggressiveness_modifier` (INFERRED) |
| `POWER_BALANCE_AGGRESSIVENESS_FACTOR` (1290) | 20 | "more aggressive against weak enemies, more cautious against strong" | — |
| `CHANCE_OF_EXPANSION_AGGRESSIVENESS_SCALE` (1384) | 10 | scales `aggressiveness_modifier` for the monthly war-plan roll | shows what `aggressiveness_modifier` actually feeds |
| `WAR_BALANCE_*_IMPORTANCE` (580-585) | regulars 3, levies 1, manpower 0.5, tax 0.05 | how the AI computes StrengthBalance | the same balance drives §2.7; an HQ regiment with 100 men barely moves it |
| `MINIMUM_WAR_SCORE_TO_CONSIDER_DEFEAT` (1211) | -50 | — | — |
| `AI_SCRIPTED_OBJECTIVE_INTERACTION_SCORE_BONUS` (1477) | 25 | bonus for interactions tied to *scripted diplomatic objectives* | the only "scripted objective" hook — diplomatic, not military |

### 2.12 Performance defines that bound the army AI

`AI_PERFORMANCE_PATHFIND_DISTANCE_THRESHOLD = 100` (825), `AI_PERFORMANCE_NODE_LIMIT_*` (≈829-831), `AI_PERFORMANCE_ATTACH_UNIT_MAX_DISTANCE = 200` (838), `AI_CARPET_SIEGE_FAILED_PATHFIND_RETRY_DAYS = 7` (835). Every one carries a "higher/shorter saves performance" comment: raising attach distance or lowering retry days costs CPU late-game. Change at most one of them per test build.

### 2.13 How to override defines (two mechanisms)

1. **Mod define file** — `loading_screen/common/defines/cw_ai_defines.txt` containing only `NAI = { KEY = value ... }`. Vanilla itself splits defines across files per block (`game/loading_screen/common/defines/jomini/*.txt` each hold one `N…` block, e.g. `fog_of_war.txt` = `NFogOfWar`, `00_tooltips.txt` whose header says "This file overrides …/00_tooltips.txt"). Partial per-key override of an existing block from a mod is the standard Jomini behaviour → **INFERRED**; verify with a deliberately absurd value (e.g. `CARPET_SIEGE_MAX_ARMIES = 1`) and `error.log`.
2. **Game-rule define override** — documented in `game/main_menu/common/game_rules/_game_rules.info:4-11`:

```text
_game_rules.info:4-11
	setting_name = {
		apply_modifier = category:modifier_key	# Apply a modifier to characters matching a specific category. Valid are player, ai, and all. E.G., player:very_easy

		defines = { # Override these defines while active. Formatted as the normal define files
			NArmy = {
				MOVEMENT_SPEED = 10
			}
		}
```

No vanilla rule uses `defines = {}` (grep over `00_game_rules.txt` finds none) → **documented but UNVERIFIED in practice**. If it works, `cw_rule_ai_concentration = { off / standard / strong }` can ship three NAI tunings without touching the define file. Fall back to mechanism 1 if the rule override is ignored.

---

## 3. (b) Country modifiers with `ai=yes` — the strategic temperament lever

### 3.1 Definition syntax (VERIFIED)

```text
game/main_menu/common/modifier_type_definitions/00_modifier_types.txt:13433-13440
aggressiveness_modifier={
	percent=yes
	color = bad
	game_data={
		category=country
		ai=yes
	}
}
```

`ai=yes` marks the modifier as consumed by the AI only; such modifiers are listed under the "Behavioral Modifiers" tooltip header (`ai_personalities_l_english.yml:26 AI_PERSONALITY_MODIFIERS: "Behavioral Modifiers"`). They can be put on **any** country modifier (static modifier, trait, societal value, personality, auto modifier) — vanilla does exactly that (§3.3).

### 3.2 Complete list (47 types, all `category=country`, all VERIFIED from `00_modifier_types.txt`)

| Modifier type (line) | Loc description (`modifier_types_l_english.yml`) / inferred meaning | War-relevant? |
|---|---|---|
| `win_war_chance_threshold` (7257) | "Leaders will not attempt to start wars unless they think they have at least this percentage chance of winning." (2920) | declare |
| `win_war_chance_lower_limit` (7265) | floor of the above (INFERRED) | declare |
| `unintegrated_land_expansion_penalty_modifier` (7273) | scales `AI_UNINTEGRATED_LAND_EXPANSION_PENALTY` (INFERRED) | declare |
| `war_declaration_stab_hit_tolerance` (7282) | "How much stability a leader is prepared to lose to start a war." (2926) | declare |
| `war_declaration_war_exhaustion_tolerance` (7289) | "How much extra war exhaustion a leader is prepared to tolerate when starting a war." (2928) | declare |
| `coalition_strength_tolerance` (12194) | "How much extra strength in a potential coalition … prepared to tolerate when taking land" (3284) | peace |
| `peace_offer_fairness` (12399) | "increases the importance of War Participation when giving treaties to allies" (3349) | peace |
| `peace_offer_negotiation_power` (12406) | "increases the War Score percentage received by a nation in a peace deal" (3351) | peace |
| `language_change_threshold_modifier` (12413) | culture/language AI | no |
| `mercenary_units_preference_modifier` (13323) | "preference of using mercenary units in wars opposed to levies and regulars" (3409) | **army composition** |
| `ai_months_between_wars` (13425) | "how much time an AI country take between its wars" (3600) | declare |
| `aggressiveness_modifier` (13433) | "how likely an AI country to attack other countries" (3594) | declare |
| `ai_conquer_desire_religion_mult` (13442) | heretic/heathen conquest weighting (3596) | declare |
| `ai_amount_of_parallel_charters` (13450) | colonisation | no |
| `carefulness_modifier` (13458) | "how careful an AI country is, attacking only way weaker countries" (3602) | declare |
| `subjugation_preference_modifier` (13466) | vassalise vs annex | peace |
| `dynastic_acquisition_preference_modifier` (13473) | PU hunting | declare |
| `ai_force_annexation_modifier` (13480) | used by static modifier `ai_force_annexation` (`country.txt:2930-2936`, with `aggressiveness_modifier = 2.5`) | declare |
| `ai_stability_target_modifier` (13487), `ai_government_power_target_modifier` (13494) | budget targets | no |
| `expected_warscore_modifier` (13501) | "how much we expect to get in a war" (3618) | peace |
| `gold_importance_modifier` (13516), `stability_importance_modifier` (13544), `manpower_importance_modifier` (13551 — "how much the AI country values manpower", 3632), `control_importance_modifier` (13558), `diplomacy_importance_modifier` (13565), `religious_unity_importance_modifier` (13572), `defence_importance_modifier` (13579 — "how much the AI country values defense", 3640), `institution_importance_modifier` (13586), `trade_importance_modifier` (13593), `societal_value_importance_modifier` (13600) | utility weights for budget/advance/privilege choices | manpower/defence: indirectly (forts, reserves) |
| `court_language_is_*_importance_modifier` (13523-13537) | language | no |
| `bias_for_*_policies` (16180-16250: administrative, balanced, colonialist, diplomat, militarist, capitalist, tolerant, spiritualist, scholar, isolationist, patron_of_arts) | parliament/IO policy votes (`script_values/io_policy.txt`) | no |
| `reject_subjugation_reasons` (16257) | — | no |
| `revoke_privileges_importance_modifier` (16323), `revoke_privileges_stability_tolerance` (16330) | estates | no |
| `ai_require_cb_for_war` (18, `boolean=yes`, no `ai=yes` flag but AI-only by name) | "will require a casus belli to start a war" (3608) | declare |
| `ai_opinion_bias` (24, no `ai=yes` flag) | opinion offset for AI decisions | diplomacy |

**Honest finding (VERIFIED by absence):** not one `ai=yes` modifier type names an objective, a stack, a siege or a retreat. The whole set is *strategic* (declare / peace / budget / composition). Nothing here changes how an AI moves armies inside a war, except indirectly: `manpower_importance_modifier` (reserve building), `defence_importance_modifier` (fort/defence valuation — INFERRED), `mercenary_units_preference_modifier` (what gets recruited).

### 3.3 Where vanilla attaches them (all VERIFIED)

- Personalities: `game/in_game/common/ai_personalities/00_ai_personalities.txt` (see §4).
- Ruler traits: `game/in_game/common/traits/00_ruler.txt` — e.g. `cruel` (43-65) has `war_declaration_stab_hit_tolerance = 25`, `coalition_strength_tolerance = 0.10`, `bias_for_militarist_policies = 25`; `conqueror`-style traits at 472-481 carry `win_war_chance_threshold = -0.2`, `aggressiveness_modifier = 0.1`, `carefulness_modifier = -0.05`, `expected_warscore_modifier = 0.1`, `manpower_importance_modifier = 0.1`.
- Societal values: `game/in_game/common/societal_values/00_default.txt:199-202` (`aggressiveness_modifier = 0.15`, `manpower_importance_modifier = 0.2`, …) and 217-220 (mirror).
- Static modifiers: `game/main_menu/common/static_modifiers/difficulty.txt:118-144`:

```text
difficulty.txt:118-125
low_aggression = {
	game_data = {
		category = country
	}
	ai_require_cb_for_war = yes
	carefulness_modifier = 0.25
	ai_months_between_wars = 60
}
```

```text
difficulty.txt:135-144
high_aggression = {
	game_data = {
		category = country
	}
	
	aggressiveness_modifier = 1.0
	ai_opinion_bias = -50
	ai_months_between_wars = 6
	carefulness_modifier = -0.25
}
```

- Auto modifiers: `game/in_game/common/auto_modifiers/country.txt:212 win_war_chance_threshold = 0.6` (a rank/size-based auto modifier).
- Script values can **read** them: `game/in_game/common/script_values/io_policy.txt:188-191`

```text
io_policy.txt:188-191
	multiply = {
		value = modifier:aggressiveness_modifier
		add = 1
	}
```

so `modifier:<ai_modifier_type>` is a valid script-value source in country scope (VERIFIED). This is how the scripted war-stance can take the AI's own temperament into account.

### 3.4 Mechanism to influence an AI stance via country modifiers

A country modifier is the only script-side object that reaches the AI's utility functions. Procedure:

1. Define static modifiers in `main_menu/common/static_modifiers/cw_ai_stances.txt` (format: `static_modifiers/readme.txt:1-8`, `game_data = { category = country }`).
2. Apply/replace them from script with `add_country_modifier = { modifier = X months = N mode = replace }` (VERIFIED form: `events/culture/cultural_event.txt:236 add_country_modifier = { modifier = diwani_script months = 60 mode = replace }`; `mode = add_and_extend` and `days = -1` at `scripted_effects/country_effects.txt:846-850`).
3. Remove with `remove_country_modifier = X` (`scripted_effects/country_effects.txt:894`); test with `has_country_modifier = X` (`events/character/personality_events.txt:524`).
4. Run it from a monthly on_action (`game/in_game/common/on_action/country_monthly.txt:2-4` shows `monthly_country_pulse = { on_actions = { … } }`; `on_actions.info:1-4` documents the per-on_action `trigger = {}` block).
5. Only for AI: `is_ai = yes` (`on_action/ai_personalities_setup.txt:16`), and clean up when `is_ai = no` (player took over).

Non-AI-flagged modifiers can be added to the same static modifier to shape *behaviour* rather than *valuation*: `global_supply_limit_modifier` (`00_modifier_types.txt:5715`, `category=country`) raises `AI_SUPPLY_LIMIT_TARGET × supply` → bigger AI stacks (INFERRED from the define comment at 1025); `land_morale_modifier`/`discipline` are unit-category and belong to the HQ research, not here.

### 3.5 Worked example — `cw_stance_waiting`

`main_menu/common/static_modifiers/cw_ai_stances.txt` (syntax VERIFIED against `difficulty.txt:118-125`; the values are design placeholders):

```text
cw_stance_waiting = {
	game_data = { category = country }
	# ai=yes types: make the AI value reserves/defence and distrust even odds
	carefulness_modifier = 0.25
	win_war_chance_threshold = 0.10
	defence_importance_modifier = 0.25
	manpower_importance_modifier = 0.25
	expected_warscore_modifier = -0.10
	ai_months_between_wars = 12
	# non-ai types (behaviour): bigger stacks while gathering
	global_supply_limit_modifier = 0.10
}
```

`in_game/common/scripted_effects/cw_ai_stance_effects.txt`:

```text
cw_apply_stance_waiting = {
	remove_country_modifier = cw_stance_offensive
	remove_country_modifier = cw_stance_defensive
	remove_country_modifier = cw_stance_harassing
	add_country_modifier = { modifier = cw_stance_waiting months = 2 mode = replace }
	set_variable = { name = cw_stance value = 3 }   # 3 = waiting; read by the top-bar plate
}
```

(`set_variable = { name = … value = … }` VERIFIED at `on_action/_hardcoded.txt:2362-2365`; `has_variable` VERIFIED in Cheat Menu Pro `sakuya_cheat_sgui.txt:6188`.)

`in_game/common/on_action/cw_on_actions.txt`:

```text
monthly_country_pulse = {
	on_actions = { cw_monthly_ai_war_stance }
}
cw_monthly_ai_war_stance = {
	trigger = { is_ai = yes at_war = yes }
	effect = { cw_update_ai_war_stance = yes }
}
```

(Appending `on_actions` to an existing vanilla on_action from a second file is the standard Jomini merge — INFERRED; test by logging with `debug_log` or an event.)

Decision triggers available for `cw_update_ai_war_stance` (all VERIFIED):

- `relative_strength = { target = <country> value < 0.5 }` — "Has … of the total combined strength of them and TARGET" (`events/DHE/flavor_geo.txt:743-746`; loc `triggers_l_english.yml:4429`). This is the script-visible twin of the engine's StrengthBalance used by `HEAVILY_OUTNUMBERED_RATIO`.
- `relative_military_strength = { target = … value … }` (loc 3044) and `military_strength` (loc 2577), `army_size` ("men in the Army", loc 3791), `regular_army_size`, `manpower_percentage`, `war_enthusiasm` (`country_triggers.txt:3553`), `months_since_war`.
- Enemy iteration: `any_country_at_war_with = { … }` (`events/culture/language_events.txt:16`); war iteration: `any_current_war = { is_in_war = scope:target.owner … }` (`_hardcoded.txt:3215-3218`); `is_an_attacker`, `war_length_in_years` (`flavor_ENG.txt:2396-2398`).
- Temperament read: `modifier:aggressiveness_modifier`, `modifier:carefulness_modifier` in a script value (§3.3); personality: `ai_personality = ai_personality:ai_aggressive` (`ai_scripted_expansion_target/attack_neighbors.txt:5-13`); ruler traits: `ruler = { has_trait = conqueror }` (`events/character/personality_events.txt:1680-1681`), `ruler ?= { has_trait = cruel }` (`artist_events.txt:1095`).

What the player will see: on the enemy country's "Behavioral Modifiers" tooltip, `cw_stance_waiting` appears like any other country modifier — which is fine, because the war-stance plate is meant to be visible anyway; name the modifier accordingly in localisation.

**Limits (honest):** the modifier changes *when* the AI declares/peaces and how it values reserves; it does **not** order armies to wait. The actual "wait" comes from the define group §2.5 and, if stances apply to independents (§5.4), from a stance with low `hunt_army_priority`.

---

## 4. AI personalities

`game/in_game/common/ai_personalities/00_ai_personalities.txt` (173 lines, 8 personalities, VERIFIED):

```text
00_ai_personalities.txt:1-18
# AI Personality Definitions
# Each personality shifts the country's behavioral profile via AI-only modifiers.
# These stack additively with trait and societal value modifiers.
# Modifiers are organized into three layers:
#   - Willingness: how eagerly the AI seeks war
#   - Tolerance: how much pain it accepts to pursue goals
#   - Priorities: what resources and outcomes it values

ai_balanced = {
	default = yes
	color = hsv { 0.130 0.120 0.720 }
	modifier = {
		# Minimal anchors only; trait and societal value modifiers do the rest.
		carefulness_modifier = 0.05
		win_war_chance_threshold = 0.05
		ai_months_between_wars = 6
	}
}
```

Summary of the others (each is a `modifier = {}` of `ai=yes` types): `ai_aggressive` (aggressiveness +0.3, carefulness −0.2, months −12, merc preference +15), `ai_expansionist` (+0.2, months −6, subjugation +0.15, colonialist bias), `ai_defensive` (aggressiveness −0.2, carefulness +0.25, `defence_importance_modifier = 0.25`, manpower +0.1, months +12), `ai_cautious` (−0.15, carefulness +0.3, `ai_require_cb_for_war = yes`, months +18), `ai_opportunistic` (+0.1, carefulness −0.1, gold/trade), `ai_isolationist` (−0.25, carefulness +0.2, months +24, requires CB), `ai_friendly` (−0.1, carefulness +0.15, requires CB, diplomacy +0.25). Localised names/descriptions: `ai_personalities_l_english.yml:3-20` (e.g. `ai_friendly: "Conciliatory"`).

**Assignment (VERIFIED):**

```text
game/in_game/common/on_action/ai_personalities_setup.txt:1-7
# AI Personality on_action hooks.
# Historical assignments are in setup/countries/26_ai_personalities.txt.
# Countries not listed there default to ai_cautious (set in C++ constructor).
# This file handles:
#   - Random mode: override all AI countries at game start
#   - Random per age: re-roll at each new age
#   - Random per ruler: re-roll whenever a new ruler takes the throne
```

- `setup/countries/26_ai_personalities.txt` **does not exist** in 1.4.7 (`find game -iname "*ai_personalit*"` returns only the common/loc/gfx files; `grep -ri personality game/in_game/setup` is empty). Consequence (INFERRED from the comment): with the default rule every AI starts as **`ai_cautious`**, except `rise_of_timur.txt:84 set_personality = ai_personality:ai_expansionist`.
- Game rule `ai_personalities` (`00_game_rules.txt:467-485`): `ai_personalities_historical` (default), `ai_personalities_random`, `_random_per_age`, `_random_per_ruler` (flags `ai_personalities_random`, `…_per_age`, `…_per_ruler`), consumed by `ai_personalities_setup.txt:13-30` (`every_country = { limit = { is_ai = yes } … random_list = { 1 = { set_personality = ai_personality:ai_aggressive } … } }`), `_hardcoded.txt:640-660` (`on_new_age`) and `3781-3794` (`on_new_ruler`).
- Effect `set_personality = ai_personality:<key>` (vanilla above; Cheat Menu Pro `main_menu/common/scripted_guis/sakuya_cheat_sgui.txt:6136-6140` uses it in a `scope = country` scripted GUI). Trigger `ai_personality = ai_personality:<key>` / `!=` (`attack_neighbors.txt:5,9,13`). `has_personality` has trigger localisation (`trigger_localization/country_triggers.txt:3316`) but no vanilla usage → argument form UNVERIFIED.
- Expansion scoring consumes personalities: `ai_scripted_expansion_target/attack_neighbors.txt` (readme lines 1-9 document `attacker_potential`, `candidate_list`, `casus_belli`, `score`, `sort_value`); `ai_scripted_expansion_score/readme.txt` adds `target_trigger`, `multiplier`, `never_attack`.

Recommendation: do not fight the personality system; add the mod's temperament as a *separate* country modifier (§3.5) and let it stack ("These stack additively with trait and societal value modifiers"). For a "colonial power keeps fighting overseas" effect, raise `aggressiveness_modifier` via the colonial-HQ modifier rather than switching personalities.

---

## 5. (c) Subject military stances

### 5.1 Fields and semantics

Readme (`game/in_game/common/subject_military_stances/readme.txt:1-28`, VERIFIED) documents 26 priority keys; the file `00_default.txt` uses three more that the readme omits: `support_sieges_priority` (lines 48, 78, 108, 138, 154), `friendly_naval_transport_priority` (28, 58, …) and `confront_factor` (188).

```text
subject_military_stances/readme.txt:4-16 (excerpt)
# chase_unit_own_location_priority = <float> prio for chasing units in own (plus subjects'/overlord's) territory
# chase_unit_friendly_location_priority = <float> prio for chasing units in other friendly territory
# chase_unit_neutral_location_priority = <float> prio for chasing units in neutral territory
# chase_unit_enemy_location_priority = <float> prio for chasing units in enemy territory
# chase_navy_priority = <float> prio for chasing boats
# hunt_army_priority = <float> prio for hunting armies
# hunt_navy_priority = <float> prio for hunting navies
# defend_own_territory_priority = <float> prio for defending own territroy
# defend_ally_territory_priority = <float> prio for defending other allies' territory
# merge_units_priority = <float> prio for keeping units together in stacks
```

| Key | normal | aggressive | supportive | passive | defensive | siege_raider | Meaning (readme / INFERRED) |
|---|---|---|---|---|---|---|---|
| `chase_unit_own/overlord/subject_location_priority` | 10 | 0 | 10 | 10 | 10 | 8/6/5 | chase enemies inside own/overlord/subject land |
| `chase_unit_friendly_location_priority` | 8 | 0 | 7 | 6 | 8 | 3 | … in other friendly land |
| `chase_unit_neutral_location_priority` | 8 | 7 | 6 | 5 | 3 | 0 | … neutral land |
| `chase_unit_enemy_location_priority` | 8 | 8 | 6 | 0 | 0 | 0 | … enemy land |
| `chase_navy_priority` | 5 | 7 | 5 | 3 | 5 | 2 | chase fleets |
| `hunt_army_priority` / `hunt_navy_priority` | 8/8 | 8/8 | 6/6 | 4/4 | 3/3 | 2/2 | `hunt_armies` objective weight |
| `defend_own_territory_priority` | 10 | 0 | 0 | 10 | 10 | 8 | `defend_home_territory` |
| `defend_ally_territory_priority` | 5 | 0 | 0 | 3 | 10 | 2 | defend allies |
| `merge_units_priority` | 10 | 10 | 10 | 10 | 10 | 10 | "keeping units together in stacks" |
| `support_armies_priority` | 5 | 0 | 5 | 0 | 0 | 3 | `support_armies` (covering force; readme text is a copy-paste error "prio for chasing boats") |
| `support_sieges_priority` | — | 0 | 5 | 0 | 0 | 10 | join/assist sieges (undocumented, INFERRED) |
| `maintain_military_levels_priority` | 4 | 4 | 4 | 4 | 4 | 4 | recruitment |
| `carpet_siege_own_locations_attacking/defending_priority` | 2/4 | 2/4 | 0/0 | 0/0 | 0/0 | 3/6 | re-take own land |
| `carpet_siege_enemy_locations_priority` | 2 | 2 | 2 | 0 | 0 | 10 | siege enemy land |
| `blockade_port_priority` / `blockade_strait_priority` | 2/3 | 2/3 | 2/3 | 2/3 | 0/3 | 3/2 | navy; straits "only active when your side has naval supremacy" |
| `suppress_rebel_priority` | 1 | 1 | 1 | 1 | 1 | 1 | — |
| `army_logistics_priority` / `navy_logistics_priority` | 2/2 | 2/2 | 2/2 | 2/2 | 2/2 | 3/2 | food supply objectives |
| `repatriate_ships/troops_priority` | 10/10 | … | … | … | … | 10/10 | bring exiled units home |
| `friendly_naval_transport_priority` | 1 | 1 | 1 | 1 | 1 | 1 | ferry allied armies |
| `hunt_pirates_priority` | 0 | 0 | 0 | 0 | 0 | 0 | — |
| `confront_factor` | — | — | — | — | — | 0.0 | eagerness to enter a location with enemies (see §2.3) |
| `is_default` | yes | — | — | — | — | — | default stance |

Loc: `military_l_english.yml:13-35` (`siege_raider_military_stance_desc: "… focus exclusively on besieging enemy fortifications and supporting our ongoing sieges, avoiding field battles where possible."`). Icons: `main_menu/gui/shared/font_icons.gui:3309-3361` (one `icon = <stance_key>` entry per stance with a `gfx/interface/icons/military_stances/<key>.dds` texture) — a new stance needs its own entry/texture (INFERRED from `GetMilitaryStanceIcon(SubjectMilitaryStance.Self)` in `manage_subjects_lateralview.gui:47`).

### 5.2 How a stance gets assigned (VERIFIED)

```text
game/in_game/common/generic_actions/military_stance.txt:1-10
change_military_stance = {
	type = owncountry

	potential = {
	}

	allow = {
	}

	ai_tick = never #handled in code
```

```text
military_stance.txt:46-58
	effect = {
		scope:actor = {
			if = {
				limit = {
					exists = scope:subject
					exists = scope:military_stance
				}
                scope:subject = {
				    set_country_military_stance = scope:military_stance
                }
			}
		}
	}
```

- Player UI: `in_game/gui/manage_subjects_lateralview.gui:340` (`action_name = "change_military_stance"` with `parameter_name = "subject"`), `context_menu.gui:372`, and "apply to all": `manage_subjects_lateralview.gui:72 on_action = "[ApplyMilitaryStanceToSubjects(SubjectMilitaryStance.Self)]"` over `datamodel = "[GetMilitaryStances]"` (line 29).
- Effect `set_country_military_stance = <stance scope>` (effect loc `effect_localization/country_effects.txt:1401-1408`; text `effects_l_english.yml:992 "Sets [subject_military_stance|e] to [TARGET_SUBJECT_MILITARY_STANCE.GetName]"`). The only vanilla argument is a saved scope from `select_trigger { looking_for_a = military_stance }`. A literal reference such as `subject_military_stance:aggressive_military_stance` is **UNVERIFIED** (no vanilla usage; `SCOPE.sSubjectMilitaryStance` in `messages_l_english.yml:5170` suggests the scope type name `subject_military_stance`). Test both `subject_military_stance:<key>` and `military_stance:<key>` and read `error.log`.
- Reading: link `country_stance` (`military_stance.txt:42 this = scope:subject.country_stance`); GUI `Country.GetMilitaryStance`, `SubjectMilitaryStance.GetName/GetDesc/GetDescAll`, `GetMilitaryStanceIcon(...)`. No `has_*_stance` trigger exists in `trigger_localization/` (grep "stance" empty) — compare via `country_stance = scope:x` style only (UNVERIFIED as a trigger).
- **AI overlords:** `ai_tick = never #handled in code` → the AI picks its subjects' stances in C++; script cannot see the rule. There is no per-subject-type default field (`grep -ri stance game/in_game/common/subject_types/` only finds `border_distance`). Default for everyone: `normal_military_stance` (`is_default = yes`).
- Message type `PERFORM_change_military_stance_ACTION` (`main_menu/gui/messagetypes/00_messagetypes.txt:12224`).

### 5.3 Does the stance only matter for subjects?

Evidence for "every AI country has one": `Country.GetMilitaryStance` is a plain Country data function (`manage_subjects_lateralview.gui:382,402`), `is_default = yes` exists, `AI_RETREAT_DICE_MARGIN_SIEGE_RAIDER` (define 1123) keys on "the active stance", and the generic action effect works on any country scope. Evidence against: the folder is named `subject_military_stances`, readme says "Configuration for AI help from subjects". **UNVERIFIED either way — this is the single most valuable experiment for the mod** (§12, E1). If independents honour their stance, the whole objective-priority table becomes the master lever for *all* AI armies and the scripted war stance can be implemented by switching stances.

### 5.4 Recommendation

1. Ship a new stance `cw_escort_military_stance` in `in_game/common/subject_military_stances/cw_stances.txt` (new file, new key — no override conflict), priorities: `support_armies_priority = 10`, `support_sieges_priority = 10`, `merge_units_priority = 10`, `hunt_army_priority = 4`, `chase_unit_enemy_location_priority = 4`, `defend_own_territory_priority = 6`, `carpet_siege_enemy_locations_priority = 1`, `friendly_naval_transport_priority = 3`, `confront_factor = 0.5`, everything else as `supportive_military_stance`. Add loc keys `cw_escort_military_stance`, `_desc`, `_desc_all` (pattern `military_l_english.yml:21-23`) and an icon entry patterned on `font_icons.gui:3349-3357`.
2. To make it the **default**, ship a full copy of `00_default.txt` with `is_default = yes` moved (two defaults = undefined behaviour; UNVERIFIED which wins) — or leave `normal` default and set the stance by script on `on_game_start`/monthly for subjects of AI overlords: `every_country = { limit = { is_ai = yes } every_subject_or_below = { set_country_military_stance = … } }` (`every_subject_or_below` VERIFIED at `attack_neighbors.txt:22`). Risk: the C++ overlord logic may overwrite it on its own tick (UNVERIFIED) — check after a few months in an observer game.
3. If E1 succeeds, map the war stages to stances: offensive → `aggressive_military_stance`, defensive → `defensive_military_stance`, waiting → `cw_escort…` (or a dedicated `cw_waiting…` with `hunt_army_priority = 2`), harassing → `siege_raider_military_stance` (already "avoid battles, raid sieges", `confront_factor = 0.0`).

---

## 6. Military objective types, objective groups and player-facing automation

All objective type keys live only in localisation (`interfaces_l_english.yml:2984-3160`, VERIFIED): `win_war`, `win_war_versus`, `suppress_rebels`, `tactical_suppress_rebels`, `prepare_for_war`, `peace_time`, `carpet_siege`, `focus_siege`, `disband_troops`, `maintain_troop_levels`, `maintain_ship_levels`, `maintain_military_levels`, `transport_troops`, `repatriate_troops`, `repatriate_ships`, `perform_navy_logistics`, `perform_army_logistics`, `hunt_armies`, `hunt_navies`, `join_to_unit`, `join_in_location`, `defend_home_territory`, `independent_operations`, `defend_coast`, `hunt_reachable_armies`, `chase_target`, `support_armies`, `patrol_the_seas`, `blockade_strait`, `blockade_ports`, `raise_land_levies`, `raise_navy_levies`, `friendly_naval_transport`. There is **no** `naval_invasion` objective; invasions are the `transport_troops` leg of other objectives (`AI_NAVAL_INVASION_*` defines).

```text
interfaces_l_english.yml:3046-3051
 MILITARY_OBJECTIVE_TYPE_NAME_hunt_armies: "Hunt Armies"
 ...
 MILITARY_OBJECTIVE_TYPE_DESC_hunt_armies: "Troops will gather into a large force and hunt smaller enemy [armies|e]."
```

```text
interfaces_l_english.yml:3070-3075
 MILITARY_OBJECTIVE_TYPE_NAME_independent_operations: "Independent Operations"
 MILITARY_OBJECTIVE_TYPE_DESC_independent_operations: "Hand control of these [armies|e] to the AI. They will pursue the war autonomously, sieging enemy territory, hunting enemy forces, or defending your lands as the situation demands. ..."
 INDEPENDENT_OPERATIONS_ACTION_CARPET_SIEGE: "Sieging enemy territory"
 INDEPENDENT_OPERATIONS_ACTION_HUNT_ARMIES: "Engaging enemy forces"
 INDEPENDENT_OPERATIONS_ACTION_DEFEND_HOME: "Defending home territory"
 INDEPENDENT_OPERATIONS_ACTION_MAINTAIN: "Maintaining readiness"
```

The four `INDEPENDENT_OPERATIONS_ACTION_*` strings are the AI's own autonomous sub-modes — a useful mental model: *carpet siege / hunt armies / defend home / maintain*.

Player-facing automation ("military objective groups"): `in_game/gui/military_objective_groups.gui` (datamodel `MilitaryObjectiveGroupsView.GetObjectiveTypes`, `TacticalMilitaryObjectiveTypeGlue.AddNew/CanAdd/GetTypeName`, lines 293-322, 506-514) and `military_objective_group.gui` (`MilitaryObjectiveGroupView.GetObjective.UsesArmies/UsesNavies/UsesSpecialOptions`, `GetSpecialOptions`, `GetGeography`, lines 956-991). Special options are `SPECIAL_OPTION_declare_war / declared_upon / joining_defensive_war` (loc 3157-3159). **Nothing in `in_game/common/` defines these groups or types** (no `military_objective*` or `tactical*` folder; `ls game/in_game/common | grep -i objective` → only `scripted_diplomatic_objectives`). So the automation cannot be scripted or extended; the mod can at most *document* which objective to pick (e.g. "Focus Siege keeps the HQ army concentrated": `MILITARY_OBJECTIVE_TYPE_DESC_focus_siege: "[armies|e] will stay concentrated and focus on sieging forts first in the highlighted locations."`, line 3015).

`ai_targets_viewer.gui` (`AiTargetsViewer.GetTargetTypes/GetTargets`, `AiTarget.GetTargetType`) and `ai_diplomatic_objectives_viewer.gui` are debug viewers of C++ data; `ai_settings_menu.gui` is the multiplayer "what the AI does when you're not connected" switch list (`pause_menu_l_english.yml:12`), items hard-coded (`AISettingsMenuItem.*`).

Other script-visible AI hooks (VERIFIED):
- `unit_abilities/*.txt` `ai_will_do = { value/add … }` (`gather_food.txt:43-51`: `add = -1`, `if = { limit = { food_percentage < 0.25 } add = 2 }`), `ai_will_revoke` — per unit, unit scope; `readme.txt:20 "# ai_will_do: script for how likely the AI are to do this"`.
- `scripted_guis.info:10-12`: `ai_is_valid = { trigger }`, `ai_chance = { }` (1-100), `ai_frequency = {}` (months) — the AI can "press" scripted buttons; this is how an AI can run the mod's "place HQ in the largest army" action without an on_action, and how it can be given the same decisions as the player.
- Generic actions: `ai_tick = never` (`military_stance.txt:10`) — evaluation frequency key (semantics INFERRED); `generic_action_ai_lists/readme.txt:1-14` groups actions for AI evaluation (`potential = trigger … actions = list`), e.g. `military_list.txt` (`train_general`, potential `num_regiments > 0`), `siege_list.txt` (`garrison_sortie`, potential `at_war = yes`).

---

## 7. Game rules: `ai_aggression`, `ai_difficulty`, and the mystery flags

```text
game/main_menu/common/game_rules/00_game_rules.txt:65-82
ai_aggression = {
	default = ai_normal_aggression

	ai_low_aggression = {
		apply_modifier = ai:low_aggression
		flag = blocks_achievements
		flag = general_rule
	}

	ai_normal_aggression = {		
		apply_modifier = ai:normal_aggression
		flag = general_rule
	}

	ai_high_aggression = {
		apply_modifier = ai:high_aggression
		flag = general_rule
	}
}
```

- `apply_modifier = ai:<static_modifier>` applies a country modifier to AI countries only (`_game_rules.info:5`: "Valid are player, ai, and all"). `low_aggression` / `normal_aggression` (`ai_months_between_wars = 24`) / `high_aggression` are shown in §3.3; `difficulty_ai_*` (`difficulty.txt:65-116`) are pure combat/economy buffs (`discipline = 0.1`, `land_morale_modifier = -0.25`, …) — no AI-behaviour keys.
- The flags `lenient_ai`, `harsh_ai`, `low_ai_aggression`, `high_ai_aggression` are listed in `_game_rules.info:24-27` with the comment `???` and are **not used by any vanilla rule** (grep over `game/main_menu/common` and `game/in_game/common` finds only the info file). Treat them as legacy/unknown: **do not rely on them**; use `apply_modifier = ai:cw_…` plus (optionally) `defines = {}` in the mod's own rules (`has_game_rule = <setting_key>` trigger VERIFIED at `ai_personalities_setup.txt:19`).

---

## 8. Ruler and general traits as inputs

- Format: `traits/_traits.info:1-23` (`category = ruler/general/admiral/artist/explorer`, `allow`, `modifier`, `chance`).
- **Ruler traits carry `ai=yes` modifiers** (VERIFIED, `00_ruler.txt`): lines 56-62 (`cruel`), 114-115 (`aggressiveness_modifier = -0.1`), 189-191 (`carefulness_modifier = 0.05`), 210-216, 313-319 (`win_war_chance_threshold = -0.1`, `aggressiveness_modifier = 0.05`), 472-481, 543-550 (`aggressiveness_modifier = 0.15`, `expected_warscore_modifier = 0.2`), 568-571, 590-596, 615-619. These apply to the country while the character is ruler (`_traits.info:12-13`: "when the character's role is the same as this trait's category").
- **General traits carry no `ai=yes` modifiers** (VERIFIED by grep over `01_general.txt`): they are pure combat modifiers, e.g.

```text
traits/01_general.txt:28-42
offensive_planner = {
	category = general

	modifier = {
		commander_combat_bonus = 1
	}
}

defensive_planner = {
	category = general

	modifier = {
		military_tactics = 0.1
	}
}
```

- Reading traits in script: `has_trait = <key>` in character scope; from country scope `ruler = { has_trait = conqueror }` (`personality_events.txt:1680-1681`), `ruler ?= { has_trait = midas_touched }` (`artist_events.txt:863`), `heir ?= { … }`. Unit → commander: trigger `has_commander = yes/no` (`unit_abilities/drill_army.txt:19,41`; `trigger_localization/unit_triggers.txt:116`), effects `set_as_commander = scope:target` (`events/colonization/conquistador.txt:127`, inside `random_army = { limit = { has_commander = no } … }`), `remove_commander = $target$` (`scripted_effects/country_effects.txt:1802`), GUI `Unit.GetCommander`. **No vanilla script enters the commander character scope from a unit** (grep for `commander = {` / `commander ?= {` in common+events is empty) → the link name (`commander`? `leader`?) is **UNVERIFIED**; test `random_army = { commander ?= { has_trait = offensive_planner } }` and watch `error.log`. Unit-scope triggers that *are* verified: `is_army`, `is_exiled`, `morale_percentage`, `strength_percentage`, `food_percentage`, `in_combat`, `in_retreat`, `in_siege`, `sub_unit_fraction`, `sub_unit_count`, `num_subunits`, `has_levies/regulars/mercenaries`, `has_unit_modifier`, `unit_location` (`unit_triggers.txt:7-176`; `flavor_dan_corfitz_ulfeldt.txt:240-243` uses `any_army = { in_siege = yes unit_location.owner = c:DAN }`).
- Formation of regiment categories per flank: `unit_formation_preference/army.txt:1-36` (`balanced_army`, `default = yes`, `left/center/right = { 2 = army_light_cavalry … max_frontage = 1.25 }`, `reserves = { 100 = army_auxiliary }`), `cav_inf_cav` (39-66). An auxiliary HQ regiment lands in `reserves` by this table; the preference is a country attribute (`attribute_columns/121_unit_formation_preference.txt`, GUI `InteractionTarget.GetUnitFormationPreference`), with no scripted setter found (UNVERIFIED how it is changed).

---

## 9. (d) What is NOT moddable (hard-coded army AI)

1. Objective **types** and their internal logic (hunt, carpet siege, support, defend, transport, invasion landing choice, blockade): C++; only the NAI numbers and the stance priorities parametrise them.
2. Unit→objective **assignment** and reassignment (only `AI_MILITARY_*_FACTOR`, `AI_REASSIGN_UNIT_THRESHOLD`, stance priorities).
3. **Splitting/merging/attaching** decisions (`merge_army`, `split_unit`, `attach_unit`, `toggle_can_attach_to`, `detach_unit` commands) — only the thresholds in §2.1/2.5.
4. **Pathfinding, movement, retreat** (thresholds only), battle join/leave, assault decisions.
5. Naval invasion target choice (two weights), transport fleet sizing (one slope), repatriation.
6. **Which stance an AI overlord gives its subjects** (`ai_tick = never #handled in code`) and the **default personality** (`ai_cautious` "set in C++ constructor").
7. The AI has **no concept of the HQ regiment**: it will not keep a specific regiment in a specific army, will not count HQs when splitting, and will carpet-siege with HQ-less splinters. The only remedies are (a) fewer splinters via defines, (b) the mod's own monthly script placing HQs into the largest armies, (c) making HQ-less sieges merely slow rather than impossible on unfortified locations.
8. Player-facing objective groups and "Independent Operations" cannot be extended.
9. No script hook fires on "AI decided X"; only generic on_actions (`on_war_declared`, `on_join_war`, `on_battle_won/lost`, `on_great_battle_won/lost`, `on_siege_won/lost`, `on_location_occupied`, `on_winning_war`, `on_losing_war`, `on_ending_war` — `_hardcoded.txt:321-2395` names) and pulses.
10. `ai=yes` modifier types are a fixed set; new modifier types cannot be invented (the engine would not read them).

---

## 10. (e) Overseas and naval-invasion behaviour — keeping colonial AIs fighting

Facts (VERIFIED):

- `NAVY_COMPARABILITY_RATIO = 0.5` (1318): an AI considers cross-water targets only with ≥50 % of the target's navy — colonial powers qualify, navy-less natives do not. Do not lower it.
- `AI_CONQUER_DESIRE_NAVAL_DISTANCE_MULTIPLIER = -0.5` (1430) and `DISTANT_WAR_CONQUEST_FACTOR = 0.1` beyond `DISTANT_WAR_BORDER_DISTANCE = 100` (1321-1322): distant wars are rarely *chosen*; overseas fighting mostly happens inside wars declared for other reasons (colonial subjects, allies, IOs).
- `AI_TRANSPORT_STRENGTH_THRESHOLD_PER_DISTANCE = 0.0004` (828): a 2500-distance crossing needs a full-strength transport fleet; `AI_HEAVY_SHIP_RATIO_FOR_TRANSPORTS = 0.25` (989) escorts; `AI_NAVAL_PERFORMANCE_PATHFIND_DISTANCE_THRESHOLD = 2500` (827, Atlantic comment); `AI_NAVAL_TRANSPORT_FAILED_PATHFIND_RETRY_DAYS = 30` (836).
- Landing choice: `AI_NAVAL_INVASION_PORT_PREFERENCE = 5.0`, `AI_NAVAL_INVASION_THREAT_WEIGHT = 0.001` (1022-1023).
- Participation: `PARTICIPATION_SCORE_OVERSEAS_MULT = 0.25` (NWar 2674) — fighting overseas from the war leader earns a quarter of the participation; an AI ally's incentive to ship troops overseas is therefore weak (INFERRED).
- Exile: `static_modifiers/unit.txt:4-9 is_exiled = { … land_morale_modifier = -0.75 }` — exiled stacks are useless, `repatriate_troops` (priority 10 in every stance) brings them home first.
- Supply: `SUPPLY_LIMIT_OWNER = 0.25 / ACCESS 0.1 / ALLY 0.1 / CONTROLLER 0.1` (NLocation 1933-1936, "Should be highest of these defines or AI will be confused") — stacks shrink abroad, which is why overseas AI armies are small.
- Geography triggers for colonial HQ rules: `is_overseas_for_owner` (location, `trigger_localization/location_triggers.txt:408`, uses `OVERSEAS_DISTANCE = 150`), `continent = continent:north_america` style (`advances/canal_advances.txt:12-14`), `original_capital ?= { continent = continent:europe }` (`advances/0_age_of_traditions.txt:249`).

How to avoid "the AI refuses to fight overseas" under the HQ rule:

1. Never make HQ-less armies unable to *fight*; keep the penalty on `siege_ability` (−90 %) and moderate on morale/discipline, so expeditionary detachments still win battles and the mod's script can hand them a colonial HQ afterwards.
2. Colonial HQ auto-placement must run for AI at least monthly and pick, per overseas continent, the largest AI army *present on that continent* (`any_army`/`random_army` with `unit_location` continent checks — `unit_location` VERIFIED, continent-of-location comparison INFERRED).
3. Keep `NAVY_COMPARABILITY_RATIO`, `DISTANT_WAR_*` untouched; nudge only `AI_TRANSPORT_STRENGTH_THRESHOLD_PER_DISTANCE` (0.0003) and `AI_NAVAL_INVASION_THREAT_WEIGHT` (0.0008) if observer games show colonial AIs stop landing.
4. Give colonial powers the mod's "expeditionary" country modifier only while they own ≥N overseas locations (design §2.4 of DESIGN.md) and include `aggressiveness_modifier = +0.05…0.1` in it so colonial wars keep being declared; natives get the mirror (a small `carefulness_modifier`) only if the native-penalty rule is on.
5. Watch `PARTICIPATION_SCORE_OVERSEAS_MULT`: raising it to 0.5 (NWar) makes allied AIs value overseas help more (INFERRED) — cheap to test, outside NAI.

---

## 11. Pitfalls

1. **Define override scope**: a mod define file must contain the whole key path (`NAI = { KEY = value }`), placed under `loading_screen/common/defines/` (not `in_game/common`); typos are silent (unknown keys log to `error.log`, check it). Partial-block override is INFERRED, not seen in vanilla/mods.
2. **Game-rule `defines = {}`** is documented but unused by vanilla → may not work; keep the plain define file as fallback.
3. **Fractions must stay fractions**: `HUNT_ARMIES_WIN_CHANCE_SPLIT = 1.0` (never split) is safe; values >1 or <0 are untested.
4. **Performance**: `AI_PERFORMANCE_ATTACH_UNIT_MAX_DISTANCE`, pathfind thresholds and retry days are explicitly "saves performance" knobs; raise one at a time and watch `performance_degradation.log`.
5. **Attrition**: bigger stacks via `AI_SUPPLY_LIMIT_TARGET`/`RATIO_OVER_SUPPLY_TARGET_TO_SPLIT`/`global_supply_limit_modifier` mean more AI attrition in poor terrain; `AI_AVOID_ATTRITION_MAX_PATH_FIND_DISTANCE` and food logistics are not raised to compensate.
6. **Stalemate risk**: higher `CARPET_SIEGE_REQUIRED_WIN_CHANCE`, `HUNT_ARMIES_DESIRED_STRENGTH_MULT = 2.0` and `BATTLE_WIN_CHANCE_ENEMY_BIAS = 1.2` all push toward "nobody attacks"; combine with `YEARS_SINCE_LAST_WAR_ACTION_BEFORE_WHITE_PEACE = 3` (NWar) → more white peaces. Measure war length.
7. **HQ-less siege splinters**: `AI_STICK_TO_SIEGE_TIME_FACTOR` keeps a splinter on a siege it cannot finish (−90 % `siege_ability`); lower `CARPET_SIEGE_MAX_ARMIES` and consider a milder penalty on unfortified locations.
8. **`ai=yes` modifiers are visible** on the AI country's "Behavioral Modifiers" tooltip — name/localise `cw_stance_*` so it reads as the intended "war stage".
9. **`is_ai` flips** when a human takes the tag (hotjoin/`switch`) — remove `cw_stance_*` modifiers when `is_ai = no`.
10. **Subject stance set by script may be overwritten** by the overlord AI's C++ tick (`ai_tick = never #handled in code`) — re-apply monthly or verify it sticks.
11. **Two `is_default = yes` stances** if the mod adds its own default without replacing `00_default.txt` → undefined; replace the file or keep vanilla default.
12. **Readme gaps**: `support_sieges_priority`, `friendly_naval_transport_priority`, `confront_factor` are undocumented but real (used by vanilla stances); `support_armies_priority` readme text is a copy-paste error.
13. **Personalities default to `ai_cautious`** in 1.4.7 (historical file missing); conditions like `ai_personality = ai_personality:ai_aggressive` are almost never true unless the random rule is on. Do not gate mod logic on personalities.
14. **Game-rule flags `lenient_ai/harsh_ai/low_ai_aggression/high_ai_aggression`** are `???` and unused — do not reference them.
15. **`ai.log` warning spam** (`AI tried to execute invalid command: merge_army/split_unit/attach_unit…`) is vanilla noise, not a mod error; but counting `split_unit` vs `merge_army` lines before/after is a cheap concentration metric.
16. **`AI_MINIMUM_AUXILIARY_RATIO = 0.15`**: if the HQ regiment is an auxiliary-category unit, the AI may treat it as filling the auxiliary quota — coordinate with the unit-type research.
17. **`WAR_BALANCE_REGULARS_IMPORTANCE = 3`** etc.: StrengthBalance ignores HQs (100 men); an HQ-less but numerous army still looks "strong" to the AI and to `relative_strength` — the scripted war stance should not expect the engine to discount HQ-less armies.

---

## 12. Recommendations for the mod (concrete)

**Experiments first (one observer game each, 1337→1400, record war count, mean war length, `split_unit`/`merge_army` lines in `ai.log`, occupations per war):**

- **E1 — stance applies to independents?** Edit a test copy of `normal_military_stance` with `carpet_siege_enemy_locations_priority = 0`, `hunt_army_priority = 0`; if independent AIs stop sieging/hunting, stances are the master lever → implement the war stages as stance switches (§5.4.3) and build `cw_*` stances for each stage.
- **E2 — define override loads?** `loading_screen/common/defines/cw_ai_defines.txt` with `NAI = { CARPET_SIEGE_MAX_ARMIES = 1 }`; confirm in-game (single siege stacks) and `error.log` clean. Then test the game-rule `defines = {}` variant.
- **E3 — literal stance reference syntax** for `set_country_military_stance` (`subject_military_stance:<key>` vs `military_stance:<key>`), and whether a script-set subject stance survives the overlord's AI tick.
- **E4 — commander scope link** from unit scope (`commander ?=`), needed for "general trait shifts the stance".

**Ship in v0.1 (`loading_screen/common/defines/cw_ai_defines.txt`), conservative tier:**

```text
NAI = {
	RATIO_OVER_SUPPLY_TARGET_TO_SPLIT = 1.8
	AI_LAND_ARMY_MERGE_THRESHOLD = 0.95
	HUNT_ARMIES_WIN_CHANCE_SPLIT = 1.0
	HUNT_ARMIES_MAX_SPLINTERS = 2
	HUNT_ARMIES_AI_MAX_NUM_OBJECTIVES = 3
	CARPET_SIEGE_MAX_ARMIES = 4
	AI_CARPET_SIEGE_MAX_ARMIES_FACTOR = 0.05
	CARPET_SIEGE_CONFRONT_FACTOR = 0.3
	AI_SUPPORT_ARMIES_DESIRED_STRENGTH_FACTOR = 0.5
	AI_ENEMY_STRENGTH_NO_SUPPORT_ARMIES_FACTOR = 3
	AI_REASSIGN_UNIT_THRESHOLD = 1.6
	AI_AWAIT_REINFORCING_ARMY_DISTANCE_MAX = 60
	AI_AWAIT_REINFORCING_ARMY_DISTANCE_MIN = 30
	AI_WAIT_FOR_JOINING_UNIT_STRENGTH_THRESHOLD = 0.2
	AI_PERFORMANCE_ATTACH_UNIT_MAX_DISTANCE = 350
	AI_ATTACH_MIN_FRONTAGE_ROOM = 0.5
	AI_REINFORCE_ONGOING_BATTLE_DISTANCE = 4
	AI_REINFORCE_BATTLE_DISTANCE_LIMIT = 5
	AI_REINFORCE_BATTLE_STRENGTH_TRESHOLD = 0.7
	AI_CALL_ALLY_STRENGTH_BALANCE_THRESHOLD = 0.85
	HEAVILY_OUTNUMBERED_RATIO = 0.5
	OUTNUMBERED_BATTLE_ADVANTAGE = 0.5
	AI_ENEMY_LAND_SUPREMACY_THRESHOLD = 2
	AI_RECOVER_MORALE_THRESHOLD = 75
	MAX_RECRUIT_DISTANCE = 6
	AI_TRANSPORT_STRENGTH_THRESHOLD_PER_DISTANCE = 0.0003
}
```

Hold back for the "strong" tier (game rule): `HUNT_ARMIES_DESIRED_STRENGTH_MULT = 2.0`, `BATTLE_WIN_CHANCE_ENEMY_BIAS = 1.2`, `CARPET_SIEGE_REQUIRED_WIN_CHANCE = 0.85`, `AI_TERRAIN_RETREAT_THRESHOLD = 0.85`, `AI_SUPPLY_LIMIT_TARGET = 1.05` — these are the stalemate-prone ones.

**Scripted war stance (§3.5)**: four static modifiers `cw_stance_offensive / defensive / waiting / harassing` built from `ai=yes` types (+ `global_supply_limit_modifier` on waiting/defensive), monthly `cw_update_ai_war_stance` with `relative_strength`, `war_enthusiasm`, `months_since_war`, `modifier:aggressiveness_modifier`, `ruler ?= { has_trait … }`; store the stage in `var:cw_stance` (+ `cw_stance_changed_date`) for the GUI plate and the "unknown" delay. If E1 passes, additionally call `set_country_military_stance` per stage.

**Subjects**: add `cw_escort_military_stance`; apply it to AI overlords' subjects monthly; re-check it is not reverted (E3).

**Personalities**: untouched; optional `+0.1 defence_importance_modifier` in the HQ-less country modifier is enough.

**Colonial AIs**: expeditionary country modifier with small `aggressiveness_modifier`; colonial HQ placement per continent monthly; do not touch `NAVY_COMPARABILITY_RATIO` / `DISTANT_WAR_*`; consider `PARTICIPATION_SCORE_OVERSEAS_MULT = 0.5` (NWar) as a separate test.

**Metrics to log** (TESTING.md): wars/decade, mean war length, average AI stack size at battle (`on_battle_won` scope `scope:actor`/`scope:target` are units — `_hardcoded.txt:3209-3218`), share of AI sieges by HQ armies, `ai.log` split/merge counts.

---

## Appendix A — Verified syntax cheat-sheet used in this note

| Thing | Example (file:line) |
|---|---|
| Define block | `NAI = { AI_SUPPLY_LIMIT_TARGET = 0.95 ... }` — `00_defines.txt:565,1025` |
| AI modifier type | `aggressiveness_modifier={ percent=yes color = bad game_data={ category=country ai=yes } }` — `00_modifier_types.txt:13433-13440` |
| Static country modifier | `low_aggression = { game_data = { category = country } ai_require_cb_for_war = yes carefulness_modifier = 0.25 ai_months_between_wars = 60 }` — `difficulty.txt:118-125` |
| Game rule applying AI modifier | `ai_low_aggression = { apply_modifier = ai:low_aggression flag = blocks_achievements flag = general_rule }` — `00_game_rules.txt:68-72` |
| Game rule trigger | `has_game_rule = ai_personalities_random` — `ai_personalities_setup.txt:19` |
| Set personality | `set_personality = ai_personality:ai_aggressive` — `ai_personalities_setup.txt:22`; Cheat Menu Pro `sakuya_cheat_sgui.txt:6139` |
| Personality trigger | `ai_personality = ai_personality:ai_expansionist`, `ai_personality != ai_personality:ai_isolationist` — `attack_neighbors.txt:5,13` |
| AI-only country loop | `every_country = { limit = { is_ai = yes } ... }` — `ai_personalities_setup.txt:15-16` |
| Subjects loop | `every_subject_or_below = { limit = { is_neighbor_of = root } ... }` — `attack_neighbors.txt:22-25` |
| Set stance | `scope:subject = { set_country_military_stance = scope:military_stance }` — `generic_actions/military_stance.txt:53-55` |
| Stance link | `this = scope:subject.country_stance` — `military_stance.txt:42` |
| New stance | `siege_raider_military_stance = { carpet_siege_enemy_locations_priority = 10 ... confront_factor = 0.0 }` — `00_default.txt:151-189` |
| Timed country modifier | `add_country_modifier = { modifier = diwani_script months = 60 mode = replace }` — `cultural_event.txt:236` |
| Remove / check modifier | `remove_country_modifier = crown_estate_head_of_cabinet_influence` — `country_effects.txt:894`; `has_country_modifier = true_republican_virtues_modifier` — `personality_events.txt:524` |
| Read AI modifier in script value | `value = modifier:aggressiveness_modifier` — `io_policy.txt:189` |
| Relative strength | `relative_strength = { target = c:CHB value < 0.5 }` — `flavor_geo.txt:743-746` |
| Enemy loop | `any_country_at_war_with = { ... }` — `language_events.txt:16` |
| War loop | `any_current_war = { is_in_war = scope:target.owner has_variable = holy_league_crusade }` — `_hardcoded.txt:3215-3218` |
| Ruler trait | `ruler = { has_trait = conqueror }` — `personality_events.txt:1680-1681` |
| Unit commander | `random_army = { limit = { has_commander = no } set_as_commander = scope:target }` — `conquistador.txt:123-128` |
| Unit location | `any_army = { in_siege = yes unit_location.owner = c:DAN }` — `flavor_dan_corfitz_ulfeldt.txt:240-243` |
| Variable | `set_variable = { name = pu_war_senior_partner value = scope:recipient }` — `_hardcoded.txt:2362-2365` |
| Monthly hook | `monthly_country_pulse = { on_actions = { on_papal_opinion_added ... } }` — `country_monthly.txt:2-21`; on_action `trigger = {}` — `on_actions.info:1-4` |
| Scripted GUI AI keys | `ai_is_valid = { trigger }`, `ai_chance = { }`, `ai_frequency = {}` — `scripted_guis.info:10-12` |
| Unit ability AI | `ai_will_do = { add = -1 if = { limit = { food_percentage < 0.25 } add = 2 } }` — `gather_food.txt:43-51` |
| Overseas location | `is_overseas_for_owner` — `location_triggers.txt:408`; `OVERSEAS_DISTANCE = 150` — `00_defines.txt:1957` |
| Continent | `continent = continent:europe` — `canal_advances.txt:12` |

## Appendix B — Files read

`game/loading_screen/common/defines/00_defines.txt` (NAI 565-1608, NWar 2665-2727, NLocation excerpts), `game/loading_screen/common/defines/jomini/*.txt`, `game/in_game/common/subject_military_stances/{00_default.txt,readme.txt}`, `game/in_game/common/generic_actions/military_stance.txt`, `game/in_game/common/unit_formation_preference/*`, `game/in_game/common/ai_personalities/00_ai_personalities.txt`, `game/in_game/common/on_action/{ai_personalities_setup.txt,_hardcoded.txt,country_monthly.txt,on_actions.info}`, `game/in_game/common/ai_scripted_expansion_target/*`, `game/in_game/common/ai_scripted_expansion_score/readme.txt`, `game/in_game/common/scripted_diplomatic_objectives/readme.txt`, `game/in_game/common/join_war_rules/*`, `game/in_game/common/generic_action_ai_lists/{readme,military_list,siege_list,lend_unit_list}.txt`, `game/in_game/common/unit_abilities/*.txt`, `game/in_game/common/unit_categories/00_army_light_infantry.txt`, `game/in_game/common/traits/{_traits.info,00_ruler.txt,01_general.txt}`, `game/in_game/common/trigger_localization/*`, `game/in_game/common/effect_localization/country_effects.txt`, `game/in_game/common/scripted_guis/scripted_guis.info`, `game/in_game/common/script_values/io_policy.txt`, `game/in_game/common/societal_values/00_default.txt`, `game/in_game/common/auto_modifiers/country.txt`, `game/in_game/gui/{ai_targets_viewer,ai_settings_menu,military_objective_groups,military_objective_group,manage_subjects_lateralview,context_menu}.gui`, `game/in_game/gui/shared/unit_tooltips.gui`, `game/main_menu/common/modifier_type_definitions/00_modifier_types.txt`, `game/main_menu/common/static_modifiers/{difficulty,country,character,unit,readme}.txt`, `game/main_menu/common/game_rules/{00_game_rules.txt,_game_rules.info}`, `game/main_menu/gui/shared/font_icons.gui`, `game/main_menu/localization/english/{ai_personalities,military,interfaces,modifier_types,triggers,effects,actions,messages,war_overview,game_concepts}_l_english.yml`, workshop mods `3600272327` (Cheat Menu Pro) and `3634102315` (Simple Cheats), `Documents/Paradox Interactive/Europa Universalis V/logs/{ai,error}.log`.
