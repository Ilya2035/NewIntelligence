# New Intelligence: Battle — Technical Specification (v0.3; formerly "Concentrated Warfare", internal prefix `cw_`)

> **v0.3 — applied tuning (2026-11-04).** The mod is now named **"New Intelligence: Battle"** (collection "New Intelligence"); the mod root is `mods/new_intelligence_battle` (launcher junction `mod\new_intelligence_battle`). All `cw_` keys and file names are kept. The final numbers and rules, as in the files:
> - **Penalty tiers** (`cw_unit_modifiers.txt`, game rule `cw_rule_hq_penalty`): standard `cw_no_hq` discipline −20 % / morale −25 %; mild −10 / −10; harsh −30 / −30; siege ability −90 % and assault ability −50 % in all three.
> - **Organized** = the right HQ **plus at least two other regiments** (`cw_min_subunits_organized = 3`): a home HQ organizes anywhere, a colonial HQ only on overseas ground.
> - **Colonial HQ at home** (only HQ colonial, non-overseas ground, ≥ 3 regiments): siege-only tier `cw_no_hq_siege_only` (siege −90 % / assault −50 %, full combat strength); a home HQ placed into the same army organizes it (the "Place headquarters" button accepts an army without a *home* HQ).
> - **Home limit** = 1 + imperial slot (≥ 300 own locations, any age) + min(age slots 0/0/1/2/3/4, one per 75 own locations), cap 5, floor 1; no age slots while the isolated military tradition is active.
> - **Colonial limit**: per overseas continent 1 (≥ 5 overseas locations or a ≥ 3-regiment army there, Age of Discovery+), +1 at 25 (Reformation+), +1 at 60 (Absolutism+); the 25 / 60 tiers **count the land of subjects at any depth** (`any_subject_or_below`); cap 4.
> - **Rebels** (`is_rebel_country`) get `cw_rebel_disorder` (discipline −20 % / morale −25 %, no siege term) on every army; nothing else of the HQ system touches them.
> - **Hordes are not exempt** (`country_type = army` is every steppe horde); only conquistador hosts are, via `is_subject_type = conquistador` (`cw_is_real_country`).
> - **War stances**: offensive enters at `relative_military_strength` 0.57 and is kept down to 0.53 (band 0.04); harassing enters at 0.33 and is kept up to 0.38 (band 0.05); offensive also needs war score ≥ −10 against the main enemy; fielded-strength term (own `army_size` ≤ 0.5 × the enemy's → harassing); losing badly (war score < −25 or war exhaustion ≥ 8) → harassing; **waiting = attacker AND (young war < 1 year OR army below 80 % of its expected size)**, defenders at parity are defensive; 2-month stance lock.
> - **Intelligence delay**: the player sees "Unknown" for **one month** after an AI stance change (expiring variable `cw_stance_changed`), separate from the lock.
> - **War defines** (`cw_war_defines.txt`): `WAR_WORTH_BASE` 0.5, `WAR_WORTH_COUNTRY_CAPITAL` 15 (+10 one-off capital bonus), `OCCUPATION_VALUE_SCALE` 1.3, `WAR_WORTH_DEVELOPMENT_MIN` −0.25, `WAR_WORTH_BUILDING_SCALE` 0.025 (vanilla), building cap 15, population scale 0.03 / cap 6, province capital 2, port 2.
> - **Rank war-score efficiencies** (`location_ranks/00_default.txt`): city −0.15, megalopolis −0.25; villages and towns vanilla.
> - **Native penalty** (`cw_is_american_native` / `cw_has_isolated_tradition`): capital on `continent:america`, not the subject of a non-American overlord, Pike and Shot not embraced, not reformed, game rule on — **no government/tribe clause**; mirrored inline in `cw_limit_values.txt` and in the auto modifier.
> - **AI define hedges** (`cw_ai_defines.txt`): `HEAVILY_OUTNUMBERED_RATIO` 0.45, `AI_SUPPORT_ARMIES_DESIRED_STRENGTH_FACTOR` 0.33 and `AI_ENEMY_STRENGTH_NO_SUPPORT_ARMIES_FACTOR` 2 (both vanilla on purpose), `AI_RECOVER_MORALE_THRESHOLD` 70, `RATIO_OVER_SUPPLY_TARGET_TO_SPLIT` 1.5.
>
> The sections below are updated to this state; §16 / §17 keep the history.

Contract for implementation. Key prefix `cw_`. Game EU5 1.4.7. Every syntax element below was verified in `docs/research/*.md` unless tagged **TODO-verify** (then the closest verified alternative is named). When a research doc contradicts this spec, the research doc wins; note the deviation in a code comment.

## 0. Conventions and engine facts that shape the design
- Script `.txt` and `.yml` files start with a UTF-8 BOM; `.gui` files have none. Loc files: `main_menu/localization/<lang>/cw_concentrated_warfare_l_<lang>.yml`, first line `l_<lang>:`, one leading space per key, **no version numbers** (`key: "text"`).
- **Database rule: first definition wins.** A mod cannot override a vanilla key by redefining it in a new file (the duplicate is silently dropped, logged in debug.log). To change vanilla objects: copy the whole file to the same relative path (location ranks) or use `REPLACE:`/`INJECT:` keywords (unverified locally – avoid). New `cw_` keys in new files are always safe.
- **On_actions merge**: redefining a vanilla on_action key in a new file with only `on_actions = { cw_x }` appends (vanilla does it itself). Never put `trigger`/`effect`/`events` under a vanilla key — only under our own `cw_*` on_actions.
- Defines: partial override files in `loading_screen/common/defines/` (wiki-documented, not locally verified).
- Triggers/effects to use: `at_war = yes` (NOT is_at_war), `is_real_country = yes`, `is_ai = yes/no`, `trigger_event_silently/trigger_event_non_silently = { id = X days = N }` (no plain trigger_event), `set_variable = { name = X value = Y }`, expiring variables `set_variable = { name = X months = 3 }` (used as cooldowns), `has_variable`, `var:x`, `add_country_modifier = { modifier = X months = N mode = replace }`, `remove_country_modifier`, `add_unit_modifier = { modifier = X years = 1 mode = replace }`, `remove_unit_modifier = X`, `has_unit_modifier = X`, `add_subunit = unit_type:X` (unit scope), `destroy_subunit = yes` (sub_unit scope), vanilla scripted effect `destroy_every_sub_unit_of_type = { sub_unit_type = unit_type:X }` (unit scope), `ordered_army = { limit = {} order_by = num_subunits max = N check_range_bounds = no ... }`, `any_sub_unit = { sub_unit_type = unit_type:X }`, `total_sub_unit_type_count:cw_hq` (country value/trigger), `num_locations` (country value/trigger), `current_age = age_3_discovery` (trigger inside values) and `current_age_or_later = { age = age_3_discovery }`, `relative_military_strength = { target = X value >= 0.55 }`, `every_current_war`/`any_current_war` with `is_an_attacker = root`, `attacker_leader`, `defender_leader`, `war_score_of_country = { country = root value < -10 }`, `war_length_in_years`, `war_exhaustion`, `war_enthusiasm`, `months_since_war`, `any_country_at_war_with`, `ruler ?= { has_trait = X }`, unit→commander link `leader` (`leader ?= { has_trait = X }`), unit triggers `is_army`, `is_exiled`, `in_combat`, `in_retreat`, `in_siege`, `has_regulars`, `has_levies`, `has_mercenaries`, `has_only_prisoners`, `num_subunits`, `unit_location`, `owner`; location triggers `is_capital`, `location_rank = location_rank:city`, `continent = continent:america`, `continent != root.capital.continent`, `is_overseas_for_owner = yes` (owned locations), `would_be_overseas_for = <country>` (any location, e.g. an army's location), `any_owned_location = { count >= 5 ... }`.
- Continent keys: `continent:europe`, `continent:asia`, `continent:africa`, `continent:america` (one continent; north/south are sub-continents), `continent:oceania`.
- "Overseas" in game terms = another continent whose sub-continent does not border the capital's continent by land or sea. Use the game concept (`would_be_overseas_for` / `is_overseas_for_owner`), iterate theatres by continent key.
- GUI: scripted widgets registry `in_game/gui/scripted_widgets/cw_scripted_widgets.txt` (`gui/cw_x.gui = cw_window_name`), root widget needs a function-valued `visible`. Scripted GUIs called as `[GetScriptedGui('key').Execute(GuiScope.SetRoot(GetPlayer.MakeScope).AddScope('loc', Unit.GetLocation.MakeScope).End)]`, `.IsValid(...)`, `.IsShown(...)`. Script variables read as `[GetPlayer.MakeScope.GetVariable('cw_hq_count_v').GetValue|0]`. `Unit.MakeScope` is **TODO-verify** (never used in vanilla) → unit-targeted scripted GUIs take the player as root and the unit's location as `scope:loc`, and resolve the army in script.
- Army window tabs: `single_unit_window.gui` must be copied whole; tab state via `SingleUnitWindow.Vars` (`NotExistOrHasValue('tab','actions')` already gates vanilla content; add `HasValue('tab','headquarters')`).

## 1. Files (owner module in brackets)

| Path | Content |
|---|---|
| `in_game/common/unit_types/cw_headquarters.txt` [hq_core] | `cw_hq`, `cw_hq_colonial` |
| `in_game/common/prices/cw_prices.txt` [hq_core] | per-unit price overrides making HQs ~free |
| `in_game/common/goods_demand/cw_demands.txt` [hq_core] | near-zero demand templates |
| `main_menu/common/script_values/cw_limit_values.txt` [hq_core] | `cw_hq_limit`, `cw_colonial_hq_limit` and helpers (vanilla keeps unit limits here) |
| `in_game/common/script_values/cw_values.txt` [hq_core] | counters, knobs |
| `in_game/common/scripted_triggers/cw_triggers.txt` [hq_core] | |
| `in_game/common/scripted_effects/cw_effects.txt` [hq_core] | organization, AI assignment, limits cache, player helpers |
| `in_game/common/on_action/cw_on_actions.txt` [hq_core] | hooks (§5) |
| `in_game/events/cw_events.txt` [hq_core] | namespaces `cw_events`, `cw_tick` |
| `in_game/common/decisions/cw_decisions.txt` [hq_core] | `cw_toggle_auto_hq` (category `government_decisions`) |
| `in_game/common/scriptable_hints/cw_hints.txt` [hq_core] | hint "army without HQ" (format: research 11 §7) |
| `in_game/common/script_values/cw_stance_values.txt`, `scripted_triggers/cw_stance_triggers.txt`, `scripted_effects/cw_stance_effects.txt`, `on_action/cw_stance_on_actions.txt` [ai_stance] | war stances |
| `in_game/common/subject_military_stances/cw_stances.txt` [ai_stance] | `cw_escort_military_stance` (new key only; vanilla default untouched) |
| `in_game/events/cw_stance_events.txt` [ai_stance] | namespace `cw_stance`: `cw_stance.1` "enemy changed its war stance" (as built; replaces the planned `cw_events.3`, §16) |
| `loading_screen/common/defines/cw_ai_defines.txt` [ai_stance] | `NAI` overrides |
| `loading_screen/common/defines/cw_war_defines.txt` [warscore_rules] | `NWar` overrides |
| `in_game/common/location_ranks/00_default.txt` [warscore_rules] | full copy of vanilla + `local_war_score_efficiency` per rank |
| `in_game/common/on_action/cw_warscore_on_actions.txt` + `scripted_effects/cw_warscore_effects.txt` [warscore_rules] | capital bonus warscore on siege/occupation (**TODO-verify** `add_bonus_warscore` usage) |
| `in_game/common/auto_modifiers/cw_auto_modifiers.txt` [warscore_rules] | `cw_isolated_tradition_auto` (country) |
| `in_game/common/decisions/cw_native_decisions.txt` [warscore_rules] | `cw_reform_war_host` |
| `main_menu/common/game_rules/cw_game_rules.txt` [warscore_rules] | 4 rules |
| `main_menu/common/game_concepts/cw_concepts.txt` [warscore_rules] | `cw_headquarters`, `cw_colonial_headquarters`, `cw_war_stance` |
| `main_menu/common/scripted_triggers/cw_warscore_triggers.txt` [warscore_rules] | `cw_is_american_native`, `cw_has_isolated_tradition`, `cw_can_reform_war_host` (menu stage on purpose, §16) |
| `main_menu/common/static_modifiers/cw_unit_modifiers.txt`, `cw_country_modifiers.txt` | done (ai_stance/warscore_rules may append) |
| `in_game/gui/cw_war_stance_plate.gui`, `in_game/gui/cw_hq_overview.gui`, `in_game/gui/scripted_widgets/cw_scripted_widgets.txt`, `in_game/common/scripted_guis/cw_scripted_guis.txt` [gui_windows] | |
| `in_game/gui/single_unit_window.gui` [gui_army_tab] | vanilla copy + 4th tab |
| `main_menu/localization/{russian,english}/cw_concentrated_warfare_l_*.yml` [localize] | |

## 2. Unit types (`cw_headquarters.txt`)
```
cw_hq = {
	category = army_auxiliary      # reserves, auxiliary art/model/icons for free; exclude_from_combined_arms comes from the category
	age = "age_1_traditions"       # icon only; no upgrades_to => same unit all game
	is_special = yes
	buildable = yes
	levy = no
	max_strength = 0.1             # 100 men (REGIMENT_SIZE 1000, category max_strength 0; stats are additive)
	combat_power = 0.25            # like vanilla auxiliaries
	construction_demand = cw_hq_construction_demand   # as built: "_demand" suffix, see §16
	maintenance_demand = cw_hq_maintenance_demand
	country_potential = { always = yes }
	limit = cw_hq_limit            # main_menu/common/script_values/cw_limit_values.txt
	gfx_tags = { medium_tag }
}
cw_hq_colonial = {   # defined in full (copy_from inheritance of limit/potentials unverified)
	category = army_auxiliary  age = "age_3_discovery"  is_special = yes  buildable = yes  levy = no
	max_strength = 0.1  combat_power = 0.25
	construction_demand = cw_hq_construction_demand  maintenance_demand = cw_hq_maintenance_demand
	country_potential = { current_age_or_later = { age = age_3_discovery }  cw_has_overseas_theatre = yes }
	location_potential = { is_overseas_for_owner = yes }     # recruitable only overseas (player); AI gets them by script
	limit = cw_colonial_hq_limit
	gfx_tags = { medium_tag }
}
```
Prices (`cw_prices.txt`, additive per-unit overrides on `army_auxiliary_*`: build gold 100/manpower 1, reinforce 5/1, maintenance 1/0.02): `cw_hq_build = { gold = -95 manpower = -0.9 }`, `cw_hq_reinforce = { gold = -4.5 manpower = -0.9 }`, `cw_hq_maintenance = { gold = -0.9 manpower = -0.018 }`, same for `cw_hq_colonial_*` → ~5 gold, practically free, never 0/negative. Goods demand templates near zero (`paper = 0.01` with the right `category`), see research 01 §4.1/§12.3.

## 3. Limits and counters
`main_menu/common/script_values/cw_limit_values.txt` (country scope; `desc = "KEY"` entries need loc):
```
cw_age_hq_slots:   0 (age 1-2), 1 (age_3_discovery), 2 (age_4), 3 (age_5), 4 (age_6)   [if/else_if on current_age]; 0 while cw_has_isolated_tradition
cw_size_hq_slots:  value = num_locations  divide = 75  floor = yes                                            # tuning pass: 100 → 75 (research 14 R2)
cw_hq_limit:       add = { value = 1 desc = "SUBUNIT_LIMIT_BASE" }
                   if = { limit = { num_locations >= 300 } add = { value = 1 desc = "CW_HQ_LIMIT_IMPERIAL" } }   # imperial slot, any age (tuning pass)
                   add = { value = cw_age_hq_slots  max = cw_size_hq_slots  desc = "CW_HQ_LIMIT_AGE_AND_SIZE" }   # min(age, size)
                   max = { value = 5 desc = "CW_HQ_LIMIT_CAP" }
                   min = { value = 1 desc = "CW_HQ_LIMIT_MIN" }
cw_colonial_hq_limit: 0 before age_3_discovery or while isolated tradition; else for each continent C in {europe asia africa america oceania}, C != capital.continent:
                   theatre active if any_owned_location = { count >= 5 continent = continent:C is_overseas_for_owner = yes }
                                 OR any_army = { num_subunits >= 3 unit_location = { continent = continent:C would_be_overseas_for = root } }   # expeditionary free slot
                   +1 per active theatre; +1 if count >= 25 there (own overseas land, or land of any subject at any depth: any_subject_or_below, tuning pass) and age >= 4; +1 if count >= 60 there and age >= 5; cap 4
```
Knobs in `cw_values.txt`: `cw_min_subunits_for_ai_hq = 3`, `cw_min_subunits_organized = 3` (an army counts as organized only if it has the right HQ AND num_subunits >= 3 → neither a lone HQ nor "HQ + one regiment" can occupy; tuning pass), `cw_stance_lock_months = 2`, `cw_peace_cadence_months = 3`. Counters: `total_sub_unit_type_count:cw_hq`, `:cw_hq_colonial`. Cached variables for GUI (set by `cw_cache_limits`): `cw_hq_limit_v`, `cw_hq_count_v`, `cw_colonial_hq_limit_v`, `cw_colonial_hq_count_v`.

## 4. Modifiers (already written; may be tuned)
Unit: `cw_no_hq` (siege −90 %, assault −50 %, discipline −20 %, morale −25 %), `cw_no_hq_mild` (−10/−10), `cw_no_hq_harsh` (−30/−30; the siege / assault terms are shared), `cw_no_hq_siege_only` (siege −90 %, assault −50 % only: colonial HQ outside its theatre), `cw_rebel_disorder` (discipline −20 %, morale −25 %, no siege term: rebel armies), `cw_expeditionary` (−15 % attrition, +10 % movement, +10 % morale recovery). Numbers as tuned on 2026-11-04 (§17). Country: `cw_stance_offensive/defensive/waiting/harassing` (ai=yes types + `regiment_reinforcement_speed 0.1` on waiting). The native handicap is the auto modifier `cw_isolated_tradition_auto` (§9); the former static twin `cw_isolated_tradition` was deleted in the tuning pass. Loc keys `STATIC_MODIFIER_NAME_<key>` / `STATIC_MODIFIER_DESC_<key>`.

## 5. Scheduling (`cw_on_actions.txt`)
```
monthly_country_pulse       = { on_actions = { cw_monthly_pulse cw_monthly_rebel_pulse } }   # rebel countries: cw_rebel_disorder only (§17)
on_game_started_after_lobby = { on_actions = { cw_on_game_start } }      # global → every_country = { limit = { cw_is_real_country = yes } ... }
on_new_age                  = { on_actions = { cw_on_new_age } }         # root = country
on_war_declared             = { on_actions = { cw_on_war_start } }       # use scope:actor / scope:recipient explicitly; idempotent
on_join_war                 = { on_actions = { cw_on_war_start } }       # root = joiner
on_ending_war               = { on_actions = { cw_on_war_end } }         # fires once per side
on_battle_won               = { on_actions = { cw_on_battle } }         # scope:actor / scope:target are units → re-check those two only (on_battle_lost carries the same pair and is NOT hooked, §16)
on_command_gained           = { on_actions = { cw_on_command } }         # root = character, scope:unit → re-check scope:unit
on_revolt_start / on_civil_war_start = { on_actions = { cw_on_revolt_start } }   # scope:target = the rebel country → cw_rebel_disorder at once (§17)
```
`cw_monthly_pulse` (trigger `cw_is_real_country = yes`):
1. `cw_cache_limits`.
2. If `at_war = yes`: `cw_update_army_organization`; AI (or player with `cw_auto_hq`): `cw_ai_assign_hqs`; AI: `cw_cleanup_excess_hqs`.
3. Else (peace): only when `NOT has_variable = cw_peace_cooldown` → `set_variable = { name = cw_peace_cooldown months = 3 }` (staggered quarterly) and run the same work.
4. Player: `cw_player_notifications` (new slot: compare `cw_hq_limit` with stored `cw_hq_limit_seen`; fire `cw_events.1`).
`cw_is_real_country = { is_real_country = yes  NOT = { is_subject_type = conquistador } }` (conquistador hosts and rebels exempt). As built — **not** `NOT = { country_type = army }`: every steppe horde is an army-type country (research 14 F1) and must stay covered, see §16.
War ticker: `cw_on_war_start` runs the organization update immediately and starts `cw_tick.1` (hidden country event, 15-day re-fire while `at_war = yes`, guarded by `set_variable = { name = cw_tick_scheduled days = 14 }` + `NOT = { has_variable = cw_tick_scheduled }` in the event trigger).

## 6. Organization and AI assignment (`cw_effects.txt`)
`cw_update_army_organization` (country):
```
every_army = {
	limit = { cw_unit_is_exempt = no }                      # exempt: is_exiled, has_only_prisoners, is_lent_unit
	if = { limit = { cw_unit_is_organized = yes }           # home HQ anywhere, or colonial HQ on overseas ground, AND num_subunits >= cw_min_subunits_organized (3)
		if = { limit = { has_unit_modifier = cw_no_hq } remove_unit_modifier = cw_no_hq }   # also the mild/harsh variants
		if = { limit = { cw_unit_has_colonial_hq = yes  unit_location = { would_be_overseas_for = root } }
			add_unit_modifier = { modifier = cw_expeditionary years = 1 mode = replace } }
		else_if = { limit = { has_unit_modifier = cw_expeditionary } remove_unit_modifier = cw_expeditionary }
	}
	else_if = { limit = { cw_unit_has_colonial_hq_at_home = yes } add_unit_modifier = { modifier = cw_no_hq_siege_only years = 1 mode = replace } }   # colonial HQ outside its theatre (§17)
	else = { add_unit_modifier = { modifier = <cw_no_hq | mild | harsh by game rule> years = 1 mode = replace } }
}
```
(Inside `every_army` the root is still the country; use `root`/`prev` carefully — see research 02 §1.)
`cw_ai_assign_hqs` (country; AI or `cw_auto_hq` players):
```
# home: fill free home slots, largest eligible armies first
ordered_army = { limit = { cw_eligible_for_home_hq = yes } order_by = num_subunits
	max = { value = cw_hq_limit subtract = total_sub_unit_type_count:cw_hq min = 0 } check_range_bounds = no
	add_subunit = unit_type:cw_hq }
# colonial: per continent C != capital.continent with a free colonial slot and no HQ army present on C:
ordered_army = { limit = { cw_eligible_for_colonial_hq = yes unit_location = { continent = continent:C } } order_by = num_subunits max = 1 check_range_bounds = no
	add_subunit = unit_type:cw_hq_colonial }
```
Eligibility (unit scope): `is_army = yes`, `cw_unit_is_exempt = no`, `in_combat = no`, `in_retreat = no`, `num_subunits >= cw_min_subunits_for_ai_hq`; home (`cw_eligible_for_home_hq`): no **home** HQ (an army whose only HQ is colonial counts — the AI strips that colonial HQ in the same pass) and `unit_location = { NOT = { would_be_overseas_for = root } }`; colonial (`cw_eligible_for_colonial_hq`): no HQ of any type and `unit_location = { would_be_overseas_for = root }`; prefer `has_regulars = yes` (first pass), fallback any.
`cw_cleanup_excess_hqs` (AI only): if `total_sub_unit_type_count:cw_hq > cw_hq_limit` → from the smallest HQ armies (`order_by = { value = num_subunits multiply = -1 }`) remove HQs with `destroy_every_sub_unit_of_type = { sub_unit_type = unit_type:cw_hq }`, max = excess; same for colonial.
`cw_initial_hq_grant` (game start, every real country): `ordered_army = { order_by = num_subunits max = 1 check_range_bounds = no add_subunit = unit_type:cw_hq }` if `total_sub_unit_type_count:cw_hq = 0`.
Player helpers (root = country, `scope:loc` = location, used by scripted GUIs): `cw_loc_add_hq` (the largest own idle, non-exempt army at `scope:loc` without a **home** HQ that is not organized yet — so a colonial-HQ army at home can receive one), `cw_loc_add_colonial_hq` (the largest own idle army at overseas `scope:loc` without any HQ); both `add_subunit` and set the organization tier immediately, `cw_loc_remove_hq` (largest own army at `scope:loc` with an HQ; `destroy_every_sub_unit_of_type`; apply the penalty immediately).

## 7. War stance (`cw_stance_*` files, module ai_stance)
Ints: 0 unknown, 1 offensive, 2 defensive, 3 waiting, 4 harassing. Country variables: `cw_stance`, `cw_stance_lock` (expiring, months = 2), `cw_enemy_stance` (player), `cw_enemy_stance_source` (scope variable = enemy country, player).
`cw_update_war_stance` (AI, at war, not civil war only):
1. Find the main enemy: iterate `every_current_war` (skip `is_civil_war_for = root`), enemy leader = `defender_leader` if `is_an_attacker = root` else `attacker_leader`; keep the one with the largest `military_strength` (store via variables), save as `scope:cw_enemy`.
2. Ratio class via `relative_military_strength = { target = scope:cw_enemy value >= 0.57 }` (≈1.3:1 → offensive candidate; 0.55 before the tuning pass; once offensive, kept down to 0.53), `value <= 0.33` (≈1:2 → harassing; once harassing, kept up to 0.38). Offensive additionally needs `war_score_of_country >= -10` against the main enemy; a fielded-strength term sends a country whose `army_size` is ≤ 0.5 × the enemy's to harassing. Adjust thresholds by traits: ruler bold/aggressive-type traits (list from `traits/00_ruler.txt`, e.g. those carrying positive `aggressiveness_modifier`) and the largest army's `leader ?= { has_trait = offensive_planner }` → offensive threshold 0.50; cautious-type traits / `defensive_planner` → 0.60 and harassing at 0.40.
3. Waiting (`cw_should_be_waiting`): not harassing, not offensive, **attacker** against the main enemy AND (war young: `war_length_in_years < 1` OR `army_size_percentage < 0.8`) → 3; else defensive 2 (an invaded AI at parity holds its forts). The "allies far away" signal stays unused (`any_country_together_in_war_with` syntax **TODO-verify**). Losing badly (`war_score_of_country < -25` or `war_exhaustion >= 8`) → harassing.
4. Hysteresis: only change when `NOT has_variable = cw_stance_lock`; on change `set_variable = { name = cw_stance_lock months = cw_stance_lock_months }` (2) and `set_variable = { name = cw_stance_changed months = 1 }` (intelligence delay).
5. Apply: `add_country_modifier = { modifier = cw_stance_<x> months = 2 mode = replace }`, remove the other three; `set_variable cw_stance`.
`cw_clear_stance`: remove modifiers and variables (peace, or `is_ai = no`).
`cw_update_player_enemy_stance` (player, monthly): same main-enemy search; `cw_enemy_stance = enemy.var:cw_stance` unless enemy `has_variable = cw_stance_changed` (change within the last month → 0 unknown; the 2-month `cw_stance_lock` no longer hides the stance) or enemy is human (0); `cw_enemy_stance_source` = enemy. Clear when at peace. Optional event `cw_stance.1` (`in_game/events/cw_stance_events.txt`, namespace `cw_stance`; as built, replaces the planned `cw_events.3`) on change (game rule gated, off by default).
Subject stance `cw_escort_military_stance`: `support_armies_priority = 10`, `support_sieges_priority = 10`, `merge_units_priority = 10`, `hunt_army_priority = 4`, `chase_unit_enemy_location_priority = 4`, `defend_own_territory_priority = 6`, `carpet_siege_enemy_locations_priority = 1`, `friendly_naval_transport_priority = 3`, `confront_factor = 0.5`, rest as `supportive_military_stance`. Not assigned by script (literal stance reference unverified) — players pick it in the subjects UI; documented.

## 8. Warscore (module warscore_rules)
- `cw_war_defines.txt`: `NWar = { WAR_WORTH_BASE = 0.5  WAR_WORTH_COUNTRY_CAPITAL = 15  WAR_WORTH_PROVINCE_CAPITAL = 2  WAR_WORTH_PORT = 2  WAR_WORTH_BUILDING_SCALE = 0.025  WAR_WORTH_BUILDING_CAP = 15  WAR_WORTH_POPULATION_SCALE = 0.03  WAR_WORTH_POPULATION_CAP = 6  WAR_WORTH_DEVELOPMENT_MIN = -0.25  OCCUPATION_VALUE_SCALE = 1.3 }` (war worth drives BOTH occupation warscore and peace cost; rural locations have little tax/pop/buildings so they drop to ~1 instead of the vanilla ~2.4; the capital at 15 is ~8-12 % of a kingdom's worth and ~40-55 % of a minor's together with the +10 bonus; the development floor is raised from the vanilla −1 so BASE + MIN stays > 0, §16).
- `location_ranks/00_default.txt` copy with `local_war_score_efficiency` in `rank_modifier`: city `-0.15`, megalopolis `-0.25` only — villages and towns keep the vanilla efficiency since the tuning pass, their peace price already follows the lowered worth (efficiency is a divisor 1/(1+x); keep > -0.5).
- Capital premium: `on_siege_won` + `on_location_occupied` → if `scope:target = { is_capital = yes }` and the target owner is at war with root: `add_bonus_warscore` (+10, one-off per war; **TODO-verify** exact syntax from vanilla usage — grep `add_bonus_warscore`; if unclear, skip and document).
- Game rule `cw_rule_warscore` off → `defines = {}` restoring vanilla values (documented-but-unverified mechanism; harmless if ignored).

## 9. Native penalty (warscore_rules)
Country auto modifier `cw_isolated_tradition_auto`: `potential_trigger = { is_real_country = yes  capital ?= { continent = continent:america }  OR = { is_subject = no  overlord ?= { capital ?= { continent = continent:america } } }  NOT = { has_embraced_institution = institution:<pike_and_shot or the verified key> }  NOT = { has_variable = cw_reformed_host }  has_game_rule = cw_native_penalty_on }` with `discipline = -0.05` (mild) and `alert = no`. Any government type: the former `government_type = government_type:tribe` clause (`cw_is_american_tribe`) was dropped in the tuning pass; the country test is `cw_is_american_native`. Scripted trigger `cw_has_isolated_tradition` mirrors the potential (used by limit values: no extra HQ slots while active). Decision `cw_reform_war_host`: `potential` = trigger true; `allow` = `current_age_or_later = { age = age_4_reformation }` OR institution embraced OR owns ≥ 60 locations; effect `set_variable = cw_reformed_host`; `ai_will_do` positive when allowed (so strong AI natives reform).

## 10. Game rules (`cw_game_rules.txt`, each setting has `flag = general_rule`)
`cw_rule_hq_penalty` = `cw_hq_penalty_standard` (default) | `cw_hq_penalty_mild` | `cw_hq_penalty_harsh` (script reads `has_game_rule = cw_hq_penalty_mild` etc.).
`cw_rule_ai_concentration` - REMOVED (2026-11-04 first launch: `defines = { }` inside a game rule is rejected by the parser; the NAI overrides are always active).
`cw_rule_warscore` = `cw_warscore_on` (default) | `cw_warscore_off` (defines block restores vanilla NWar values).
`cw_rule_native_penalty` = `cw_native_penalty_on` (default) | `cw_native_penalty_off`.
`cw_rule_stance_events` = `cw_stance_events_off` (default) | `cw_stance_events_on`.

## 11. Scripted GUIs (`cw_scripted_guis.txt`, module gui_windows; all `scope = country`, root = player)
| key | is_shown / is_valid | effect |
|---|---|---|
| `cw_sgui_loc_has_hq_army` | is_shown: `scope:loc = { any_unit_in_location = { owner = root  cw_unit_is_organized = yes } }` | – |
| `cw_sgui_loc_has_colonial_hq_at_home` | is_shown: an own army with `cw_unit_has_colonial_hq_at_home = yes` at `scope:loc` (siege-only tier; replaces the unreferenced `cw_sgui_loc_has_colonial_hq_army`, tuning pass) | – |
| `cw_sgui_loc_is_overseas` | is_shown: `scope:loc = { would_be_overseas_for = root }` | – |
| `cw_sgui_loc_add_hq` | is_valid: free home slot (`total_sub_unit_type_count:cw_hq < cw_hq_limit`) and an own idle, non-exempt army at land `scope:loc` with `cw_unit_has_home_hq = no` and `cw_unit_is_organized = no` | `cw_loc_add_hq = yes` |
| `cw_sgui_loc_add_colonial_hq` | is_shown: colonial limit > 0; is_valid: free colonial slot and `scope:loc` overseas | `cw_loc_add_colonial_hq = yes` |
| `cw_sgui_loc_remove_hq` | is_valid: own army with HQ at `scope:loc` | `cw_loc_remove_hq = yes` |
| `cw_sgui_stance_is_0..4` | is_shown: `var:cw_enemy_stance = N` (0 also when unset) | – |
| `cw_sgui_player_at_war` | is_shown: `at_war = yes` | – |
| `cw_sgui_toggle_auto_hq` | is_shown always; is_valid `is_ai = no` | toggle variable `cw_auto_hq` |
| `cw_sgui_auto_hq_on` | is_shown: `has_variable = cw_auto_hq` | – |
GUI call form: `GuiScope.SetRoot(GetPlayer.MakeScope).AddScope('loc', <Unit>.GetLocation.MakeScope).End` where `<Unit>` = `SingleUnitWindow.GetSelectedUnit` in the army window.

## 12. GUI (gui_windows, gui_army_tab)
1. Plate `cw_war_stance_plate.gui`: `window`, `layer = topbar`, `parentanchor = top|hcenter`, `position = { 0 132 }`, ~26 px high, `visible = "[And(GetPlayer.IsValid, GetScriptedGui('cw_sgui_player_at_war').IsShown(GuiScope.SetRoot(GetPlayer.MakeScope).End))]"`; five state widgets toggled by `cw_sgui_stance_is_N`; icon (vanilla textures: `gfx/interface/icons/military_stances/*.dds`, `ai_dispositions/planning_war.dds`, `wary.dds`, `alerts_icons/military.dds` — pick 5 distinct), label `CW_STANCE_N`, tooltip `CW_STANCE_N_TT` with the enemy name `[GetPlayer.MakeScope.GetVariable('cw_enemy_stance_source').GetCountry.GetName]`; click toggles `GetVariableSystem` key `cw_hq_overview_visible`. Native look: vanilla templates (`bg_text_mask_container_brown`, `Font_Type_Headers`, gold dividers).
2. Overview `cw_hq_overview.gui`: window with header `CW_OVERVIEW_TITLE`, counters from cached variables, automation toggle button (shows `CW_AUTO_HQ_ON/OFF`), list `datamodel = "[AccessPlayerUnits]"` filtered `Unit.IsArmy`, each row: name, location, size (`Unit.GetNumSubUnits`), HQ marker via `Unit.GetSubUnits` + `EqualTo_string(SubUnit.GetDefinition.GetNameWithNoTooltip, Localize('cw_hq'))` (also `cw_hq_colonial`), close button. Reuse `bg_paper_card`, `header_button_*`, `divider_solid_gold`, `icon_text_2rows`.
3. Army tab: in the vanilla copy add a `header_secondary_tabs` row with two `button_secondary_tab_alt` buttons (`CW_TAB_ACTIONS` → `Vars.Set('tab','actions')` **TODO-verify** `Set` on SingleUnitWindow.Vars; alternative `Toggle`/`Clear`, see research 07 §12.1; `CW_HQ_TAB` → `'headquarters'`), existing content stays under `NotExistOrHasValue('tab','actions')`, new `vbox` under `HasValue('tab','headquarters')`: status rows driven by the army's own regiment / modifier lists plus `cw_sgui_loc_has_hq_army` / `cw_sgui_loc_has_colonial_hq_at_home` (row `CW_HQ_COLONIAL_AT_HOME`) / `cw_sgui_loc_is_overseas`, explanation text with penalties (`CW_HQ_PENALTY_INFO`), slots line (cached variables), three buttons (add / add colonial / remove) with `IsValid`+`Execute`, regiment list from `Unit.GetSubUnits` marking HQ rows.

## 13. Events (`cw_events.txt`)
`cw_events.1` new HQ slot (player; `interface_lock = no`), `cw_events.2` army lost its HQ (player; fired from `cw_on_battle` when `scope:target.owner` is human and the unit lost its HQ — detect via `has_unit_modifier` change if possible, else from the monthly pass when an army that had `cw_expeditionary`/no penalty now lacks an HQ; keep simple), `cw_stance.1` (file `cw_stance_events.txt`, module ai_stance — the planned `cw_events.3`) enemy stance changed (rule-gated), `cw_tick.1` hidden ticker. Hidden event pattern per research 11 §2.6 / 04 §5.3.

## 14. Localization keys (RU + EN)
Units `cw_hq`, `cw_hq_desc`, `cw_hq_colonial`, `cw_hq_colonial_desc`; limit descs `CW_HQ_LIMIT_AGE_AND_SIZE`, `CW_HQ_LIMIT_MIN`, `CW_COLONIAL_HQ_LIMIT_THEATRE`, …; `STATIC_MODIFIER_NAME/DESC_` for `cw_no_hq`, `cw_no_hq_mild`, `cw_no_hq_harsh`, `cw_no_hq_siege_only`, `cw_rebel_disorder`, `cw_expeditionary`, `cw_stance_offensive/defensive/waiting/harassing`; `AUTO_MODIFIER_NAME_cw_isolated_tradition_auto` (+desc if the pattern exists); stances `CW_STANCE_0..4`, `CW_STANCE_0..4_TT`; GUI `CW_PLATE_TITLE`, `CW_TAB_ACTIONS`, `CW_HQ_TAB`, `CW_HQ_PRESENT`, `CW_HQ_ABSENT`, `CW_HQ_COLONIAL_PRESENT`, `CW_HQ_OVERSEAS`, `CW_HQ_PENALTY_INFO`, `CW_HQ_COLONIAL_AT_HOME`, `CW_HQ_SIEGE_ONLY`, `CW_HQ_SLOTS`, `CW_HQ_COLONIAL_SLOTS`, `CW_HQ_ADD`, `CW_HQ_ADD_TT`, `CW_HQ_ADD_COLONIAL`, `CW_HQ_REMOVE`, `CW_OVERVIEW_TITLE`, `CW_OVERVIEW_HINT`, `CW_AUTO_HQ_ON`, `CW_AUTO_HQ_OFF`, `CW_AUTO_HQ_TT`, `CW_CLOSE`; events `cw_events.1.t/.d/.a`, `.2.*`, `.3.*`; decisions `cw_toggle_auto_hq.title/.desc/.a`, `cw_reform_war_host.title/.desc/.a`; rules `rule_cw_rule_*`, `setting_cw_*`, `setting_cw_*_desc`; concepts `game_concept_cw_headquarters`, `_desc`, `game_concept_cw_colonial_headquarters`, `game_concept_cw_war_stance`; subject stance `cw_escort_military_stance`, `_desc`, `_desc_all`; hint `hint_cw_army_without_hq` (+ whatever the hint format needs); custom tooltips `cw_*_tt`.
Stance wording RU/EN: 0 Неизвестно/Unknown, 1 Наступление/Offensive, 2 Оборона/Defensive, 3 Выжидание/Waiting, 4 Изматывание/Harassing.

## 15. Exemptions and edge cases
- Non-real countries (pirates, mercenary hosts) and conquistador hosts (`is_subject_type = conquistador`): never touched. Rebel countries (`is_rebel_country`) get `cw_rebel_disorder` on every army and nothing else (§17). Steppe hordes are `country_type = army` but ARE covered (research 14 F1, §16). Navies ignored (`every_army`).
- Exempt units: `is_exiled = yes`, `has_only_prisoners = yes` (modifier neither applied nor removed). As built, `is_lent_unit` is not tested (mercenary-scope trigger only; a recalled lent unit is destroyed and recreated anyway) and hired mercenary stacks are deliberately NOT exempt (§16).
- Lone HQ, or HQ + one regiment (num_subunits < 3), is NOT organized (penalty applies) → cannot occupy.
- Merged armies with several HQs: fine; AI cleanup only removes above the country limit, smallest armies first; players are never force-disbanded.
- Colonial HQ at home (non-overseas ground): organizes nothing — the army gets the siege-only tier `cw_no_hq_siege_only` (full combat strength, no sieges); a home HQ in the same army organizes it normally, and the player can add one from the army tab ("Place headquarters here" requires no *home* HQ; status row `CW_HQ_COLONIAL_AT_HOME`) (§17, research 15 §2.4).
- Native penalty: countries of the Americas of any government type; subjects of a non-American overlord (colonial nations, conquistador hosts) are exempt (§9).
- Penalty modifiers self-expire after a year if the mod is removed; refreshed every pass.

## 16. As-built deviations (final consistency pass, 2026-11-04)
Recorded so that this SPEC describes the shipped files; every item is also commented at its place in the code. Balance numbers were NOT changed in that pass; the DESIGN.md decisions listed in `docs/IMPLEMENTATION_NOTES.md` §6 were applied afterwards in the tuning pass (§17, v0.3 block at the top).
- **`cw_is_real_country`** = `{ is_real_country = yes  NOT = { is_subject_type = conquistador } }` (§5, §15). `country_type = army` is the type of every steppe horde (`government_reforms/steppe_horde.txt`, research 14 F1), not only of conquistador hosts, so the SPEC form exempted the Golden Horde, Chagatai, the Jalayirids … from the whole HQ system. `cw_stance_country_is_eligible` (ai_stance) delegates to it; `cw_on_capital_taken` (warscore_rules) uses it.
- **Stance event** is `cw_stance.1` in `in_game/events/cw_stance_events.txt` (namespace `cw_stance`, module ai_stance), not `cw_events.3` (§7, §13); `cw_events.txt` holds `cw_events.1`, `cw_events.2` and `cw_tick.1` only.
- **`on_battle_lost` is not hooked** (§5): it carries the same two units as `on_battle_won`; `cw_on_battle` re-checks both `scope:actor` and `scope:target` from the winner-side hook.
- **Exempt units** (§15): `is_exiled`, `has_only_prisoners` only. `is_lent_unit` is verified in mercenary scope only (and recall destroys/recreates the unit); hired mercenary stacks are deliberately NOT exempt (unlimited organised siege armies for gold otherwise, research 15 §2.4).
- **Goods-demand keys** are `cw_hq_construction_demand` / `cw_hq_maintenance_demand` (§2), so they cannot be confused with the engine-named price keys `cw_hq_build` / `_reinforce` / `_maintenance`.
- **`cw_warscore_triggers.txt` is a `main_menu` scripted-trigger file** (§1, §9): the HQ limit values live in the main_menu stage and must not depend on in_game triggers; the native-tradition condition is additionally inlined in `cw_limit_values.txt` and in the auto modifier's `potential_trigger` (keep the three in sync).
- **`NWar.WAR_WORTH_DEVELOPMENT_MIN = -0.25`** (§8) is added to `cw_war_defines.txt` so that `WAR_WORTH_BASE` (0.3 at that time, 0.5 since the tuning pass) plus the development term can never reach zero; the OFF game rule restores the vanilla `-1`.
- **Army-window tab state** uses the global `GetVariableSystem` key `cw_unit_tab` (§0, §12.3) instead of `SingleUnitWindow.Vars` (`Vars.Set` has no vanilla use; `Toggle` switched the tab off again on a second click); both vanilla gates were widened so navies and foreign armies always see the vanilla content.
- **Plate visibility** (§11): `cw_sgui_player_at_war` also requires `has_variable = cw_enemy_stance_source`, so the plate never claims "Unknown" while the player has no real enemy (civil war only).
- **Colonial placement** (§6): the AI may keep 1 / 2 / 3 HQ armies on a theatre according to the same 25- / 60-location tiers that grant the slots (otherwise those tiers were dead code for the AI); a pass-local counter (`local_var:cw_col_free`) prevents overshoot.
- **AI relocation** (`cw_ai_relocate_hqs`, not in the SPEC): when every slot is taken, one HQ stranded in a stack below `cw_min_subunits_for_ai_hq` is stripped (AI only) so that the placement in the same pass hands the slot to the largest HQ-less army. `cw_initial_hq_grant` also re-grants a lost last HQ regardless of army size.
- **Cached colonial limit**: `cw_colonial_hq_limit` (up to ten owned-location scans) is evaluated by script only in `cw_cache_limits`; every trigger and value compares the live engine counter with `var:cw_colonial_hq_limit_v`.
- **Stance thresholds** carry dead bands (`cw_stance_offensive_band = 0.04`, `cw_stance_harassing_band = 0.05`: offensive enters at 0.57 and is kept down to 0.53, harassing enters at 0.33 and is kept up to 0.38), an offensive war-score floor (−10), a fielded-strength term (`army_size` ≤ 0.5 × the enemy's → harassing) and a 1-month intelligence delay (`cw_stance_changed`) separate from the 2-month lock; "waiting" applies to the attacking side only, when its war is young OR its army is below 80 % of its expected size (defenders at parity are defensive); the temperament test uses `is_leading_largest_army_of` instead of a saved largest-army scope (TODO-verify in code).
- **Player helpers** `cw_loc_add_hq` / `cw_loc_add_colonial_hq` (§6) skip armies `in_combat` / `in_retreat` and refresh the cached counters themselves; the scripted GUIs do not call `cw_cache_limits` a second time.
- **`cw_isolated_tradition`** (static country modifier) was a never-applied twin of the auto modifier `cw_isolated_tradition_auto`; it and its loc keys were deleted in the tuning / localization pass.

## 17. Tuning pass (2026-11-04)
Balance decisions taken after `docs/research/15_balance_review.md` (and `14_hq_limits_at_game_start.md`) and now in the files — the sections above were updated in place; the full table with the rationale per change is `docs/IMPLEMENTATION_NOTES.md` §6.
- Penalty: standard discipline −20 % / morale −25 % (mild −10/−10, harsh −30/−30; siege −90 % / assault −50 % shared). Rebel armies: `cw_rebel_disorder` (combat half only) via `cw_monthly_rebel_pulse` and `on_revolt_start` / `on_civil_war_start`.
- Organized = right HQ + ≥ 3 regiments (`cw_min_subunits_organized = 3`). Colonial HQ organizes only overseas; at home → `cw_no_hq_siege_only`; the AI strips misplaced colonial HQs.
- Home limit: 1 + imperial slot (≥ 300 locations) + min(age, locations / 75), cap 5. Theatre tiers count subject land (`any_subject_or_below`).
- War worth: base 0.5, capital 15, building scale 0.025 (vanilla), occupation scale 1.3; rank efficiency city −0.15 / megalopolis −0.25 only.
- NAI: `HEAVILY_OUTNUMBERED_RATIO` 0.45, `AI_SUPPORT_ARMIES_DESIRED_STRENGTH_FACTOR` 0.33 and `AI_ENEMY_STRENGTH_NO_SUPPORT_ARMIES_FACTOR` 2 (vanilla), `AI_RECOVER_MORALE_THRESHOLD` 70, `RATIO_OVER_SUPPLY_TARGET_TO_SPLIT` 1.5.
- Native penalty: any government type (tribe clause dropped), subjects of a non-American overlord exempt; `cw_is_american_tribe` → `cw_is_american_native`; the two inlined copies in `cw_limit_values.txt` mirror it.
- Stances: bands 0.04 / 0.05, offensive war-score floor −10, fielded-strength term 0.5, waiting also below 80 % army size, 1-month `cw_stance_changed` intelligence delay.
