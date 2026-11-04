# 02 — Scripting on armies (`unit` scope) and regiments (`sub_unit` scope)

EU5 1.4.7 (Caesar/Jomini). Research for mod **Concentrated Warfare** (`cw_`).
All paths below are relative to `game/` inside the EU5 install unless stated otherwise
(`G:` = `C:\Program Files (x86)\Steam\steamapps\common\Europa Universalis V\game`).
Workshop mods: `WS:3600272327` = Cheat Menu Pro, `WS:3634102315` = Simple Cheats.

Legend:
- **VERIFIED** — seen used in vanilla/workshop script with the given syntax (file:line quoted).
- **VERIFIED-INDEX** — the name exists in `common/effect_localization/*` or `common/trigger_localization/*`
  (so the engine knows it) but no vanilla usage was found → the exact argument shape is INFERRED.
- **INFERRED** — composition of verified parts / reasonable reading of localization text.
- **UNVERIFIED** — not seen anywhere; must be tested in game.

---

## 1. Scope model and links

```
country ──every_army / every_navy / every_unit──▶ unit ──every_sub_unit──▶ sub_unit
                                                  │ owner → country           │ owner → country
                                                  │ leader → character        │ (sub_unit_type / sub_unit_category = …)
                                                  │ unit_location → location
character ──unit ?=──▶ unit
location ──every_unit_in_location──▶ unit ;  location ──siege──▶ siege ──any_besieging_unit──▶ unit
country ──every_hired_mercenary / every_rented_out_mercenary──▶ mercenary ──every_mercenary_sub_unit──▶ sub_unit
```

| Link (from → to) | Status | Example (file:line) |
|---|---|---|
| `unit.owner` → country | VERIFIED | `scope:target.owner ?= { tag = TUR }` `common/on_action/_hardcoded.txt:3216`; `owner = { ... }` inside `every_sub_unit` `common/scripted_effects/unit_effects.txt:19` (sub_unit.owner too) |
| `unit.leader` → character (optional; use `exists = leader` / `leader ?=`) | VERIFIED | `limit = { exists = leader } leader = { is_ruler = no }` `common/generic_actions/make_unit_available_for_hire.txt:61-64`; `remove_commander = leader` `events/estates/nobles_estate_events.txt:307`; `scope:target.leader ?= …` `_hardcoded.txt:3298` |
| `unit.unit_location` → location | VERIFIED | `unit_location.owner ?= owner` `common/unit_abilities/scorch_earth.txt:15`; `unit_location = { save_scope_as = target_location province = {…} }` `events/situations/little_ice_age.txt:1667-1672` |
| `character.unit` → unit (optional) | VERIFIED | `unit ?= { sub_unit_fraction:army_heavy_cavalry > 0.2 }` `common/traits/01_general.txt:12-17`; `unit ?= { owner != root }` `common/auto_modifiers/country.txt:1252` |
| `location.siege` → siege; `siege.any_besieging_unit` → unit | VERIFIED | `has_siege = yes  siege = { any_besieging_unit = { owner = { has_variable = … } } }` `common/on_action/country_monthly.txt:218-224` |
| `location.combat` → combat; `combat_attacker/combat_defender`; value `combat_side_strength` | VERIFIED | `common/script_values/garrison.txt:14-24` |
| `mercenary.owner` (lender/home country), `mercenary.customer` (hirer), `mercenary.mercenary_home` (location) | VERIFIED | `return_lent_unit.txt:52-56`, `recall_lent_unit.txt:53-57`, `events/mercs.txt:24-37` |
| Values through links in script values: `scope:target_army.food_percentage`, `prev.strength_percentage`, `leader.total_abilities` | VERIFIED | `little_ice_age.txt:1696`; `D008_fate_of_the_phoenix.txt:594`; `hellenism_religion.txt:304` |

`root` caveat: inside `every_army = { … }` called from a country event/on_action, `root` stays the **country**; the unit is `this`
(and `prev` from inside `unit_location = { }`). Only unit abilities evaluate with `root = unit`
(`absorb_pops.txt:15-16` uses `culture = root.owner.culture` inside `unit_location = { any_pop = {…} }`).

---

## 2. Iterators (list builders)

Every list exists in the four flavours `any_` (trigger, supports `count`/`percent`/`count = all`), `every_`, `random_`, `ordered_`
(effects; `limit = {}`, `ordered_` takes `order_by`, `max`, `check_range_bounds = no`, `position`). Flavours actually seen in vanilla are listed.

| List (scope → element) | Seen flavours (count of uses in `in_game`) | Example (file:line) |
|---|---|---|
| country → **army** unit: `*_army` | any 27, random 17, ordered 4, every 2 | `ordered_army = { limit = {…} order_by = num_subunits max = 1 check_range_bounds = no save_scope_as = target_army add_unit_modifier = {…} }` `common/generic_actions/parliament.txt:1262-1273`; `every_army = { every_sub_unit = { add_subunit_morale = {…} } }` `events/colonization/conquistador.txt:108-116` |
| country → **navy** unit: `*_navy` | any 2, random 2 | `random_navy = { destroy_unit = yes }` `events/debug/000_johan_debug.txt:429-431`; `any_navy = { NOT = { exists = leader } }` `common/generic_actions/unlockable_io_actions.txt:215` |
| country → **any unit** (armies + navies): `*_unit` | any 18, random 16, every 5, ordered 2 | `every_unit = { limit = { is_navy = no } damage_unit_morale_percent = 0.2 }` `events/DHE/flavor_SCO.txt:4434-4437`; `ordered_unit = { limit = {…} check_range_bounds = no order_by = experience_percentage max = 1 save_scope_as = target_unit … }` `events/government/D008_latinization_vs_hellenization.txt:371-394` |
| country → **sub_unit** (all regiments/ships of the country): `*_country_sub_unit` | any 6, every 1 | `every_country_sub_unit = { limit = { sub_unit_type = unit_type:a_tofangchi } add_subunit_experience = subunit_experience_severe_bonus }` `events/DHE/flavor_ira.txt:1214-1217`; `any_country_sub_unit = { sub_unit_category = sub_unit_category:army_heavy_infantry }` `000_johan_debug.txt:369-371` |
| unit → sub_unit: `*_sub_unit` | any 29, every 10, random 6, ordered 3 | `any_sub_unit = { sub_unit_type = $sub_unit_type$ count = all }` `common/scripted_effects/unit_effects.txt:41`; `ordered_sub_unit = { order_by = subunit_strength max = 10 check_range_bounds = no add_subunit_experience = { 25 100 } }` `D008_latinization_vs_hellenization.txt:2439-2444`; `random_sub_unit = { limit = {…} … destroy_subunit = yes }` `common/unit_abilities/convert_galley.txt:45-56` |
| location → unit: `*_unit_in_location` | every 10, random 4, any 3 | `every_unit_in_location = { damage_unit_percent = { 0.33 1 } damage_unit_morale_percent = { 0.5 1 } }` `events/earthquake_events.txt:152-155`; `any_unit_in_location = { count >= 1 owner = root }` `events/DHE/flavor_hol.txt:1048-1051`; `random_unit_in_location = { limit = { owner ?= scope:target.owner } save_scope_as = target_army }` `_hardcoded.txt:5916-5921` |
| siege → besieging unit: `*_besieging_unit` | any 7, random 5, every 3 | `country_monthly.txt:218-224` (above) |
| country → mercenary company: `*_hired_mercenary` (hired by me), `*_rented_out_mercenary` (mine, rented out) | hired: any 12, random 9, every 1, ordered 1; rented: any 7, random 3, every 1 | `every_hired_mercenary = { limit = { is_lent_unit = yes NOT = { is_carrying_or_loaded_unit = yes } } add_to_list = source }` `common/generic_actions/return_lent_unit.txt:25-33`; `ordered_hired_mercenary = { order_by = monthly_cost max = 1 save_scope_as = merc_company }` `events/government/societal_values.txt:5466-5471` |
| mercenary → sub_unit: `*_mercenary_sub_unit` | any 8, every 7, random 5, ordered 2 | `every_mercenary_sub_unit = { add_subunit_strength_percentage = -0.2 }` `events/mercs.txt:44-46` |
| world → mercenary: `random_mercenary` | 1 | `random_mercenary = { limit = { mercenary_home.region = region:iberia_region } save_scope_as = my_merc }` `events/DHE/flavor_ARA.txt:2826-2829` |

`count` on `any_` lists: `any_army = { count > 3 owner = root unit_location = {…} }` `events/DHE/flavor_ENG.txt:22838-22844`;
`any_unit_in_location = { count < 1 }` `events/religion/orthodox_icon_events.txt:18-20`; `any_unit = { count > 0 has_commander = yes is_army = yes NOR = {…} }` `events/disaster/D008_fate_of_the_phoenix.txt:565-574`.

`order_by` with a script-value block (VERIFIED, `events/religion/hellenism_religion.txt:292-307`):

```
ordered_unit = {
	limit = { has_commander = yes leader = { has_nickname = no total_abilities > 150 } }
	order_by = {
		value = unit_strength
		if = { limit = { has_commander = yes } add = leader.total_abilities }
	}
	max = 3
	check_range_bounds = no
	add_to_list = hellenism_religion_2_list
}
```

`order_by = "unit_location.distance_to(scope:x.var:y)"` (quoted expression with a link) — `events/expeditions/treasure_fleet_events.txt:2186-2190`.
`max` as a script value block `max = { value = 1 add = {…} }` — `events/earthquake_events.txt:166-174` (on `ordered_buildings_in_location`; same list machinery).

Scripted lists (`main_menu/common/scripted_lists/scripted_lists.info`, in-game definitions in `in_game/common/scripted_lists/*.txt`) can wrap any base list:
`general = { base = character conditions = { is_general = yes } }` `in_game/common/scripted_lists/character_lists.txt:10-15` → `every_general`. A `cw_hq_army = { base = army conditions = { any_sub_unit = { sub_unit_type = unit_type:cw_hq } } }` is INFERRED to work (base = `army`, i.e. the part after `every_`).

---

## 3. Triggers — `unit` scope

Index source: `common/trigger_localization/unit_triggers.txt` (names listed there: `is_moving is_army is_movement_locked morale_percentage strength_percentage experience_percentage is_unit_locked is_exiled food_percentage is_carrying_troops can_hire_prisoners_as_mercenaries can_ransom_prisoners can_execute_prisoners can_sell_prisoners_into_slavery prisoner_strength has_prisoners has_only_prisoners can_upgrade_unit has_unit_modifier has_commander in_combat in_retreat in_siege sub_unit_fraction sub_unit_count sub_unit_strength num_subunits has_levies has_regulars has_mercenaries`).

| Trigger | Status | Example |
|---|---|---|
| `is_army = yes/no` | VERIFIED | `common/unit_abilities/drill_army.txt:14` |
| `is_navy = yes/no` | VERIFIED (not in loc index) | `make_unit_available_for_hire.txt:52`; `flavor_SCO.txt:4435` |
| `is_moving`, `is_exiled`, `in_combat`, `in_siege`, `in_retreat`, `has_commander`, `has_only_prisoners`, `has_prisoners` | VERIFIED | `drill_army.txt:13-19` (`has_only_prisoners = no is_army = yes in_combat = no is_moving = no is_exiled = no in_siege = no has_commander = yes`); `march_to_sound_of_guns.txt:16` (`in_retreat = no`) |
| `is_movement_locked`, `is_unit_locked`, `is_carrying_troops` | VERIFIED | `000_johan_debug.txt:398-410` |
| `morale_percentage`, `strength_percentage`, `experience_percentage`, `food_percentage` (0..1 comparisons) | VERIFIED | `000_johan_debug.txt:403-408`; `gather_food.txt:47`; `italian_wars.txt:1035-1036` |
| `has_unit_modifier = <static_modifier>` | VERIFIED | `parliament.txt:1263`; `black_death.txt:944`; `D008_fate_of_the_phoenix.txt:570-573` |
| `num_subunits <op> N` | VERIFIED-INDEX (as value in `order_by` VERIFIED) | loc `NUM_SUBUNITS_TRIGGER: "Has $COMPARATOR$ $NUM|0V$ [sub_units|e]"` |
| `sub_unit_fraction:<category> <op> x`, `sub_unit_count:<category> = N`, `sub_unit_strength:<category> <op> x` | VERIFIED | `000_johan_debug.txt:1031-1035`; `traits/01_general.txt:14-15` |
| `total_sub_unit_category_in_unit:<category> > 0` | VERIFIED | `unit_abilities/raid_clan_holdings.txt:17-21`; `gui/filters/07_unit.txt:58-59` |
| `has_levies`, `has_regulars`, `has_mercenaries` | VERIFIED | `make_unit_available_for_hire.txt:57-58`; `gui/filters/07_unit.txt:25-50` |
| `exists = leader`, `leader = { <character triggers> }` | VERIFIED | `unlockable_io_actions.txt:209`; `nobles_estate_events.txt:297-305`; `muscovite_succession_war.txt:206` (`leader = root.ruler`) |
| `unit_location = { <location triggers> }`, `unit_location.owner ?= owner` | VERIFIED | `scorch_earth.txt:15-22`; `corruption_event.txt:506-514` |
| `owner = root` / `owner ?= {…}` | VERIFIED | `flavor_ENG.txt:22748`; `absorb_pops.txt:8-10` |
| `any_sub_unit = { … count = all }` | VERIFIED | `unit_effects.txt:41` |
| scripted trigger in unit scope (`scripted_trigger x = {}` inside an event file) | VERIFIED | `events/DHE/flavor_ENG.txt:6890-6900`, used as `any_army = { unit_eng_74_trigger = yes }` `:6994` |
| `has_variable` / `var:` on a unit | UNVERIFIED (no vanilla use on units; only on countries/locations/IOs) | — |
| `is_lent_unit` | VERIFIED **on mercenary scope**, not unit | `return_lent_unit.txt:6,27,41` |

Hardcoded unit states also exist as static modifiers the engine applies itself (`main_menu/common/static_modifiers/unit.txt:4-47`):
`is_exiled` (land_morale -0.75), `army_leaderless` (land_morale -0.20), `navy_leaderless`, `in_combat`, `in_siege`, `is_blockading`.
**`army_leaderless` is the vanilla precedent for "penalty for lacking X"** and can be re-tuned by overriding that file.

---

## 4. Triggers — `sub_unit` scope

Index: `common/trigger_localization/subunit_triggers.txt` (`is_regiment is_ship sub_unit_type sub_unit_category_this_equal subunit_morale_percentage subunit_strength_percentage is_levy definition_is_for_levy is_mercenary can_upgrade_subunit subunit_morale subunit_strength subunit_number`).

| Trigger | Status | Example |
|---|---|---|
| `sub_unit_type = unit_type:<key>` | VERIFIED | `unit_effects.txt:7-8`; `promote_to_farari.txt:55-56` |
| `sub_unit_category = sub_unit_category:<key>` | VERIFIED | `convert_galley.txt:12,29,41` |
| `is_ship = yes`, `is_regiment` | VERIFIED (`is_ship`) | `convert_galley.txt:40` |
| `is_mercenary = yes` | VERIFIED | `corruption_event.txt:503` |
| `is_levy` | VERIFIED-INDEX (`IS_LEVY_TRIGGER: "Is an [army_levy|e] or [navy_levy|e]"`) | GUI equivalent `SubUnit.IsLevy` used 17× in `gui/` |
| `subunit_strength_percentage < 0.8` | VERIFIED | `societal_values.txt:5281-5283` (inside `any_mercenary_sub_unit`) |
| `subunit_strength`, `subunit_morale`, `subunit_morale_percentage` as **values** | VERIFIED | `conquistador.txt:110-114` (`value = subunit_morale divide = subunit_morale_percentage`); `corruption_event.txt:558-565` (`value = subunit_strength multiply = -0.10`) |
| `owner ?= { … }`, `location = { … }`, `culture = …`, `pop_type = …` (regiment's pop/location, used in levy/pop triggers) | VERIFIED (in `unit_type` pop/location triggers, root = pop/location) | `scripted_triggers/unit_triggers.txt:416-430` (`owner ?= { religion ?= {…} }` + `sub_unit_type`) |

Localization hints: `SUBUNIT_STRENGTH_TRIGGER: "Has $COMPARATOR$ $NUM|Y$ Men"`, `SUBUNIT_NUMBER_TRIGGER: "Regimental number is $COMPARATOR$ $NUM|Y$"`
(`main_menu/localization/english/*.yml:7707-7711`).

---

## 5. Army-related triggers in other scopes

**Country** (`trigger_localization/country_triggers.txt`): `army_size regular_army_size expected_army_size country_total_army_levy_size potential_navy_size potential_army_size army_size_percentage num_regiments possible_military_leaders navy_size … relative_military_strength military_strength … total_sub_unit_count total_sub_unit_strength total_sub_unit_type_count total_sub_unit_type_strength … has_raised_levies has_raised_army_levies can_raise_levies … has_unlocked_any_unit_of_category can_build_unit_type can_build_units_of_category`.

| Trigger / value | Status | Example |
|---|---|---|
| `regular_army_size > 0` | VERIFIED | `parliament.txt:1261`; loc `ARMY_SIZE_TRIGGER: "Has … men in the Army"` |
| `army_size > 0` | VERIFIED | `flavor_hol.txt:1046`; `lend_unit_to_ally.txt:6` |
| `num_regiments > 0` (and as value) | VERIFIED | `generic_actions/train_general.txt:23,32` |
| `total_sub_unit_type_count:<unit_type_key>` as value | VERIFIED | `government_reforms/country_specific.txt:1969` (`value = total_sub_unit_type_count:a_farfanes divide = army_size`) |
| `total_sub_unit_count:<category> > N` | VERIFIED | `hegemons/1_naval_hegemon.txt:5-12` |
| `can_build_units_of_category = sub_unit_category:x` | VERIFIED | `convert_galley.txt:22` |
| `is_ai = yes` / `is_human` | VERIFIED | `on_action/ai_personalities_setup.txt:16`; `_hardcoded.txt:55` |
| `at_war = yes`, `is_at_war_with = X` | VERIFIED | `lend_unit_to_ally.txt:11`; `raid_clan_holdings.txt:31` |

**Character**: `is_general is_admiral has_unit is_general_of is_admiral_of is_leading_largest_army_of is_leading_largest_navy_of years/days_of_service_as_general is_eligible_military_leader` (index `character_triggers.txt`).
`NOT = { is_leading_largest_army_of = root }` + `unit ?= { owner != root }` — `auto_modifiers/country.txt:1250-1258` (VERIFIED).
`has_unit = no` — `character_interactions/grant_cabinet_right.txt:58`.

**Location**: `has_siege`, `has_combat`, `is_overseas_for_owner`, `would_be_overseas_for = <country>`, `in_zone_of_control`, `continent`/`sub_continent`/`region` links.
`has_siege = yes` `events/DHE/flavor_GEN.txt:1777`; `has_combat = yes` `generic_actions/siege.txt:48`;
`is_overseas_for_owner = yes` `building_types/plantation_buildings.txt:17`; `continent != root.capital.continent` `events/DHE/flavor_cas_por.txt:26` — the pattern for "colonial = on a different continent than the capital".

---

## 6. Effects — `unit` scope

Index `common/effect_localization/unit_effects.txt`: `remove_unit_modifier add_unit_modifier add_unit_modifier_duration add_unit_modifier_forever add_morale add_subunit lock_unit unlock_unit add_food add_food_percentage destroy_unit set_unit_size change_unit_owner damage_unit_percent damage_unit_morale_percent set_as_commander make_unit_available_for_hire move_to_assist_on_adjacent_combat lend_unit_to_country`.
`common_effects.txt` adds `remove_commander`, `change_unit_modifier_size`.

| Effect | Status | Example / semantics |
|---|---|---|
| `add_subunit = unit_type:<key>` — adds a regiment of that type into **this existing army** | VERIFIED (debug event only) | `random_army = { add_morale = 0.1 add_subunit = unit_type:a_feudal_levy lock_unit = 30 unlock_unit = yes add_food = 10 }` `events/debug/000_johan_debug.txt:417-423`; loc `GAIN_SUBUNIT_EFFECT: "Gains a [TARGET_UNIT_TYPE.GetName]"`. Whether it respects the unit type `limit`, pop/manpower cost, `buildable`, or `country_potential`: **UNVERIFIED** (assume it ignores all of them — debug usage). |
| `add_unit_modifier = { modifier = X days/years = N mode = replace\|add_and_extend [size = {script value}] }` | VERIFIED | `parliament.txt:1268-1272` (`years = modifier_duration_years_short mode = replace`); `laws.txt:1068-1072` (`days = 120 mode = add_and_extend`); `D008_latinization_vs_hellenization.txt:413-430` (with `size = { add = {…} multiply = {…} }`); `months =` seen only for country modifiers (`000_johan_debug.txt:273-277`) → INFERRED for units |
| `add_unit_modifier_forever = X` (permanent) | VERIFIED-INDEX (loc `ADD_UNIT_MODIFIER_FOREVER: "Gains $MODIFIER|V$ until $END_OF_TIME_UNITS$…"`) | argument shape INFERRED from `add_location_modifier_forever` siblings; test |
| `remove_unit_modifier = X` | VERIFIED | `000_johan_debug.txt:293` |
| `change_unit_modifier_size = {…}` | VERIFIED-INDEX only | `common_effects.txt:293` |
| `add_morale = 0.1` / `{ -0.5 -1 }` (absolute morale delta; ranges allowed) | VERIFIED | `000_johan_debug.txt:418`; `hundred_years_war.txt:1939-1941` |
| `damage_unit_percent = { 0.33 1 }`, `damage_unit_morale_percent = { 0.5 1 }` | VERIFIED | `earthquake_events.txt:153-154`; `little_ice_age.txt:1681-1682` |
| `add_food = 10`, `add_food_percentage = { -0.5 1 }` | VERIFIED | `000_johan_debug.txt:422`; `little_ice_age.txt:1683,1711` |
| `set_unit_size = 0.01` ("strength of all its regiments set to X%") | VERIFIED | `000_johan_debug.txt:440` |
| `change_unit_owner = <country>` | VERIFIED | `000_johan_debug.txt:441`; `pirate_events.txt:398` (`change_unit_owner = root`); `flavor_KOR.txt:2257` |
| `destroy_unit = yes` | VERIFIED | `unit_effects.txt:42`; `qa_debug.txt:1950-1952` (`every_unit = { destroy_unit = yes }`) |
| `lock_unit = 30` / `unlock_unit = yes` ("Becomes locked until $DURATION$" → days INFERRED) | VERIFIED | `000_johan_debug.txt:420-421`. NB name collision: in `common/advances/*.txt` `unlock_unit = a_footmen` is a *country-level* unit-type unlock (`advances/2_army_unlocks.txt:7`). |
| `set_as_commander = <character>` | VERIFIED | `random_unit = { set_as_commander = owner.ruler }` `000_johan_debug.txt:345`; `random_army = { limit = { has_commander = no } set_as_commander = scope:target }` `conquistador.txt:124-128` |
| `remove_commander = <character>` (unit scope: `remove_commander = leader`; country scope: `remove_commander = scope:x`) | VERIFIED | `nobles_estate_events.txt:307`; `_hardcoded.txt:1882` (`remove_commander = ruler`); `culture_japan.txt:1264` |
| `move_to_assist_on_adjacent_combat = yes/no` | VERIFIED | `march_to_sound_of_guns.txt:24,27` |
| `lend_unit_to_country = <country>` | VERIFIED | `country_interactions/lend_unit_to_ally.txt:143` |
| `make_unit_available_for_hire = { cost_multiplier = … months = … save_scope_as = merc_for_hire }` | VERIFIED | `generic_actions/make_unit_available_for_hire.txt:95-101` |
| `save_scope_as`, `add_to_list`, `custom_tooltip` inside unit iterators | VERIFIED | `parliament.txt:1267`; `hellenism_religion.txt:307`; `hundred_years_war.txt:1937-1942` |
| `grant_special_unit_experience = { value = X }` (vanilla scripted effect, root = unit; stores exp as **country** variable) | VERIFIED | `scripted_effects/unit_effects.txt:1-36`; called with `scope:actor = {…}` in `_hardcoded.txt:3230-3239` |
| `destroy_every_sub_unit_of_type = { sub_unit_type = unit_type:X }` (vanilla scripted effect, root = unit) | VERIFIED | definition below; used `events/DHE/flavor_ira.txt:307-312` |
| `merge_unit` / `split_unit` | **not found** anywhere (no loc index entry, no usage) → does not exist as a script effect | — |
| `set_variable` on a unit | UNVERIFIED | — |

Vanilla reference (`common/scripted_effects/unit_effects.txt:39-54`):

```
destroy_every_sub_unit_of_type = {
	if = {
		limit = { any_sub_unit = { sub_unit_type = $sub_unit_type$ count = all } }
		destroy_unit = yes
	}
	else = {
		custom_description = {
			text = destroy_every_sub_unit_of_type
			value = $sub_unit_type$
			every_sub_unit = {
				limit = { sub_unit_type = $sub_unit_type$ }
				destroy_subunit = yes
			}
		}
	}
}
```
Note the pattern: if *all* regiments would be destroyed, destroy the unit instead (avoids leaving an empty army).

---

## 7. Effects — `sub_unit` scope

Index `common/effect_localization/subunit_effects.txt`: `add_subunit_morale destroy_subunit add_subunit_strength add_subunit_strength_percentage add_subunit_experience change_subunit_type`.

| Effect | Status | Example |
|---|---|---|
| `destroy_subunit = yes` | VERIFIED | `unit_effects.txt:50`; `flavor_ENG.txt:6985`; `flavor_GEN.txt:1577-1583` (`ordered_sub_unit = { limit = { sub_unit_type = unit_type:a_genoese_crossbowmen } max = 10 destroy_subunit = yes }`) |
| `change_subunit_type = unit_type:<key>` | VERIFIED | `promote_to_farari.txt:66-71` |
| `add_subunit_experience = 10` / `{ 25 100 }` / script value | VERIFIED | `institution_events.txt:1355`; `D008…:2443`; `flavor_ira.txt:1216` |
| `add_subunit_strength = { value = subunit_strength multiply = -0.10 }` (absolute men) | VERIFIED | `corruption_event.txt:558-561`; `___test_effects.txt:1-3` (`damage_regiment = { add_subunit_strength = heavy_melee_damage }`) |
| `add_subunit_strength_percentage = -0.5` / `root.var:x` | VERIFIED | `flavor_ENG.txt:6999`; `D008_fate_of_the_phoenix.txt:616` |
| `add_subunit_morale = { value = … }` | VERIFIED | `conquistador.txt:110-114` |
| `owner = { set_variable … }` (sub_unit → country) | VERIFIED | `unit_effects.txt:19-33` |

---

## 8. Spawning units / regiments (location & country scope)

Index `effect_localization/location_effects.txt`: `create_sub_unit_of_category create_sub_unit create_num_sub_unit_of_category create_sub_unit_with_owner create_army_country_in_location spawn_army_levy_unit spawn_navy_levy_unit`.

| Effect (scope) | Status | Example |
|---|---|---|
| `create_sub_unit = unit_type:<key>` (location; owner = the country whose event it is, i.e. the context country) | VERIFIED | `capital = { create_sub_unit = unit_type:a_genoese_crossbowmen … }` `events/DHE/flavor_GEN.txt:1561-1569`; `qa_debug.txt:2401-2422` (scripted effect `spawn_unit_type = { type = … location = … }` using a `while = { limit = { var:qa_counter > 0 } … }` loop); same in `WS:3600272327/in_game/common/scripted_effects/sakuya_army_generator_effects.txt:3-21` |
| `create_sub_unit_of_category = sub_unit_category:<key>` (location) | VERIFIED | `qa_debug.txt:1786-1790`; `convert_galley.txt:50-54` (inside `scope:ship_unit = { unit_location = {…} }` — i.e. spawns at the fleet's location; whether it merges into that fleet or creates a new unit: UNVERIFIED, vanilla comment implies it converts "in place") |
| `create_num_sub_unit_of_category = { count = {script value} category = sub_unit_category:x }` (location) | VERIFIED | `events/DHE/flavor_ARA.txt:2256-2262` |
| `create_sub_unit_with_owner = { type = a_houfnice owner = <country> origin = <location> experience = 100 }` (location; **bare** type key, no `unit_type:` prefix) | VERIFIED | `flavor_ARA.txt:1834-1839`; `conquistador.txt:66-73` (in `while = { count = 6 … }`); `WS:3600272327 …/sakuya_army_generator_effects.txt:35-39` |
| `create_army_country_in_location = { reforms = {…} overlord = … culture = … religion = … subject_type = subject_type:conquistador ruler = … }` (location; creates an "army country", `country_type = army`) | VERIFIED | `conquistador.txt:45-53`; `change_country_type = army` `000_johan_debug.txt:1330` |
| `spawn_army_levy_unit` / `spawn_navy_levy_unit` | VERIFIED-INDEX only (`SPAWN_ARMY_LEVY_UNIT_EFFECT: "Raise an [army_levy|e] for [TARGET_COUNTRY.GetName]"`) | — |
| `raise_all_levies`, `raise_all_levies_instant`, `hire_mercenary`, `dismiss_mercenary` (country) | VERIFIED-INDEX (`country_effects.txt:2400-2409,1707-1716`) | — |

Whether repeated `create_sub_unit` calls in one location create one army or N single-regiment armies is UNVERIFIED (vanilla writes 8–10 calls in a row and the tooltip says "gain 10 regiments", suggesting they merge into one new unit at that location — INFERRED).

---

## 9. Unit modifiers

**Definition** (static modifier with unit category; `main_menu/common/static_modifiers/unit.txt:85-99`):

```
extensive_training_modifier = {
	game_data = { category = unit }

	discipline = 0.05
	experience_decay = -0.025
	monthly_experience_gain = 0.1
}

battle_hardened_veterans_modifier = {
	game_data = { category = unit }

	discipline = 0.05
	land_morale_modifier = 0.10
	experience_decay = -0.05
}
```

**Modifier types with `category=unit`** (`main_menu/common/modifier_type_definitions/00_modifier_types.txt`): `siege_ability` (:5985, `percent=yes`), `assault_ability` (:5992), `discipline` (:6014), `naval_damage_done/taken`, plus those used in `unit.txt`/abilities: `land_morale_modifier`, `land_unit_attrition`, `experience_decay`, `monthly_experience_gain` (:4516), `army_maintenance_efficiency` (:4572), `force_army_maintenance` (:4564), `army_food_gathering` (:14794), `navy_repair_efficiency`, `naval_morale_modifier`, `anti_piracy_warfare_modifier`, `global_maritime_presence_modifier`. (Any `category=unit` modifier type can go into a unit modifier; `siege_ability = -0.9` for the HQ-less penalty is therefore VERIFIED-typed.)

**Apply / remove / check** — see §6 (`add_unit_modifier`, `remove_unit_modifier`) and §3 (`has_unit_modifier`). `unit_modifier_strength` (trigger, `common_triggers.txt`) and `change_unit_modifier_size` (effect) are VERIFIED-INDEX only.

Modes seen: `replace` (parliament, italian_wars, D008), `add_and_extend` (laws, pirate, black_death, debug), `extend` (country modifier `D008…:2487`). Duration keys seen on units: `days`, `years`. `size = { … }` script-value scaling VERIFIED (`D008…:417-429`).

Unit abilities also carry a `modifier = { … }` block applied while the ability is active (`drill_army.txt:22-27`: `monthly_experience_gain = 2.5 force_army_maintenance = yes army_maintenance_efficiency = -0.25 land_morale_modifier = -0.9`).

**Auto modifiers** (`in_game/common/auto_modifiers/readme.txt`): engine-evaluated conditional modifiers with `type` (scope for `potential_trigger`, default country) and `category`. Vanilla uses `type = country`, `type = dynasty` (`dynasty.txt:7-8`), `type = international_organization` (`international_organization.txt:6-7`). **`type = unit` is UNVERIFIED** — if it works it is the cleanest implementation of "penalty when no HQ regiment" (no monthly pulse, instant, tooltip auto-generated, "The AI will also understand them" per `country.txt:1-4`). Test first (see §16).

---

## 10. Unit abilities (format; the only vanilla place with `root = unit` script)

`common/unit_abilities/readme.txt:4-26` — `hidden`/`allow`/`finished_when`/`ai_will_revoke` (unit-scope triggers), `duration`, `toggle`, `army_only`/`navy_only`, `cancel_on_combat`, `cancel_on_combat_end`, `cancel_on_move` (used in `drill_army.txt:6`), `map`, `start_effect`/`finish_effect`/`on_entering_location` (unit-scope effects), `ai_will_do` (script value), `modifier`, `confirm`, `block_reorg`, `highlight = { … add_to_list = target }` (`tun_tax_raid.txt:22-29`).

`scorch_earth.txt:8-33` (VERIFIED, root = unit):

```
	allow = {
		has_only_prisoners = no
		is_army = yes
		in_combat = no
		is_moving = no
		is_exiled = no
		in_siege = no
		unit_location.owner ?= owner
		unit_location.controller ?= owner
		unit_location.province.capital ?= unit_location
		unit_location.province ?= { province_food_percentage > 0.2 NOT = { has_province_modifier = scorched_earth } }
	}
	start_effect = {
		unit_location.province = { add_province_modifier = { modifier = scorched_earth years = 1 mode = add_and_extend } }
	}
```

`ai_will_do` for abilities: AI only uses abilities with positive weight (`drill_army.txt:45-60` is `-1` = never; `tun_tax_raid.txt:70-72` `value = 1`). Abilities are **player/AI-toggled**, not automatic — unsuitable for an automatic penalty, but a good UI vehicle for an optional player action (e.g. "detach HQ").

---

## 11. On_actions and pulses — what exists (part d)

Grep of `common/on_action/_hardcoded.txt` (all top-level names) and the other on_action files:

- **No daily country/unit on_action** exists. The only "daily" mentions: `on_ruler_death_delayed` comment ("fires at the next daily tick", `:4000`) and `automation_tick = daily` in generic actions (`make_unit_available_for_hire.txt:23`, a per-action AI/automation tick, not a script hook).
- **No** `on_unit_created`, `on_army_merged`, `on_unit_destroyed`, `on_regiment_recruited`, `on_levy_raised` or similar.
- Code-invoked pulses (defined, never referenced by other script): `monthly_country_pulse` (`country_monthly.txt:2`), `yearly_country_pulse` (`country_yearly.txt:1`), `biyearly_country_pulse` (`country_biyearly.txt:4`), `on_four_yearly_check_for_script` (`country_four_yearly.txt`), `colonial_charter_monthly_pulse`, `on_exploration_monthly_pulse`, `in_regency_yearly_pulse`, location pulses `weather_monthly_pulse`/`volcano_location_pulse`/`earthquake_location_pulse` (`location_pulses.txt`), `on_game_start` (`ai_personalities_setup.txt:10`), `on_game_started_after_lobby` (`_hardcoded.txt:316`), `on_new_age` / `on_new_age_global` (`:633-640`, root = country for every country when a new age starts).
- Unit-related hardcoded on_actions (`_hardcoded.txt`):

| on_action | Scopes (vanilla comment) | Line |
|---|---|---|
| `on_command_gained` / `on_command_lost` | `root = character, scope:unit = unit` (both empty in vanilla) | 669-675 |
| `in_battle` | `root = character`, "every tick while a character is the supreme commander of a battle" (empty) | 627-630 |
| `on_battle_won` / `on_battle_lost` / `on_great_battle_won` / `on_great_battle_lost` | `root = actor, scope:actor = winning "unit", scope:target = losing "unit"`; float scopes `scope:killed_land_units`, `scope:killed_navy_units`, `scope:lost_land_units`, `scope:lost_navy_units`, `scope:war_score` | 2976-2983, 3136-3143, 3202-3209, 3328-3335 |
| `on_battle_won_character` / `on_battle_lost_character` | `root = character` | 2885-2886, 2955-2956 |
| `on_overrun_imprisoned` | `root = unit of prisoners, scope:winner = country` | 3381-3386 |
| `on_siege_won` / `on_siege_lost` / `on_location_occupied` / `on_location_lost` | `root = country, scope:target = location, scope:character = leading general character` | 319-321, 447, 492-494, 620 |
| `on_war_declared`, `on_join_war`, `on_winning_war`, `on_losing_war`, `on_pre_ending_war`, `on_ending_war` | country + `scope:war`, `scope:winner/loser`, `scope:actor/recipient` | 1534-2395 |

`on_battle_won` body (VERIFIED unit links on the event targets, `_hardcoded.txt:3230-3239`):

```
		scope:actor = {
			grant_special_unit_experience = { value = special_unit_victory_experience }
		}
		scope:target = {
			grant_special_unit_experience = { value = special_unit_defeat_experience }
		}
```
and `scope:actor = { owner = { tag = SER } unit_location = location:pristina }` (`:3261-3264`), `exists = scope:actor.leader` (`:2997`).

Monthly pulse structure (`country_monthly.txt:2-20`): `monthly_country_pulse = { on_actions = { … } random_events = { … } events = { … } }` — a mod adds its own on_action file containing `monthly_country_pulse = { on_actions = { cw_monthly_army_pulse } }` (on_actions with the same name are merged/appended by the engine — INFERRED from the vanilla split of `on_winning_war`/`on_ending_war` across `_hardcoded.txt` and `religious_order_conquest.txt`, which both define them). `on_actions.info` documents `trigger`, `effect`, `events`, `random_events`, `first_valid`, `on_actions`, `fallback`, `delay`.

---

## 12. Unit size / strength values and "largest army" (part c)

Values readable in **unit** scope (as triggers with comparators and inside script values / `order_by`):

| Value | Status | Notes |
|---|---|---|
| `num_subunits` | VERIFIED as `order_by` (`parliament.txt:1264`, `little_ice_age.txt:1663`); VERIFIED-INDEX as trigger | regiment/ship count |
| `unit_strength` | VERIFIED as script value term (`hellenism_religion.txt:301`) | semantics INFERRED = total men (GUI analogue `Unit.GetVisualStrength`, `Unit.GetAccumulatedUnitStat`) |
| `strength_percentage`, `morale_percentage`, `experience_percentage`, `food_percentage` | VERIFIED (`experience_percentage` as `order_by` `D008…:390`; `scope:target_army.food_percentage` as value) | 0..1 |
| `sub_unit_strength:<category>`, `sub_unit_count:<category>`, `sub_unit_fraction:<category>`, `total_sub_unit_category_in_unit:<category>` | VERIFIED as triggers; INFERRED usable as values | per-category men / count / fraction |
| sub_unit: `subunit_strength`, `subunit_morale`, `subunit_strength_percentage`, `subunit_morale_percentage` | VERIFIED (`order_by = subunit_strength` `D008…:2440`) | men per regiment |
| Country: `army_size`, `regular_army_size`, `num_regiments`, `total_sub_unit_type_count:<type>`, `military_strength`, `country_strength` | VERIFIED (`order_by = military_strength` 14×, `order_by = army_size` 1×, `order_by = expected_army_size` 2× — all on country lists) | |

**Largest army (VERIFIED recipe)** — `common/generic_actions/parliament.txt:1261-1273`:

```
			if = {
				limit = { regular_army_size > 0 }
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
			}
```

Preferred for "largest by men": `order_by = unit_strength` (VERIFIED term) or the composite script value from `hellenism_religion.txt:299-305`. The engine itself has a "largest army" notion (`is_leading_largest_army_of = <country>` character trigger, `auto_modifiers/country.txt:1251`) — its metric is unknown.

Engine defines relevant to sizes (`loading_screen/common/defines/00_defines.txt`): `REGIMENT_SIZE = 1000` (:381), `BASE_REGIMENT_PRICE_SCALE = 0.1  #100 men is a base` (:374), `AI_SUPPLY_LIMIT_TARGET = 0.95` (:1025, "AI will try to make army stacks of this ratio of average supply limit"), `RATIO_OVER_SUPPLY_TARGET_TO_SPLIT = 1.3` (:1026), `AI_LAND_ARMY_MERGE_THRESHOLD = 0.80` (:1137, "Idle armies below 80% frontage fill are candidates for merging"), `AI_HOSTILE_BORDER_MIN_SUBUNITS = 3` (:1061), `OUTNUMBERED_BATTLE_ADVANTAGE = 0.60` (:1110).
Unit types scale men with `max_strength` (multiplier of REGIMENT_SIZE, INFERRED): age-1 infantry `max_strength = 0.5` (`unit_types/00_age_templates_land.txt:69`), age-3 auxiliary `max_strength = 0.15` (`:260`), age-4 infantry `2.0` (`:285`) → a 100-man HQ ≈ `max_strength = 0.1` (INFERRED).

---

## 13. Recommended pseudo-implementation (part b)

Files (mod layout mirrors game): `in_game/common/scripted_triggers/cw_unit_triggers.txt`, `in_game/common/scripted_effects/cw_unit_effects.txt`, `in_game/common/on_action/cw_on_actions.txt`, `main_menu/common/static_modifiers/cw_unit_modifiers.txt`, `main_menu/common/script_values/cw_values.txt`, `in_game/common/unit_types/cw_headquarters.txt`.

Everything below is composed only of VERIFIED building blocks unless tagged.

```
# ---------- main_menu/common/static_modifiers/cw_unit_modifiers.txt  (format: static_modifiers/unit.txt:85-91)
cw_no_hq_penalty = {
	game_data = { category = unit }
	siege_ability = -0.9          # modifier type category=unit, 00_modifier_types.txt:5985
	discipline = -0.10            # :6014
	land_morale_modifier = -0.20  # :4537
}
cw_colonial_hq_bonus = {          # small buff ONLY while on an overseas continent
	game_data = { category = unit }
	land_morale_modifier = 0.05
	land_unit_attrition = -0.10   # used in unit.txt:73
}

# ---------- in_game/common/scripted_triggers/cw_unit_triggers.txt   (root = whatever calls it; written scope-relative)
cw_army_has_hq_trigger = {                     # unit scope
	any_sub_unit = { OR = { sub_unit_type = unit_type:cw_hq  sub_unit_type = unit_type:cw_colonial_hq } }
}
cw_army_has_colonial_hq_trigger = {            # unit scope
	any_sub_unit = { sub_unit_type = unit_type:cw_colonial_hq }
}
cw_army_is_overseas_trigger = {                # unit scope; pattern: flavor_cas_por.txt:26 + hussite_tribunal.txt:27 (prev)
	unit_location = { NOT = { continent = prev.owner.capital.continent } }
}
cw_army_needs_hq_trigger = {                   # unit scope: which stacks the rule applies to
	is_army = yes
	is_exiled = no
	has_only_prisoners = no
	NOT = { has_levies = yes  has_regulars = no }   # pure-levy stacks exempt (design choice; see §14)
}

# ---------- in_game/common/scripted_effects/cw_unit_effects.txt
# root = country. Called monthly for every country (AI and human).
cw_monthly_army_update = {
	# (1) penalty bookkeeping on every army -------------------------------------------------
	every_army = {
		limit = { cw_army_needs_hq_trigger = yes }
		if = {
			limit = { cw_army_has_hq_trigger = yes }
			if = {
				limit = { has_unit_modifier = cw_no_hq_penalty }
				remove_unit_modifier = cw_no_hq_penalty                     # johan_debug:293
			}
		}
		else = {
			# re-applied every month with mode = replace so it never expires while the condition holds,
			# and self-cleans ~1 year after the mod stops re-applying it (e.g. mod removed, army got an HQ via on_action).
			add_unit_modifier = { modifier = cw_no_hq_penalty years = 1 mode = replace }   # parliament.txt:1268-1272
		}
		# colonial HQ buff only while overseas
		if = {
			limit = { cw_army_has_colonial_hq_trigger = yes  cw_army_is_overseas_trigger = yes }
			add_unit_modifier = { modifier = cw_colonial_hq_bonus years = 1 mode = replace }
		}
		else_if = {
			limit = { has_unit_modifier = cw_colonial_hq_bonus }
			remove_unit_modifier = cw_colonial_hq_bonus
		}
	}

	# (2) keep the country's HQ limit variable fresh (script values: cw_values.txt) ----------------
	set_variable = { name = cw_hq_limit value = cw_hq_limit_value }                 # set_variable with script value: reform_society.txt:30-33
	set_variable = { name = cw_colonial_hq_limit value = cw_colonial_hq_limit_value }

	# (3) AI only: put HQs into the largest HQ-less armies, up to the limit ------------------------
	if = {
		limit = { is_ai = yes  regular_army_size > 0 }                               # ai_personalities_setup.txt:16, parliament.txt:1261
		ordered_army = {
			limit = {
				cw_army_needs_hq_trigger = yes
				cw_army_has_hq_trigger = no
				in_combat = no
				in_retreat = no
			}
			order_by = num_subunits                                                  # or: order_by = unit_strength (hellenism_religion.txt:301)
			max = {                                                                  # script-value max: earthquake_events.txt:166-174
				value = var:cw_hq_limit
				subtract = total_sub_unit_type_count:cw_hq                           # country_specific.txt:1969
				min = 0
			}
			check_range_bounds = no
			add_subunit = unit_type:cw_hq                                            # johan_debug:419  (limit-respect: UNVERIFIED)
		}
		# colonial HQs: only into armies standing on an overseas continent
		ordered_army = {
			limit = {
				cw_army_needs_hq_trigger = yes
				cw_army_has_hq_trigger = no
				cw_army_is_overseas_trigger = yes
				in_combat = no
			}
			order_by = num_subunits
			max = { value = var:cw_colonial_hq_limit subtract = total_sub_unit_type_count:cw_colonial_hq min = 0 }
			check_range_bounds = no
			add_subunit = unit_type:cw_colonial_hq
		}
	}

	# (4) over-limit cleanup (ages change, locations lost): strip surplus HQs from the SMALLEST armies first
	if = {
		limit = { total_sub_unit_type_count:cw_hq > var:cw_hq_limit }
		ordered_army = {
			limit = { cw_army_has_hq_trigger = yes }
			order_by = { value = num_subunits multiply = -1 }                       # reversed sort (INFERRED; alternative: position = …)
			max = { value = total_sub_unit_type_count:cw_hq subtract = var:cw_hq_limit min = 0 }
			check_range_bounds = no
			destroy_every_sub_unit_of_type = { sub_unit_type = unit_type:cw_hq }    # unit_effects.txt:39-54 (handles last-regiment case)
		}
	}
}

# ---------- main_menu/common/script_values/cw_values.txt   (root = country)  format: default_values.txt:664-673
cw_hq_limit_value = {
	add = { value = 1 desc = "SUBUNIT_LIMIT_BASE" }
	add = { value = num_locations divide = 100 }                 # num_locations as value: auto_modifiers/country.txt:333
	if = { limit = { current_age = age_3_discovery }   add = 1 }  # current_age: holy_war_values.txt:4-12
	if = { limit = { current_age = age_4_reformation } add = 2 }
	if = { limit = { current_age = age_5_absolutism }  add = 3 }
	if = { limit = { current_age = age_6_revolutions } add = 4 }
	floor = yes                                                   # UNVERIFIED keyword; otherwise round via integer variable
}
cw_colonial_hq_limit_value = {
	value = 0
	if = { limit = { any_owned_location = { NOT = { continent = root.capital.continent } } } add = 2 }   # flavor_cas_por.txt:26 pattern
}

# ---------- in_game/common/on_action/cw_on_actions.txt
monthly_country_pulse = {                      # country_monthly.txt:2 (code-invoked, root = country)
	on_actions = { cw_monthly_army_pulse }
}
cw_monthly_army_pulse = {
	trigger = { is_real_country = yes }        # trigger index country_triggers.txt (is_real_country); avoids rebels/pirates
	effect = { cw_monthly_army_update = yes }
}
on_new_age = {                                 # _hardcoded.txt:640, root = country for every country
	effect = { set_variable = { name = cw_hq_limit value = cw_hq_limit_value } }
}
on_command_gained = {                          # _hardcoded.txt:669-671, root = character, scope:unit = unit → instant re-check on reorganisation events the engine exposes
	effect = { scope:unit.owner = { cw_monthly_army_update = yes } }   # INFERRED link chain (scope:unit → owner VERIFIED for scope:actor.owner)
}
```

Unit type sketch (`in_game/common/unit_types/cw_headquarters.txt`; keys from `unit_types/readme.txt:3-28`, `limit` form from `1_uniques_for_age_4_reformation.txt:72-77`, family limit from `unit_families/readme.txt`):

```
cw_hq = {
	category = army_auxiliary          # auxiliary = yes category; exclude_from_combined_arms = yes (05_army_auxiliary.txt:4,33)
	is_special = yes                   # 3_janissaries.txt:3
	buildable = yes
	levy = no
	max_strength = 0.1                 # ≈100 men (INFERRED scaling, see §12)
	combat_power = 0
	supply_weight = 0.05
	limit = cw_hq_limit_value          # script value, as `limit = wagenburg_unit_limit` (1_uniques_for_age_2_renaissance.txt:61)
	country_potential = { … }          # root = country
	maintenance_demand = …             # "free" = empty goods demand: UNVERIFIED whether allowed
	construction_demand = …
	gfx_tags = { … }
}
```
(Unit-type details belong to the unit-types research doc; listed here only because `add_subunit`/`limit` interplay matters.)

---

## 14. Caveats (part e)

1. **`add_subunit` and limits** — only usage is a debug event. Whether it checks `limit`, `buildable`, `country_potential`, manpower/goods cost, or age availability is UNVERIFIED; design assumes it ignores all of them, so the scripted limit variable must be enforced by script (§13 steps 3–4). If it silently fails when over limit, the `max = {limit − count}` guard already prevents a runaway loop (no `while`).
2. **Levies vs regulars** — unit: `has_levies / has_regulars / has_mercenaries`; sub_unit: `is_levy`, `is_mercenary`, `definition_is_for_levy`; unit type: `levy = yes/no`. Levy units are raised/disbanded by the engine (`raise_all_levies`, `has_raised_levies`). Putting a regular HQ regiment into a levy army and what happens to it on disband: UNVERIFIED → either exempt pure-levy armies from the penalty (as in `cw_army_needs_hq_trigger`) or keep HQs only in armies with `has_regulars = yes`.
3. **Mercenaries** — hired companies are `mercenary` objects (`every_hired_mercenary`), with `customer` (hirer) and `owner` (lender/home). Their regiments are reachable via `every_mercenary_sub_unit` and flagged `is_mercenary`. Whether a hired company's unit appears in the hirer's `every_army` is UNVERIFIED (vanilla checks `has_mercenaries` on units from `every_unit`, so mercenary regiments can sit inside normal armies). `recall_lent_unit = {}` "destroys and recreates the underlying unit" (`return_lent_unit.txt:28-29`) → unit modifiers/HQs on lent units are lost; `lend_unit_to_country` converts a unit into a lent "mercenary".
4. **Army countries** — conquistador/pop armies are countries with `country_type = army/pop`; vanilla excludes them with `NOT = { country_type = army }` (`lend_unit_to_ally.txt:12`). Use `is_real_country = yes` or that check in the pulse trigger so HQ rules don't hit expeditions/rebels (`country.txt:11` says non-real = Rebels, Pirates, Mercenaries).
5. **Embarked / transported armies** — `is_carrying_troops` (unit), `is_carrying_or_loaded_unit` (mercenary), `Unit.IsInTransport` (GUI). Adding/removing regiments while embarked is risky (vanilla explicitly skips embarked units in `return_lent_unit.txt:28-31`).
6. **`every_unit` includes navies** — always use `every_army` or `is_army = yes` / `is_navy = no`.
7. **`root` inside iterators** — scripted triggers/effects called from `every_army` see `root = country`; use `this`/`prev`/`owner` for unit-relative logic (§1).
8. **Modifier durations** — no vanilla permanent unit modifier via script (`add_unit_modifier_forever` exists only in the loc index). Re-apply with `mode = replace` monthly, or test `add_unit_modifier_forever`.
9. **Variables on units** — no vanilla precedent; store state as country variables or encode it as a unit modifier flag (`has_unit_modifier` is cheap and VERIFIED).
10. **Prisoner stacks** — units with `has_only_prisoners = yes` exist (captured armies); exclude them (`drill_army.txt:13`).
11. **on_battle_won `scope:actor/target` are written as "unit" in quotes** in vanilla comments; vanilla only uses `.owner`, `.leader`, `.unit_location` and calls a unit-scope scripted effect on them — treat as unit scope but don't rely on sub-unit iteration there without testing.

---

## 15. Pitfalls

- `check_range_bounds = no` is set in every vanilla `ordered_army`/`ordered_unit` with `max` (`parliament.txt:1266`, `little_ice_age.txt:1665`, `D008…:389`) — omit it and an empty/short list logs errors.
- Prefix rules: `sub_unit_type = unit_type:X`, `add_subunit = unit_type:X`, `create_sub_unit = unit_type:X`, `change_subunit_type = unit_type:X`, but `create_sub_unit_with_owner = { type = X }` (bare) and `unlock_unit = X` (advances, bare).
- `destroy_subunit` on the last regiment: follow `destroy_every_sub_unit_of_type` (destroy the unit instead).
- `?=` (optional link) everywhere a link may be empty: `owner ?=`, `leader ?=`, `unit ?=`, `unit_location.owner ?=`, `scope:x ?=`.
- `every_country_sub_unit` monthly for every country is O(regiments); prefer `every_army + any_sub_unit` (early-exit) as in §13.
- `monthly_country_pulse` is one on_action shared by vanilla; put mod logic in a *separate* named on_action listed under `on_actions = {}` and never redefine vanilla's `events`/`random_events` blocks (INFERRED merge semantics; verify in `error.log` that vanilla monthly events still fire).
- Unit-scope GUI filters (`gui/filters/07_unit.txt:5-13`, `scope = unit tag = unit trigger = { has_commander = yes }`) show the engine accepts `scope = unit` for filter scripts — a hint (not proof) that `scope = unit` scripted GUIs / auto modifiers may be accepted (`scripted_guis.info: scope = <string>`; no vanilla scripted_gui uses `unit`).
- Loc keys for custom tooltips of unit effects follow `effect_localization` structure (`global/third/global_past/third_past`); for any new scripted effect used in option tooltips add a `custom_description` with a *different* key than the effect (`scripted_effects/readme.txt:31-38`).
- `error.log` (`Documents/Paradox Interactive/Europa Universalis V/logs/error.log`) currently has **no** unit-related script errors — a clean baseline for diffing after adding the mod.

---

## 16. Recommendations for the mod

1. **Test two architectures in this order** (each is a 10-minute in-game test):
   a. Auto modifier with `type = unit`, `category = unit`, `potential_trigger = { is_army = yes NOT = { any_sub_unit = { sub_unit_type = unit_type:cw_hq } } }` carrying the penalty (UNVERIFIED but highest payoff: instant, engine-tooltipped, AI-aware).
   b. Fallback (fully VERIFIED parts): the monthly scripted effect of §13 hooked into `monthly_country_pulse`, plus `on_new_age` and `on_command_gained` hooks for faster refresh.
2. Use **penalty-only** modifier `cw_no_hq_penalty` (siege_ability −0.9, discipline/morale malus) and **no** HQ bonus — matches the brief and the vanilla `army_leaderless` precedent (`static_modifiers/unit.txt:11-16`). Consider also re-tuning `army_leaderless` itself in the same override file.
3. Find the largest army with `ordered_army = { order_by = num_subunits … }` (VERIFIED) and switch to `order_by = unit_strength` only after confirming in game that the value is the men count (check tooltip of a debug `custom_tooltip`/`debug_log` with `[Unit.GetVisualStrength]`).
4. Keep HQ accounting on the **country**: `total_sub_unit_type_count:cw_hq` (VERIFIED value) vs. `var:cw_hq_limit`; never iterate all regiments to count.
5. Enforce the limit twice: engine-side via the unit type `limit = cw_hq_limit_value` (blocks the player's recruitment UI) and script-side for `add_subunit` (AI) with `max = {limit − count}`; add the surplus-removal pass (§13 step 4) for age/territory changes.
6. Exempt non-real countries (`is_real_country = yes`), prisoner stacks, exiled stacks and (decide) pure-levy stacks; recheck `has_mercenaries` handling once the mercenary/`every_army` relation is tested.
7. Colonial HQ: define `cw_colonial_hq` as a separate unit type with its own `limit` (`cw_colonial_hq_limit_value`: >0 only when the country owns locations on another continent — `any_owned_location = { NOT = { continent = root.capital.continent } }`), buff applied only while `unit_location.continent != owner.capital.continent`.
8. For the war-stance feature, `on_battle_won/lost`, `on_siege_won/lost`, `on_location_occupied` (scopes in §11) are the only unit/war event hooks; there is no daily tick — drive stance evaluation from `monthly_country_pulse` and these events.
9. Use `has_unit_modifier` as the state flag for GUI (`[Unit.…]` data functions in the army window can show the modifier; the 4th tab can read `GetNumSubUnits`, `SubUnit.GetDefinition`, `SubUnit.IsLevy/IsMercenary/IsRegiment` — 17/11/13 vanilla uses) instead of variables on units.
10. Before shipping, grep `error.log` for `cw_` after a 1-year test run; validate that `add_subunit` actually inserted a regiment (`[Unit.GetNumSubUnits]` before/after) and that the regiment survives merges/splits done by the player (merge/split are engine actions with no script hook — the monthly pass reconciles).

---

## Appendix A — full index lists (names only, from `common/effect_localization` / `trigger_localization`)

- Unit effects: `remove_unit_modifier add_unit_modifier add_unit_modifier_duration add_unit_modifier_forever add_morale add_subunit lock_unit unlock_unit add_food add_food_percentage destroy_unit set_unit_size change_unit_owner damage_unit_percent damage_unit_morale_percent set_as_commander make_unit_available_for_hire move_to_assist_on_adjacent_combat lend_unit_to_country` (+ `remove_commander`, `change_unit_modifier_size` in `common_effects.txt`).
- Sub-unit effects: `add_subunit_morale destroy_subunit add_subunit_strength add_subunit_strength_percentage add_subunit_experience change_subunit_type`.
- Location effects (unit-related): `create_army_country_in_location create_sub_unit_of_category create_sub_unit create_num_sub_unit_of_category create_sub_unit_with_owner spawn_army_levy_unit spawn_navy_levy_unit change_siege_progress change_garrison_size set_garrison_size`.
- Country effects (unit-related): `raise_all_levies raise_all_levies_instant hire_mercenary dismiss_mercenary set_country_military_stance add_army_tradition set_army_tradition`.
- Siege effects: `add_breach remove_breach garrison_sortie`; combat side effects: `hire_prisoners_as_mercenaries ransom_prisoners request_ransom_prisoners move_prisoners_to_safety execute_prisoners sell_prisoners_into_slavery`; mercenary effects: `become_hired_by destroy_mercenary`; war effects: `add_bonus_warscore set_revolt_target add_access_for_attackers add_access_for_defenders`.
- Unit triggers: see §3; sub-unit triggers: see §4; siege trigger: `in_assault`; mercenary triggers: `has_customer monthly_cost is_carrying_or_loaded_unit` (+ `is_lent_unit` VERIFIED by usage).

## Appendix B — key verbatim snippets not quoted above

`events/debug/000_johan_debug.txt:398-410` (unit triggers):
```
		any_unit = {
			is_moving = no
			is_army = yes
			is_movement_locked = no
			morale_percentage = 0.73
			strength_percentage >= 0.20
			experience_percentage >= 0.95
			is_unit_locked = no
			is_exiled = no
			food_percentage < 0.654
			is_carrying_troops = no
		}
```

`events/situations/little_ice_age.txt:1662-1684` (largest army + damage):
```
		ordered_army = {
			order_by = num_subunits
			max = 1
			check_range_bounds = no
			save_scope_as = target_army
			unit_location = {
				save_scope_as = target_location
				province = { save_scope_as = target_province }
			}
		}
	…
		scope:target_army = {
			damage_unit_percent = { 0.33 1 }
			damage_unit_morale_percent = { 0.5 1 }
			add_food_percentage = { -0.5 1 }
		}
```

`common/unit_abilities/convert_galley.txt:33-57` (loop over sub units with `while`):
```
		while = {
			limit = {
				owner = { gold >= 5 }
				any_sub_unit = { is_ship = yes sub_unit_category = sub_unit_category:navy_galley }
			}
			owner = { add_gold = -5 }
			random_sub_unit = {
				limit = { is_ship = yes sub_unit_category = sub_unit_category:navy_galley }
				scope:ship_unit = {
					unit_location = { create_sub_unit_of_category = sub_unit_category:navy_light_ship }
				}
				destroy_subunit = yes
			}
		}
```

`common/on_action/country_monthly.txt:216-228` (siege scope iterator):
```
wor_on_wallenstein_prison_occupation = {
	trigger = {
		global_var:wallensteins_prison ?= {
			has_siege = yes
			siege = {
				any_besieging_unit = {
					owner = { has_variable = wallenstein_rescue_mission }
				}
			}
		}
	}
	effect = { trigger_event_non_silently = war_of_religions.1203 }
}
```

`in_game/common/auto_modifiers/readme.txt:1-18` (auto modifier attributes; `type`/`category` — `type = unit` untested):
```
# - category: Modifier category for the modifiers. (default: country - if set must be before any modifiers)
# - type: Scope type for potential_trigger. (default: country - if set must be before potential_trigger )
# - potential_trigger: trigger for if the auto modifier will be applied
# - scales_with: evaluates a value to multiply the auto modifier effects by
# - limit: trigger checks to see when the auto modifier can be applied
# - alert: (yes/no) should this modifier show in the alerts when it is active?
```
