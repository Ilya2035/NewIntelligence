# 03 — Modifier types, static / unit modifiers, auto modifiers, game rules (EU5 1.4.7)

Research for the **Concentrated Warfare** mod (`cw_`). Game root: `C:\Program Files (x86)\Steam\steamapps\common\Europa Universalis V\` — all paths below are relative to that root unless stated. Line numbers are from the 1.4.7 files as installed on 2026‑11‑04.

Legend: **VERIFIED** = read in game/mod files (quoted); **INFERRED** = strongly implied by file evidence but not stated anywhere; **UNVERIFIED** = plausible, no file evidence; needs an in‑game test.

Tooling note: the game ships no `/docs` folder and no script‑docs logs (`logs/` holds only error/gui/ai/etc. logs, all clean of modifier errors), so everything here comes from `game/` files, DLC files and the two workshop mods.

---

## 0. Where things live (VERIFIED)

| Thing | Path |
|---|---|
| Modifier **type** definitions | `game/main_menu/common/modifier_type_definitions/00_modifier_types.txt` (19 515 lines, **2 658** types), `01_byz.txt` (29), `02_generic_bureaucracies.txt` (23); DLC adds `game/dlc/D009_across_the_pillars/main_menu/common/modifier_type_definitions/03_d009.txt` → extra files are simply merged, a mod can add its own file |
| Modifier type loc | `game/main_menu/localization/english/modifier_types_l_english.yml` — keys `MODIFIER_TYPE_NAME_<type>` / `MODIFIER_TYPE_DESC_<type>` |
| Modifier type icons | `game/main_menu/common/modifier_icons/00_modifier_icons.txt` (+ `01_byz.txt`, DLC `02_d009.txt`) → textures in `game/main_menu/gfx/interface/icons/modifier_types/<name>.dds` (1 455 files) |
| Static modifiers | `game/main_menu/common/static_modifiers/*.txt` (readme, unit, subunit, country, location, province, difficulty, movement, character, religion, estates, …) |
| Static modifier loc | `game/main_menu/localization/english/static_modifiers_l_english.yml` — keys `STATIC_MODIFIER_NAME_<key>` / `STATIC_MODIFIER_DESC_<key>` |
| Static modifier icons | `game/main_menu/gfx/interface/icons/modifiers/*.dds` (23 files, see §2.4) |
| Auto modifiers | `game/in_game/common/auto_modifiers/*.txt` (+ readme), loc `auto_modifiers_l_english.yml` (`AUTO_MODIFIER_NAME_<key>` / `AUTO_MODIFIER_DESC_<key>`) |
| Game rules | `game/main_menu/common/game_rules/_game_rules.info`, `00_game_rules.txt`; loc `game_rules_l_english.yml` |
| Defines | `game/loading_screen/common/defines/00_defines.txt` (+ `jomini/`, `graphic/` subfolders) |
| Script values usable as modifier values / durations | `game/main_menu/common/script_values/default_values.txt` |
| Mod layout examples | Simple Cheats (`workshop/content/3450310/3634102315`): `main_menu/common/static_modifiers/sc_modifiers.txt`; Cheat Menu Pro (`…/3600272327`): `main_menu/common/static_modifiers/sakuya_*.txt`, loc in `main_menu/localization/english/*_l_english.yml` |

`game/in_game/localization/` only contains `jomini/script_system` — **mod localization goes under `<mod>/main_menu/localization/<lang>/`** (VERIFIED by both workshop mods and vanilla).

---

## 1. Modifier type definitions

### 1.1 Format (VERIFIED)

`game/main_menu/common/modifier_type_definitions/00_modifier_types.txt:1-16`:

```
# Modifier types
# color = good(default)/neutral/bad
# boolean = no(default)/yes
# percent = no(default)/yes
# already_percent = no(default)/yes
# decimals = 2(default)/x (int)
# in game_data = {}
# 	category = all(default)/none/country/location/province/character/unit/mercenary/religion/internationalorganizatiuon/rebel/dynasty
#	min = -infinity(default)/x (fixed point)
#	max = +infinity(default)/x (fixed point)
#	cap_zero_to_one = no(default)/yes
#	scale_with_pop = no(default)/yes
# 	format = ""(default)/FormatPopCaps/FormatManPower/FormatGold
# 	ai = no(default)/yes
# 	bias_type = opinion/trust/voting (can have more than 1 entry - default=none of them)
# 	should_show_in_modifiers_tab = yes(default)/no (should modifier appear in the government modifiers tab)
```

Typical entries (`00_modifier_types.txt:5985-6019`):

```
siege_ability={
	percent=yes
	game_data={
		category=unit
	}
}

assault_ability={
	percent=yes
	game_data={
		category=unit
	}
}
…
discipline={
	percent=yes
	game_data={
		category=unit
	}
}
```

Category census of all 2 710 types (parsed from the three files): `country` 2049, `location` 428, `internationalorganization` 100, **`unit` 70**, `character` 47, explicit `all` 7, `movement` 4 (only in `01_byz.txt`, category **not** listed in the header comment), `religion` 3, `province` 1, `rebel` 1. `mercenary` and `dynasty` are documented categories but no type uses them. **48 types have `ai = yes`** — all are `category=country`.

Loc: `modifier_types_l_english.yml:502-505`:

```
 MODIFIER_TYPE_NAME_siege_ability: "Siege Ability"
 MODIFIER_TYPE_DESC_siege_ability: "This impacts how quickly that [armies|e] can [siege|e]."
 MODIFIER_TYPE_NAME_assault_ability: "Assault Ability"
 MODIFIER_TYPE_DESC_assault_ability: "This impacts how well an [army|e] can perform an [assault|e]."
```

28 vanilla types have no `MODIFIER_TYPE_NAME_` entry (e.g. `ambition_slots`, `monthly_towards_sinicized`, several `*_price_cost_modifier`) — the game tolerates it, but a new `cw_*` type without loc will show raw keys.

Icons for types (`game/main_menu/common/modifier_icons/00_modifier_icons.txt:1-11,20-22`):

```
#example = {
#	positive = "gfx/interface/icons/modifier_types/example_positive.dds" # Will be used if >= 0 or if `negative` isn't set
#	negative = "gfx/interface/icons/modifier_types/example_negative.dds" # Will be used if < 0 (optional)
#	default = yes # The first one in the file with this flag will be used as default
#}

default = {
	positive = "gfx/interface/icons/modifier_types/_default.dds"
	default = yes
}
…
fort_limit = {
	positive = "gfx/interface/icons/modifier_types/fort_limit.dds"
}
```

`siege_ability.dds`, `assault_ability.dds`, `discipline.dds`, `land_morale.dds`, `occupation_time.dds`, `max_siege_memory.dds`, `global_supply_limit_modifier.dds` all exist in `gfx/interface/icons/modifier_types/`. A new type without an entry falls back to `_default.dds` (VERIFIED by the `default = yes` mechanism). GUI reads it via `[ModifierType.GetIcon]`.

### 1.2 (a) Complete list of `category = unit` modifier types (70) — VERIFIED

Flags: `pct` = `percent=yes` (0.1 = +10 %), `bool` = `boolean=yes`, `color=` as defined. Name/description verbatim from `modifier_types_l_english.yml`. Line = `00_modifier_types.txt`.

| Type | Line | Flags | Name | Description |
|---|---|---|---|---|
| `army_logistics_distance` | 68 | flat | Logistics Distance | This impacts how far an [army] can trace for a [food_source]. |
| `army_logistics_distance_modifier` | 74 | pct | (= Logistics Distance) | (same) |
| `army_artillery_power` | 81 | pct | Artillery Power | This impacts the [combat] ability of Artillery [regiments]. |
| `army_auxiliary_power` | 88 | pct | Auxiliary Power | …of Auxiliary regiments. |
| `army_light_cavalry_power` | 95 | pct | Light Cavalry Power | …of Light Cavalry regiments. |
| `army_heavy_cavalry_power` | 102 | pct | Heavy Cavalry Power | …of Heavy Cavalry regiments. |
| `army_light_infantry_power` | 109 | pct | Light Infantry Power | …of Light Infantry regiments. |
| `army_heavy_infantry_power` | 116 | pct | Heavy Infantry Power | …of Heavy Infantry regiments. |
| `navy_galley_power` | 123 | pct | Galley Power | combat ability of galleys |
| `navy_heavy_ship_power` | 130 | pct | Heavy Ship Power | |
| `navy_light_ship_power` | 137 | pct | Light Ship Power | |
| `navy_transport_power` | 144 | pct | Transport Power | |
| `damage_done_versus_heathens_modifier` | 829 | pct | Damage Done versus Heathens in Battle | damage vs heathen hostile armies in battle |
| `damage_done_versus_heretics_modifier` | 836 | pct | Damage Done versus Heretics in Battle | |
| `own_coast_naval_combat_bonus` | 4062 | pct | Combat Outside Own Coasts | bonus/penalty to navies fighting in seazones adjacent to owned locations |
| `combined_arms_max_threshold` | 4476 | pct, good | Combined Arms Threshold | max % of a unit a category can be to give the combined‑arms bonus |
| `combined_arms_min_percent_for_bonus` | 4485 | pct, bad | Combined Arms Requirement | min % of a unit a category must be for the bonus |
| `combined_bonus_per_type` | 4492 | pct | Combined Arms Bonus | size of the combined‑arms bonus per valid category |
| `army_weight_modifier` | 4500 | pct, bad | Army Weight | unit weight of a regiment (affects attrition) |
| `navy_weight_modifier` | 4508 | pct, bad | Navy Weight | |
| `monthly_experience_gain` | 4516 | pct | Monthly Experience Gain | experience a regiment/ship gains each month |
| `experience_decay` | 4523 | pct, bad | Monthly Experience Decay | % of current experience lost each month |
| `land_morale` | 4531 | flat | Army Morale | modifies max morale of a regiment by a fixed amount |
| `land_morale_modifier` | 4537 | pct | Army Morale | modifies max morale of a regiment by a percentage |
| `naval_morale` | 4544 | flat | Navy Morale | |
| `naval_morale_modifier` | 4550 | pct | Navy Morale | |
| `force_army_maintenance` | 4564 | bool, bad | Army Maintenance Minimum 100% | army always at maximum spending |
| `army_maintenance_efficiency` | 4572 | pct, good | Army Maintenance Efficiency | gold and manpower to maintain a regiment |
| `navy_maintenance_efficiency` | 4580 | pct, good | Navy Maintenance Efficiency | |
| `army_reinforce_efficiency` | 4596 | pct, good | Army Reinforcement Efficiency | reduces gold/manpower cost of reinforcing |
| `navy_repair_efficiency` | 4604 | pct, good | Navy Repair Efficiency | |
| `land_morale_attrition_cost` | 4612 | pct, bad | Army Morale Attrition Cost | morale lost every day while taking attrition |
| `naval_morale_attrition_cost` | 4620 | pct, bad | Naval Morale Attrition Cost | |
| `land_morale_movement_cost` | 4628 | pct, bad | Army Morale Movement Cost | morale lost every hour while moving |
| `naval_morale_movement_cost` | 4636 | pct, bad | Naval Morale Movement Cost | |
| `morale_recovery_in_friendly` | 4644 | pct | Morale Recovery in Friendly Territory | |
| `land_morale_recovery` | 4651 | pct | Army Morale Recovery Speed | |
| `naval_morale_recovery` | 4658 | pct | Navy Morale Recovery Speed | |
| `land_unit_attrition` | 4665 | pct, bad | Army Attrition | attrition a regiment takes |
| `naval_unit_attrition` | 4673 | pct, bad | Navy Attrition | |
| `army_movement_speed` | 4705 | pct | Army Movement Speed | |
| `army_disembark_speed` | 4712 | pct | Army Disembark Speed | |
| `navy_movement_speed` | 4719 | pct | Navy Movement Speed | |
| `movement_speed_if_no_road` | 4726 | pct | Movement Speed without Road | |
| `regiment_reinforcement_speed` | 4761 | pct | Reinforcement Speed | how quickly a regiment reinforces |
| `ship_repair_at_sea` | 4775 | pct | Ship Repair Speed at Sea | |
| `ship_repair_at_sea_to_max_strength` | 4782 | pct | Maximum Ship Strength to Repair at Sea | |
| `global_maritime_presence_modifier` | 5252 | pct | Maritime Presence % | (oddly `unit` category) |
| **`siege_ability`** | 5985 | pct | Siege Ability | This impacts how quickly that [armies] can [siege]. |
| **`assault_ability`** | 5992 | pct | Assault Ability | This impacts how well an [army] can perform an [assault]. |
| `naval_damage_done` | 5999 | pct | Naval Damage Done | |
| `naval_damage_taken` | 6006 | pct, bad | Naval Damage Taken | |
| **`discipline`** | 6014 | pct | Discipline | This impacts the [discipline] of a [regiment]. |
| `military_tactics` | 6021 | flat | Military Tactics | This impacts the [military_tactics] of a [regiment]. |
| `commander_combat_bonus` | 6027 | flat | Commander Combat Bonus | A flat dice bonus applied to every combat phase this [commander] leads. |
| `blockade_efficiency` | 6046 | pct | Blockade Efficiency | |
| `move_to_assist_on_adjacent_combat` | 6115 | bool | Move to Assist on Adjacent Battle | unit auto‑moves to assist a battle in an adjacent location |
| `movement_speed_when_attached_to_another_unit` | 6122 | pct, bad | Movement Time when Attached to Another Unit | |
| `possible_frontage_modifier` | 6130 | pct | Possible Frontage | frontage a unit can use in battle |
| `army_initiative` | 6137 | pct | Army Initiative | |
| `navy_initiative` | 6144 | pct | Navy Initiative | |
| `combat_speed_modifier` | 6151 | pct | Combat Speed | |
| `food_consumption_modifier` | 6158 | pct, bad | Unit Food Consumption | |
| `levy_recovery_modifier` | 6882 | pct | Levy Recovery | |
| `levy_combat_efficiency_modifier` | 6890 | pct | Levy Combat Efficiency | |
| `anti_piracy_warfare_modifier` | 10045 | pct | Anti-Piracy Warfare Modifier | |
| `amount_looted_modifier` | 10052 | pct | Amount Looted | amount an army can loot |
| `correct_box_chance` | 10075 | pct | Correct Section Chance | chance a late unit joins its intended section |
| `army_food_gathering` | 14794 | flat | Army Food Gathering | food gathered per 1000 soldiers |
| `army_food_gathering_modifier` | 14800 | pct | Army Food Gathering Modifier | |

Notes: none of the 70 has `min`/`max`/`cap_zero_to_one`; `naval_damage_taken`, `experience_decay`, `*_attrition`, `*_cost`, `army_weight_modifier`, `force_army_maintenance` are `color=bad` (so a positive value is shown red). There is **no** unit‑category `occupation_*`, `war_score_*` or `supply_*` type — those are location/country (§1.4).

### 1.3 (b) Complete list of `ai = yes` modifier types (48) — VERIFIED

All 48 are `game_data = { category=country ai=yes }`; `pct` = `percent=yes`, `dec0` = `decimals=0`. Lines in `00_modifier_types.txt`. Descriptions verbatim from loc.

| Type | Line | Flags | Name | Description |
|---|---|---|---|---|
| `win_war_chance_threshold` | 7257 | pct | Win War Chance Threshold | Leaders will not attempt to start wars unless they think they have at least this percentage chance of winning. |
| `win_war_chance_lower_limit` | 7265 | pct | Win War Chance Lower Limit | The lowest chance of winning the leader can ever accept when attempting to start wars regardless of the threshold. |
| `unintegrated_land_expansion_penalty_modifier` | 7273 | pct | Unintegrated Land Expansion Penalty | Modifies the penalty on considering a new war from unintegrated owned land. |
| `war_declaration_stab_hit_tolerance` | 7282 | flat | War Declaration Stability Hit Tolerance | How much stability a leader is prepared to lose to start a war. |
| `war_declaration_war_exhaustion_tolerance` | 7289 | flat | War Declaration War-Exhaustion Tolerance | How much extra war exhaustion a leader tolerates when starting a war. |
| `coalition_strength_tolerance` | 12194 | flat | Coalition Strength Tolerance | How much extra strength in a potential coalition compared to their own a leader is prepared to tolerate when taking land in a war. |
| `peace_offer_fairness` | 12399 | flat | Peace Offer Fairness | Increases the importance of War Participation when giving treaties to allies in a war. |
| `peace_offer_negotiation_power` | 12406 | flat | Peace Offer Negotiation Power | Increases the War Score percentage received by a nation in a peace deal compared to other nations. |
| `language_change_threshold_modifier` | 12413 | flat | Language Change Threshold Modifier | (court/liturgical language candidate threshold) |
| `mercenary_units_preference_modifier` | 13323 | flat | Mercenary Units Preference Modifier | Modifies the preference of using mercenary units in wars opposed to levies and regulars. |
| `ai_months_between_wars` | 13425 | dec0 | Months Between Wars | How much time an AI country takes between its wars. |
| `aggressiveness_modifier` | 13433 | pct, bad | Aggressiveness | How likely an AI country is to attack other countries. |
| `ai_conquer_desire_religion_mult` | 13442 | pct | AI Conquer Desire Religious Antagonism | Scales how strongly the AI weighs heretic/heathen targets in conquest desire (0 = base). |
| `ai_amount_of_parallel_charters` | 13450 | dec0 | AI Maximum Parallel Colonial Charters | Hard cap on simultaneous colonial charters the AI pursues. |
| `carefulness_modifier` | 13458 | pct | Carefulness | How careful an AI country is, attacking only way weaker countries. |
| `subjugation_preference_modifier` | 13466 | flat | Subjugation Preference | Prefer diplomatic subjugation over war. |
| `dynastic_acquisition_preference_modifier` | 13473 | flat | Dynastic Acquisition Preference | Prefer marriages/PU inheritance over conquest. |
| `ai_force_annexation_modifier` | 13480 | flat | AI Force Annexation Modifier | Forces AI to annex subjects when possible. |
| `ai_stability_target_modifier` | 13487 | flat | AI Stability Target | Minimum stability target the AI will reach and keep. |
| `ai_government_power_target_modifier` | 13494 | flat | AI Government Power Target | Minimum government power target. |
| `expected_warscore_modifier` | 13501 | flat | Expected Warscore Modifier | This modifies how much we expect to get in a war. |
| `gold_importance_modifier` | 13516 | flat | Gold Importance Modifier | how much the AI values gold |
| `court_language_is_liturgical_language_importance_modifier` | 13523 | flat | Prefers Court Language to be Liturgical Language | |
| `court_language_is_common_language_importance_modifier` | 13530 | flat | Prefers Court Language to be Common Language | |
| `court_language_is_market_language_importance_modifier` | 13537 | flat | Prefers Court Language to be Market Language | |
| `stability_importance_modifier` | 13544 | flat | Stability Importance Modifier | |
| `manpower_importance_modifier` | 13551 | flat | Manpower Importance Modifier | |
| `control_importance_modifier` | 13558 | flat | Control Importance Modifier | |
| `diplomacy_importance_modifier` | 13565 | flat | Diplomacy Importance Modifier | |
| `religious_unity_importance_modifier` | 13572 | flat | Religious Unity Importance Modifier | |
| `defence_importance_modifier` | 13579 | flat | Defense Importance Modifier | This modifies how much the AI country values defense. |
| `institution_importance_modifier` | 13586 | flat | Institution Importance Modifier | |
| `trade_importance_modifier` | 13593 | flat | Trade Importance Modifier | |
| `societal_value_importance_modifier` | 13600 | flat | Societal Value Importance Modifier | |
| `bias_for_administrative_policies` | 16180 | flat | Bias for Administrative Policies | Will prefer policies which supplement the administrative nature of ruler/country. |
| `bias_for_balanced_policies` | 16187 | flat | Bias for Balanced Policies | |
| `bias_for_colonialist_policies` | 16194 | flat | Bias for Colonialist Policies | |
| `bias_for_diplomat_policies` | 16201 | flat | Bias for Diplomat Policies | |
| `bias_for_militarist_policies` | 16208 | flat | Bias for Militarist Policies | |
| `bias_for_capitalist_policies` | 16215 | flat | Bias for Capitalist Policies | |
| `bias_for_tolerant_policies` | 16222 | flat | Bias for Tolerant Policies | |
| `bias_for_spiritualist_policies` | 16229 | flat | Bias for Spiritualist Policies | |
| `bias_for_scholar_policies` | 16236 | flat | Bias for Scholar Policies | |
| `bias_for_isolationist_policies` | 16243 | flat | Bias for Isolationist Policies | |
| `bias_for_patron_of_arts_policies` | 16250 | flat | Bias for Patron of Arts Policies | |
| `reject_subjugation_reasons` | 16257 | neutral | Reject Subjugation Reasons | How much more difficult it becomes to diplomatically subjugate this country. |
| `revoke_privileges_importance_modifier` | 16323 | flat | Revoke Privileges Importance Modifier | |
| `revoke_privileges_stability_tolerance` | 16330 | flat | Revoke Privileges Stability Tolerance | |

Also AI‑relevant but **not** flagged `ai=yes`: `ai_require_cb_for_war` (line 18, bool, country: "determines if the AI countries will require a casus belli to start a war"), `ai_opinion_bias` (24, country). Vanilla usage of the AI set — `game/main_menu/common/static_modifiers/difficulty.txt:118-143`:

```
low_aggression = {
	game_data = {
		category = country
	}
	ai_require_cb_for_war = yes
	carefulness_modifier = 0.25
	ai_months_between_wars = 60
}
…
high_aggression = {
	…
	aggressiveness_modifier = 1.0
	ai_opinion_bias = -50
	ai_months_between_wars = 6
	carefulness_modifier = -0.25
```

Related defines (`00_defines.txt`, NAI): `EXPECTED_WAR_SCORE_BASE = 25` (l.1206, "How much warscore Ai expects to get in a war"), `MINIMUM_WAR_SCORE_TO_CONSIDER_DEFEAT = -50` (1211), `IDEAL_WARSCORE_DIFFERENCE_THRESHOLD_TO_CONSIDER_PEACE = 20` (1222), `CARPET_SIEGE_MAX_ARMIES = 10` (1021), `AI_CARPET_SIEGE_MAX_ARMIES_FACTOR = 0.1` (1593), `AI_STICK_TO_SIEGE_TIME_FACTOR = 0.003` (1134). (AI stance/army behaviour proper is another doc's topic.)

### 1.4 (c) Warscore‑relevant modifier types — VERIFIED

**Location category** (usable in `category = location` static modifiers, and in hardcoded location modifiers such as `capital` — see §2.3):

| Type | Line | Flags | Name | Description (loc) |
|---|---|---|---|---|
| `local_war_score_efficiency` | 6661 | pct | War Score Efficiency | This impacts how much [war_score] it will cost for this [location] to be taken in a [peace_treaty]. |
| `occupation_time` | 5963 | pct | Occupation Time | This impacts how quickly it takes to [siege] a [location] without [fortifications]. |
| `max_siege_memory` | 5970 | dec0 | Max Siege Progress | Max siege progress that can be accumulated against this location. |
| `local_defensive` | 5949 | pct | Fort Defense | This impacts how quick a [siege] will go against a [location]. |
| `supply_limit` | 5702 | flat | Supply Limit | supply limit of this location |
| `local_supply_limit_modifier` | 5708 | pct | Supply Limit | |
| `max_attrition` | 5695 | bad | Maximum Attrition | |
| `local_army_attrition` | 5656 | already_pct, bad | Army Attrition | |
| `local_hostile_attrition` | 5671 | already_pct, bad | Hostile Attrition | attrition of hostile armies in a location we own and control |
| `local_forced_attrition` | 5664 | bad | Unavoidable Attrition | |
| `hostile_food_multiplier` | 5641 | pct, already_pct | Total Food Multiplier | |
| `movement_cost` | 4681 | pct, bad | Movement Cost | how slow it is to move an army through this location |
| `hostile_movement_cost` | 4689 | pct, bad | Hostile Movement Cost | …for hostile armies |
| `friendly_movement_cost` | 4697 | pct, bad | Friendly Movement Cost | …for us and allies |
| `movement_blocked` | 5956 | bool | Movement Blocked | |
| `fort_level` / `minimum_fort_level` | 4733 / 4740 | dec0 | Fort Level / Minimum Fort Level | |
| `propagating_zone_of_control` | 4754 | bool | Allows Zone of Control | |
| `local_garrison_size` / `local_garrison_growth` | 5934 / 5920 | dec0 / pct | Garrison Size / Growth | |
| `local_frontage_allowed` | 6109 | flat | Possible Frontage | |
| `hostile_disembark_time_modifier` | 7053 | pct | Hostile Disembark Time Modifier | |
| `local_max_control`, `local_monthly_control`, `local_monthly_control_decline` | 5117 / 5159 / 5201 | pct | Max/Monthly Control | |
| `local_devastation_recovery` | 11196 | pct | Prosperity Recovery | |
| `blockade_force_required` | 6040 | flat | — | |
| `can_recruit_regiment_in_this_location` | 10875 | bool | — | |

**Country category** warscore / peace / war:

| Type | Line | Flags | Name | Description (loc) |
|---|---|---|---|---|
| `global_war_score_efficiency` | 6646 | pct | War Score Efficiency | This impacts how much [war_score] it will cost for this [country] to take territory. |
| `war_score_vs_other_religion_efficiency` | 6653 | pct, good | War Score vs other Religion Efficiency | |
| `lack_of_control_impact_on_warscore` | 5233 | pct | Control Impact on Warscore | This impacts the effect that low [control] has on [war_score]. |
| `global_defensive` | 5942 | pct | Fort Defense | how quick a siege goes against a country |
| `global_supply_limit_modifier` | 5715 | pct | Supply Limit | |
| `global_hostile_attrition` | 5679 | already_pct, bad | Hostile Attrition | |
| `ignore_zone_of_control` | 4747 | bool | Ignore Zone of Control | |
| `artillery_bonus_vs_fort` | 6166 | dec0 | Artillery Bonus vs Fort | |
| `max_war_exhaustion` / `monthly_war_exhaustion` | 4557 / 4841 | | | |
| `retreat_delay` | 5977 | dec0, bad | Retreat Delay | hours locked in combat before retreat |
| `expected_army_size` / `_modifier` | 6081 / 6089 | | Expected Army Size | what the estates expect |
| `army_losses_in_war_cost_modifier`, `enemy_army_losses_in_war_cost_modifier` | 805 / 813 | pct, bad | Cost of (Enemy) Army Losses in Battle | |
| `blocked_from_peace`, `allowed_enforce_peace` | 13932 / 13918 | bool | | |
| `fort_limit`, `fort_limit_modifier`, `fort_maintenance_efficiency` | 7437 / 7443 / 7450 | | | |

There is **no** `war_score_cost_modifier` type (the `global_war_score_cost.dds` icon is an orphan). Vanilla usages: `local_war_score_efficiency = -0.25` in `static_modifiers/location.txt:2175-2183` (`stronghold_city_modifier`), `-5` in DLC `d009_battle_for_the_strait_modifiers.txt:112`; `global_war_score_efficiency` −0.1/−0.05/+0.10/+0.15 in `static_modifiers/country.txt:2020,2547,12117,12235,12924`; `occupation_time = 0.0025` scaled by location size (`location.txt:306-314`, `location_size_impact`), `0.01` in the development‑scaled block (`location.txt:445`), `-0.5` in `rot_timur_scare` (`location.txt:2212-2222`, `decaying = yes`).

How per‑location warscore is composed (defines, `00_defines.txt` NWar 2665-2699) — this is what `local_war_score_efficiency` (INFERRED) multiplies:

```
NWar = {
	MAX_WAR_SCORE = 100
	OCCUPATION_VALUE_SCALE = 2.0		#at 1.0 you need 100% of the occupied land to get 100% warscore, higher requires less..
	…
	WAR_WORTH_BASE = 2
	WAR_WORTH_TAX_BASE_SCALE = 0.13
	WAR_WORTH_TAX_BASE_CAP = 6
	WAR_WORTH_BUILDING_SCALE = 0.025
	WAR_WORTH_BUILDING_CAP = 10
	WAR_WORTH_POPULATION_SCALE = 0.02
	WAR_WORTH_POPULATION_CAP = 4
	WAR_WORTH_COUNTRY_CAPITAL = 5
	WAR_WORTH_PROVINCE_CAPITAL = 1
	WAR_WORTH_PORT = 1
	WAR_WORTH_FORT_BASE = 0.5
	WAR_WORTH_FORT_LEVEL_SCALE = 0.25
```

`interfaces_l_english.yml:4768`: `LOCATION_WARSCORE_TT_TEXT: "The $game_concept_war_score$ of [Location.GetName] is [Location.GetWarWorth|W] due to:"` — i.e. "war worth" **is** the location's warscore value (VERIFIED), built from base + tax base + buildings + population + capital/port/fort bonuses (VERIFIED define names; exact formula INFERRED). Peace‑cost side: NDiplomacy `PEACE_COST_EFFICIENCY_UNOCCUPIED_FORT = -0.15`, `PEACE_COST_EFFICIENCY_FORT_NEVER_SIEGED = -0.18`, `PEACE_COST_SIZE_DISCOUNT_*` (2377-2388), `MONTHS_BEFORE_TOTAL_OCCUPATION = 60`, `WARSCORE_MAX_FROM_BATTLES = 50` (2427-2437).

---

## 2. Static modifiers

### 2.1 File format (VERIFIED) — `game/main_menu/common/static_modifiers/readme.txt:1-8`

```
#<static_modifier_key> = {
#	game_data = {
#		category = location/country/unit/character/religion/mercenary/province/internationalorganization/rebel/dynasty
#		decaying = <yes/no>	#default: no, the modifier gets weaker as time goes on
#		remove_if = <none/religion/culture>	#default: none, modifier gets automatically removed from the country if religion/culture changes
#	}
#	<modifiers>
#}
```

Vanilla also uses `category = movement` (`movement.txt:1-6`), not in the readme list. No `icon =` key exists in any static modifier file (grep over vanilla + DLC) → whether `icon` is accepted here is UNVERIFIED (it *is* documented for auto modifiers, §3).

### 2.2 Unit and sub‑unit static modifiers (VERIFIED) — `static_modifiers/unit.txt`

```
###################################
# Hardcoded
###################################
is_exiled = {
	game_data = {
		category = unit
	}
	land_morale_modifier = -0.75
}

army_leaderless = {
	game_data = {
		category = unit
	}
	land_morale_modifier = -0.20
}
```
(`unit.txt:1-16`; also `navy_leaderless` −0.20 naval morale, `in_combat` (experience_decay −0.05), `in_siege` (`unit.txt:32-38`: `experience_decay = -0.03`, `monthly_experience_gain = 0.10`), `is_blockading`.) Scripted ones (`unit.txt:50-99`):

```
###################################
# Scripted form Events
###################################
better_morale = {
	game_data = {
		category = unit
	}
	land_morale_modifier = 0.666
}
…
extensive_training_modifier = {
	game_data = { category = unit }

	discipline = 0.05
	experience_decay = -0.025
	monthly_experience_gain = 0.1
}
```

`subunit.txt:1-14` — modifiers applied **per regiment type class**, with an explicit engine note on what is read at sub‑unit level:

```
###################################
# Hardcoded
#  (only a few modifiers are applicable)
# _xx_power, discipline, naval_damage_done, own_coast..., expertise_gain, expertise_decay, army_weight
#  food_consumption_modifier is also read (per subunit) in CUnit::CalcSubUnitFoodConsumption
###################################
is_army_levy = {
	game_data = {
		category = unit
	}
	discipline = -0.20
	experience_decay = 0.02
	food_consumption_modifier = -0.75	# levies forage and travel light; …
}
```

Loc (`static_modifiers_l_english.yml:29-30, 574-579`):

```
 STATIC_MODIFIER_NAME_better_morale: "Better Morale"
 STATIC_MODIFIER_DESC_better_morale: "Sometimes you just fight better... And the reasons are a bit unknown."
…
 STATIC_MODIFIER_NAME_is_exiled: "Exiled"
 STATIC_MODIFIER_NAME_army_leaderless: "No Commander"
 STATIC_MODIFIER_NAME_navy_leaderless: "No Admiral"
 STATIC_MODIFIER_NAME_in_combat: "In Combat"
 STATIC_MODIFIER_NAME_in_siege: "In Siege"
```
`_DESC_` is optional (most hardcoded ones have none). Mod example of loc (Cheat Menu Pro `main_menu/localization/english/1.7/Cheat_menu_1.7_remaining_l_english.yml:47`): ` STATIC_MODIFIER_NAME_sakuya_1_7_monthly_political_influence_positive: "$sakuya_1_7_monthly_political_influence_positive$"`.

Applying / removing / testing unit modifiers (VERIFIED):

```
# game/in_game/common/generic_actions/parliament.txt:1262-1271  (scope: country)
ordered_army = {
	limit = { NOT = { has_unit_modifier = extensive_training_modifier} }
	order_by = num_subunits
	max = 1
	check_range_bounds = no
	save_scope_as = target_army
	add_unit_modifier = {
		modifier = extensive_training_modifier
		years = modifier_duration_years_short
		mode = replace
	}
}
```
```
# game/in_game/events/debug/000_johan_debug.txt:264-268
add_unit_modifier = {
	modifier = better_morale
	days = 127
	mode = add_and_extend
}
```
Scaled application with `size` (a script‑value block) — `in_game/events/government/D008_latinization_vs_hellenization.txt:412-425`:
```
scope:target_unit = {
	add_unit_modifier = {
		modifier = inspiring_service_modifier
		years = modifier_duration_years_extended
		mode = replace
		size = {
			add = { desc = BASE_VALUE value = 1 }
			if = {
				limit = { root = { has_country_modifier = suppressing_latinization_modifier } }
				multiply = { value = 0.5 desc = "[ShowModifier('suppressing_latinization_modifier')]" }
			}
		}
	}
}
```
Duration keys seen: `days`, `months`, `years`; `years = -1` / `months = -1` = permanent (Cheat Menu Pro `sakuya_1_7_sgui.txt:44`: `add_country_modifier = { modifier = … years = -1 mode = add_and_extend }`; vanilla `flavor_CAS.txt:10482-10486` `months = -1`; GUI exposes `TimedModifier.IsPermanent`). `mode` values used with `add_*_modifier` in vanilla: `add_and_extend` (1814×), `add` (672), `replace` (522), `extend` (101), `multiply` (41). Removal: `remove_country_modifier = <key>` (Cheat Menu Pro `sakuya_1_7_sgui.txt:62`); `remove_unit_modifier` not seen in vanilla/mods → UNVERIFIED name. Triggers: `has_unit_modifier = <key>` (unit scope, `parliament.txt:1263`), `has_country_modifier`, and reading a current modifier value as a script value: `add = modifier:discipline` (`000_johan_debug.txt:1070`), `modifier:tolerance_heretic < 0` in a trigger (`auto_modifiers/wrong_religion_ruler.txt:4`).

Values may be script values: `societal_value_monthly_move = 0.1` (`script_values/default_values.txt:422`), `large_selling_efficiency_bonus = 0.2` (889), `modifier_duration_years_short = 5` (713), `modifier_duration_years_extended = 15` (711) — used directly as `tax_income_efficiency = large_tax_income_efficiency_bonus` (`difficulty.txt:24`).

### 2.3 Country and location static modifiers that matter here (VERIFIED)

Country‑category blocks **carrying unit‑category types** (engine propagates country modifiers to all its units):

```
# static_modifiers/country.txt:387-394
#multiplied by 1-maintenance
army_maintenance_reverse_mod = {
	game_data = {
		category = country
	}
	siege_ability = -1.0
	monthly_prestige = -0.05
}
```
Also `is_bankrupt` (`country.txt:146-170`): `land_morale_modifier = -0.9`; `the_beating_of_the_drums` (2562): `siege_ability = 0.15`; `chi_capture_of_beijing` (2014): `siege_ability = 0.1`; `bad_discipline` (2605): `discipline = -0.05`; `difficulty_ai_hard` (`difficulty.txt:84-95`): `discipline = 0.1`, `naval_damage_done = 0.1`.

Hardcoded **location** blocks the engine applies by itself (`static_modifiers/location.txt`):

```
# location.txt:355-366
under_siege = {
	game_data = {
		category = location
	}
	hostile_food_multiplier = -1.0
	local_monthly_development_modifier = -0.20
	road_building_blocked = yes
	local_prosperity_decay = 0.05

	constructions_stalled = yes
	local_mercenaries_modifier = 0.25
}
```
```
# location.txt:454-466
capital = {
	game_data = {
		category = location
	}
	local_proximity_source = 100
	local_max_control = 0.20
	local_population_capacity_modifier = 0.10
	local_migration_attraction = 0.025

	local_nobles_desired_pop_scaled = 0.002
	local_clergy_desired_pop_scaled = 0.002
	local_fort_maintenance_efficiency = 1.00

	free_building_levels = 5
}
```
Likewise `province_capital` (470-481), `historical_capital` (484-497), `is_occupied` (369-380), `location_base_values` (4-42, has `supply_limit = 15`, `max_attrition = 10`, `local_frontage_allowed = 10`), and three **scaled** hardcoded blocks: `devastation` (387, comment "#multiplies with devastation in location (0 to -1)"), `prosperity` (408, "(0 to 1)"), `development` (421-437, "#multiplies with development in location (0-100)", contains `local_supply_limit_modifier = 0.02`, `occupation_time = 0.01`). Loc: `STATIC_MODIFIER_NAME_capital: "[capital|e]"` (389), `…province_capital` (390), `…under_siege: "Under Siege"` (383), `…is_occupied` (384). There are **no** hardcoded rank blocks (`rural`/`town`/`city`) — only flavour `rural_center_modifier` (3779).

### 2.4 Icons for static modifiers (VERIFIED folder, INFERRED lookup)

`game/main_menu/gfx/interface/icons/modifiers/` holds 23 files: `_default.dds`, per‑file/category icons `unit.dds`, `subunit.dds`, `country.dds`, `locations.dds`, `province.dds`, `difficulty.dds`, `movement.dds`, `religion.dds`, `institution.dds`, `integration.dds`, `ios.dds`, `free_cities.dds`, `rebel.dds`, `dynasty.dds`, `character.dds`, `mercenary.dds`, `location_historical_base_values.dds`, plus per‑key icons `looted.dds`, `excommunicated.dds`, `overpopulation.dds`, `nobles_priviledged.dds`, `ambition.dds` — and `looted`, `excommunicated`, `overpopulation`, `nobles_priviledged` **are** static modifier keys (`location.txt:771`, `character.txt:150`, `location.txt:594`, `country.txt:1472`). INFERRED: the engine resolves `[StaticModifier.GetIcon]` / `[TimedModifier.GetIcon]` to `icons/modifiers/<key>.dds` if present, else the category/file icon, else `_default.dds`. GUI hooks: `in_game/gui/cooltip.gui:931-937` (`StaticModifierTooltip` → `texture = "[StaticModifier.GetIcon]"`), `in_game/gui/shared/standard_types.gui:772-825` (`timed_modifier_icon`, `texture = "[TimedModifier.GetIcon]"` at 808), list template `in_game/gui/shared/modifiers.gui:5-26`:

```
	type OneOrSeveralTimedModifiers = icon {
		…
		visible = "[GreaterThan_int32(GetDataModelSize(TimedModifierOwner.GetModifiers), '(int32)0')]"
		…
			datamodel = "[TimedModifierOwner.GetModifiers]"
			item = {
				timed_modifier_icon = {
					datacontext = "[TimedModifier]"
```
and the army window, `in_game/gui/single_unit_window.gui:3723-3728`:
```
						widget = {
							size = { 50 20 }
							datacontext = "[SingleUnitWindow.GetSelectedUnit.GetTimedModifierOwner]"
							visible = "[GreaterThan_int32(GetDataModelSize(TimedModifierOwner.GetModifiers), '(int32)0')]"
							OneOrSeveralTimedModifiers = {}
						}
```
So a `cw_no_headquarters` unit modifier added by script will automatically appear in the vanilla army window and a 4th HQ tab can reuse `OneOrSeveralTimedModifiers` / `timed_modifier_icon` with `datacontext = "[Unit.GetTimedModifierOwner]"` (INFERRED from the three vanilla usages).

---

## 3. Auto modifiers

### 3.1 Format (VERIFIED) — `game/in_game/common/auto_modifiers/readme.txt:1-17`

```
# Auto Modifiers
#
# Modifiers automatically applied to countries based on specified criteria and scale.
#
# ATTRIBUTES
#
# - category: Modifier category for the modifiers. (default: country - if set must be before any modifiers)
# - type: Scope type for potential_trigger. (default: country - if set must be before potential_trigger )
#
# - icon: icon path for the modifier
# - requires_real: (yes/no) does this auto modifier require a real country
# - potential_trigger: trigger for if the auto modifier will be applied
# - scales_with: evaluates a value to multiply the auto modifier effects by
# - limit: trigger checks to see when the auto modifier can be applied
# - hide_effects: (yes/no) is this a hidden modifier
# - alert: (yes/no) should this modifier show in the alerts when it is active?
# Everything else is the modifiers to be applied
```

Examples (VERIFIED):

```
# auto_modifiers/country.txt:508-524
high_legitimacy = {
	potential_trigger = {
		uses_government_power = legitimacy
	}
	limit = {
		legitimacy > 50
	}
	scales_with = {
		value = legitimacy
		multiply = 0.01
	}

	global_crown_estate_power = 0.10
	pop_leave_rebels_threshold = -0.05
	…
```
```
# auto_modifiers/country.txt:1118-1130  (unit-type modifier inside a country auto modifier)
horde_army_expectation = {
	potential_trigger = {
		government_type ?= government_type:steppe_horde
	}

	scales_with = {
		value = 1
		subtract = army_size_percentage
		min = 0
	}

	stability_cost_efficiency = -2
	land_morale_modifier = -0.5
}
```
```
# auto_modifiers/wrong_religion_ruler.txt:1-18 (alert + scales_with on a modifier value)
heretic_ruler_penalty = {
	potential_trigger = {
		has_ruler = yes
		modifier:tolerance_heretic < 0
		ruler.religion != religion
		ruler.religion.group = religion.group
	}

	alert = yes

	scales_with = {
		value = modifier:tolerance_heretic
		multiply = -1
		min = 0
		max = 6
	}
```
Non‑country scope examples — `dynasty.txt:6-10`: `dynasty_base_values = { type = dynasty  category = dynasty }`; `international_organization.txt:5-9`: `type = international_organization  category = internationalorganization`; `catholic_church.txt:1-10` sets `category = country` explicitly; `country.txt:10-11` `requires_real = no`; DLC `granada.txt:3-20` scales with a situation variable (`value = situation:battle_for_the_strait.var:granadan_sovereignty  divide = 100`) and uses `has_dlc`. Loc: `auto_modifiers_l_english.yml:245-246`:

```
 AUTO_MODIFIER_NAME_heretic_ruler_penalty: "Heretic Ruler"
 AUTO_MODIFIER_DESC_heretic_ruler_penalty: "Our [ruler|e] adheres to a heretical faith, undermining the authority of the state religion."
```
GUI hook: `[StaticAutoModifier.GetIcon]`. The `icon` attribute is documented but **used nowhere** in vanilla or DLC (grep), so its value format (full path? key into `modifier_icons`?) is UNVERIFIED. `hide_effects` is also unused in vanilla.

### 3.2 (e) Can an auto modifier apply a LOCATION‑category modifier from a location trigger?

Findings:

* Every vanilla/DLC auto modifier has `type` ∈ {country (default), dynasty, international_organization}; the only `category` values used are `country`, `dynasty`, `internationalorganization` (VERIFIED, grep over all 10 files).
* `country.txt:291-329` has blocks named `location_tt_name`, `army_tt_name`, … but their trigger is `country_type = location` / `country_type = army` — these are *country types* (settled/army‑based countries), **not** location scopes.
* Engine limitation is acknowledged in script: `country.txt:1562-1567`:

```
# Imperial Circles modifiers
# -------------------------------------------------------------------------
# All circle modifiers are in static_modifiers/country.txt (manually applied
# via add_country_modifier). Auto-modifier evaluation does not support
# circle-scope iterators (any_imperial_circle_country_is_member_of).
```

Conclusion: `type = location` + `category = location` + `potential_trigger = { is_capital = yes }` is **UNVERIFIED** (the readme syntax allows writing it; nothing proves the engine evaluates auto modifiers per location — the readme header says "applied to countries"). Treat as "try once, expect it to be ignored or to error". Verified alternatives:

1. **Extend the hardcoded location modifiers** the engine already applies per location: add `local_war_score_efficiency` / `occupation_time` to `capital`, `province_capital`, `development` (scaled 0‑100), `prosperity` — by overriding those keys in a mod file in `main_menu/common/static_modifiers/` (same key → later file replaces; load‑order/override behaviour itself is INFERRED from standard Paradox DB rules, `database_conflicts.log` is empty so no vanilla duplicates exist to confirm).
2. **Scripted location modifiers** with `add_location_modifier` from on_actions: `on_location_changed_rank` (`in_game/common/on_action/_hardcoded.txt:4848-4851`, comment `#root = location, old_rank = location_rank, actor = country`), `on_capital_moved` (6333), `on_location_changed_owner` (4858-4860, `#root= location, scope:loser…, scope:winner…`), `on_location_occupied` (494), or a country yearly pulse iterating `every_owned_location = { limit = { location_rank = location_rank:city } add_location_modifier = { … } }` — the iterator/trigger/effect combination is VERIFIED in `in_game/events/DHE/flavor_CAS.txt:10504-10513` (`every_owned_location` + `add_location_modifier = { modifier = refused_merino_wool years = 100 mode = add_and_extend }`); rank triggers in vanilla: `location_rank = location_rank:city` (306 uses), `…:town` (189), `…:rural_settlement` (104), `…:megalopolis` (250), `is_city = yes` (48), `is_capital = yes` (location scope, e.g. `in_game/common/scripted_triggers` usages).
3. **Defines** (`WAR_WORTH_*`, `OCCUPATION_VALUE_SCALE`) for the global shape of warscore (§1.4).

---

## 4. Game rules

### 4.1 Format (VERIFIED) — `game/main_menu/common/game_rules/_game_rules.info:1-32`

```
game_rule = {
	default = setting_name 	# Which setting to default to

	setting_name = {
		apply_modifier = category:modifier_key	# Apply a modifier to characters matching a specific category. Valid are player, ai, and all. E.G., player:very_easy

		defines = { # Override these defines while active. Formatted as the normal define files
			NArmy = {
				MOVEMENT_SPEED = 10
			}
		}

		flag = flag_key	# Has some specific effect. See "flags" section for list
	}
}

rule_<key> will be used as the key for game rule names
setting_<key> will be used as the key for game rule setting names
setting_<key>_desc will be used as the key for game rule setting descs
```
Flags listed in the .info: `blocks_achievements`, `lenient_ai`, `harsh_ai`, `low_ai_aggression`, `high_ai_aggression` (all four "???"), `no_subject_flags`, `no_subject_map_color`, `no_ahistorical_formable_countries`, `disable_<production_method_key>`, `force_<production_method_key>`. Vanilla additionally uses (counts in `00_game_rules.txt`): `flavour_rule` 39, `general_rule` 31, `blocks_achievements` 17, `multiplayer_rule` 15, `blocks_ironman`, `proficiency_*`, `historical_ai_choices`, `random_ai_choices`, `ai_personalities_random*`, `formable_*`, `timeout_*`, `byz_name_*` … The three "tab" flags decide where a rule is shown: `in_game/gui/game_rules.gui:99` `visible = "[GuiGameRule.GetSetting.HasFlag( 'multiplayer_rule' )]"`, `:112` `'flavour_rule'`, `:1058` `'general_rule'` — **a rule with none of them is invisible in the UI** (INFERRED from those three filters).

Vanilla rule applying static modifiers (`00_game_rules.txt:1-31, 65-83`):

```
player_difficulty = {
	default = player_normal_difficulty

	player_very_easy_difficulty = {
		apply_modifier = player:difficulty_player_very_easy
		flag = blocks_achievements
		flag = general_rule
		flag = proficiency_novice
	}
	…
ai_aggression = {
	default = ai_normal_aggression

	ai_low_aggression = {
		apply_modifier = ai:low_aggression
		flag = blocks_achievements
		flag = general_rule
	}
```
All 13 vanilla `apply_modifier` uses are `player:` or `ai:`; `all:` is documented only (UNVERIFIED). `defines = { }` inside a rule is documented but **never used in vanilla** (UNVERIFIED in practice; the .info example uses `NArmy`, a block that does not exist in `00_defines.txt` — real blocks are `NUnit`, `NCombat`, `NAI`, `NWar`, `NDiplomacy`, …). The applied modifier is an ordinary `category = country` static modifier (`difficulty.txt:118-143`, §1.3). Loc (`game_rules_l_english.yml:2-4, 27-29`):

```
 rule_player_difficulty: "Player Difficulty"
 setting_player_very_easy_difficulty: "Very Easy"
 setting_player_very_easy_difficulty_desc: "This is the easiest setting to play the game in, human players will be given substantial bonuses."
…
 rule_ai_aggression: "AI Aggression"
 setting_ai_low_aggression: "Low Aggression"
```
Script can branch on a rule: `has_game_rule = <setting_key>` (`in_game/common/scripted_triggers/game_triggers.txt:1-10`, e.g. `has_game_rule = ai_easy_difficulty`; 20+ uses for `institution_spawn_*`, `byz_name_*`). Workshop mods: neither Cheat Menu Pro nor Simple Cheats ships game rules, so a mod‑added `game_rules/cw_rules.txt` is syntactically straightforward but untested here (INFERRED: files in the folder merge like every other DB folder).

---

## 5. (g) Percentages, value scales, stacking

* **Percent types**: `percent=yes` → the script value is a fraction; `0.1` = +10 %, `-0.9` = −90 % (VERIFIED by the header comment, by `army_leaderless → land_morale_modifier = -0.20` = "No Commander −20 %", by `siege_ability = -1.0` in `army_maintenance_reverse_mod` = −100 % at zero maintenance, and by the display format `$VAL|+=2%$` in `units_l_english.yml:1908-1910`).
* **`already_percent=yes`** types take the number *as* percent points: `local_army_attrition = 1` in `winter_normal` (`location.txt:849-854`), `= 2` in `winter_severe` (862-868), `local_hostile_attrition = 1` (166). Check this flag before writing a value (`hostile_food_multiplier` is both `percent` and `already_percent`).
* **Flat / `decimals=0`** types take integers (`fort_level`, `max_siege_memory`, `ai_months_between_wars = 60`, `retreat_delay`); **booleans** take `= yes` (`force_army_maintenance = yes`, `ai_require_cb_for_war = yes`).
* `min`/`max`/`cap_zero_to_one` are not set on any unit/warscore type, so −90 % siege ability is not clamped by the type definition; whether the siege code clamps at some floor is UNVERIFIED (vanilla already goes to −100 %).
* **Stacking unit ← country** (VERIFIED by co‑existence, INFERRED additive): the same unit‑category type is set simultaneously in (1) unit static modifiers (`army_leaderless`, `in_siege`, `extensive_training_modifier` discipline +5 %), (2) sub‑unit static modifiers (`is_army_levy` discipline −20 %), (3) country static modifiers (`difficulty_ai_hard` discipline +10 %, `army_maintenance_reverse_mod` siege −100 %), (4) country auto modifiers (`horde_army_expectation` land morale −50 %), (5) general traits (`siege_specialist` siege +15 %). The siege tooltip is an explicit breakdown (`SIEGE_ABILITY_TOTAL: "Siege Ability: #TOOLTIP:$BREAKDOWN_TAG$ $VAL|-=2%$#!"`, `SIEGE_ABILITY_BREAKDOWN_TITLE`, `units_l_english.yml:1908-1910`) and the country value is readable as `[Country.GetModifierValueNoFormat('siege_ability')]` (`diplomacy_l_english.yml:3343`) — consistent with all sources being summed into one per‑army value. No file states "multiplicative" anywhere.

### 5.1 `siege_ability` / `assault_ability` at unit level — plausibility

* Both are `category=unit`, `percent=yes` (`00_modifier_types.txt:5985-5997`) → exactly the category the static‑modifier readme reserves for `category = unit` blocks (VERIFIED).
* Vanilla unit‑level sources: general traits `in_game/common/traits/01_general.txt:52-57` (`ruthless`: `assault_ability = 0.1`), `:95-104` (`siege_specialist`: `allow = { unit ?= { sub_unit_fraction:army_artillery > 0.01 } }`, `siege_ability = 0.15`), `:147-156` (`strategist`: `discipline = 0.1`, `assault_ability = 0.33`, `siege_ability = 0.25`). `_traits.info:11-13`: "modifier = { # What effect does this trait have when the character's role is the same as this trait's category? }" — i.e. applied through the commanding general to his army; the trait block freely mixes unit types with country types (`prestige_from_land_battle`), showing the engine routes each type by its category.
* No vanilla `category = unit` *static* modifier uses `siege_ability` (only morale/discipline/experience/attrition/repair types appear in `unit.txt`), so `cw_no_hq = { game_data = { category = unit } siege_ability = -0.9 discipline = -0.1 land_morale_modifier = -0.1 }` is **INFERRED‑plausible, not VERIFIED**; the first in‑game check should be the siege tooltip breakdown of an army carrying it.

---

## 6. Pitfalls

1. **Auto modifiers are country‑centric.** No vanilla auto modifier runs in location (or unit) scope; the script comment at `auto_modifiers/country.txt:1565-1567` documents an iterator limitation. Do not build the warscore rework on `type = location` auto modifiers without a test; prefer hardcoded‑block overrides, defines, or on_action‑driven `add_location_modifier`.
2. **`already_percent` vs `percent`.** Attrition/hostile‑food types are written in percent points; morale/discipline/siege in fractions. Mixing them up gives 100× errors silently.
3. **`color=bad` inverts the colouring**, not the sign: `experience_decay = -0.05` is shown green. For `cw_` types decide the colour once.
4. **Loc keys are per object kind**: `MODIFIER_TYPE_NAME_` (types), `STATIC_MODIFIER_NAME_` (static), `AUTO_MODIFIER_NAME_` (auto), `rule_`/`setting_`/`setting_*_desc` (game rules); all under `<mod>/main_menu/localization/english/<file>_l_english.yml` starting with `l_english:` and a BOM‑free/BOM UTF‑8 file (vanilla files carry a BOM).
5. **New modifier types need an icon entry** in `main_menu/common/modifier_icons/<file>.txt` or they get `_default.dds`; DLC D009 reuses existing textures (`02_d009.txt`: `positive = "gfx/interface/icons/modifier_types/global_max_bureaucracy_slots.dds"`), which is the cheap route for `cw_*` types.
6. **Static modifier icon path is implicit** (`icons/modifiers/<key>.dds`, INFERRED). Ship `gfx/interface/icons/modifiers/cw_no_hq.dds` under `<mod>/main_menu/gfx/...` (vanilla gfx lives in `main_menu/gfx`, cf. the Cheat Menu Pro note file in its `in_game/gfx` folder saying assets do not belong under `in_game`).
7. **Sub‑unit modifiers read only a short list** (`subunit.txt:3-5`): `*_power`, `discipline`, `naval_damage_done`, `own_coast…`, experience gain/decay, `army_weight`, `food_consumption_modifier`. A per‑regiment‑type `siege_ability` would be ignored at sub‑unit level → the HQ penalty must be a **unit** (army) modifier, not a sub‑unit one.
8. **`mode`** must be given with `add_*_modifier` (every vanilla call has one); `replace` resets duration/size, `add_and_extend` stacks duration. `years = -1` for permanent.
9. **Game‑rule `defines = {}`** is documented but unused in vanilla; the `.info` example even references a non‑existent `NArmy` block. Verify with a trivial define before relying on it; `apply_modifier = all:` likewise.
10. **Game rules without `general_rule`/`flavour_rule`/`multiplayer_rule` flags will not be shown** in any tab of `game_rules.gui` (INFERRED from the three `HasFlag` filters).
11. **`movement` category** exists in files but not in the type‑definition header; the header's category list is not authoritative. The static readme omits `movement` too.
12. **28 vanilla types have no loc** — harmless for them, but a `cw_` type without `MODIFIER_TYPE_NAME_` shows the raw key in every tooltip.
13. `local_war_score_efficiency` loc says it changes what a location *costs in a peace treaty*; whether it also scales the occupation‑warscore contribution (`OCCUPATION_VALUE_SCALE`) is UNVERIFIED — test both numbers in the location tooltip (`LOCATION_WARSCORE_TT_TEXT` shows `Location.GetWarWorth`).
14. `siege_ability` at −100 % exists in vanilla (`army_maintenance_reverse_mod`), so −90 % is within tested range, but the AI's `CARPET_SIEGE_*` logic does not read modifiers (defines only) — AI armies without an HQ will still try to siege (relevant for doc 02/AI work).

---

## 7. Recommendations for the mod (`cw_`)

1. **HQ penalty as a `category = unit` static modifier** in `<mod>/main_menu/common/static_modifiers/cw_unit.txt`:
   ```
   cw_no_headquarters = {
   	game_data = { category = unit }
   	siege_ability = -0.9
   	discipline = -0.10
   	land_morale_modifier = -0.10
   	assault_ability = -0.5
   }
   ```
   plus `STATIC_MODIFIER_NAME_cw_no_headquarters` / `_DESC_` loc, optional `gfx/interface/icons/modifiers/cw_no_headquarters.dds`. Apply/remove by script (country pulse or on_actions) with `add_unit_modifier = { modifier = cw_no_headquarters years = -1 mode = replace }` on armies failing an HQ trigger, and test visibility via the vanilla `OneOrSeveralTimedModifiers` strip in the army window. Keep **no** positive HQ modifier (per design) — the vanilla pattern for "penalty only when absent" is exactly `army_leaderless`.
2. **Colonial HQ buff** = a second unit modifier (`cw_colonial_hq_overseas`, small `land_unit_attrition`/`army_movement_speed`/`land_morale_recovery` bonuses) applied only while `location.continent != owner.capital.continent` (trigger wording to be verified in doc 02); remove with `replace`/`remove_*` on return.
3. **AI steering**: a `category = country` static modifier per war stance using the `ai=yes` set (`aggressiveness_modifier`, `carefulness_modifier`, `win_war_chance_threshold`, `expected_warscore_modifier`, `defence_importance_modifier`, `ai_months_between_wars`, `peace_offer_*`, `coalition_strength_tolerance`) applied via `add_country_modifier … years = -1 mode = replace`; expose a **game rule** (`cw_ai_concentration = { default = cw_ai_concentration_normal  cw_ai_concentration_low = { apply_modifier = ai:cw_ai_low … flag = general_rule } }`) mirroring `ai_aggression`, and read it in script with `has_game_rule`.
4. **Warscore rework**: (a) ship `cw_` overrides of the hardcoded `capital`, `province_capital`, `development` blocks adding `local_war_score_efficiency` (negative = location worth *more*? — sign semantics UNVERIFIED, loc says "cost … to be taken"; verify with the tooltip), (b) tune `WAR_WORTH_BASE`, `WAR_WORTH_COUNTRY_CAPITAL`, `WAR_WORTH_PROVINCE_CAPITAL`, `WAR_WORTH_PORT`, `WAR_WORTH_TAX_BASE_*`, `WAR_WORTH_POPULATION_*`, `OCCUPATION_VALUE_SCALE` through a mod defines file (`<mod>/loading_screen/common/defines/cw_defines.txt`, partial‑override behaviour INFERRED) and optionally a game‑rule `defines = {}` block as the toggle, (c) use `on_location_changed_rank` / a yearly `every_owned_location` pass with `location_rank = location_rank:rural_settlement` to attach `cw_rural_low_warscore` (`local_war_score_efficiency`), since no vanilla rank block exists.
5. **New modifier types** (if needed, e.g. `cw_hq_capacity`, `cw_colonial_hq_capacity`): add `main_menu/common/modifier_type_definitions/cw_types.txt` with `decimals=0 game_data={ category=country }`, `MODIFIER_TYPE_NAME_cw_hq_capacity` loc, and an icon entry in `main_menu/common/modifier_icons/cw_icons.txt` reusing an existing `.dds`; the count can then be fed through `modifier:cw_hq_capacity` in script values and shown with `[Country.GetModifierValueNoFormat('cw_hq_capacity')]`‑style loc.
6. **Auto modifiers** are still the right tool for *country‑level* scaling penalties (e.g. "armies without HQ as % of all armies → `monthly_war_exhaustion`", `scales_with` a script value) — `category = country` only; put them in `<mod>/in_game/common/auto_modifiers/cw_auto.txt` with `AUTO_MODIFIER_NAME_` loc; use `alert = yes` for the HQ‑missing warning.
7. First in‑game validation list: (1) tooltip of an army with `cw_no_headquarters` shows Siege Ability −90 % in the breakdown; (2) a `type = location` auto modifier prototype — keep or delete depending on `error.log`; (3) a one‑line `cw_defines.txt` override of `WAR_WORTH_COUNTRY_CAPITAL`; (4) `apply_modifier = all:` and `defines = {}` in a throw‑away game rule.
