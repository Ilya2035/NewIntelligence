# 10 — Overseas / colonial warfare and balance (EU5 1.4.7)

Research note for the *Concentrated Warfare* mod (`cw_`). Game root: `C:\Program Files (x86)\Steam\steamapps\common\Europa Universalis V` (all paths below are relative to it unless stated). Workshop examples: Cheat Menu Pro (`workshop/content/3450310/3600272327`), Simple Cheats (`…/3634102315`).

Legend: **VERIFIED** = seen verbatim in vanilla/workshop files (path:line quoted). **INFERRED** = composed only from verified parts, but the exact composition was not seen in vanilla. **UNVERIFIED** = plausible, not found in files; must be tested in game.

---

## 1. Geography model: continents, sub-continents, "overseas"

### 1.1 Hierarchy and keys (VERIFIED)

The map hierarchy is `continent > sub_continent > region > area > province > location`, defined by nesting in `game/in_game/map_data/definitions.txt` (10 563 lines, 1 tab per level):

```
game/in_game/map_data/definitions.txt
1:     europe = {
2:         western_europe = {
1245:      eastern_europe = {
1943:  asia = {            # central_asia 1944, middle_east 2052, east_asia 2433, north_asia 3395,
                           # south_asia 3665, south_east_asia 4334
4785:  africa = {          # central_africa 4786, east_africa 5011, north_africa 5335,
                           # southern_africa 5523, west_africa 5658
5880:  america = {
5881:      north_america = {
5882:          canada_region = {
5883:              quebec_area = {
5884:                  gaspe_province = {
8064:      south_america = {
9125:  oceania = {         # australasia 9126, pacific_islands 9354
10287: atlantic_ocean_continent = {   # indian_ocean_continent 10407, pacific_ocean_continent 10470,
                                       # antarctic_ocean_continent 10550
```

**Land continent keys (5):** `continent:europe`, `continent:asia`, `continent:africa`, `continent:america`, `continent:oceania`. Sea continents: `atlantic_ocean_continent`, `indian_ocean_continent`, `pacific_ocean_continent`, `antarctic_ocean_continent`.
**Sub-continent keys (17 land):** `western_europe eastern_europe central_asia middle_east east_asia north_asia south_asia south_east_asia central_africa east_africa north_africa southern_africa west_africa north_america south_america australasia pacific_islands` (+ 6 ocean sub-continents).

Important: **`america` is one continent**; North and South America are *sub-continents*. Icons in `game/main_menu/gfx/interface/icons/continents/` (africa, asia, europe, north_america, oceania, south_america) are GUI art, not keys.

### 1.2 Trigger / scope syntax (VERIFIED)

Usage counts over `game/in_game/common`, `events`, `main_menu/common` (grep): `sub_continent = sub_continent:X` 232, `continent = continent:X` 195, `capital.continent = continent:X` 69, `capital.sub_continent = sub_continent:X` 61, `location.continent = continent:X` 16, `continent != root.capital.continent` 10, `continent = root.capital.continent` 8, `continent != continent:X` 6.

```
game/in_game/common/scripted_triggers/exploration_triggers.txt
49: capital_in_old_world_trigger = {
50: 	capital = {
51: 		OR = {
52: 			continent = continent:europe
53: 			continent = continent:asia
54: 			continent = continent:africa
55: 		}
56: 	}
57: }
```

```
game/in_game/events/DHE/flavor_cas_por.txt
25: 			any_owned_location = {
26: 				continent != root.capital.continent
27: 				OR = {
28: 					raw_material = goods:goods_gold
```

```
game/in_game/common/scripted_triggers/situation_triggers.txt
63: 			top_overlord_or_this ?= { capital.continent = continent:europe }
64: 			top_overlord_or_this ?= { capital.continent = continent:asia }
65: 			top_overlord_or_this ?= { capital.continent = continent:africa }
```

```
game/in_game/common/unit_types/a_north_american.txt
15: 	country_potential = {
16: 		government_type = government_type:tribe
17: 		NOT = { is_capital_mesoamerica = yes }
18: 		NOT = { is_capital_in_south_america_or_carribean = yes }
19: 		capital ?= { continent = continent:america }
20: 	}
```

`continent` / `sub_continent` are location-scope triggers *and* scope links (`capital.continent`, `location.continent`); comparison to another scope's continent works (`continent != root.capital.continent`). Finer geography triggers: `region = region:x`, `area = area:x` (`location_triggers.txt:211-232`, `is_capital_mesoamerica`, `is_capital_in_south_america_or_carribean`).

Pitfall caught during research: a naive grep for `continent:western_europe` returns 65 hits, but every one is `sub_continent:western_europe` (substring). **There is no `continent:western_europe`.**

### 1.3 The "overseas" concept (VERIFIED)

```
game/main_menu/localization/english/game_concepts_l_english.yml
92:  game_concept_overseas_desc: "This is a [location|e] on another [continent|e] whose [sub_continent|e] does not border the [capital|e]'s [continent], by land or sea."
```

So "overseas" is **not** "other continent": a sub-continent that borders the capital's continent by sea (very likely north_africa / middle_east for European capitals) is *not* overseas. Exact adjacency table is engine-side — **UNVERIFIED which sub-continents count as bordering Europe**; test with the triggers below in a debug tooltip.

Two location triggers exist (trigger localization proves both):

```
game/in_game/common/trigger_localization/location_triggers.txt
408: is_overseas_for_owner= {
409: 	none = IS_OVERSEAS_FOR_OWNER_TRIGGER
410: 	global = IS_OVERSEAS_FOR_OWNER_TRIGGER
...
414: would_be_overseas_for = {
415: 	none = WOULD_BE_OVERSEAS_FOR_TRIGGER
416: 	global = WOULD_BE_OVERSEAS_FOR_TRIGGER
```

```
game/in_game/common/subject_types/colonial_nation.txt
106: 	subject_creation_enabled = {
107: 		scope:target_province ?= { is_overseas_for_owner = yes }
108: 	}
```

```
game/in_game/common/colonial_charter_goals/form_colonial_nation.txt
11: 			any_location_in_province_definition = {
12: 				would_be_overseas_for = scope:owner
13: 			}
```

Other verified users: `building_types/plantation_buildings.txt:17` (`is_overseas_for_owner = yes` OR `owner ?= { is_colonial_subject = yes }`), `rural_buildings.txt:17`, `capital_buildings.txt:1156`, `generic_actions/church_power.txt:318`.

Semantics: `is_overseas_for_owner` is relative to the **location's owner** (useless for an army standing in enemy or unowned land); `would_be_overseas_for = <country scope>` takes the country explicitly — use it for armies.

A separate, distance-based define also exists (do not confuse with the continent concept):

```
game/loading_screen/common/defines/00_defines.txt
1957: 	OVERSEAS_DISTANCE = 150			# Provinces beyond this distance to capital are distant overseas
2674: 	PARTICIPATION_SCORE_OVERSEAS_MULT = 0.25 		# How much less participation do you get if fighting overseas from war leader?
```

### 1.4 Army-scope geography (VERIFIED parts, INFERRED composition)

`unit_location` is a scope link from a unit (army) to its location; `owner` links to the country:

```
game/in_game/common/on_action/_hardcoded.txt   (inside on_great_battle_won, root at 2983; scope:actor = unit)
3082: 				scope:actor = { 
3083: 					owner = { tag = SER } 
3084: 					unit_location = location:pristina
3085: 				}
...
3089: 				unit_location = { save_scope_as = target_location }
```

Country iterators over armies: `every_army` (`events/colonization/conquistador.txt:108`), `ordered_army` with `order_by = num_subunits` (`generic_actions/parliament.txt:1262-1268`), `any_army` (23 uses), `random_army` (17). Unit triggers (localized list, `trigger_localization/unit_triggers.txt:7-176`): `is_army, is_exiled, strength_percentage, morale_percentage, has_unit_modifier, has_commander, in_combat, in_retreat, in_siege, sub_unit_fraction, sub_unit_count, sub_unit_strength, num_subunits, has_levies, has_regulars, has_mercenaries, is_lent_unit`. Sub-unit triggers (`subunit_triggers.txt:7-75`): `is_ship, sub_unit_type, sub_unit_category_this_equal, is_levy, is_mercenary, subunit_strength…`. Sub-unit iterators: `any_sub_unit` (26), `every_sub_unit` (10), `any_country_sub_unit` (6, `insults/00_insults.txt:372-374`), `every_country_sub_unit` (1).

**INFERRED** "army is on an overseas continent" (all parts verified; the composition is new):

```
# country scope
save_scope_as = cw_owner
every_army = {
    limit = {
        is_army = yes
        is_exiled = no
        unit_location = { would_be_overseas_for = scope:cw_owner }   # or: continent != scope:cw_owner.capital.continent
    }
    ...
}
```

Note `continent != scope:cw_owner.capital.continent` gives "other continent" (America/Asia/Africa/Oceania), while `would_be_overseas_for` gives the game's own "overseas" notion. Pick deliberately (see §7).

### 1.5 GUI data functions (VERIFIED)

`[Location.GetSubContinent]` (4 uses in `game/in_game/gui`), `[InteractionTarget.GetContinent.GetTotalPopulation]` (`gui/attribute_columns/continent.gui:24`), loc function `[ShowContinentName('europe')]` (`game_rules_l_english.yml:67`). `Unit.GetLocation.GetContinent…` — UNVERIFIED chain, but `GetContinent` exists on a location object.

---

## 2. Colonial subjects: who actually fights overseas

### 2.1 `colonial_nation` subject type (VERIFIED, `game/in_game/common/subject_types/colonial_nation.txt`)

```
8: 	join_offensive_wars_always = {
9: 		NOT = { scope:actor ?= { is_subject_of = scope:recipient } }
10: 	}
...
30: 	join_defensive_wars_always = {        # unless the recipient is in a colonial_federation IO (lines 31-47)
...
53: 	is_colonial_subject = yes
...
58: 	strength_vs_overlord = -0.05
...
65: 	allow_declaring_wars = { 
66: 		colonial_nation_can_declare_wars_trigger = yes
67: 	}
69: 	fleet_basing_rights = yes
70: 	food_access = yes
97: 	subject_modifier = {
98: 		global_population_capacity_modifier = 0.10
99: 		allow_rgo_slave_demand = yes
100: 		loyalty_to_overlord = 20
```

Colonial nations are **real, separate AI countries** with their own armies; they always join the overlord's offensive wars and are always called defensively. They may start their own wars only on the same continent and never against their own overlord's tree:

```
game/in_game/common/scripted_triggers/country_triggers.txt
1226: colonial_nation_can_declare_wars_trigger = {
1227: 	OR = {
1228: 		NOT = { exists = scope:attacker }
1229: 		scope:attacker = {			
1230: 			OR = {
1231: 				NOT = { exists = scope:defender }
1232: 				AND = {
1233: 					capital.continent = scope:defender.capital.continent
1234: 					NOT = {top_overlord_or_this = scope:defender.top_overlord_or_this}
```

Setup effect `setup_colonial_nation` (`scripted_effects/country_effects.txt:2603-2616`): republic, +100 gold, `add_reform = government_reform:colonial_subject`, 50-year `new_colonial_nation_founded` (`static_modifiers/country.txt:1425-1434`: `monthly_rebel_growth -0.01, global_pop_promotion_speed_modifier 1.0, global_population_growth 0.005`). Reform `colonial_subject` (`government_reforms/country_specific.txt:3496-3517`): `global_population_growth 0.00025, global_raw_material_output 0.1, government_reform_slots 1`. Colonial-nation advances (`advances/colonial_nations.txt`): `colonial_militia` `global_levy_size_modifier = 0.1` (l.31), `liberty_heroes` `combat_speed_modifier = 0.2` (l.83), `colonial_ambition` `land_morale_modifier = 0.1` (l.91).

### 2.2 The AI never keeps overseas charter land directly (VERIFIED)

```
game/in_game/common/colonial_charter_goals/keep_as_territory.txt
17: 	ai_will_select = {
18: 		value = -1000
19: 		# AI never keeps overseas territory directly
20: 		if = {
21: 			limit = { scope:target = { any_location_in_province_definition = { would_be_overseas_for = scope:owner } } }
22: 			add = -9000
23: 		}
24: 		else = {
25: 			add = 2000
26: 		}
```

Consequence for the mod: an AI Castile/Portugal/England **owns almost no overseas locations itself** — its American land sits in colonial-nation subjects (expanded via `expand_subject.txt`, same/adjacent area or same region, l.9-13). Overseas fighting on the American continent is done by colonial nations and natives; the European AI's own army appears overseas only for naval invasions (§3) and conquests in non-"overseas" sub-continents (e.g. North Africa). Land taken by peace treaty is a different path; no vanilla script was found that transfers conquered overseas land to subjects (UNVERIFIED what the AI does with war-conquered overseas land).

### 2.3 Overlord recruits regiments in subject land (VERIFIED)

```
game/in_game/common/laws/colonial_laws.txt
17: 	colonial_representation_law_yes = { #Colonial Nation has representation
...
21: 		country_modifier = {
22: 			overlord_blocked_from_recruiting_regiments = yes
23: 			overlord_blocked_from_building_ships = yes
```

`modifier_types_l_english.yml:3584`: "This disallows the [overlord|e] from [recruiting|e] [regiments|e]." → by default the overlord **can** recruit regiments inside its colonial nation (locally raised overseas armies are possible without transport).

### 2.4 `colonial_federation` IO (VERIFIED, `international_organizations/colonial_federation.txt:5-6`): members at war with each other are expelled; members stop auto-joining the overlord's wars (colonial_nation.txt:12-29).

### 2.5 Subject military stances = AI objective priorities (VERIFIED)

```
game/in_game/common/subject_military_stances/00_default.txt
1: normal_military_stance = {
2:     is_default = yes
3:     chase_unit_own_location_priority = 10
...
10:     hunt_army_priority = 8
11:     hunt_navy_priority = 8
12:     defend_own_territory_priority = 10
13:     defend_ally_territory_priority = 5
14:     merge_units_priority = 10
...
20:     carpet_siege_own_locations_attacking_priority = 2
21:     carpet_siege_own_locations_defending_priority = 4
22:     carpet_siege_enemy_locations_priority = 2
...
28:     friendly_naval_transport_priority = 1
```

Stances: `normal`, `aggressive` (l.31), `supportive` (l.61), `passive`, `defensive`, `siege_raider` (`carpet_siege_enemy_locations_priority = 10`). The readme (`readme.txt:4-28`) documents every priority key — this is the complete list of **AI military objective types** (`chase_unit_*`, `hunt_army`, `defend_own_territory`, `merge_units`, `carpet_siege_*`, `blockade_*`, `suppress_rebel`, `army_logistics`, `navy_logistics`, `friendly_naval_transport`, `support_armies`, `support_sieges`, `repatriate_troops`, `maintain_military_levels`). A stance is set by the overlord through a generic action:

```
game/in_game/common/generic_actions/military_stance.txt
53:                 scope:subject = {
54: 				    set_country_military_stance = scope:military_stance
55:                 }
```

(`set_country_military_stance` — effect localized in `effect_localization/country_effects.txt:1401`; read-back: `scope:subject.country_stance`, l.42.) Whether a new stance file in the mod can be applied to **non-subject** AI countries is UNVERIFIED (the generic action's `source_flags = subjects`), but the effect itself takes any country scope — worth a test for "concentrate" stances.

### 2.6 Conquistadors — vanilla's "expeditionary army overseas" (VERIFIED)

Unlocked only for Iberian Catholics in Iberia:

```
game/in_game/common/advances/religion_catholic.txt
115: conquistador_advance = {
117: 	age = age_3_discovery
119: 	potential = {
120: 		religion = religion:catholic
121: 		culture = { has_culture_group = culture_group:iberian_group }
122: 		capital.region ?= region:iberia_region
123: 	}
125: 	allow_conquistadors = yes
126: 	requires = colonial_charters
```

Target selection is continent-gated and strength-gated:

```
game/in_game/common/generic_actions/conquistadors.txt
54: 		visible = {
55: 			within_colonial_range_of = scope:actor
57: 			continent = continent:america
58: 			scope:actor = {
59: 				has_discovered_area = prev
60: 			}
...
78: 				owner ?= { potential_army_size < conquistador_max_target_army_size }   # = 18, script_values/conquistador_values.txt:1
```

The event creates an **army-type pseudo-country** and spawns its army with a supply unit:

```
game/in_game/events/colonization/conquistador.txt
44: 			scope:target_location = {
45: 				create_army_country_in_location = {
46: 					reforms = {
47: 						conquistador_country
48: 					}
49: 					overlord = scope:actor
...
52: 					subject_type = subject_type:conquistador
...
66: 					while =  {
67: 						count = 6 #6 * 1500 = 9K troops
68: 						create_sub_unit_with_owner = {
69: 							type = a_discovery_conquistadors
70: 							owner = scope:new_conquistador
71: 							origin = scope:location
72: 							experience = 100
```

(`else` branch l.85: `count = 6 #6 * 1000 = 6K troops` → a regiment = 1 000 men in age 2, 1 500 in age 3; then `every_army = { every_sub_unit = { add_subunit_morale … } }` l.108-110.) The unit (`unit_types/2_conquistador.txt:1-13`): `copy_from = a_age_2_renaissance_heavy_infantry, is_special = yes, strength_damage_taken = -0.1, morale_damage_done = 0.2, food_storage_per_strength = 10, buildable = no`. The reform:

```
game/in_game/common/government_reforms/country_specific.txt
551: conquistador_country = {
554: 	potential = {
555: 		country_type = army
556: 		religion = religion:catholic
557: 		capital ?= { continent = continent:america }
...
567: 	country_modifier = {
568: 		auto_conquer_different_religion_at_war = yes
569: 		blocked_from_peace = yes
572: 		damage_done_versus_heathens_modifier = 0.25
573: 		discipline = 0.10
574: 		land_morale_modifier = 0.15
```

Subject type `conquistador.txt`: `subject_modifier = { military_tactics 0.5, global_max_control 0.5, global_integration_speed_modifier 1.0, wrong_culture_levy_size 0.5, blocked_from_peace = yes }` (l.56-62), annexable after 20 years (l.6-9). **This is the main vanilla "Europeans beat natives" lever: a free 6-9k veteran army with +10 % discipline, +15 % morale, +25 % damage vs heathens, auto-conquering, unable to make peace.** `country_type = army` countries are pseudo-countries — exclude them from HQ logic with `is_real_country = yes` (`on_action/country_monthly.txt:303`, `country_yearly.txt:1001`) / `country_type != army`.

Related Iberian flavour: Treaty of Tordesillas generic actions (`generic_actions/treaty_of_tordesillas.txt:2, 238, 418`) add colonial claims outside `continent:europe` / `south_asia` / `east_asia` (l.59-61) — claims, not military bonuses.

### 2.7 Other overseas subject types / tools

`trade_company.txt` (building-type country, `join_defensive_wars_always` only when actor is its subject, l.8-12; no offensive auto-join). Expeditions (`expedition_types/`: `cape_route_to_india, circumnavigation_expedition, pacific_crossing, treasure_fleet, western_ocean_voyage, …`) are character-led voyages, not armies. Peace treaties `abandon_colonial_claim.txt`, `abandon_colonies.txt` touch charters, not armies.

---

## 3. AI defines: distant wars, naval invasions, transports, stacking (VERIFIED)

`game/loading_screen/common/defines/00_defines.txt`:

| line | define | value | meaning / relevance |
|---|---|---|---|
| 579 | `WAR_ALLY_DISTANCE_BASE` | 200 | ally-distance scale for war evaluation |
| 1318 | `NAVY_COMPARABILITY_RATIO` | 0.5 | ≥ half the enemy navy ⇒ cross-water targets are considered at all |
| 1319 | `AI_BORDERING_CONQUEST_FACTOR` | 5 | bordering targets ×5 |
| 1321-1323 | `DISTANT_WAR_BORDER_DISTANCE / _CONQUEST_FACTOR / _SUBJUGATION_FACTOR` | 100 / 0.1 / 0.33 | beyond 100 border-distance a conquest war scores ×0.1 → AI rarely declares distant wars |
| 1425-1427 | `AI_CONQUER_DESIRE_DISTANCE_BASE / _PER_COUNTRY_SIZE / _PER_AGE` | 100 / 0.5 / 50 | allowed distance grows with size and age |
| 1429-1430 | `AI_CONQUER_DESIRE_DISTANCE_MULTIPLIER / _NAVAL_DISTANCE_MULTIPLIER` | −0.1 / −0.5 | sea distance penalised 5× harder ("smaller number means more likely to attack") |
| 1433-1434 | `AI_CONQUER_DESIRE_CAPITAL_DISTANCE / _MIN_FACTOR` | 100 / 0.05 | far-from-capital targets decay to 5 % |
| 1196-1200 | `CONQUER_DESIRE_DISTANCE_FLOOR…TAIL_DECAY` | 0 / 0.25 / 0 / 0.5 / 1.5 | distance gate shape |
| 1402 | `AI_ENEMY_LAND_SUPREMACY_THRESHOLD` | 3 | enemy 3× land armies in a defensive war ⇒ AI hangs back |
| 1405 | `AI_UNIT_WAIT_FOR_WAR_DISTANCE_THRESHOLD` | 100 | units wait up to 100 from the enemy border avoiding attrition |
| 1404 | `AI_MAX_RECRUIT_DISTANCE_FROM_UNIT` | 500 | recruits join units up to 500 away |
| 1037 | `MAX_RECRUIT_DISTANCE` | 10 | AI recruits ≤10 from base location |
| 1022-1023 | `AI_NAVAL_INVASION_PORT_PREFERENCE / _THREAT_WEIGHT` | 5.0 / 0.001 | landing-point choice: prefers ports, avoids enemy strength |
| 828 | `AI_TRANSPORT_STRENGTH_THRESHOLD_PER_DISTANCE` | 0.0004 | "2500 distance needs a 100 % strength transport fleet" |
| 836 | `AI_NAVAL_TRANSPORT_FAILED_PATHFIND_RETRY_DAYS` | 30 | |
| 838 | `AI_PERFORMANCE_ATTACH_UNIT_MAX_DISTANCE` | 200 | allied units attach only within 200 |
| 1016-1021 | `CARPET_SIEGE_REQUIRED_WIN_CHANCE / _CONFRONT_FACTOR / _SEARCH_DEPTHS / _MAX_ARMIES` | 0.8 / 0.5 / {10 8 6 5 4 3 2 …} / 10 | carpet siege splits down to ≤10 armies |
| 1025-1026 | `AI_SUPPLY_LIMIT_TARGET`, `RATIO_OVER_SUPPLY_TARGET_TO_SPLIT` | 0.95 / 1.3 | AI sizes stacks to ~95 % of average supply limit, splits in half at 130 % |
| 1131-1132 | `AI_AWAIT_REINFORCING_ARMY_DISTANCE_MAX / _MIN` | 35 / 20 | collaborating armies wait for each other |
| 1051 | `AI_AVOID_ATTRITION_MAX_PATH_FIND_DISTANCE` | 7 | |
| 2674 | `PARTICIPATION_SCORE_OVERSEAS_MULT` | 0.25 | allies get ¼ participation overseas → little incentive to help overseas |
| 2676 | `PARTICIPATION_SCORE_UNFORTIFIED_MULT` | 0.1 | engine distinguishes "besieging unfortified provinces" |
| 643-647 | `AI_EAGER_COLONIZER_TAGS {SWE POR KUR}`, `AI_WESTERN_COLONIZATION_CONTINENTS {"europe"}`, `…_EXCLUDED_TAGS {PAP}`, `…_EXCLUDED_PREFERENCE_TAGS {warfare}` | | who colonises under the default rule |
| 626-642 | `AI_BASE_COLONY_UTILITY 3`, `AI_COLONIZE_TAX_BASE_THRESHOLD 100`, `AI_COLONIAL_CHARTER_TICK_MONTHS 6` | | |
| 1558 | `AI_SAVING_MODE_COLONIAL_MAINTENANCE` | 0.5 | |

No define mentions "naval invasion size", "overseas participation of armies" or "HQ"; the AI's naval-invasion stack is whatever army the objective picks (code-side). AI personalities (`ai_personalities/00_ai_personalities.txt`) only use AI modifiers (`aggressiveness_modifier`, `carefulness_modifier`, `ai_months_between_wars`, `bias_for_colonialist_policies = 15` for `ai_expansionist`, l.59); the full AI-modifier list is in `modifier_type_definitions/00_modifier_types.txt` (all with `ai=yes`; line numbers are those of the `ai=yes` flag: `win_war_chance_threshold` 7261, `aggressiveness_modifier` 13438, `carefulness_modifier` 13462, `subjugation_preference_modifier` 13469, `expected_warscore_modifier` 13504, `mercenary_units_preference_modifier` 13326, `ai_amount_of_parallel_charters` 13454, …). None controls stack concentration or overseas behaviour directly.

Observed AI commands (`Documents/…/logs/ai.log`, 23 448 "[AI Warning] AI tried to execute invalid command" lines): `merge_army`, `toggle_can_attach_to`, `transfer_occupation`, `set_cabinet_action`, `build_road`, `perform_generic_action` — evidence the AI issues merge/attach commands (useful when reading logs after the mod).

---

## 4. Supply, attrition, logistics relevant to overseas armies (VERIFIED keys)

`game/main_menu/common/modifier_type_definitions/00_modifier_types.txt` (category in brackets):

- `army_logistics_distance` (68, unit), `army_logistics_distance_modifier` (74, unit, %) — "how far an army can trace for a food source" (`modifier_types_l_english.yml:81`); vanilla values +0.1…+0.5 (`advances/4_choices_mil.txt:420`, `societal_values/00_default.txt:260`).
- `land_unit_attrition` (4665, unit, %, bad), `naval_unit_attrition` (4673).
- `supply_limit` (5702, location), `local_supply_limit_modifier` (5708), `global_supply_limit_modifier` (5715, country).
- `max_attrition` (5695, location), `local_army_attrition` (5656), `local_hostile_attrition` (5671), `global_hostile_attrition` (5679, country), `hostile_food_multiplier` (5641, location).
- `local_food_capacity`/`global_food_capacity` (5587/5593), `local_monthly_food` (5613), `global_monthly_food_modifier` (5634), `food_consumption_modifier` (6158), `supply_depot_capacity` (6249), `create_supply_depot_cost_modifier` (2724).
- `naval_range` (6790), `colonial_range` (6804), `colonial_range_modifier` (6811) — "simply how far away we can colonize" (`game_concepts_l_english.yml:1526`); `within_colonial_range_of = <country>` is an area/location trigger (`conquistadors.txt:55`, `treaty_of_tordesillas.txt:56`).
- Sea-landing: `army_disembark_speed` (4712), `hostile_disembark_time_modifier` (7053), `friendly_disembark_time_modifier` (7060); `sea_cost_on_distance_from_capital` (5288) etc. are control/propagation costs, not military.
- Combat/siege (unit category): `siege_ability` (5985), `assault_ability` (5992), `discipline` (6014), `land_morale_modifier` (4537). Country modifier blocks accept unit-type modifiers — `discipline = 0.10` and `land_morale_modifier = 0.15` inside a reform `country_modifier` (§2.6).

Base location values: `static_modifiers/location.txt:4-30` `location_base_values { … max_attrition = 10  supply_limit = 15  hostile_disembark_time_modifier = 0.25 … }`; `mll_expansion_of_coastal_fortifications` (l.2363-2371) `hostile_disembark_time_modifier = 3.0, hostile_fleet_attrition = 1`.

Defines: `ATTRITION_DAYS_AT_SEA 0.02` (425), `OUTSIDE_OF_NAVAL_RANGE_ATTRITION 0.5` (427), `NAVAL_ATTRITION_CHANCE 0.1` (419), `FROZEN_ATTRITION 0.5` (428), `SEA_LANDING_DICE -1` / `STRAIT_CROSSING_DICE -2` / `RIVER_CROSSING_DICE -1` (467-469), `EMBARK_DISEMBARK_MULTIPLIER 0.4` (367), `DISEMBARK_COST_MULTIPLIER 0.5` (438), `FORCE_TRANSPORT_LAND_COST_FACTOR 100` / `AUTO_TRANSPORT_SUGGEST_COST_RATIO 2.5` (368-369), `ATTRITION_ON_FOOD_CONSUMPTION_IMPACT 2.0` / `MAX_FOOD_CONSUMPTION_PENALTY 3.0` / `MONTHS_OF_FOOD_FOR_DETACHED_SUPPORT 6` (382-384), `FOOD_PERCENTAGE_LOST_AT_OCCUPATION 0.9` (471).

Unit-type keys usable on the HQ regiment (`unit_types/readme.txt:30-47`): `supply_weight`, `attrition_loss`, `food_storage_per_strength`, `food_consumption_per_strength`, `movement_speed`, `max_strength`, `combat_power`, `frontage`; plus `levy`, `buildable`, `is_special`, `category`, `country_potential`, `location_potential`, `limit = { <value> }` (l.6-21).

---

## 5. How vanilla makes colonisers strong and natives weak (concrete modifiers)

### 5.1 Institutions gate whole advance trees (VERIFIED) — the big one

Root advances of each age have `depth = 0` and `allow = { has_embraced_institution = institution:<x> }`; everything downstream `requires` them, and units are unlocked by advances:

```
game/in_game/common/advances/0_age_of_discovery.txt
18: new_world_advance = {
19: 	age = age_3_discovery
22: 	depth = 0
24: 	allow = { has_embraced_institution = institution:new_world }
26: 	exploration_preparation_time_modifier = -0.05
27: 	colonial_range = 600
28: 	diplomatic_range_modifier = 0.10
...
431: pike_and_shot_advance = {
432: 	age = age_3_discovery
435: 	land_morale = 0.25
436: 	depth = 0
439: 	allow = { has_embraced_institution = institution:pike_and_shot }
```

```
game/in_game/common/advances/2_army_unlocks.txt
90: unlock_early_arquebusiers_advance = {
91: 	age = age_3_discovery
92: 	unlock_unit = a_early_arquebusiers
94: 	requires = matchlock_gun
...
107: unlock_arquebusiers_advance = {
108: 	age = age_4_reformation
109: 	unlock_unit = a_arquebusiers
111: 	requires = flintlock_gun
```

Institutions per age (`common/institution/`): age 2 `banking, professional_armies`; age 3 `new_world, printing_press, pike_and_shot`; age 4 `global_trade, artillery_institution`; age 5 `scientific_revolution, military_revolution`; age 6 `industrialization, levee_en_masse`. `new_world` spawns in Seville / a `new_world_plausible_location` (western_europe or north_africa port with burghers, `institution_triggers.txt:60-75`) and spreads by coast/trade. Natives in America/Africa lag institutions by decades → no gunpowder units, no pike-and-shot morale, no artillery. (`static_modifiers/institutions.txt:43-48`: embracing `new_world` only adds `local_sailors_modifier = 0.5` locally.)

### 5.2 Native unit lines and the buildings/religions that enable them (VERIFIED)

- `unit_types/a_north_american.txt:1-21` `a_war_party` (light infantry, `upgrades_to = a_early_arquebusiers`), `a_lodge_warriors`; `location_potential = { modifier:local_may_build_north_american_units = yes }`, `country_potential` tribe + capital on `continent:america` (quoted §1.2). The location modifier comes from the warrior-lodge building (`building_types/unique_buildings.txt:1236-1253`: `local_manpower = 0.009, can_recruit_regiment_in_this_location = yes`, raw `local_may_build_north_american_units = yes`).
- `unit_types/a_nahuatl.txt:1-20` `a_jaguar_warrior` (`strength_damage_taken -0.1, morale_damage_done 0.1`), `a_eagle_warrior`; enabled by `global_may_build_nahuatl_units = yes` from the Tonal religion (`religions/tonal.txt:9`).
- Tribal levies: `unit_types/0_tribal.txt:1-25` `a_moa_hunters`/`a_tribesmen` (`levy = yes, buildable = no`, `location_potential` owner `government_type:tribe`); `levies/06_tribal_levies.txt:8-15` `levy_tribal_camelry { allowed_pop_type = tribesmen … }`.
- Conquistador units (§2.6) are the European counterpart.

### 5.3 Tribe government and tribal cohesion (VERIFIED)

```
game/in_game/common/government_types/00_default.txt
130: tribe = {
141: 	government_power = tribal_cohesion
...
153: 		court_language_is_common_language_importance_modifier = 30
154: 		rural_settlement_downgrade_cost_modifier = -0.5
155: 		global_nobles_food_consumption = -0.25
156: 		diplomatic_upkeep_efficiency = 1.5
```

```
game/in_game/common/auto_modifiers/country.txt
648: high_tribal_cohesion = {
649: 	potential_trigger = {
650: 		uses_government_power = tribal_cohesion
651: 	}
652: 	scales_with = {
653: 		value = tribal_cohesion
654: 		multiply = 0.01
655: 	}
657: 	global_levy_size_modifier = 0.25
658: 	pop_leave_rebels_threshold = -0.05
```

(`low_tribal_cohesion` l.660-670: `global_estate_target_satisfaction` penalty.) Tribes have no inherent combat malus; their weakness is structural (levies of tribesmen, no institutions, few forts: `num_locations_impact` l.331-338 gives `fort_limit = 1` per 10 locations). Steppe hordes get `global_war_score_efficiency = 0.25` (l.122) — a precedent for a government-type warfare modifier. `country_ranks/00_default.txt` has no tribal/settled distinction.

### 5.4 Culture tag for natives (VERIFIED)

```
game/in_game/common/cultures/eastcoast.txt
1: penobscot_culture = { 
6: 	tags = { iroquois_gfx native_american_tag north_american_gfx american_gfx eastern_woodlands_coa_gfx }
```

`scripted_triggers/culture_triggers.txt:13-18` `is_culture_native_american = { custom_tooltip = { … has_culture_with_tag = native_american_tag } }` (culture scope). `native_american_tag` appears in 19 culture files (alaska, argentinian, aridoamerican, brasilian, canadian, caribbean, central_america, central_north_american, eastcoast, great_bassin, …). Sub-Saharan cultures have no equivalent "native" tag found; use `capital.sub_continent` / `continent:africa` + `government_type:tribe` instead.

### 5.5 Game rules and defines about colonisation (VERIFIED)

```
game/main_menu/common/game_rules/00_game_rules.txt
186: ai_colonisation_rule = {
187: 	default = western_colonisation_only
189: 	all_countries_colonize = {
190: 		flag = flavour_rule
193: 	western_colonisation_only = {
194: 		flag = flavour_rule
...
198: ai_exploration_rule = {
199: 	default = western_exploration_only
```

Loc (`game_rules_l_english.yml:67`): "Only [countries|e] with a [capital|e] in [ShowContinentName('europe')] will [colonize|e]." The exploration gate is scripted (`exploration_triggers.txt:1-28`: `has_game_rule = all_countries_explore` or `western_exploration_only` → `capital.continent = continent:europe` or overlord's capital in Europe, not PAP, not `has_preference_tag = "land"`); the colonisation gate is code-side via `AI_WESTERN_COLONIZATION_CONTINENTS = { "europe" }` (defines 645). There is **no vanilla game rule that handicaps or boosts natives**; `institution_spawn_rule` (l.282) decides where institutions appear.

### 5.6 Ages and expected army size (VERIFIED)

`common/age/00_default.txt`: ages start 1337 / 1342 / 1437 / 1537 / 1637 / 1737 (l.2, 54, 114, 175, 242, 322); `expected_army_size_modifier` 1.0 / 2.0 / 4.0 / 8.0 / 16.0 for ages 2-6 (l.68, 129, 190, 258, 337); age 3 `unique = { exploration_mission_speed = 0.25  colonial_maintenance_efficiency = 0.50 }` (l.124-127). `army_size_percentage` is a country trigger/value (`auto_modifiers/country.txt:1113`, `missions/generic_conquer_province_mission_pack.txt:153`).

### 5.7 Summary table

| side | vanilla lever | file |
|---|---|---|
| Colonisers (+) | conquistador army-country: +10 % discipline, +15 % morale, +25 % dmg vs heathens, 6×1-1.5k veterans, auto-conquer | §2.6 |
| Colonisers (+) | institutions → advance trees → gunpowder/pike units, `land_morale +0.25` root advance | §5.1 |
| Colonisers (+) | colonial nations: free extra AI countries that auto-join wars, +10 % levy size advance, +10 % morale advance | §2.1 |
| Colonisers (+) | overlord may recruit regiments in colonial land | §2.3 |
| Colonisers (−) | AI distance/naval penalties, ¼ participation overseas, transport-strength thresholds | §3 |
| Natives (−) | no institutions for decades; tribesmen levies; `fort_limit` by location count; conquistador targeting `potential_army_size < 18` | §5.1-5.3, §2.6 |
| Natives (+) | war-party/jaguar lines (terrain bonuses), `high_tribal_cohesion` +25 % levy size, `is_culture_native_american` only used for flavour | §5.2-5.4 |

---

## 6. Risks: does the HQ mechanic break AI colonisers? Mitigations

Facts that drive the analysis: (a) the European AI owns little overseas land itself (§2.2); (b) its wars in America are fought by colonial nations, conquistador army-countries and natives; (c) the AI's own armies cross the ocean only via naval invasions/transports, and the AI sizes stacks to supply limits (base 15) and carpet-sieges with up to 10 fragments (§3); (d) the finest scripted hook for armies is the monthly country pulse (`on_action/country_monthly.txt:2 monthly_country_pulse`); no disembark/landing on_action exists (full list of hard-coded on_actions checked in `on_action/_hardcoded.txt` — only `on_siege_won` l.321, `on_location_occupied` l.494, `on_battle_won` 3209, `on_great_battle_won` 2983, `on_location_changed_owner` 4859 are military).

| # | risk | severity | mitigation |
|---|---|---|---|
| R1 | AI naval-invasion landing force has no HQ → `siege_ability −90 %` → cannot take the port/forts → invasion stalls, war exhaustion, AI "never wins overseas" | high | **Expeditionary free slot:** any country from age 3 gets 1 colonial-HQ slot per overseas continent where it has an army (≥ `cw_min_subunits_for_ai_hq` sub-units) even with 0 owned locations; monthly `cw_ai_assign_hqs` adds the HQ to the largest overseas army. Worst case the landing is HQ-less for < 30 days. |
| R2 | Conquistador countries (`country_type = army`, `blocked_from_peace`) and other pseudo-countries get `cw_no_hq` and can never siege | high | exempt everything with `is_real_country = no` (VERIFIED trigger) / `country_type = army`; optionally give conquistador countries a free HQ in `on_subject_created` (hard-coded on_action list contains `on_subject_created`, `on_new_country_formed`, `on_released_country`). |
| R3 | Colonial nations are tiny (few locations) → HQ limit formula must still give ≥1 | medium | keep `cw_hq_limit = 1 + …` (SPEC §3) — 1 HQ always. Verify `num_locations` is a plain country trigger: `num_locations > 0` (`advances/country_ayu.txt:82`). |
| R4 | AI splits stacks at 130 % of supply target and carpet-sieges with ≤10 fragments; only one fragment carries the HQ → fragments occupy rural land at −90 % | medium (intended for concentration, but may stall occupation-based wars vs fort-less natives) | (i) test whether `siege_ability` affects *occupation* of unfortified locations at all (UNVERIFIED; engine distinguishes unfortified sieges, defines 2676); (ii) use a milder penalty tier for locations without a fort or make the warscore rework carry the weight (rural ≈ 0 warscore) so slow rural occupation is harmless; (iii) monthly re-assignment keeps the HQ in the *largest* fragment. |
| R5 | HQ regiment consumes transport capacity / supply weight | low | set `supply_weight` low on the HQ unit type (key VERIFIED in readme); check transport slot usage in game (UNVERIFIED whether capacity counts regiments or strength). |
| R6 | Colonial HQ "buffs" make the colonial HQ better than the home HQ at home | design | buffs only while `unit_location = { would_be_overseas_for = <owner> }`; at home it is a plain HQ (SPEC §15). |
| R7 | AI colonial nations and natives fight each other with equal rules; natives have 1 HQ (small) and no transport need → natives relatively **stronger** than vanilla if the European landing force is handicapped | medium | R1 + keep conquistador exemption; do not add any native buff; optional mild native HQ-limit handicap (§8). |
| R8 | Monthly HQ auto-assignment picks an army that is in combat / retreating / exiled / mercenary-only | low | eligibility: `is_exiled = no`, `in_combat = no`, `in_retreat = no`, `has_regulars = yes` (all VERIFIED trigger names). |
| R9 | HQ destroyed in a lost battle overseas; no replacement source overseas | low | overlord may recruit regiments in its colonial nations (§2.3) → recruiting the HQ overseas works if `can_recruit_regiment_in_this_location` holds; AI re-creation via script each month (SPEC §15). |
| R10 | `PARTICIPATION_SCORE_OVERSEAS_MULT 0.25` + distance penalties already keep allies home; our AI-concentration defines must not add further overseas penalties | low | do not touch `AI_CONQUER_DESIRE_NAVAL_DISTANCE_MULTIPLIER`; if anything, relax it slightly (−0.5 → −0.4) if testing shows fewer naval wars. |

Exemptions for colonial subjects' siege penalty: **not recommended** as a blanket rule — colonial nations are full countries and get their own HQ for free; a blanket exemption would make colonial-nation armies the best siege troops in the world. Exempt only pseudo-countries (R2).

---

## 7. Proposed rule set for colonial HQs (`cw_hq_colonial`)

Numbers marked ⚙ are tunable; the historical grounding is in §9.

1. **Availability:** `country_potential = { current_age_or_later = { age = age_3_discovery } }` (syntax VERIFIED, `events/colonization/conquistador.txt:64`). Colonial HQs exist for every real country, not only Europeans (an Inca/Mali player with overseas holdings qualifies).
2. **Theatre definition:** a "theatre" = one of the 5 land continents (`europe asia africa america oceania`) that is *not* the capital's continent **and** on which at least one owned location `would_be_overseas_for = root` (so a Spanish Oran/Ceuta on `continent:africa` that borders by sea does not create a theatre, matching the game's own concept). Keep `continent != capital.continent` as a fallback switch if `would_be_overseas_for` turns out too narrow (UNVERIFIED adjacency).
3. **Slots per theatre:** base 1 if (≥ 5 ⚙ owned locations there) **or** (an army with ≥ 3 ⚙ sub-units stands there — the expeditionary rule, R1); +1 if ≥ 25 ⚙ owned locations and age ≥ 4; +1 if ≥ 60 ⚙ owned locations and age ≥ 5. Global cap 4 ⚙. America counts as one theatre (one continent) — this is intended: Spain had one viceregal army per hemisphere until the Bourbon reforms.
4. **Effects:** a colonial HQ removes `cw_no_hq` anywhere (same as a home HQ). While the army is overseas (`unit_location = { would_be_overseas_for = scope:owner }`) it also gets `cw_expeditionary` (unit modifier, small): `land_unit_attrition = -0.15`, `army_logistics_distance_modifier = 0.10`, `land_morale_modifier = 0.05` (all three keys VERIFIED as unit-category or used in unit static modifiers; `land_morale_modifier` in `static_modifiers/unit.txt:60-65 incorrect_orders`). No buffs at home. No buff for HQs in general (only penalties for lacking one — user requirement).
5. **AI assignment (monthly, in `monthly_country_pulse`):** for each theatre with a free slot and no HQ army present, add `cw_hq_colonial` to the largest eligible army there. Sketch (VERIFIED building blocks; composition INFERRED):

```
cw_ai_assign_colonial_hqs = {            # country scope, after cw_cache_limits
    save_scope_as = cw_owner
    if = {
        limit = {
            cw_colonial_hq_free_slots > 0
            any_army = { cw_eligible_for_colonial_hq = yes }
            NOT = { any_army = { cw_has_any_hq = yes  unit_location = { continent = continent:america } } }
        }
        ordered_army = {
            limit = { cw_eligible_for_colonial_hq = yes  unit_location = { continent = continent:america } }
            order_by = num_subunits
            max = 1
            check_range_bounds = no
            unit_location = { create_sub_unit_with_owner = { type = cw_hq_colonial  owner = scope:cw_owner  origin = this } }
        }
    }
    # repeat per continent key: asia africa europe oceania (skip the capital's continent)
}
cw_eligible_for_colonial_hq = {          # unit scope
    is_army = yes   is_exiled = no   in_combat = no   has_regulars = yes
    num_subunits >= 3
    NOT = { any_sub_unit = { OR = { sub_unit_type = unit_type:cw_hq  sub_unit_type = unit_type:cw_hq_colonial } } }
    unit_location = { would_be_overseas_for = scope:cw_owner }
}
```

`ordered_army … order_by = num_subunits … check_range_bounds = no` is verbatim vanilla (`parliament.txt:1262-1268`); `create_sub_unit_with_owner { type owner origin experience }` is verbatim (`conquistador.txt:68-73`, Cheat Menu Pro `sakuya_army_generator_effects.txt:35-39`). **UNVERIFIED:** whether a sub-unit created in the army's location auto-merges into that army (vanilla spawns a *new* unit; a merge effect was not found — `add_subunit` from SPEC is not in vanilla; grep found only `destroy_subunit`, `set_unit_size`, `create_sub_unit`, `create_sub_unit_of_category`, `create_sub_unit_with_owner`). If no merge effect exists, the AI's own `merge_units_priority = 10` (§2.5) should merge the 100-man unit within days — test it; the player gets a button.
6. **Counting owned locations per continent (INFERRED from VERIFIED parts):** `any_owned_location = { count >= 5  continent = continent:america }` (`count >= 3` inside `any_owned_location`: `decisions/flavor_decisions_rus.txt:512-515`; `count = all` and `count > 10` inside `any_sub_unit`: `lend_unit_to_ally.txt:100-103`, `flavor_decisions_rus.txt:1472-1475`).
7. **Counting HQs:** `any_country_sub_unit = { count >= N  sub_unit_type = unit_type:cw_hq_colonial }` (INFERRED) for threshold checks; for an exact number use `every_country_sub_unit = { limit = { sub_unit_type = … } change_variable = … }` (while/`change_variable` counter pattern verbatim in Cheat Menu Pro `sakuya_army_generator_effects.txt:3-20`).
8. **"Professionals only" overseas (user idea):** do not hard-restrict (vanilla early armies are levy-heavy and colonial nations rely on levies); instead require `has_regulars = yes` for HQ eligibility and let `cw_expeditionary` apply only if `NOT = { any_sub_unit = { is_levy = yes } }` (both triggers VERIFIED by name; `is_levy` used in `lend_unit_to_ally.txt:98`). This naturally kicks in late-game when regulars dominate — matches the brief ("professionals appear late in the Age of Discovery").
9. **Small countries:** with 0 overseas theatres the colonial limit is 0 → only the single home HQ (brief: small countries have one army). Colonial powers (Castile/Portugal/England/France/Netherlands, and Oman/Majapahit-style Asian maritime powers) get +1-4.

---

## 8. Optional mild, removable native disadvantage

Vanilla already handicaps American/sub-Saharan countries structurally (§5); any extra malus must be small and self-removing. Two implementations, both using only VERIFIED keys:

**A (recommended, HQ-flavoured): "no staff tradition".** While active, `cw_age_hq_slots = 0` (home limit stays 1 — one army, like a vanilla "one war host"), and no colonial slots. Auto-modifier (country) with `hide_effects = no`, shown as an alert:

```
cw_isolated_tradition = {                       # in_game/common/auto_modifiers/cw_auto_modifiers.txt
    potential_trigger = {
        is_real_country = yes
        is_ai = yes                               # OR has_game_rule = cw_native_penalty_all (player opt-in)
        capital ?= { continent = continent:america }      # add continent:africa sub-Saharan via sub_continent if desired
        government_type = government_type:tribe
        NOT = { has_embraced_institution = institution:pike_and_shot }
        NOT = { has_variable = cw_reformed_host }
    }
    discipline = -0.05        # optional: country_modifier blocks accept discipline (conquistador_country reform l.573)
}
```

(`auto_modifiers/readme.txt:5-17` documents `potential_trigger`, `scales_with`, `limit`, `hide_effects`, `alert`, `requires_real`; `has_embraced_institution = institution:x` VERIFIED `0_age_of_discovery.txt:24`; `government_type = government_type:tribe` VERIFIED `0_tribal.txt:16`.) Removal: automatic once `pike_and_shot` is embraced (vanilla path, AI included), or via decision `cw_reform_war_host` (`in_game/common/decisions/`) with `allow = { OR = { current_age_or_later = { age = age_4_reformation }  has_embraced_institution = institution:new_world  any_subject … } }` setting `cw_reformed_host`; `ai_will_do` moderate so some AI natives (Aztec/Inca-tier, `army_size_percentage > 0.75`) reform. The user brief says the removal should be player-only because the AI "will be dumb"; making the AI removal conditional (age ≥ 4 or institution) rather than impossible keeps late-game Americas alive.

**B (modifier-based):** same trigger, `discipline = -0.05, siege_ability = -0.10` (country-modifier `siege_ability` INFERRED, discipline VERIFIED in a country modifier). Not both A and B.

Game rule `cw_rule_native_penalty` (`on`/`off`, default **off** is safer given §5; the brief wants it on-but-mild — use `mild` as default with A only). Check that `has_game_rule = <setting>` is a country trigger (VERIFIED `exploration_triggers.txt:8-11`).

---

## 9. Historical summary — regulars Europeans kept overseas, 1500-1800

(Secondary web sources; numbers vary between sources, treat as orders of magnitude. 1 EU5 regiment ≈ 1 000 men, `conquistador.txt:85`.)

- **Spanish America.** 16th-17th c.: conquest was done by small private hosts (Cortés ~500-600 men, Pizarro ~170 — general knowledge, not from the searched sources); afterwards the interior of New Spain had "only a couple of regular companies", defence rested on fortified ports with garrisons; Havana was the largest garrison on the Spanish Main with "over 600 regular soldiers" plus militia (undated), Cartagena's 18th-c. garrison was ~150-200 men ([Military of New Spain](https://en.wikipedia.org/wiki/Military_of_New_Spain), [Treasure ports of the Spanish Main](https://brewminate.com/treasure-ports-of-the-spanish-main-in-the-early-modern-world), [historylab.es](https://historylab.es/?p=4320)). Bourbon reforms: a 1771 report counts **42 995 soldiers of all categories** across Spanish America (Cuba 4 851, Puerto Rico 2 884, Buenos Aires 4 628); late-18th-c. New Spain ~9 971 regulars (4 infantry + 2 dragoon regiments), Peru 1 985, Chile 1 249; Peru's 50 000 "reserve" militia rarely in uniform ([Spain's American Empire](https://bigboardgaming.com/spains-american-empire/)). → 1-2 small field forces per theatre until c. 1760, then 3-5 regiment-scale armies in the 1770s-90s.
- **Portuguese Estado da Índia / Brazil.** Goa 1510: 1 200 Portuguese soldiers in the conquest force; in the War of the League of the Indies (1570-75) **no more than ~650 soldiers** defended Goa, reinforced by casados, 1 500 Christian lascarins and 1 000 armed slaves ([Army of Portuguese India](https://en.wikipedia.org/wiki/Army_of_Portuguese_India), [War of the League of the Indies](https://kaweah.freedombox.rocks/kiwix/wikipedia_en_all_maxi_2023-10/War_of_the_League_of_the_Indies), [More soldiers and less priests, 1629-36](https://revistas.unisinos.br/index.php/historia/article/view/htu.2012.163.08)). Brazil 17th c.: no reliable figure found. → ≤1 regiment of regulars per theatre.
- **British North America / EIC.** 1759: **23 regular battalions** in continental North America (vs 6 in Germany); 1763: 17 of 75 regiments stationed in North America; 1775: ~7 000 regulars in North America incl. Canada; EIC 1748: ~13 000 Europeans (civil + military) and 33 000 Indian troops ([Dictionary of Canadian Biography essay](https://www.biographi.ca/en/theme_essais.html?p=24), [Britannica — New colonial policy](https://britannica.com/topic/American-colonies/New-colonial-policy), [encyclopedia.com — British Army in North America](https://encyclopedia.com/history/encyclopedias-almanacs-transcripts-and-maps/british-army-north-america), [weaponsandwarfare](https://weaponsandwarfare.com/?p=17372)). → wartime peak 2-3 field armies, peacetime ≈ 1.
- **New France.** 1683: 3 companies (~130-156 men); 1689: 28 companies; 1750s: 30-40 companies in Canada (≤ 50 men each, ≈ 1 500-2 000) plus 24 companies at Louisbourg; metropolitan battalions only from 1755 ([Canadian Encyclopedia — Troupes de la Marine](https://thecanadianencyclopedia.ca/en/article/troupes-de-la-marine), [militaryheritage.com](https://mail.militaryheritage.com/c_franch.htm), [tfcg.ca](https://www.tfcg.ca/soldiers-new-france), [Parks Canada](https://pc.gc.ca/lhn-nhs/qc/fortchambly/culture/histoire-history/site/troupes-francaises-french-troups)). → 1 army-equivalent.
- **VOC.** c. 1613: ~500 men in all Asian forts; Coen asked 700 soldiers for Batavia (1614); 1684: 1 500 soldiers in Batavia (¼ fit); end of 17th c.: ~8 200-10 000 soldiers in Asia, dispersed over many garrisons ([amboyna.org](https://amboyna.org/node/3.html), [vocwarfare.net](https://vocwarfare.net/thesis/2/soldiers), [encyclopedia.com — Dutch United East India Company](https://www.encyclopedia.com/history/encyclopedias-almanacs-transcripts-and-maps/dutch-united-east-india-company), [Wars Overseas (Cambridge)](https://core-prod.cambridgecore.org/core/books/wars-overseas/voc-soldiers-and-seamen/7713397C1F5D6CE93850C4F676FED8BE)). → 1-2 field forces despite 10k men (garrison dispersion — exactly the "dispersal" problem the brief mentions).

**Mapping to HQ counts:** Age 3-4 (1437-1637): ≤ 1-2 regiments of regulars per theatre → **1 colonial HQ per overseas continent**. Age 5 (1637-1737): 2-10 regiments (VOC, New France, Spanish presidios) → **1-2**. Age 6 (1737-1837): 10-45 regiments (British 1759, Spanish 1771) → **2-4**. Total overseas regulars never exceeded ~15-20 % of the metropolitan army, which supports: (i) colonial HQs count separately and are capped (4), (ii) no buffs at home, (iii) big European wars still need the home HQs. Dispersion (VOC, Spanish presidios) was historically a *weakness* — the mod's "one HQ per theatre" rule models it: garrisons without the theatre HQ cannot siege, only hold.

---

## 10. Pitfalls

1. **Keys:** continents are `europe asia africa america oceania`; `western_europe`, `north_america`, `south_asia` … are `sub_continent:` keys. `continent:north_america` does not exist (icons do). Grep hits for `continent:X` are polluted by `sub_continent:X`.
2. **America is one continent** → "per continent" = one theatre for both Americas; use `sub_continent:north_america` / `south_america` if two theatres are wanted (the SPEC's "+1 for ≥25 locations in America" is the simpler alternative).
3. **`is_overseas_for_owner` is relative to the location's owner.** For armies use `would_be_overseas_for = <country>`; for enemy/unowned land `is_overseas_for_owner` answers the wrong question.
4. **"Overseas" ≠ "other continent"** (`game_concepts_l_english.yml:92`): sea-adjacent sub-continents are not overseas. Which ones is engine data — test (UNVERIFIED); provide a fallback trigger.
5. **Pseudo-countries:** conquistadors are `country_type = army` with `blocked_from_peace`; locations/pops/buildings/navies also exist as country types (`country_type = location/pop/building/army/navy`, 155/135/130/61/22 uses). Apply HQ logic only to `is_real_country = yes`.
6. **The AI's overseas land is in subjects**, so colonial-HQ demand for AI overlords is low; the critical path is naval invasions (R1) and colonial nations' own HQ (R3).
7. **No landing/disembark on_action**; monthly pulse is the finest hook — design for a ≤30-day HQ-less window (expeditionary free slot) rather than per-day correctness.
8. **AI stack sizing** is supply-driven (`AI_SUPPLY_LIMIT_TARGET 0.95`, base `supply_limit 15`): overseas (low-supply) armies will be small; set `cw_min_subunits_for_ai_hq` ≤ 3 there or the AI never qualifies.
9. **`siege_ability` vs occupation:** unverified whether −90 % also slows occupation of unfortified locations; if it does, fort-less native wars by HQ-less fragments stall — tie the harsh tier to `has_fort`-type checks or rely on the warscore rework.
10. **`add_subunit` (SPEC) is not a vanilla effect**; only `create_sub_unit*` effects exist (`effect_localization/location_effects.txt:300-340`) — spawning creates a *separate* unit; merging must be tested (AI `merge_units_priority`, player manual merge).
11. **Modifier categories:** `siege_ability`, `discipline`, `land_unit_attrition`, `army_logistics_distance*` are `category=unit`; they are nevertheless accepted inside country modifier blocks (reform `conquistador_country`). A unit static modifier needs `game_data = { category = unit }` (`static_modifiers/unit.txt:85-91`).
12. **`add_unit_modifier` syntax** (`parliament.txt:1268-1272`): `{ modifier = X  years = N | days = N  mode = replace | add_and_extend }`; `add_unit_modifier_forever` and `add_unit_modifier_duration` also exist (`effect_localization/unit_effects.txt:14-33`).
13. **Levy vs regulars:** a colonial-HQ unit must be `levy = no`; levies are chosen engine-side by combat power (`levies/readme.txt:13-25`), so never give the HQ a high `combat_power`.
14. **Transports:** `AI_TRANSPORT_STRENGTH_THRESHOLD_PER_DISTANCE` means weak transport fleets never sail far; an extra 100-man regiment is negligible, but confirm it does not need its own transport slot.
15. **Game-rule-driven modifiers:** vanilla game rules only set flags read by script (`has_game_rule = x`); they do not apply modifiers themselves — route rule choices through auto-modifiers/script values.
16. `error.log` currently has 0 "continent" errors — keep it that way; the validator cache (`tools/cache/vanilla_script_keys.txt`) contains every key used in this note (checked: `is_overseas_for_owner would_be_overseas_for unit_location num_subunits any_army every_army ordered_army any_country_sub_unit every_country_sub_unit every_sub_unit any_sub_unit sub_unit_type sub_unit_category is_army within_colonial_range_of num_locations has_unit_modifier add_unit_modifier remove_unit_modifier create_sub_unit_with_owner destroy_subunit set_country_military_stance is_colonial_subject is_subject_type continent sub_continent capital_in_old_world_trigger is_capital_mesoamerica is_culture_native_american has_culture_with_tag army_size_percentage regular_army_size potential_army_size current_age_or_later has_embraced_institution is_exiled is_lent_unit is_mercenary is_levy sub_unit_count country_type top_overlord_or_this has_discovered_area`).

---

## 11. Recommendations for the mod

1. Implement theatres with `would_be_overseas_for = scope:cw_owner` on `unit_location` / owned locations, iterating the five land continent keys explicitly; keep a `cw_overseas_mode` script switch (`overseas` vs `other_continent`) until adjacency is confirmed in game.
2. Adopt the **expeditionary free slot** (R1) — it is the single most important protection for AI naval invasions and costs nothing to a player.
3. Exempt `is_real_country = no` / `country_type = army` from `cw_no_hq` entirely; conquistador hosts stay vanilla-strong (they are the reason Spain beats the Aztecs in vanilla).
4. Keep colonial-nation and native HQ rules identical to everyone's (1 home HQ minimum); no blanket siege exemption for colonial subjects.
5. Colonial-HQ buffs: three small unit modifiers only while overseas (§7.4); never at home; no buffs for home HQs.
6. Slots: 1 per overseas continent (age ≥ 3), +1 at ≥25 locations (age ≥ 4), +1 at ≥60 (age ≥ 5), cap 4 — consistent with §9.
7. Native penalty: ship **variant A** (no extra HQ slots while a tribe without pike-and-shot, auto-removed by institution or age-4 decision; AI removal allowed under those conditions), default `mild`; do not add combat maluses on top of vanilla's institution gap.
8. Before balancing further, run three test games as observer (1444-ish start of age 3 → 1600): count AI naval invasions that end in a peace with territory, colonial-nation wars vs natives, and Spanish/Portuguese holdings in America vs vanilla; log via `cw_debug` events using `any_army = { unit_location = { would_be_overseas_for = … } }` counters.
9. Expose AI war stance text in the top-bar plate only when the player has intel, mirroring vanilla's `OBJECTIVES_SPY_NETWORK_REQUIRED` ("Build a [spy_network|e] above #G 25#! to reveal their strategic objectives.", `ai_personalities_l_english.yml:55`) — optional, but consistent with vanilla UX.
10. Do not change `AI_CONQUER_DESIRE_NAVAL_DISTANCE_MULTIPLIER`, `DISTANT_WAR_*` or `PARTICIPATION_SCORE_OVERSEAS_MULT` in v0.1; they already keep AI overseas wars rare, and the HQ system should not make them rarer. Revisit only with test data.

---

## Appendix A — Verified key index (this note)

Triggers (location): `continent`, `sub_continent`, `region`, `area`, `is_overseas_for_owner`, `would_be_overseas_for`, `within_colonial_range_of`, `is_coastal`, `is_port`, `has_owner`, `controller`. Triggers (country): `capital.continent`, `capital.sub_continent`, `capital_in_old_world_trigger`, `is_capital_mesoamerica`, `is_capital_in_south_america_or_carribean`, `is_real_country`, `country_type`, `is_colonial_subject`, `is_subject_type`, `is_subject_of`, `top_overlord_or_this`, `has_game_rule`, `has_embraced_institution`, `current_age_or_later = { age = … }`, `government_type`, `num_locations`, `army_size_percentage`, `regular_army_size`, `potential_army_size`, `has_discovered_area`, `has_preference_tag`, `uses_government_power`, `modifier:<key>`. Triggers (unit/sub-unit): `is_army`, `is_exiled`, `in_combat`, `in_retreat`, `in_siege`, `num_subunits`, `has_regulars`, `has_levies`, `has_unit_modifier`, `is_lent_unit`, `sub_unit_type`, `sub_unit_category`, `is_levy`, `is_mercenary`, `is_condottieri`. Scopes/iterators: `unit_location`, `owner`, `capital`, `overlord`, `every_army`, `any_army`, `ordered_army` (`order_by`, `max`, `check_range_bounds`), `random_army`, `any_sub_unit` (`count = all`), `every_sub_unit`, `any_country_sub_unit`, `every_country_sub_unit`, `any_owned_location` (`count >= N`), `any_subject`, `any_location_in_province_definition`, `ordered_location_in_area`. Effects: `create_sub_unit_with_owner { type owner origin experience }`, `create_sub_unit`, `create_sub_unit_of_category`, `destroy_subunit`, `add_unit_modifier { modifier years|days mode }`, `remove_unit_modifier`, `set_country_military_stance`, `create_army_country_in_location`, `add_country_modifier`, `set_variable/change_variable/remove_variable`, `save_scope_as`, `while = { count = N | limit = {…} }`. Modifiers: see §4 and §5; game concepts: `overseas`, `colonial_range`, `subject_military_stance`.

## Appendix B — Unverified / to test in game

1. Sub-continent ↔ continent sea adjacency used by the `overseas` concept (which Old-World sub-continents are *not* overseas for European capitals).
2. Whether `siege_ability` affects occupation of unfortified locations.
3. Whether a sub-unit created with `create_sub_unit_with_owner` in an army's location merges into it (and whether the AI merges it quickly).
4. Transport-capacity accounting for a 100-man regiment; effect of `supply_weight` on it.
5. `set_country_military_stance` on non-subject AI countries, and custom stance definitions in `subject_military_stances/`.
6. `siege_ability` inside a *country* modifier block (only `discipline`/`land_morale_modifier` seen there).
7. `Unit.GetLocation.GetContinent` GUI chain; `any_country_sub_unit = { count >= N … }`.
8. What the AI does with war-conquered overseas land (kept directly vs transferred).
