# 11 — Ages, Events, Localization, Decisions, Game Concepts, Alerts, Messages, Hints

Research for the *Concentrated Warfare* mod (key prefix `cw_`), EU5 1.4.7 (Caesar/Jomini).
Game root: `C:\Program Files (x86)\Steam\steamapps\common\Europa Universalis V` (all paths below are relative to it unless stated).
Workshop syntax examples: Cheat Menu Pro (`workshop/content/3450310/3600272327`), Simple Cheats (`.../3634102315`).

Legend: **VERIFIED** = seen in game/workshop files (path + line given). **INFERRED** = deduced from file structure / naming, not directly documented. **UNVERIFIED** = plausible (Jomini convention) but no EU5 example found; test in game before relying on it.

---

## 1. Ages

### 1.1 File and the six ages (VERIFIED)

Single file `game/in_game/common/age/00_default.txt` (391 lines, no `.info`). Six top-level blocks:

| # | Key | `year` | `hegemons_allowed` | `victory_card` | `efficiency` | `mercenaries` | `war_score_from_battles` |
|---|---|---|---|---|---|---|---|
| 1 | `age_1_traditions` | 1 (l.2) | – | 0 | 1.0 | – | – |
| 2 | `age_2_renaissance` | 1342 (l.54, "#5 years shorter") | – | 1 | 0.8 | 0.25 | – |
| 3 | `age_3_discovery` | 1437 (l.114) | yes | 2 | 0.6 | – | -0.05 |
| 4 | `age_4_reformation` | 1537 (l.175) | yes | 3 | 0.4 | – | -0.1 |
| 5 | `age_5_absolutism` | 1637 (l.242) | yes | 4 | 0.2 | -0.40 | -0.15 |
| 6 | `age_6_revolutions` | 1737 (l.322) | yes | 5 | 0.1 | -0.9 | -0.2 |

`year` is the calendar year the age starts (age 1 = `year = 1`, i.e. from game start 1337). INFERRED: the age advances when the game date reaches `year` (the ages_of_eu event fires then, see §2.2); `efficiency` and `victory_card` semantics are not localized anywhere (UNVERIFIED meaning — do not touch).

Full field set used per age (VERIFIED, all in the same file):
`year`, `price_stability`, `max_price`, `hegemons_allowed`, `known_goods_demand_threshold`, `burgher_max_trade_range`, `bureaucracy_maintenance_multiplier`, `months_for_exploration_spread`, `unique = {…}`, `modifier = {…}`, `goods_demand = {…}`, `mercenaries`, `mercenary_starting_experience`, `war_score_from_battles`, `efficiency`, `victory_card`, `max_ai_privilege_per_estate = {…}`, `min_ai_privilege_per_estate = {…}`.

The scalar fields are localized for the age card as `AGE_MERCENARIES_AMOUNT`, `AGE_MERCENARY_STARTING_EXPERIENCE`, `AGE_BATTLE_WAR_SCORE_IMPACT`, `AGE_KNOWN_GOODS_DEMAND_THRESHOLD`, `AGE_BURGHER_MAX_TRADE_RANGE`, `AGE_EXPLORATION_SPREAD` (`game/main_menu/localization/english/advances_l_english.yml:328-334`).

### 1.2 `modifier` blocks (global country modifiers active during the age) — VERIFIED

INFERRED: `modifier = {}` is applied to every country while the age is current (it holds normal country-modifier keys such as `expected_army_size_modifier`); `unique = {}` holds a different, smaller set per age (`diplomatic_capacity_modifier`, `exploration_mission_speed`, `global_pop_conversion_speed_modifier`, `revoke_privilege_cost_modifier`, `global_war_score_efficiency`…). The GUI does not expose a data function named after `unique` (grep of `in_game/gui/*.gui` for `Unique` only finds DLC "unique content" and unique advances), so the exact semantics of `unique` are UNVERIFIED — treat as "age bonus" and do not rely on it.

Military-relevant progression (verbatim, `game/in_game/common/age/00_default.txt`):

```
     9	modifier = {
    10		expected_navy_size_modifier = -0.8	# expected navy size at 20% of its demographic value; ramps to 100% by Age of Revolutions
    11	
    12		lack_of_control_impact_on_warscore = 0.1
    13	}
```
```
   128	modifier = {
   129		expected_army_size_modifier = 2.0
   130		expected_navy_size_modifier = -0.48	# expected navy size at 52%
   131		levy_maintenance_modifier = 0.25
   132	
   133		lack_of_control_impact_on_warscore = 0.4
   ...
   148	war_score_from_battles = -0.05
```
```
   257	modifier = {
   258		expected_army_size_modifier = 8.0
   ...
   264		lack_of_control_impact_on_warscore = 0.8
   265	
   266		global_war_score_efficiency = 0.2
```
```
   331	unique = {
   332		global_war_score_efficiency = 1.0
   333		subject_loyalty = -30
   334	}
   335	
   336	modifier = {
   337		expected_army_size_modifier = 16.0
   338		levy_maintenance_modifier = 1.0
   339	
   340		lack_of_control_impact_on_warscore = 1.0
```

Per-age summary of `modifier`: `expected_army_size_modifier` 0 → 1.0 → 2.0 → 4.0 → 8.0 → 16.0; `levy_maintenance_modifier` – → 0.1 → 0.25 → 0.5 → 0.75 → 1.0; `lack_of_control_impact_on_warscore` 0.1 → 0.2 → 0.4 → 0.6 → 0.8 → 1.0; `global_war_score_efficiency` 0.2 (age 5 modifier), 1.0 (age 6 `unique`). Ages 4–6 also add `antagonism_*_influence`, `global_free_building_levels_modifier`, `construction_center_max_level`, `subject_pays_colonial_cost_modifier`, `subject_loyalty`.

Relevance: `lack_of_control_impact_on_warscore` and `global_war_score_efficiency` already scale warscore by age — the warscore rework (rural ≈ 0) must be tested per age, not only in 1337. A mod can override the whole file by shipping `in_game/common/age/00_default.txt` (same name) — INFERRED (standard Paradox file replacement); prefer NOT to touch it and instead gate HQ slots via triggers (§1.4).

### 1.3 Age triggers (VERIFIED)

Two triggers are used across vanilla (523 and 308 usages respectively; no `current_age_or_earlier`, `age_number` or `current_age_index` exist anywhere in `common`, `events`, `gui`):

```
game/in_game/common/decisions/generic_age_decisions.txt
     5	potential = {
     6		current_age = age_2_renaissance
     7		religion.group = religion_group:christian
     8	}
```
```
game/in_game/common/decisions/generic_age_decisions.txt
   282	potential = {
   283		current_age_or_later = { age = age_3_discovery }
```
Scope-agnostic: `current_age` is used in character scope (`game/in_game/common/death_reason/02_life_expectancy.txt:120`), country scope (decisions), building `country_potential` (`building_types/unique_buildings.txt:4273`), customizable_localization (`customizable_localization/parliaments.txt:165`). "Earlier than age X" must be written as `NOT = { current_age_or_later = { age = X } }` or an `OR` of `current_age` (vanilla does the latter: `nanban_trade.txt:134-137` uses `NOR = { current_age = age_1_traditions current_age = age_2_renaissance }`).

Age-gated HQ slots (recommended pattern, built only from VERIFIED triggers + standard script_value syntax):

```
# in_game/common/script_values/cw_hq_values.txt   (INFERRED structure: vanilla ai_will_do blocks use value/add/if/limit exactly like this)
cw_hq_slots_by_age = {
	value = 0
	if = { limit = { current_age_or_later = { age = age_3_discovery } }   add = 1 }
	if = { limit = { current_age_or_later = { age = age_4_reformation } } add = 1 }
	if = { limit = { current_age_or_later = { age = age_5_absolutism } }  add = 1 }
	if = { limit = { current_age_or_later = { age = age_6_revolutions } } add = 1 }
}
```

### 1.4 `on_new_age` / `on_new_age_global` (VERIFIED)

```
game/in_game/common/on_action/_hardcoded.txt
   632	# on action called only once before each country
   633	on_new_age_global = {
   634		effect = {
   635			setup_area_preferences = yes
   636		}
   637	}
   638	
   639	# scope is country, this is done for ALL active countries when a new nation is picked.
   640	on_new_age = {
   641		events = {
   642			ages_of_eu.1
   643		}
   644		effect = {
   645			if = {
   646				limit = {
   647					has_game_rule = ai_personalities_random_per_age
   648					is_ai = yes
   649				}
```
`on_new_age`: ROOT = country, fired for every country; it fires the age event `ages_of_eu.1` and runs effects (the vanilla comment text is garbled but the effect body proves country scope: `is_ai`, `has_game_rule`, `set_personality`). `on_new_age_global`: no country scope, called once.

On-actions are **additive across files** (VERIFIED): the DLC redeclares vanilla on-actions and only appends its own sub-on-actions:
```
game/dlc/D009_across_the_pillars/in_game/common/on_action/d009_tlemcen.txt
     1	on_siege_won = {
     2		on_actions = { on_tlemcen_occupy_location }
     3	}
     4	
     5	on_location_occupied = {
     6		on_actions = { on_tlemcen_occupy_location }
     7	}
     8	
     9	on_tlemcen_occupy_location = {
    10		trigger = {
    11			has_dlc = "d009_across_the_pillars"
```
The folder is `common/on_action` (singular). Cheat Menu Pro has an empty, ignored `common/on_actions/` folder with the comment "我删除了" — PITFALL: a file in `on_actions/` is silently never loaded.

On-action grammar is documented in `game/in_game/common/on_action/on_actions.info` (VERIFIED): `trigger`, `weight_multiplier`, `events` (with `delay = { days = 365 }` / `delay = { months = { 6 12 } }` entries between events), `random_events` (`chance_to_happen`, `chance_of_no_event`, weighted `100 = event_id`, `100 = 0`), `first_valid`, `on_actions`, `random_on_action`, `first_valid_on_action`, `effect`, `fallback`. Note from the .info: effects in `effect = {}` run **concurrently** with the listed events, so scopes/variables set there are not visible to those events.

Mod hook for "new HQ slot unlocked":
```
# in_game/common/on_action/cw_on_actions.txt
on_new_age = {
	on_actions = { cw_on_new_age }
}
cw_on_new_age = {
	trigger = { is_ai = no }          # player only
	events = { cw_events.1 }          # "A new Headquarters slot is available"
}
```

### 1.5 Age data functions / loc keys (VERIFIED)

- `[GetCurrentAge.GetName]`, `[GetCurrentAge.GetNameWithNoTooltip]`, `[GetCurrentAge.GetDesc]` (`advances_l_english.yml:148-149`; global, no scope needed).
- `[ShowAgeNameWithNoTooltip('age_1_traditions')]` (`economy_l_english.yml:593`).
- GUI: `[Age.GetNameWithNoTooltip]`, `[IsCurrentAge(Age.Self)]`, `[IsFutureAge(Age.Self)]`, `[GetAgeIcon(Age.Self)]`, `[GetAgeEndingDate(Age.Self)]` (`game/in_game/gui/advances_lateralview.gui:2150-2260`).
- Loc keys per age: `age_3_discovery: "Discovery"`, `age_3_discovery_desc`, `age_format_age_3_discovery: "Age of $age_3_discovery$"` (`advances_l_english.yml:125-137`); Russian: `age_format_age_3_discovery: "Эпоха $age_3_discovery$"`, `age_3_discovery: "Открытий"` (`russian/advances_l_russian.yml:102-110`).

---

## 2. Events

### 2.1 Event grammar (`game/in_game/events/readme.txt`, VERIFIED)

Namespace first: `namespace = <name>`; ids `<name>.<1..9999>`, globally unique. Fields (readme lines 6-114): `type = country_event/location_event/unit_event/exploration_event/age_event`; `title`/`desc`/`historical_info` as a key or `{ first_valid = { triggered_desc = { trigger = {} desc = key } ... } }` (or `random_valid`); `trigger`; `major = yes` + `major_trigger` (root = country seeing the notification, `scope:from` = original firer); `hidden = yes`; `immediate`; `after` (after an option is picked); `on_trigger_fail`; `fire_only_once = yes`; `interface_lock = no` (do not pause SP; default yes); `dynamic_historical_event = { tag from to monthly_chance }`; `orphan = yes` (suppress "unreferenced" error); `hide_portraits`; `outcome = positive/neutral/negative`; `category = disaster_event/situation_event/international_organization_event`; `illustration_tags = { 10 = ages }`; `weight_multiplier`; `image = "<path>"`; `option = { name historical_option trigger (or hidden_trigger) <effects> fallback exclusive original_recipient_only ai_will_select{script math} ai_chance{base/modifier} }`. `show_as_unavailable` is marked NOT IMPLEMENTED.

Also VERIFIED in files but absent from the readme: `event_window_type = age_event_window` (`ages.txt:5`; the window exists: `game/in_game/gui/eventwindow.gui:1739 name = "age_event_window"`); only other value used is `omens_event_window`.

`unit_event` is listed by the readme but has **zero** vanilla usages (`grep "type = unit_event" game/in_game/events` → nothing) — UNVERIFIED in practice; prefer `country_event` with the army saved as a scope.

### 2.2 Age-change event (how the player is informed) — full template (VERIFIED)

```
game/in_game/events/ages.txt
     1	namespace = ages_of_eu
     2	
     3	ages_of_eu.1 = {
     4		type = age_event
     5		event_window_type = age_event_window
     6	
     7		title = ages_of_eu.1.title
     8		desc = ages_of_eu.1.desc
     9		outcome = neutral
    10		
    11		illustration_tags = {
    12			10 = ages
    13		}
    14		
    15		option = {
    16			name = ages_of_eu.adm
    17			set_age_preference = adm
    18	
    19			# make sure Ottomans gets the Deus Vult CB
    20			ai_will_select = {
    21				if = {
    22					limit = {
    23						has_or_had_tag = TUR
    24					}
    25					value = 1000
    26				}
    27			}
    28		}
    29		option = {
    30			name = ages_of_eu.dip
    31			set_age_preference = dip
    32		}
    33		option = {
    34			name = ages_of_eu.mil
    35			set_age_preference = mil
    36		}
    37	}
```
Loc (`game/main_menu/localization/english/advances_l_english.yml:148-152`):
```
 ages_of_eu.1.title: "The [GetCurrentAge.GetNameWithNoTooltip]"
 ages_of_eu.1.desc: "This is the dawning of the [GetCurrentAge.GetName]!\n\n[GetCurrentAge.GetDesc]"
 ages_of_eu.adm: "Administrative Focus"
```
So the player is informed by one `age_event` fired from `on_new_age` for every country (AI picks via `ai_will_select`). Our mod should NOT add a second `age_event`; add a `country_event` via the `on_new_age` hook (§1.4) and only for `is_ai = no`.

### 2.3 Small vanilla events to copy from (VERIFIED)

`custom_tooltip` with effects inside, `add_country_modifier` with `years = -1`:
```
game/in_game/events/thalassocracy_events.txt
    34	option = {
    35		name = thalassocracy_events.1.a
    36		trigger = {
    37			navy_size_percentage >= 0.75
    38		}
    39		add_prestige = prestige_severe_bonus
    40		custom_tooltip = {
    41			text = unlock_thalassocracy_reform_tt
    42			set_variable = thalassocracy_achieved
    43		}
    44		add_country_modifier = {
    45			modifier = thalassocracy_achieved_modifier
    46			years = -1
    47			mode = replace
    48		}
    49	}
```
Same file lines 7-22 show the `desc = { first_valid = { triggered_desc = { trigger = {…} desc = key } } }` form.

Player-only option (`is_ai = no`) and effects wrapped in `custom_tooltip`:
```
game/in_game/events/colonial_federation_events.txt
   111	option = {
   112		name = colonial_federation_events.1001.b
   113		trigger = { is_ai = no }
   114		custom_tooltip = {
   115			text = colonial_federation_break_away_tt
   116			if = {
   117				limit = { exists = scope:target_country }
   118				every_owned_location = {
   119					limit = { is_core_of = scope:target_country }
   120					change_location_owner = scope:target_country
   121				}
   122			}
   123		}
   124	}
```
`major = yes` + `major_trigger` (notifies other countries), lines 3-11 of the same file:
```
     3	colonial_federation_events.1000 = {
     4		type = country_event
     5		title = colonial_federation_events.1000.title
     6		desc = colonial_federation_events.1000.desc
     7		outcome = neutral
     8		major = yes
     9		major_trigger = {
    10			is_neighbor_of = root
    11		}
```
`hidden_effect`, string-form `custom_tooltip`, delayed `trigger_event_non_silently`, `after`, `is_human`:
```
game/in_game/events/civil_war.txt
    11	trigger = {
    12		is_human = yes
    ...
    27			hidden_effect = {
    28				set_variable = english_civil_war_lost_variable
    29			}
    ...
    35					trigger_event_non_silently = {
    36						id = english_civil_war.252
    37						days = 30
    38					}
    ...
    52	option = {
    53		name = civil_war.1.b
    54		custom_tooltip = civil_war_game_over
    55	}
    56	
    57	after = {
    58		hidden_effect = {
```
Both `is_ai = yes/no` (232 usages) and `is_human = yes/no` (87 usages) exist in vanilla (VERIFIED counts).

Workshop example of a minimal event (Cheat Menu Pro, `in_game/events/sakuya_truce_events.txt:1-22`): `namespace = sakuya_truce`, `type = country_event`, `title`, `desc`, `outcome = neutral`, `trigger = { any_country = { has_variable = … } }`, `immediate = { random_country = { limit = {…} save_scope_as = marked_country } }`.

### 2.4 Firing events from script (VERIFIED forms)

- `trigger_event_silently = flavor_bul.7` (on_action files) / `trigger_event_silently = { id = flavor_ned.1003 days = 2 }` / `trigger_event_silently = { id = character_events.1 years = 2 }` / `trigger_event_non_silently = { id = red_turban_rebellions.23 days = 1 }` (all from `common/on_action/*.txt`, `common/scripted_effects/*.txt`). INFERRED: `_silently` = no notification message to others; `_non_silently` = also generates the message. Fire for another country with `scope:x = { trigger_event_silently = … }` (`king_in_prussia.txt:62-64`).
- From on-actions: `events = { id }`, `random_events`, `first_valid` (§1.4).
- Timed variables for cooldowns: `set_variable = { name = pacific_defiance_cooldown value = yes days = 45 }` (5 usages), `set_variable = { name = recently_had_any_western_schism_event years = 8 }` (31 usages) — VERIFIED.

### 2.5 Event loc keys (VERIFIED)

`<ns>.<id>.title`, `<ns>.<id>.desc` (or `.desc_success` etc. when using `first_valid`), `<ns>.<id>.a/.b…` for options, free keys for `custom_tooltip` text. Vanilla keeps event loc in a subfolder: `game/main_menu/localization/english/events/thalassocracy_events_l_english.yml` and `…/russian/events/thalassocracy_events_l_russian.yml` (37 files/dirs in `events/`). Nesting another event's title: `colonial_federation_events.1001.title: "$colonial_federation_events.1000$"`. Scopes saved in `immediate` are usable in text as `[target_location.GetName]` (58 usages), `[target_country.GetName]`, `[target_io.GetNameWithNoTooltip]`.

### 2.6 "Notification-style" events (VERIFIED pattern)

Vanilla has no toast effect; a plain informational event is a `country_event` with one option and a comment "simple notification event because we have no pop-ups" (`game/in_game/events/DHE/flavor_mlo.txt:1991`), or `nanban_trade.2` (`events/economy/nanban_trade.txt:107`). Only ONE vanilla event uses `interface_lock = no` (count verified) — use it for low-importance notifications so the game does not pause.

---

## 3. Localization

### 3.1 Where files go (VERIFIED)

- Vanilla: `game/main_menu/localization/<lang>/*.yml` (132 files in `english/`, plus subfolders `decisions/`, `events/`). `game/in_game/localization/` contains only `jomini/script_system/` (engine trigger/effect strings) — so loc is normally a **main_menu** asset and is available in game (Cheat Menu Pro's in-game GUI strings live in `main_menu/localization/english/cheat_menu_l_english.yml`).
- Mod: `<mod>/main_menu/localization/<lang>/<name>_l_<lang>.yml`; subfolders allowed (Cheat Menu Pro: `main_menu/localization/english/1.7/Cheat_menu_1.7_shared_l_english.yml`). Language folder names: `braz_por english french german japanese korean polish russian simp_chinese spanish turkish` (vanilla dir listing; Cheat Menu Pro ships the same set).
- INFERRED (Jomini convention, not verified for EU5): keys defined later override earlier ones with the same key and the mod's files load after vanilla; no `replace/` folder exists in vanilla EU5 (`find game -type d -name replace` → none).

### 3.2 File format (VERIFIED)

- Encoding **UTF-8 with BOM**: first bytes `EF BB BF` in `english/_achievements_l_english.yml`, `russian/EU5_customizable_localization_ru_constructionname_l_russian.yml`, and Cheat Menu Pro's `cheat_menu_l_english.yml`. The engine complains about missing BOM even for script files: `debug.log: [lexer.cpp:513]: File 'common/static_modifiers/sakuya_1_7_modifiers.txt' should be in utf8-bom encoding (will try to use it anyways)` — save **every** mod file (.txt, .yml, .gui) as UTF-8-BOM; `tools/validate.sh` already checks this.
- First line: `l_english:` / `l_russian:` (must match the folder/suffix). Then one key per line, **one leading space**, `key: "text"`. Vanilla EU5 uses **no version numbers**: 155 836 keys match `^ key: "`, zero match `^ key:0 "` (also none in the workshop mods). `key:0 "text"` is UNVERIFIED for EU5 (accepted in other Jomini titles) — just omit the number.
- Comments: `#` at line start (e.g. ` # Menu buttons` in Cheat Menu Pro). Escapes: `\n` newline, `\"` quote (`hints_l_english.yml:59`).

```
game/main_menu/localization/english/_achievements_l_english.yml   (hexdump shows EF BB BF before 'l')
l_english:
 ACHIEVEMENTS_LABEL: "Achievements"
 ACHIEVEMENT_GROUP_TOOLTIP_TITLE: "Achievement Difficulty"
```

### 3.3 Text syntax (VERIFIED, with sources)

| Feature | Example | Source |
|---|---|---|
| Nesting another key | `"Age of $age_1_traditions$"` | `advances_l_english.yml:125` |
| Parameters from code/script | `$NAME$`, `$ID$`, `$ICON$`, `$NUM$`, `$VALUE$`, `$COMPARATOR$` | `core_l_english.yml`; `trigger_localization/_trigger_localization.info` |
| Data function, global | `[GetCurrentAge.GetName]` | `advances_l_english.yml:149` |
| Data function, ROOT | `[ROOT.GetCountry.GetName]`, `[ROOT.GetLocation.GetName]` | 5 / 10 usages in loc |
| Saved scope | `[target_country.GetName]`, `[SCOPE.sCountry('actor').GetName]` | events loc; `actions` loc (1240 usages) |
| Game concept link (lowercase) | `[overseas|e]`, `[armies|e]` | 34 274 usages of `[x|e]` |
| Game concept, capitalized | `[marriage|E]` at sentence start | 1 618 usages |
| Concept with custom display text | `[Concept('units_with_icon', 'отряды')|e]` | `russian/hints_l_russian.yml:348`; English: `[Concept('capital', 'Country Capitals')|e]` |
| Modifier value | `[Country.GetModifierValueNoFormat('siege_ability')]`, `[ShowModifierTypeName('siege_ability')]` | `diplomacy_l_english.yml:3343`, `interfaces_l_english.yml:6223` |
| Script value in text | `[ROOT.ScriptValue('assassinate_character_spy_network_cost')|V0]`, `[actor.MakeScope.ScriptValue('jihad_plunder_estimated_total')|0+=]` | `country_interactions_l_english.yml:629`, `actions_l_english.yml:34` |
| Variable value in text | `[ROOT.GetVariable('num_ba…').GetValue|V0]`, `[THIS.GetVariable('x').GetValue]`, `[ROOT.GetVariable('x').GetCharacter.GetName]` | `events/DHE/flavor_byz_l_english.yml:531`; 7+7 usages |
| Formatting | `#bold Allies army size#!`, `#T Recommended Actions:#!`, `#W Alert#!` | `hints_l_english.yml:390` |
| Icon in text | `@gold!`, `@hint!`, `@warning_icon!`, `@army_strength!`, `@military_panel!` | icon list below |
| Value format suffix | `$VAL|+=2%$`, `$VAL|V0$`, `[TRADE.GetEfficiency|2%Y]` | `advances_l_english.yml:328-334` |
| Custom loc call | `[ROOT.GetCountry.Custom('common_string_positive')]` | `decisions/generic_age_decisions_l_english.yml:4` |
| Panel link | `[Link('unit_overview', '', 'lateralview_unit_overview_entry_name')]` | `hints_l_english.yml:390` |
| Age name by key | `[ShowAgeNameWithNoTooltip('age_1_traditions')]`, `[ShowBuildingTypeName('cathedral')]`, `[ShowGovernmentReformName('x')]`, `[ShowPolicyName('x')]` | economy/decisions/events loc |

`|e` vs `|E`: INFERRED — `E` capitalizes the concept text (used at sentence starts). `|V` is used for currency/value names (`[doom|V]`, 36 usages), `|U` once.

Formatting codes (VERIFIED list from `game/loading_screen/gui/textformatting.gui`, `name = …`): colors `R G Y O M J` (red/green/yellow/orange/…), `T` (tooltip label/title), `S` (subheading), `V` (value), `H`/`highlight`, `L` (link), `E` (explanation link), `W` (white), `B`, `N`/`P`/`Z` (negative/positive/zero), `D`/`debug`, `X`, `I`, `F`/`flavor`, `high`, `low`, `medium`, `weak`, `important_number`, `bold`, `italic` (used 1805×), `header_titles`, `yellow_titles`, `subtle_name`, `trigger_pass`, `trigger_fail`, `col`, `col_t`, `col_m`. Usage frequency in loc: `#italic` 1805, `#T` 1365, `#Y` 684, `#R` 210, `#G` 202, `#V` 160, `#high` 144, `#W` 111, `#bold` 10. Close every format with `#!`.

Text icons are declared in `game/main_menu/gui/shared/font_icons.gui` (VERIFIED):
```
    13	texticon = {
    14		icon = power
    15		iconsize = {
    16			texture = "gfx/interface/icons/foreign_country/power.dds"
    17			size = { @[font_icon_default_size * 0.85] @[font_icon_default_size * 0.85] }
```
Frequently used in loc: `@trigger_no!` 1550, `@hint!` 276, `@gold!` 233, `@army_strength!` 59, `@location!` 50, `@warning_icon!` 36, `@manpower!` 10, `@military_panel!`, `@leftclick!`, `@automation!`. INFERRED: a mod can add its own `texticon` entries (e.g. `@cw_hq!`) in a new `.gui` file under `main_menu/gui/shared/` (that folder is loaded wholesale — the file is not referenced by name anywhere).

### 3.4 Modifier localization (VERIFIED)

- Modifier **types** (`game/main_menu/common/modifier_type_definitions/00_modifier_types.txt:5985` `siege_ability={ percent=yes game_data={ category=unit } }`, `:6014 discipline={…}`): names/descs are `MODIFIER_TYPE_NAME_siege_ability: "Siege Ability"`, `MODIFIER_TYPE_DESC_siege_ability: "This impacts how quickly that [armies|e] can [siege|e]."` (`modifier_types_l_english.yml:502-503`; Russian `modifier_types_l_russian.yml:498 "Способность к осаде"`). No new types needed for the mod.
- **Static modifiers** (`game/main_menu/common/static_modifiers/readme.txt`): `category = location/country/unit/character/religion/mercenary/province/internationalorganization/rebel/dynasty`, `decaying`, `remove_if`. Loc: `STATIC_MODIFIER_NAME_<key>` / `STATIC_MODIFIER_DESC_<key>` (`static_modifiers_l_english.yml:3040-3041`). Unit-category example:
```
game/main_menu/common/static_modifiers/subunit.txt
     7	is_army_levy = {
     8		game_data = {
     9			category = unit
    10		}
    11		discipline = -0.20
    12		experience_decay = 0.02
```
So the `cw_no_hq` unit modifier gets `STATIC_MODIFIER_NAME_cw_no_hq` / `STATIC_MODIFIER_DESC_cw_no_hq`; the per-modifier lines (−90 % siege ability, …) are generated by the engine from `MODIFIER_TYPE_NAME_*` — nothing to localize per value.

### 3.5 customizable_localization (VERIFIED)

Folder `game/in_game/common/customizable_localization/` (+ workshop: Cheat Menu Pro `in_game/common/customizable_localization/sakuya_mark_country_status.txt`). Format from `customizable_localization.info`:
```
key = {
	type = scope
	text = {
		trigger = { ... }
		localization_key = string
		fallback = yes # Optional; will cause this one to be picked if no 
	}
	random_valid = yes # Optional, will randomize instead of picking first valid
}
# variants: key = { parent = some_custom_loc_key  suffix = "_suffix"  fallback = true }
# usage in text: [<scope>.Custom('<key>')]
```
Vanilla example (`00_customizable_localization.txt:1-13`): `GetHeathenInsult = { type = country text = { localization_key = religious_insult_devil trigger = { religion.group = religion_group:christian } } text = { localization_key = religious_insult_fool fallback = yes } }`. Type values seen: `country`, `location`, `culture`, `character`. Use this for the war-stance plate text: `cw_stance_text = { type = country text = { trigger = { has_variable = cw_stance_offensive } localization_key = cw_stance_offensive } … fallback }` and show it as `[Country.Custom('cw_stance_text')]` (INFERRED composition of verified parts; `[VoteTargetGlue.GetVoteTarget.GetCountry.Custom('GetWarOfReligionsPosition')]` shows country-scope `.Custom` usage).

Also VERIFIED: `custom_description = { text = key value = scope:x <effects> }` (effect wrapper with a value, `country_interactions/hre.txt:1959-1968`), and disasters accept `custom_description: <string> key for a custom description loc in customizable_localization` (`disasters/readme.txt:3`).

### 3.6 effect_localization / trigger_localization (VERIFIED)

Folders `game/in_game/common/effect_localization/` and `…/trigger_localization/` (one entry per effect/trigger name, including scripted ones). Grammar (`_trigger_localization.info`):
```
my_trigger = {
	global = <localization_key>	# no pronoun ("Is an adult", used for example inside any triggers)
	first = <localization_key>	# first person ("I am an adult")
	third = <localization_key>	# third person ("[CHARACTER.GetName] is an adult")
	# <localization_key> requires a positive version and a negative version ("NOT_<localization_key>")
	# <rule>_not = <localization_key>	# optional override of the negative key
}
# value comparison triggers get $COMPARATOR$ and $NUM$
```
Effect variant adds past tense (`effect_localization/scripted_effects.txt:1-8`): `unlock_advance_effect = { global first third global_past first_past third_past }` → keys `UNLOCK_ADVANCE_EFFECT`, `WE_UNLOCK_ADVANCE_EFFECT`, `THIRD_…`, `PAST_…`, `PAST_WE_…`, `PAST_THIRD_…` (`scripted_effects_l_english.yml:333-338`). `__example.txt` notes `_category = {}` groups and `neg` variants ("gain x" vs "lose x").

**Do scripted effects need loc entries? No (INFERRED from counts):** vanilla defines 556 scripted effects but only 197 effect-loc entries; the rest just show their inner effects in tooltips. Add an entry only when the expanded tooltip is ugly (e.g. a big HQ-distribution effect) — then `cw_assign_hq_effect = { global = CW_ASSIGN_HQ_EFFECT first = … }`. Alternative without loc files: wrap effects in `custom_tooltip = { text = cw_x_tt … }` (§2.3).

---

## 4. Decisions

### 4.1 Format (VERIFIED by examples; no readme/.info exists in `common/decisions`)

Field frequency over all 161 vanilla decisions (`game/in_game/common/decisions/*.txt`): `decision_category` 161, `potential` 161, `ai_will_do` 161, `allow` 159, `option` 293, `only_once` 143, `illustration_scope` 138, `illustration_tags` 135, `tags` 126, `historical_info` 78, `only_once_scope` 6, `hide_repeatable_tag` 6, `image` 4. **No `cooldown` field exists for decisions** (only `generic_actions` have `cooldown = { type = <tag> days/weeks/months/years = <int> }`, readme line ~97). Options have **no** `trigger` field in vanilla (grep → none); `effect` is mandatory per option.

Minimal verified template:
```
game/in_game/common/decisions/test_decisions.txt
     1	test_decision_simple = {
     2		decision_category = other_decisions
     3	
     4		potential = {
     5			debug_only = yes
     6		}
     7	
     8		allow = {
     9			at_war = no
    10		}
    11	
    12		ai_will_do = {
    13			value = 0
    14		}
    15	
    16		option = {
    17			name = test_decision_simple.a
    18			ai_chance = { value = 100 }
    19			effect = {
    20				add_gold = 10
    21			}
    22		}
```
Full-featured (age-gated, cooldown via variable, custom_tooltip inside `allow`, weighted illustration scope):
```
game/in_game/common/decisions/generic_age_decisions.txt
    10	allow = {
    11		current_age = age_2_renaissance
    12		has_ruler = yes
    13		has_advance = cathedral_advance
    14		custom_tooltip = {
    15			text = sponsor_a_cathedral_cooldown_tt
    16			NOT = {
    17				ruler = { has_variable = sponsor_a_cathedral_cooldown }
    18			}
    19		}
    ...
    31	ai_will_do = {
    32		value = -10
    33	
    34		add = {
    35			if = {
    36				limit = {
    37					root.gold >= {
    38						value = root.monthly_income_trade_and_tax
    39						multiply = 6
    40					}
    41				}
    42				add = 50
    43			}
    44		}
    45	}
```
Lines 47-75: `illustration_tags = { 10 = interior 10 = happy }`, `illustration_scope = { event_illustration_estate_effect = {…} random_owned_location = { limit … weight = { base = 1 modifier = { add = … } } save_scope_as = target_location } }`; lines 77-102: `option = { name = sponsor_a_cathedral_decision.a ai_chance = { value = 100 } effect = { … hidden_effect = { ruler = { set_variable = sponsor_a_cathedral_cooldown } } } }`.
Other fields: `only_once = yes` + `only_once_scope = country` (`flavor_decisions_jap.txt:3-4`), `tags = { ENG GBR }` (`flavor_decisions_eng.txt:6`; INFERRED: pre-filter by country tag for performance — omit for generic decisions), `historical_info = <key>` (`:3`), `image = "gfx/interface/icons/trade_goods/illustrations/icon_goods_coal.dds"` (`coal_prospecting.txt:3`), `hide_repeatable_tag = yes` (`canal_construction.txt:3`), `potential = { debug_only = yes }` for dev-only decisions.

INFERRED semantics: `potential` = shown at all; `allow` = can be taken (failed triggers shown in tooltip); `ai_will_do` script value, AI takes when > 0 (vanilla uses `value = -10` + conditional `add = 50`); `ai_chance` per option.

Cooldown pattern (VERIFIED parts): `set_variable = { name = cw_auto_hq_cooldown value = yes days = 365 }` in the option effect + `NOT = { has_variable = cw_auto_hq_cooldown }` in `allow`, wrapped in `custom_tooltip`.

### 4.2 Decision categories (VERIFIED)

```
game/in_game/common/decision_categories/base_decision_categories.txt
    12	government_decisions = {
    13		name_key = DECISION_CATEGORY_GOVERNMENT
    14		sort_order = 2
    15	}
    ...
    27	other_decisions = {
    28		name_key = DECISION_CATEGORY_OTHER
    29		sort_order = 5
    30		default_collapsed = yes
    31	}
```
Categories: `country_specific_decisions`, `expansion_decisions`, `government_decisions`, `religious_decisions`, `economy_decisions`, `other_decisions`, `infrastructure_decisions`. Loc: `DECISION_CATEGORY_GOVERNMENT: "Government"` (`interfaces_l_english.yml:7584`). A mod may add `cw_military_decisions = { name_key = CW_DECISION_CATEGORY_MILITARY sort_order = 7 }` (INFERRED: same grammar).

### 4.3 Decision loc keys (VERIFIED, `game/main_menu/localization/english/decisions/*.yml`)

`<key>.title`, `<key>.desc`, `<key>.desc.entry` (short list text), `<key>.a` / `.b` (option names), `<key>.a.entry` (option text in list), `<key>.historical_info`, plus free `*_tt` keys for custom tooltips (`flavor_decisions_eng_l_english.yml:2-8`, `generic_age_decisions_l_english.yml:2-5`, `test_decisions_l_english.yml:2-6`).

---

## 5. Game concepts

### 5.1 Format (VERIFIED, `game/main_menu/common/game_concepts/00_game_concepts.txt`)

```
     1	modifier = {
     2		alias = { modifiers }
     3		texture = "modifiers/_default"
     4	}
    ...
    21	unit_modifier = {
    22		alias = { unit_modifiers }
    23		texture = "modifiers/unit"
    24	}
    ...
    79	overseas = {
    80		texture = "flat_icons/overseas"
    81	}
```
Fields used (counts): `texture` 721, `alias` 444, `shown_in_loading_screen` 106, `family` 97, `shown_in_encyclopedia` 3 (`ambition_modifier` line 44: `= no`), `tooltip_map_mode` 1 (`court_language`, line 687). `texture` resolves under `game/main_menu/gfx/interface/icons/` (e.g. `flat_icons/overseas` → `…/icons/flat_icons/overseas.dds`, VERIFIED exists). `alias = { trigger triggers condition conditions }` lists alternative link words (line 62).

Loc (VERIFIED `game_concepts_l_english.yml:91-92`, Russian `game_concepts_l_russian.yml:76-77`):
```
 game_concept_overseas: "Overseas"
 game_concept_overseas_desc: "This is a [location|e] on another [continent|e] whose [sub_continent|e] does not border the [capital|e]'s [continent], by land or sea."
 game_concept_overseas: "Заморские земли"
```
Referencing: `[overseas|e]` / `[overseas|E]`, or in Russian with an inflected form `[Concept('overseas', 'заморских землях')|e]`. Aliases get their own key: INFERRED from `game_concept_unit_modifier` existing while the alias `unit_modifiers` has no separate description (plural alias uses `game_concept_<alias>` for the display word — add `game_concept_cw_headquarters_plural: "Headquarters"` if you alias; UNVERIFIED whether an alias without a loc key shows raw text).

### 5.2 Our concept (INFERRED composition of verified grammar)

```
# main_menu/common/game_concepts/cw_game_concepts.txt
cw_headquarters = {
	alias = { cw_hq cw_headquarters_plural }
	texture = "flat_icons/overseas"      # placeholder: reuse an existing icon until gfx is made
}
cw_colonial_headquarters = {
	alias = { cw_colonial_hq }
	texture = "flat_icons/overseas"
}
cw_war_stance = {
	alias = { cw_war_stances }
	texture = "alerts_icons/military"
}
```
Alerts can point at a concept via `game_concept = "policies"` (`alert_descriptions/00_default.txt:24`).

---

## 6. Alerts

### 6.1 `alert_descriptions` format (VERIFIED, `game/in_game/common/alert_descriptions/00_default.txt`, 137 entries)

```
   134	has_army_without_leader = {
   135		title = "ALERT_NO_LEADER_TITLE"
   136		hint = "hint_has_army_without_leader"
   137		texture = "alerts_icons/army_without_leader"
   138		priority = green
   139	}
   140	has_army_without_leader_in_war = {
   141		title = "ALERT_NO_LEADER_TITLE"
   142		hint = "hint_has_army_without_leader"
   143		texture = "alerts_icons/army_without_leader"
   144		priority = yellow
   145	}
```
Only five fields exist: `title` (loc key, e.g. `ALERT_NO_LEADER_TITLE: "Lack of Commander"` / RU `"Нет командира"`, `alerts_l_*.yml:35`), `texture` (under `main_menu/gfx/interface/icons/`), `priority` ∈ `blue(4) green(37) yellow(48) orange(39) red(8) purple(2)`, optional `hint` (a scripted-hint key, opened by the alert's hint button: `alertmanager.gui:463 OpenLateralViewWithParams('hints', LinkParam('selected_hint', AlertEntry.GetDescription.GetHint))`), optional `game_concept`.

**There is no `trigger`/`potential` field**: the alert condition and its click action (`AlertEntry.GetAlertAction.PerformAction`, `alertmanager.gui:446-452`) are C++. INFERRED/strong: a mod **cannot add a new alert type** (`cw_army_without_hq`) through `alert_descriptions`; it can only restyle/retitle existing keys (e.g. change `has_army_without_leader_in_war` to `priority = orange`). No `scripted_gui` is referenced from `alertmanager.gui` either.

### 6.2 What to do instead for "Army without HQ" (recommendation)

1. **Scripted hint** (fully scriptable, §7) — `hint_cw_army_without_hq = { priority = { <any cw_ trigger> } sort_priority = 200 }` appears in the Hints lateral view; `sort_priority = 200` "Corresponds to alert severity" (vanilla comment).
2. **Custom alert-bar widget**: a scripted GUI widget appended to the alert bar via a GUI override (covered in the GUI research doc). Visibility from script: `scripted_guis` entries have `scope = country` + `effect` (Simple Cheats `in_game/common/scripted_guis/sc_scripts.txt:2-5`); add an `is_shown = {}` trigger (UNVERIFIED for EU5 — standard Jomini scripted_gui field; check `in_game/common/scripted_guis/*.info` in the GUI doc).
3. The army-window "Headquarters" tab itself shows the penalty state (the strongest signal for the player).

---

## 7. Scriptable hints

VERIFIED grammar (`game/in_game/common/scriptable_hints/scripted_hints.txt`, fields: `priority` 81, `sort_priority` 83, `hint_tag` 75, `player_playstyle` 66 with `style = diplomatic/military/administrative` + `hint_tag`, `hide` 48; the `____info.txt` describes an older `needed = {}` form and warns the trigger is evaluated per frame — keep it cheap):
```
   528	hint_has_army_without_leader = {
   529		priority = { 
   530			is_alert_shown = has_army_without_leader
   531		}
   532		sort_priority = 200 #Corresponds to alert severity.
   533	}
```
```
     1	hint_in_deficit = {
     2		priority = { monthly_balance < 0 }
     3		sort_priority = 25
     4		hide = {} #9 times out of 10 you aren't gonna want to hide a tip. If the user wants to see it, why not let them.
     5		#icon = 
     6		player_playstyle = {
     7			style = diplomatic
     8			hint_tag = hint_in_deficit_diplomatic
     9		}
```
`is_alert_shown = <alert_key>` is a country trigger (29 usages) — usable anywhere in our scripts (e.g. to detect vanilla "army without leader").
Loc (VERIFIED `hints_l_english.yml:387-391`): `<hint>: "Lack of Commander"` (title), `<hint>_hint_text: "$<hint>_hint_text_1$\n\n$…_2$"` (body, vanilla splits into `_1/_2/_3` and uses `#T Recommended Actions:#!`, `@arrow_bonus_tier_3!`, `@hint!`, `[Link('unit_overview', '', 'lateralview_unit_overview_entry_name')]`). Playstyle variants: `hint_in_deficit_military: "\"War might be costly…\""` (`:59`). GUI: `hints_lateralview.gui:6 visible = "[ScriptedHintItem.ShouldShow]"`, `:40 IsHighPriority`, `:82 EqualTo_string(ScriptedHintItem.GetHintKey, 'hint_in_deficit')`; situations/disasters link to hints via `GetHintTag` (`alertmanager.gui:7644`).

---

## 8. Messages and notifications

### 8.1 Message types (VERIFIED, `game/main_menu/gui/messagetypes/00_messagetypes.txt`, 1470 entries; DLC adds `game/dlc/D009_…/main_menu/gui/messagetypes/d009_messagetypes.txt`, so additional files merge)

```
    41	REGIMENT_BUILT={
    42	log=no
    43	onmap=yes
    44	popup=no
    45	idle=no
    46	option=no
    47	pausepopup=no
    48	message_category = military
    49	}
```
Fields: `log`, `onmap`, `popup`, `idle`, `option`, `pausepopup`, `message_category` ∈ `diplomacy(656) society(333) government(201) geopolitics(118) wars(72) military(52) economy(43)`. Player overrides are saved to `Documents/…/messagetypes_custom.txt` (e.g. `SIEGEOVER_LOST={ settings={ onmap=yes } }`).
Loc per message key (VERIFIED `messages_l_english.yml:917-924`): `<KEY>_SETUP` (settings description), `_HEADER` (`"$MESSENGER$"`), `_TITLE`, `_DESC`, `_EFFECTS` (`"$EFFECT$"`), `_FLAVOR`, `_LOG`, `_BTN1`.

**The message keys are hardcoded C++ events** (REGIMENT_BUILT, SIEGEOVER_LOST, …). The only script-driven way to get a *message* with your own key is a **generic action** (`game/in_game/common/generic_actions/readme.txt:118-133`):
```
# Generic catch-all message: PERFORM_ + Key + _ACTION e.g. PERFORM_do_some_stuff_ACTION
# These are added as message types in the gui/messagetypes/ folder.
# When the player does the action: WE_PERFORM_ + Key + _ACTION
# When another country does it: OTHER_PERFORMS_ + Key + _ACTION
# When another country does it to us: ACTION_ + Key + _PERFORMED_ON_US
# presets: $ACTION$ (name) $EFFECT$ (effect) $DESC$ (<action_tag>_desc)
```
plus the optional `message = <key>` field on an action (`generic_actions/church_power.txt:18 message = national_church_action`), `show_message = no`, `show_message_to_target = no` (`country_interactions/incite_desertion.txt:6-7`). DLC example of the resulting type + loc: `d009_messagetypes.txt:1-9 WE_PERFORM_cas_demand_war_entry_ACTION = { log=yes onmap=no popup=yes idle=no option=yes pausepopup=no message_category = diplomacy }` and `d009_messages_l_english.yml:40-43 WE_PERFORM_cas_demand_war_entry_ACTION_TITLE: "Our Demand for War Entry Is Met!"`.

No free-form "send message/toast" effect exists in EU5 script: grep of `common`, `events`, `dlc` for `send_interface_message|send_interface_toast|post_notification|add_message|custom_message|send_message|show_message_effect` → none (`show_message` only appears as the yes/no field above). UNVERIFIED/absent — do not plan on it.

`game/main_menu/notifications/game.txt` (VERIFIED) is the **engine dialog** system (`level = dialog/alert`, `category`, `window_file`, `title_text`, `accept_text`, `decline_text` for things like "confirm delete mod") — not in-game country messages; irrelevant for us. `jomini/in_game/notifications/jomini_scripted_gui.txt` likewise.

### 8.2 Practical notification channels for the mod (ranked)

| Need | Channel | Verified basis |
|---|---|---|
| New HQ slot unlocked (age change / +100 locations) | `country_event` fired from `on_new_age` hook (player only) and from a monthly on-action when `cw_hq_limit` grows (compare with a stored variable); `interface_lock = no` if you do not want a pause | §1.4, §2.2, §2.6 |
| Army lost its HQ | `country_event` with the army saved in `immediate` (`save_scope_as = cw_army`), fired from the monthly HQ check / `on_battle_lost` (`_hardcoded.txt:3335`) / `on_siege_lost` (`:447`); one option; plus a scripted hint `hint_cw_army_without_hq` while any army lacks an HQ | §2.3, §7 |
| Enemy changed war stance | per-stance `country_event` (`trigger_event_silently`) sent to each human enemy: `every_country = { limit = { is_ai = no is_at_war_with = root } trigger_event_silently = { id = cw_events.3 } }` (`is_at_war_with` 400 usages, `is_enemy_of` 215); or one `major = yes` event with `major_trigger = { is_at_war_with = scope:from }` — but the plate in the top bar should remain the primary signal, and the event should be optional (game rule) because it fires often | §2.3, §2.4 |
| Tooltip-only information (penalty active, slots left) | `custom_tooltip` keys + `customizable_localization` | §3.5 |

Avoid `major = yes` for frequent stance changes (it spams all qualifying countries and creates message entries for everyone matching `major_trigger`).

---

## 9. Localization skeleton for the mod (RU + EN)

Files (both UTF-8-BOM): `main_menu/localization/english/cw_concentrated_warfare_l_english.yml`, `main_menu/localization/russian/cw_concentrated_warfare_l_russian.yml`. Keys follow the verified naming conventions above. Russian strings use `[Concept('key', 'inflected text')|e]` where a case other than nominative is needed (vanilla RU does this 22 874 times).

```yaml
l_english:
 ### Game concepts
 game_concept_cw_headquarters: "Headquarters"
 game_concept_cw_headquarters_desc: "A 100-man officer corps regiment. Only an [army|e] containing a $game_concept_cw_headquarters$ can [siege|e] and occupy at full speed and fight at full strength. There are no bonuses for having one — only penalties for lacking it. Slots are limited by [age|e] and by the number of owned [locations|e]."
 game_concept_cw_colonial_headquarters: "Colonial Headquarters"
 game_concept_cw_colonial_headquarters_desc: "A separate $game_concept_cw_headquarters$ pool granted for each [overseas|e] continent where we own enough [locations|e]. Removes the no-headquarters penalty anywhere; gives small expeditionary bonuses only while the army stands on an overseas continent."
 game_concept_cw_war_stance: "War Stance"
 game_concept_cw_war_stance_desc: "The current posture of an AI country at war: $cw_stance_offensive$, $cw_stance_defensive$, $cw_stance_waiting$, $cw_stance_harassing$ or $cw_stance_unknown$."
 ### Static modifiers (unit category)
 STATIC_MODIFIER_NAME_cw_no_hq: "No Headquarters"
 STATIC_MODIFIER_DESC_cw_no_hq: "This army has no [cw_headquarters|E]. It cannot conduct a proper [siege|e] and fights without coordination."
 STATIC_MODIFIER_NAME_cw_expeditionary: "Expeditionary Corps"
 STATIC_MODIFIER_DESC_cw_expeditionary: "A [cw_colonial_headquarters|E] is leading this army on an [overseas|e] continent."
 ### War stances
 cw_stance_offensive: "Offensive"
 cw_stance_defensive: "Defensive"
 cw_stance_waiting: "Waiting"
 cw_stance_harassing: "Harassing"
 cw_stance_unknown: "Unknown"
 cw_stance_plate_tt: "#T [cw_war_stance|E] of [SCOPE.sCountry('cw_enemy').GetName]#!\n[SCOPE.sCountry('cw_enemy').Custom('cw_stance_desc')]"
 cw_stance_desc_offensive: "Seeks a decisive battle. Expect its main army to advance on us."
 cw_stance_desc_defensive: "Holds its fortresses and waits for us to attack."
 cw_stance_desc_waiting: "Gathers forces and allies before acting."
 cw_stance_desc_harassing: "Avoids pitched battles; strikes small detachments and besieges our rear."
 cw_stance_desc_unknown: "The stance changed recently and our scouts have not reported yet."
 ### Events (namespace cw_events)
 cw_events.1.title: "A New Headquarters Slot"
 cw_events.1.desc: "With the dawn of the [GetCurrentAge.GetName] our officer corps may now field more headquarters. We can establish #V [ROOT.ScriptValue('cw_hq_limit')|V0]#! headquarters in total."
 cw_events.1.a: "Appoint the staff."
 cw_events.2.title: "An Army Has Lost Its Headquarters"
 cw_events.2.desc: "The officer corps of [cw_army.GetName] has been destroyed. Until a new [cw_headquarters|e] is assigned, the army will besiege at a fraction of its speed and fight poorly."
 cw_events.2.a: "Reorganize."
 cw_events.3.title: "Enemy Changes Its War Stance"
 cw_events.3.desc: "Our scouts report that [cw_enemy.GetName] has changed its [cw_war_stance|e] to #V [cw_enemy.Custom('cw_stance_text')]#!."
 cw_events.3.a: "Noted."
 ### Decisions
 cw_auto_hq_decision.title: "Entrust Headquarters Placement to the General Staff"
 cw_auto_hq_decision.desc: "Let the general staff place and move our [cw_headquarters|e] automatically, using the same rules as other courts."
 cw_auto_hq_decision.a: "Let them handle it."
 cw_auto_hq_decision_cooldown_tt: "Can be changed again in one year"
 CW_DECISION_CATEGORY_MILITARY: "Military"
 ### Hints / tooltips
 hint_cw_army_without_hq: "Army Without Headquarters"
 hint_cw_army_without_hq_hint_text: "$hint_cw_army_without_hq_hint_text_1$\n\n$hint_cw_army_without_hq_hint_text_2$"
 hint_cw_army_without_hq_hint_text_1: "One of our [armies|e] has no [cw_headquarters|e] and suffers the $STATIC_MODIFIER_NAME_cw_no_hq$ penalty."
 hint_cw_army_without_hq_hint_text_2: "#T Recommended Actions:#!\n@arrow_bonus_tier_3! Open the army and use the #W Headquarters#! tab to assign one, if a slot is free.\n@arrow_bonus_tier_2! Merge the army into one that already has a headquarters."
 cw_hq_slots_tt: "Headquarters: #V $USED$/$MAX$#! (home) · #V $CUSED$/$CMAX$#! (colonial)"
 cw_no_free_slot_tt: "No free headquarters slot"
```

```yaml
l_russian:
 ### Игровые понятия
 game_concept_cw_headquarters: "Штаб"
 game_concept_cw_headquarters_desc: "Полк офицерского корпуса в 100 человек. Только [Concept('army', 'армия')|e] со штабом ведёт [Concept('siege', 'осаду')|e] и оккупирует с нормальной скоростью и сражается в полную силу. Бонусов за штаб нет — только штрафы за его отсутствие. Число штабов ограничено [Concept('age', 'эпохой')|e] и количеством владеемых [Concept('locations', 'локаций')|e]."
 game_concept_cw_colonial_headquarters: "Колониальный штаб"
 game_concept_cw_colonial_headquarters_desc: "Отдельный лимит штабов за каждый заморский континент, где у нас достаточно [Concept('locations', 'локаций')|e]. Снимает штраф «без штаба» где угодно; небольшие экспедиционные бонусы действуют только за морем."
 game_concept_cw_war_stance: "Стадия войны"
 game_concept_cw_war_stance_desc: "Текущая позиция воюющей страны под управлением ИИ: $cw_stance_offensive$, $cw_stance_defensive$, $cw_stance_waiting$, $cw_stance_harassing$ или $cw_stance_unknown$."
 ### Статические модификаторы
 STATIC_MODIFIER_NAME_cw_no_hq: "Без штаба"
 STATIC_MODIFIER_DESC_cw_no_hq: "У этой армии нет [Concept('cw_headquarters', 'штаба')|e]. Она не способна вести полноценную [Concept('siege', 'осаду')|e] и сражается несогласованно."
 STATIC_MODIFIER_NAME_cw_expeditionary: "Экспедиционный корпус"
 STATIC_MODIFIER_DESC_cw_expeditionary: "Армией на заморском континенте руководит [Concept('cw_colonial_headquarters', 'колониальный штаб')|e]."
 ### Стадии войны
 cw_stance_offensive: "Наступление"
 cw_stance_defensive: "Оборона"
 cw_stance_waiting: "Выжидание"
 cw_stance_harassing: "Изматывание"
 cw_stance_unknown: "Неизвестно"
 cw_stance_plate_tt: "#T [Concept('cw_war_stance', 'Стадия войны')|e]: [SCOPE.sCountry('cw_enemy').GetName]#!\n[SCOPE.sCountry('cw_enemy').Custom('cw_stance_desc')]"
 cw_stance_desc_offensive: "Ищет генеральное сражение. Ждите наступления главной армии."
 cw_stance_desc_defensive: "Держится своих крепостей и ждёт нашего удара."
 cw_stance_desc_waiting: "Собирает силы и союзников, прежде чем действовать."
 cw_stance_desc_harassing: "Избегает крупных боёв, бьёт мелкие отряды и осаждает наш тыл."
 cw_stance_desc_unknown: "Стадия сменилась недавно — разведка ещё не донесла."
 ### События
 cw_events.1.title: "Новый слот штаба"
 cw_events.1.desc: "С наступлением эпохи [GetCurrentAge.GetName] наш офицерский корпус может содержать больше штабов. Всего доступно: #V [ROOT.ScriptValue('cw_hq_limit')|V0]#!."
 cw_events.1.a: "Назначить штаб."
 cw_events.2.title: "Армия потеряла штаб"
 cw_events.2.desc: "Офицерский корпус армии [cw_army.GetName] уничтожен. Пока не назначен новый [Concept('cw_headquarters', 'штаб')|e], армия осаждает в разы медленнее и плохо сражается."
 cw_events.2.a: "Переформировать."
 cw_events.3.title: "Противник сменил стадию войны"
 cw_events.3.desc: "Разведка доносит: [cw_enemy.GetName] перешёл к стадии #V [cw_enemy.Custom('cw_stance_text')]#!."
 cw_events.3.a: "Принято."
 ### Решения
 cw_auto_hq_decision.title: "Доверить размещение штабов Генштабу"
 cw_auto_hq_decision.desc: "Генеральный штаб будет сам ставить и переносить наши [Concept('cw_headquarters', 'штабы')|e] по тем же правилам, что и у других держав."
 cw_auto_hq_decision.a: "Пусть занимаются."
 cw_auto_hq_decision_cooldown_tt: "Изменить можно будет через год"
 CW_DECISION_CATEGORY_MILITARY: "Военные"
 ### Подсказки
 hint_cw_army_without_hq: "Армия без штаба"
 hint_cw_army_without_hq_hint_text: "$hint_cw_army_without_hq_hint_text_1$\n\n$hint_cw_army_without_hq_hint_text_2$"
 hint_cw_army_without_hq_hint_text_1: "Одна из наших [Concept('armies', 'армий')|e] не имеет [Concept('cw_headquarters', 'штаба')|e] и получает штраф «$STATIC_MODIFIER_NAME_cw_no_hq$»."
 hint_cw_army_without_hq_hint_text_2: "#T Что делать:#!\n@arrow_bonus_tier_3! Откройте армию и на вкладке #W Штаб#! назначьте штаб, если есть свободный слот.\n@arrow_bonus_tier_2! Объедините армию с той, у которой штаб уже есть."
 cw_hq_slots_tt: "Штабы: #V $USED$/$MAX$#! (домашние) · #V $CUSED$/$CMAX$#! (колониальные)"
 cw_no_free_slot_tt: "Нет свободного слота штаба"
```
Notes on the skeleton: `[ROOT.ScriptValue('cw_hq_limit')|V0]` follows the VERIFIED form `[ROOT.ScriptValue('assassinate_character_spy_network_cost')|V0]` (`country_interactions_l_english.yml:629`; ROOT = country in a country_event); a variable can be printed the same way: `[ROOT.GetVariable('cw_hq_limit_shown').GetValue|V0]` (`events/DHE/flavor_byz_l_english.yml:531`). `cw_army.GetName` assumes the saved scope is a unit and that units expose `GetName` (INFERRED — vanilla loc only shows `[UnitTypeItem.GetUnitType.GetName]`; verify against the GUI doc). `$USED$/$MAX$` placeholders are only filled by code — in script-driven GUI, build the text with separate text widgets or `GetVariable(...).GetValue` calls instead.

---

## 10. Pitfalls

1. **Folder names**: `common/on_action` (singular). `common/on_actions/` is ignored (Cheat Menu Pro has such a dead folder). Game concepts, static_modifiers, modifier_type_definitions, game_rules and **all localization** live under `main_menu/`, not `in_game/`.
2. **BOM**: every `.txt/.yml/.gui` must be UTF-8 with BOM; the lexer logs `should be in utf8-bom encoding` otherwise (debug.log, verified for workshop files). Loc without BOM may silently fail to load (UNVERIFIED but likely).
3. **Loc header/indent**: `l_russian:` on line 1 of a `*_l_russian.yml`, one space before each key, no `:0` numbers needed (vanilla has none). A Russian file put in `english/` is still parsed by header, but keep them consistent.
4. **No new alert types** via `alert_descriptions` (C++ keys, no trigger field). Use scripted hints + custom GUI.
5. **No scripted message/toast effect** exists; message type keys are hardcoded except the generic-action naming pattern. Use events.
6. **Events**: forgetting `namespace = cw_events` on line 1 breaks the file; events never referenced by an on_action/effect log an "unreferenced" error unless `orphan = yes`; `age_event` is reserved for the vanilla age window — use `country_event`. Events with `trigger = {}` fired via on_action lists must pass the trigger both at fire time and after the `delay`.
7. **`current_age_or_later` syntax** is `{ age = age_3_discovery }` (block), while `current_age = age_3_discovery` is a plain equality. There is no "or earlier" trigger.
8. **Decisions** have no `cooldown`, no per-option `trigger`; cooldowns are variables with `days =`. `only_once = yes` without `only_once_scope = country` is INFERRED to be global-per-decision (vanilla adds `only_once_scope = country` on flavor decisions — copy that).
9. **Scripted hints are evaluated per frame** (`____info.txt`): keep `priority` triggers trivial (check a country variable/flag set by the monthly script, not `any_army = {…}` scans).
10. `on_new_age` runs for **all** countries; gate player notifications with `is_ai = no` in a sub-on-action trigger. Effects in an on_action's `effect = {}` cannot pass scopes to the events it fires (documented in `on_actions.info`).
11. **Age modifiers already scale warscore** (`lack_of_control_impact_on_warscore`, `global_war_score_efficiency`) — balance the rural-warscore change per age.
12. Alert `hint` keys and scripted hint keys share one namespace (`hint_has_army_without_leader` is both the hint entry and the alert's `hint` value); name ours `hint_cw_*`.
13. Russian text: use `[Concept('key', 'инфлексия')|e]` for cases; `$key$` nesting is case-blind, so nest only nominative labels (stance names, modifier names).

---

## 11. Recommendations for the mod

1. **Age gating**: do not ship a modified `common/age/00_default.txt`; compute `cw_hq_slots_by_age` with `current_age_or_later` (§1.3) and read ages only through triggers. Keep age keys as constants: `age_1_traditions … age_6_revolutions`.
2. **Hooks**: `on_new_age` → `cw_on_new_age` (player notification event + AI re-distribution effect), `on_battle_lost`/`on_siege_lost`/`on_war_declared` sub-on-actions for HQ checks, plus a monthly pulse in `country_monthly` style file (`common/on_action/country_monthly.txt` exists in vanilla — verify its root on-action name in the AI/on-action doc before hooking).
3. **Notifications**: three `country_event`s in `in_game/events/cw_events.txt` (namespace `cw_events`): `.1` new slot (fired for `is_ai = no` only), `.2` army lost HQ (`interface_lock = no`, one option), `.3` enemy stance changed (optional via game rule; fired with `trigger_event_silently` to each human enemy, throttled by the 2-month stance cooldown). Mark all three `orphan = yes` only if some are fired exclusively from scripted GUI/effects that the validator cannot trace; otherwise leave default.
4. **Hints**: one scripted hint `hint_cw_army_without_hq` driven by a country flag (`has_variable = cw_has_army_without_hq`) set by the monthly check; `sort_priority = 200`.
5. **Decisions**: `cw_auto_hq_decision` (category `government_decisions` or a new `cw_military_decisions`), `potential = { is_ai = no }`, cooldown via `set_variable … days = 365`, `ai_will_do = { value = 0 }`.
6. **Concepts**: add `cw_headquarters`, `cw_colonial_headquarters`, `cw_war_stance` with placeholder vanilla textures (`flat_icons/overseas`, `alerts_icons/military`, both VERIFIED paths), and reference them everywhere as `[cw_headquarters|e]` so tooltips become consistent.
7. **Localization**: one EN and one RU file (skeleton §9), BOM, no version numbers; reuse vanilla format codes `#T #V #W #G #R #!` and icons `@warning_icon! @army_strength! @hint!`. Localize `STATIC_MODIFIER_NAME_/DESC_` for `cw_no_hq` and `cw_expeditionary`; no `effect_localization` entries required unless a scripted effect's auto-tooltip is unreadable.
8. **Validation**: extend `tools/validate.sh` to check that every `cw_events.N` referenced by on-actions/effects exists, that every `*.title/.desc/.a` key exists in both languages, and that all `.yml` begin with BOM + `l_<lang>:`.
