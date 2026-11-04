# 01 — Defining the HQ regiment as a new unit type

EU5 1.4.7 (Caesar/Jomini). Research for mod **Concentrated Warfare** (`cw_`).
All paths are relative to `game/` inside the EU5 install unless stated otherwise
(`G:` = `C:\Program Files (x86)\Steam\steamapps\common\Europa Universalis V\game`).
Workshop mods: `WS:3600272327` = Cheat Menu Pro, `WS:3634102315` = Simple Cheats.
User data: `U:` = `C:\Users\fyrno\Documents\Paradox Interactive\Europa Universalis V`.

Legend:
- **VERIFIED** — seen in vanilla/workshop script with the quoted syntax (file:line).
- **INFERRED** — composition of verified parts, or a reading of code comments / localization text.
- **UNVERIFIED** — not seen anywhere; must be tested in game (see §14).

---

## 0. TL;DR

| Question | Answer | Status |
|---|---|---|
| Where | `in_game/common/unit_types/*.txt` (mod: `in_game/common/unit_types/cw_headquarters.txt`) | VERIFIED |
| 100 men | `max_strength = 0.1` with `category = army_auxiliary` (category `max_strength = 0`); `NUnit.REGIMENT_SIZE = 1000` | VERIFIED |
| Free | no "empty demand" exists in vanilla; use **near-zero** goods demands + **negative per-unit price override** in `common/prices` (`<unit_key>_build/_reinforce/_maintenance`, pattern `a_clan_retainers_build = { gold = -30 }`) | VERIFIED pattern / UNVERIFIED that a 0 total is accepted |
| Always available | `buildable = yes` + `country_potential = { always = yes }`, **no** advance `unlock_unit` needed (`a_order_knights`, `a_champions`, `a_jonow_auxiliary` do this) | VERIFIED |
| Limit | `limit = cw_hq_limit` (named country-scope script value, pattern `limit = wagenburg_unit_limit`) or inline formula with `desc` keys | VERIFIED |
| Age-aware limit | `if = { limit = { current_age = age_3_discovery } … }` inside the script value; `current_age_or_later = { age = … }` as trigger | VERIFIED |
| Owned-location count | `num_locations` (country-scope value and trigger); `num_locations_owned_or_owned_by_subjects` (trigger) | VERIFIED |
| Enforcement | blocks **recruitment / hiring / templates / upgrades** (counts in-progress too); **no** automatic disband found | VERIFIED loc / INFERRED |
| AI recruits it? | unit types carry **no AI fields**; AI composes by *category* (`ai_weight` on the category + defines). Do **not** rely on it — insert HQs by script (`add_subunit = unit_type:cw_hq`, unit scope) | VERIFIED / INFERRED |
| Build time | category `build_time = standard_aux_recruitment_time` = **30 days**; unit field `build_time_modifier` | VERIFIED |
| GFX | nothing mandatory: 2D art falls back by `unit_category`, 3D model is keyed by `army_auxiliary`; optional `is_unit_type` illustration entry | VERIFIED |
| Loc | `cw_hq: "…"`, `cw_hq_desc: "…"` in `main_menu/localization/<lang>/*.yml` + one key per `desc` used in the limit formula | VERIFIED |
| Referencing | `sub_unit_type = unit_type:cw_hq` (sub_unit scope), `total_sub_unit_type_count:cw_hq` (country), `sub_unit_fraction:<CATEGORY>` (unit scope, categories only) | VERIFIED |

---

## 1. Files read

- `in_game/common/unit_types/readme.txt`, `00_age_templates_land.txt`, `1_uniques_for_age_{1..6}_*.txt`, `2_unlocked_through_tech.txt`, `0_tribal.txt`, `0_knights.txt`, `3_camel_units.txt`, `a_north_american.txt`, `a_nahuatl.txt`, `a_bedouin_cavalry.txt`, `2_conquistador.txt`, `D008_byzantine_unit_types.txt`, `navy_galley.txt`
- `in_game/common/unit_categories/*.txt` + readme, `unit_families/*` + readme, `levies/readme.txt`, `recruitment_method/army.txt` + readme
- `in_game/common/goods_demand/army_demands.txt`, `hardcoded.txt`, `from_events.txt`, `goods_demand_category/00_default.txt`
- `in_game/common/prices/02_units.txt` + readme (**gold/manpower price per category + per-unit overrides — this is where "free" is decided**)
- `main_menu/common/script_values/default_values.txt` (unit limits, build times), `in_game/common/script_values/_script_values.info`, `unit_values.txt`
- `loading_screen/common/defines/00_defines.txt` (`NUnit`, `NAI`), `defines/graphic/00_graphics.txt`
- `in_game/gfx/unit_illustrations/readme.txt`, `00_unit_illustrations.txt`, `dlc/D009_across_the_pillars/in_game/gfx/unit_illustrations/d009_unit_illustrations.txt`, `main_menu/gfx/unit_graphics/units/00_units.info`, `01_army.txt`
- `main_menu/localization/english/units_l_english.yml`, `interfaces_l_english.yml`, `economy_l_english.yml`, `modifier_types_l_english.yml`, `effects_l_english.yml`
- `in_game/common/advances/2_army_unlocks.txt`, `country_BOH.txt`, scripted triggers/effects (`has_unlocked_unit_trigger`, `unlock_unit_effect`), `customizable_localization/subunit_types.txt`, `unit_formation_preference/army.txt`, `gui/filters/07_unit.txt`, `modifier_type_definitions/00_modifier_types.txt`, `modifier_icons/00_modifier_icons.txt`
- GUI: `in_game/gui/army_builder.gui`, `unit_overview.gui`, `shared/unit_tooltips.gui`, `shared/combat_tooltips.gui`, `setup_mercenary_requirements.gui`
- Logs: `U:/logs/error.log` (no unit-type errors in the current log), `U:/logs/ai.log` (only "AI tried to execute invalid command: disband_subunit/upgrade_subunit/…" warnings)
- Workshop: `WS:3600272327/in_game/common/scripted_effects/sakuya_army_generator_effects.txt` (spawning units by type)

No script documentation dump (`triggers.log`/`effects.log`/`docs/`) exists in the install or the user folder; names were verified by usage only. The project cache `tools/cache/vanilla_script_keys.txt` contains every token below that is marked VERIFIED (e.g. `num_locations`, `total_sub_unit_type_count`, `add_subunit`, `any_country_sub_unit`), and does **not** contain `num_owned_locations` or `add_sub_unit`.

---

## 2. Unit type field reference

### 2.1 Documented fields (`in_game/common/unit_types/readme.txt:3-57`)

```
# age: determines in which age this unis is enabled
# build_time:
# upgrades_to = <another unit type> preferred upgrade path if available (optional)
# buildable = yes / no
# levy = yes / no (can be used for levy)
# default:
# construction_demand:
# maintenance_demand:
# repair_demand:        # Goods consumed while reinforcing or repairing. Falls back to the category's repair_demand, then to construction_demand
# use_ship_names = yes / no
# assault = yes/no      # Allows the unit to assualt a fort
# bombard = yes/no      # Allows the unit to bombard a fort
# auxiliary = yes/no    # The unit gets treated as an auxiliary unit
# category = <unit_category>
```
(`readme.txt:3-16`), continued (`readme.txt:17-30`):
```
# location_trigger = { <location_triggers> }   # Allows the unit to recruit in the location if the location triggers are fulfilled
# location_potential = { <location_triggers> } # Shows the unit to recruit in the location if the location triggers are fulfilled
# country_potential = { <country_triggers> }   # Shows the unit to recruit if the triggers are fulfilled
# mercenaries_per_location = { pop_type = <pop type> multiply = <proportion> }
# limit = { <value calculations> } / <default_value>    # Determines how many units of this type you can have
# combat = { <topography> / <vegetation> / <climate> / coastal / inland / river }   # damage modifier per terrain
# impact = { ... }                                      # movement speed modifier per terrain
# copy_from = <unit_type>   # The unit type will copy all its value from the specified unit template. All traits can be then further modified later
# force_culture = <culture> / force_religion = <religion> / force_culture_gfx = yes/no
# gfx_tags = {}
# color = color             # override primary color in visuals
```
Modifier stats allowed on a unit type (`readme.txt:31-57`): general `morale_damage_taken, strength_damage_taken, morale_damage_done, strength_damage_done, supply_weight, attrition_loss, food_storage_per_strength, food_consumption_per_strength, movement_speed`; land `max_strength, combat_speed, initiative, frontage, combat_power, flanking_ability, secure_flanks_defense`; naval `transport_capacity, maritime_presence, crew_size, blockade_capacity, cannons, hull_size, anti_piracy_warfare`.

### 2.2 Fields used in vanilla but not in the readme (counts = occurrences across `unit_types/*.txt`) — all VERIFIED by usage

| Field | Count | Meaning (status) | Example |
|---|---|---|---|
| `is_special = yes` | 206 | flags a "special regiment": gold frame in the army builder (`UnitTypeItem.IsSpecialRegiment`, `army_builder.gui:1150-1151`), excluded from the *generic* levy ladder (`levies/readme.txt:103-104`), AI tech scoring `AI_UNLOCK_SPECIAL_UNIT_FACTOR = 3` (`00_defines.txt:1579`). No stat effect. | `1_uniques_for_age_2_renaissance.txt:57` |
| `hide = yes` | 40 | only on the age templates in `00_age_templates_land.txt`; hides the template from lists (INFERRED) | `00_age_templates_land.txt:68` |
| `empty = yes` | 4 | only on the 4 bare category templates (`a_light_infantry` …) (INFERRED: "no stats, not a real unit") | `00_age_templates_land.txt:12` |
| `family = <key>` | 31 | shared limit across unit types (`unit_families/readme.txt`) | `1_uniques_for_age_1_traditions.txt:566` |
| `upgrades_to_only = <key>` | 20 | forced single upgrade path (INFERRED vs `upgrades_to`) | `3_janissaries.txt:5` |
| `build_time_modifier = <float>` | 23 | relative change of the category build time (sign: see §5) | `1_uniques_for_age_2_renaissance.txt:73` |
| `content_priority = <int>` | 2 | ordering in content lists (INFERRED) | `1_uniques_for_age_1_traditions.txt:560` |
| `use_religious_order_coa = yes` | 12 | visuals of order knights | `0_knights.txt:169` |
| `bombard_efficiency`, `artillery_barrage` | 8 / 7 | artillery-only stats | `00_age_templates_land.txt:130-132` |
| `default = yes` | 3 | marks the starting/default unit of its category (`a_footmen`, `a_archers`, + one age-1 unique) | `2_unlocked_through_tech.txt:6` |
| `color = <color key>` | 5 | model colour override | `1_uniques_for_age_6_revolutions.txt:41` |

Never used on a unit type: `ai_weight` (0 hits — it exists only on **categories**), `build_time` (0 hits — only on categories, units use `build_time_modifier`).

### 2.3 Category fields (`in_game/common/unit_categories/readme.txt:1-42`) and the auxiliary category

```
army_auxiliary = {
	is_army = yes
	auxiliary = yes
	movement_speed = 2.0
	build_time = standard_aux_recruitment_time
	max_strength = 0
	supply_weight = 0.2
	food_storage_per_strength = 3000
	food_consumption_per_strength = 0.2
	damage_taken = 1.25
	frontage = 1
	initiative = 1
	combat_speed = 0.1
	flanking_ability = 1.0
	secure_flanks_defense = 0
```
(`unit_categories/05_army_auxiliary.txt:1-25`) and
```
	maintenance_demand =  auxuliary_maintenance
	construction_demand = auxuliary_construction
	startup_amount = 1
	ai_weight = 0.25
	exclude_from_combined_arms = yes
}
```
(`05_army_auxiliary.txt:27-33`). Undocumented category fields seen: `fallback` (`00_army_light_infantry.txt:2`, "pre-1.2 values which some things like illustrations still use"), `is_garrison` (only light+heavy infantry), `damage_taken`, `startup_amount`, `ai_weight`, `exclude_from_combined_arms` (auxiliary + transport only), `transport = yes` (navy_transport).

---

## 3. Stat semantics: additive, category + unit; men per regiment

**Every stat line is additive** (`levies/readme.txt:46-50`, VERIFIED by the comment and by `a_varangians`):

```
#EVERY STAT LINE IS ADDITIVE, NEVER AN ASSIGNMENT. A unit's effective stat is
#  <its own accumulated value, inherited wholesale through copy_from and then added to by
#   each stat line in its own block>  +  <its category's value>
#So on a light cavalry unit (category initiative 5) that copies a parent already carrying
#initiative 5, writing "initiative = 2" yields 12, not 2.
```
Example: `a_varangians` copies `a_age_1_traditions_heavy_infantry` (`max_strength = 0.5`) and writes `max_strength = 0.1` (`1_uniques_for_age_1_traditions.txt:614-619`) → 600-man regiment, not 100.

**Regiment size**: `NUnit.REGIMENT_SIZE = 1000` (`loading_screen/common/defines/00_defines.txt:381`) and
`BASE_REGIMENT_PRICE_SCALE = 0.1		#100 men is a base  (divided)` (`00_defines.txt:374`).
Cross-check: `events/colonization/conquistador.txt:66-69` spawns `a_discovery_conquistadors` (template `a_age_3_discovery_heavy_infantry`, `max_strength = 1.5`) with the comment `count = 6 #6 * 1500 = 9K troops` → **`max_strength = 1.0` = 1000 men, `0.1` = 100 men** (VERIFIED).
Vanilla auxiliary templates are 50/100/150/200/250/300 men by age (`00_age_templates_land.txt:117,197,260,325,386,449`); they set the category directly:

```
a_age_2_renaissance_auxiliary = {
	category = army_auxiliary
	hide = yes
	buildable = no
	max_strength = 0.1
	combat_power = 0.25
	age = "age_2_renaissance"
}
```
(`00_age_templates_land.txt:193-201`). Because category `max_strength = 0`, writing `category = army_auxiliary` + `max_strength = 0.1` directly (no `copy_from`) yields exactly 100 men.

**Total combat power** used by the AI/levy code (`levies/readme.txt:37-44`):
`max_strength * combat_power * (1 + initiative*0.025) * (1 + (flanking_ability-1)*0.3) * (1+morale_damage_done)*(1-morale_damage_taken)*(1+strength_damage_done)*(1-strength_damage_taken)`.
A 100-man HQ with `combat_power = 0.25` has total power 0.025 — negligible, as intended.

Supply: category gives `supply_weight = 0.2` and `food_storage_per_strength = 3000` → a 100-man auxiliary still carries 300 food (INFERRED from the per-strength naming); if the HQ should not act as a supply wagon, add `food_storage_per_strength = -2990` (additive, UNVERIFIED that negative totals clamp to 0 — test).

---

## 4. Costs: goods demands, gold/manpower prices, "free"

### 4.1 Goods demands (`construction_demand` / `maintenance_demand` / `repair_demand`)
- Keys point into `in_game/common/goods_demand/*.txt`; a unit type without its own lines **falls back to the category** (`unit_types/readme.txt:11`, and e.g. `a_supply_carts` has none → category `auxuliary_*`). Vanilla auxiliary demands:
```
auxuliary_construction = {
	tools = 0.2
	leather = 0.1
	copper = 0.2
	category = regiment_construction
}
```
(`goods_demand/army_demands.txt:96-101`) and `auxuliary_maintenance` (paper/medicaments/tools/leather/salt 0.04-0.05, `:257-264`). Demand categories are plain `regiment_maintenance = {}` / `regiment_construction = {}` (`goods_demand_category/00_default.txt:4-5`).
- Demands are quoted **per 1,000 men**: `UNIT_T_MAINTENANCE_DEMAND_REGIMENT: "Monthly maintenance requires [SUBUNITDEFINITION.GetMaintenanceDemand.GetInfo] per #V 1,000#! men."` (`interfaces_l_english.yml:5822`) → a 100-man HQ already consumes 1/10 of the listed amounts (INFERRED).
- **No vanilla demand block is empty or all-zero** (checked all 8 files). Whether `cw_hq_construction = { category = regiment_construction }` (no goods) loads is UNVERIFIED. Safe route: a near-zero demand (`paper = 0.01`).

### 4.2 Gold and manpower (`in_game/common/prices/02_units.txt`) — the real cost
```
# All manpower costs scale by max_strength, so army units should be at 1 manpower
...
army_auxiliary_build = {
	gold = 100
	manpower = 1
}
army_auxiliary_reinforce = {
	gold = 5
	manpower = 1
}
army_auxiliary_maintenance = {
	gold = 1
	manpower = 0.02
}
```
(`prices/02_units.txt:2, 86-98`). Per-unit-type **additive overrides** use the unit key as prefix:
```
a_clan_retainers_build = {
	gold = -30 #Base 50 - 30 = 20
	manpower = 0
}
a_clan_retainers_reinforce = {
	gold = -1.5 #Base 2.5 -1.5 = 1
	manpower = 0
}
a_clan_retainers_maintenance = {
	gold = -0.3 #Base 0.5 - 0.3 = 0.2
	manpower = 0
}
```
(`prices/02_units.txt:184-197`; same for `n_panokseon_*` `:170-182`). So `cw_hq_build = { gold = -100 manpower = -1 }` etc. should cancel the category price (VERIFIED pattern; **UNVERIFIED** whether a resulting 0 or negative total is clamped — vanilla never goes to 0; the price readme offers `min`/`min_scale`/`max_scale`, `prices/readme.txt:28-30`, only used by diplomacy prices). Gold scaling by size: `BASE_REGIMENT_PRICE_SCALE = 0.1 #100 men is a base (divided)` → a 100-man regiment pays the base listed price, bigger regiments proportionally more (INFERRED from the comment). Category cost modifiers also exist (`army_auxiliary_build_cost_modifier`, `_reinforce_`, `_maintenance_`; `00_modifier_types.txt:3561-3581`, used e.g. `advances/country_chi.txt:194`).
- `LEVY_MAINTENANCE_FACTOR = 0.01` (`00_defines.txt:388`) is for levies only.

---

## 5. Build time and recruitment

- Category: `build_time = standard_aux_recruitment_time` (`05_army_auxiliary.txt:7`) with
```
standard_inf_recruitment_time	= 30
standard_cav_recruitment_time	= 45
standard_art_recruitment_time	= 60
standard_aux_recruitment_time	= 30
```
(`main_menu/common/script_values/default_values.txt:1231-1234`). Unit is **days**: `CONSTRUCT_REGIMENT_TOOLTIP: "Recruiting one [SUBUNITDEFINITION.GetName] in [LOCATION.GetName] will cost $COST$ and take $TIME|Y$ days."` (`interfaces_l_english.yml:5660`).
- Unit-level `build_time_modifier` (e.g. `a_genoese_crossbowmen` 0.5, `a_bedouin_cavalry` 0.1, `a_byzantine_cataphracts` 0.50). Sign: INFERRED positive = longer, by analogy with recruitment methods where `elite_training` has `experience = 20  build_time = 0.5` and `rushed_training` has `build_time = -0.75  strength = -0.75` (`recruitment_method/army.txt:6-16`).
- Country modifier `regiment_recruit_speed` (percent, `00_modifier_types.txt:6948-6953`, loc "Recruitment Speed").
- The readme lists `build_time:` as a unit field but **no vanilla unit type sets it** (UNVERIFIED on units).

---

## 6. Availability: buildable, advances, potentials, age

- `buildable` default is **yes**: `n_canoe` has no `buildable` line, no `copy_from`, and is recruitable (`navy_galley.txt:1-24`). The age templates set `buildable = no` + `hide = yes` explicitly.
- **No advance is required.** Buildable special units with no `unlock_unit` anywhere in `common/advances` (checked by script): `a_champions`, `a_clan_retainers`, `a_clan_retainer_cavalry`, `a_camel_auxiliary`, `a_crusader_knights`, `a_eagle_warrior`, `a_lodge_warriors`, `a_iberian_jinetes`, `a_jonow_auxiliary`, `a_varangians`, … Minimal pattern:
```
a_order_knights = {
	copy_from = a_order_knights_base
	is_special = yes
	upgrades_to = a_order_knights_2
	buildable = yes
	country_potential = {
		always = yes
	}
```
(`0_knights.txt:183-193`). Auxiliary analogue: `a_jonow_auxiliary = { copy_from = a_age_1_traditions_auxiliary  is_special = yes  upgrades_to = a_supply_carts  buildable = yes … }` (`1_uniques_for_age_1_traditions.txt:682-692`).
- Advance gating is an engine field `unlock_unit = a_wagenburg` in an advance (`advances/country_BOH.txt:13-22`, 207 uses) — the GUI then shows `SubUnitType.NeedsAdvance` / `GetUnlocks` (`shared/combat_tooltips.gui:367-370`). The scripted variant is a variable: `has_unlocked_unit_trigger = { type = X }` ⇔ `has_variable = unlocked_unit_X` (`scripted_triggers/country_triggers.txt:415-421`) set by `unlock_unit_effect = { type = X }` (`scripted_effects/country_effects.txt:234-242`, used in `events/DHE/flavor_pap.txt:540-542`). Not needed for the HQ.
- `copy_from` and `buildable/hide`: `a_footmen`, `a_camp_followers`, `a_supply_carts` copy templates that are `buildable = no  hide = yes`, set neither field, and are recruitable in game → INFERRED that `buildable`/`hide` are **not** inherited (or are reset by the unlock). Always write `buildable = yes` explicitly, as every `1_uniques_*` file does.
- `age = "age_1_traditions"` only drives the age icon (`GetAgeIcon(SubUnitType.GetAge)`, `army_builder.gui:1326`) and template selection; a unit **without `upgrades_to` keeps its stats for the whole game** (`levies/readme.txt:91-94`: "A buildable is never re-picked: it follows its own upgrades_to chain, and with no valid chain it keeps its starting age's stats for the rest of the game"). So one `cw_hq` with `age = "age_1_traditions"` is "available in all ages".
- Age gating inside potentials: `current_age_or_later = { age = age_3_discovery }` (`1_uniques_for_age_3_discovery.txt:114`, `advances/country_KON.txt:62`) or `OR = { current_age = age_4_reformation current_age = age_5_absolutism … }` (`1_uniques_for_age_4_reformation.txt:141-146`).
- `location_potential` / `location_trigger` omitted → recruitable in every owned location (`a_wagenburg` has neither). `location_trigger = { is_capital = yes }` restricts to the capital (`1_uniques_for_age_1_traditions.txt:629-631`). Overseas: `is_overseas_for_owner = yes` is a location trigger (`building_types/plantation_buildings.txt:17`); country side `capital.continent` / `capital ?= { continent = continent:america }` (`a_north_american.txt:19`, `customizable_localization/country_history.txt:178`).
- `mercenaries_per_location` omitted → no mercenary copies of the unit (INFERRED; all mercenary-able units set it).

---

## 7. Limits

### 7.1 Syntax
Named value (preferred): `limit = wagenburg_unit_limit` (`1_uniques_for_age_2_renaissance.txt:61`), `limit = ghilman_unit_limit` (`…age_4_reformation.txt:217`), defined in **`main_menu/common/script_values/default_values.txt`** (country scope):
```
wagenburg_unit_limit = {
	add = {
		value = 1
		desc = "SUBUNIT_LIMIT_BASE"
	}
	add = {
		desc = "EFFECTIVE_ARMORY_BUILDINGS"
		value = total_effective_building_levels:armory
	}
}
```
(`default_values.txt:664-673`). Inline with a cap/floor and a modifier term:
```
	limit = {
		value = {
			value = 2
			desc = "SUBUNIT_LIMIT_BASE"
		}
		add = modifier:num_of_banner_cavalry
	}
```
(`1_uniques_for_age_4_reformation.txt:199-205`; modifier type `num_of_banner_cavalry={ decimals=0 game_data={ category=country } }` `00_modifier_types.txt:13955-13960`, loc `MODIFIER_TYPE_NAME_num_of_banner_cavalry` `modifier_types_l_english.yml:3747`) and
```
	limit = {
		value = { value = 10  desc = "SUBUNIT_LIMIT_MAX" }
		multiply = { value = societal_value:quality_vs_quantity  multiply = -1  multiply = 0.01  desc = "SUBUNIT_LIMIT_SCALE_WITH_QUALITY" }
		min = { value = 1  desc = "SUBUNIT_LIMIT_MIN" }
	}
```
(`1_uniques_for_age_6_revolutions.txt:23-37`, reformatted). Every `desc = "KEY"` is a loc key shown in the breakdown (`SUBUNIT_LIMIT_BASE: "Base"`, `units_l_english.yml:379`; the breakdown format `UNIT_LIMIT_ENTRY_FORMAT: "$KEY$: $VALUE|+=2$"` `interfaces_l_english.yml:5815`). Script-value grammar (`if/else_if/limit/floor/min/max/value`) is in `in_game/common/script_values/_script_values.info`; age branches exactly as in
```
crusade_jihad_age_dampener = {
	value = 0
	if = {
		limit = { current_age = age_2_renaissance }
		value = -10
	}
	else_if = {
		limit = { current_age = age_3_discovery }
		value = -20
	}
```
(`in_game/common/script_values/holy_war_values.txt:1-10`).
- Family alternative: `family = cawa` + `unit_families/00_unit_families.txt:1-8` (`limit = { add = { desc = … value = total_effective_building_levels:cawa_barracks } }`); "A unit type that sets its own limit does not use its family's limit. Setting both is an error" (`unit_families/readme.txt:10-11`). Loc for the family name = the family key (`units_l_english.yml:1029 janissaries`).

### 7.2 Owned-location count (country scope)
- `num_locations` — value: `multiply = num_of_non_rural  divide = num_locations` (`advances/0_age_of_discovery.txt:587-588`, inside a country `ai_weight`); trigger: `num_locations > 0` (`advances/region_balkans.txt:10`). 155 uses. Also `num_of_non_rural` (towns+cities), `num_of_ports`, `num_provinces` (used by the Swiss Guard limit `…age_4_reformation.txt:72-77`).
- `num_locations_owned_or_owned_by_subjects >= 100` (trigger, `situations/italian_wars.txt:177`) if subjects should count.
- `any_owned_location = { count >= N … }` for conditional counting; list arithmetic in values (`every_owned_location = { limit = {…} add = 1 }`) follows `_script_values.info` ("Lists" / "Scoping") — INFERRED for `every_owned_location` specifically.
- `num_owned_locations` does **not** exist (0 hits, absent from the key cache).

### 7.3 How the engine enforces the limit (what is VERIFIED from text)
- Recruitment is blocked and in-production units count: `BUILD_UNIT_REACHED_LIMIT: "@trigger_no! We can only have … [SUBUNITDEFINITION.GetName], and we already have $CURR|V$."` and `BUILD_UNIT_REACHED_LIMIT_PLUS_SOME_IN_PROGRESS: "… and we already have $CURR|V$ plus $NEW|V$ in production"` (`interfaces_l_english.yml:5663-5664`); `UNIT_T_LIMIT: "[COUNTRY.GetName] can only have … at the same time."` (`:5820`).
- Upgrades into a limited type are blocked: `UPGRADE_ARMY_UNIT_TYPE_LIMIT_REACHED: "@trigger_fail! We have reached our limit for [SUBUNIT.GetDefinition.GetName] type."` (`units_l_english.yml:2524`).
- Mercenary hiring and templates respect it: `SUBUNIT_LIMIT_MAX_MERC` (`units_l_english.yml:377`), `SUBUNIT_LIMIT_MAX_TEMPLATE` (`interfaces_l_english.yml:3927`), slider cap `maxcap = "[PossibleSubUnitDefinition.GetAvailableLimit]"` (`setup_mercenary_requirements.gui:894`).
- **No** localization, define or GUI text about disbanding over-limit regiments was found → INFERRED: existing regiments survive when the limit shrinks; over-limit cleanup must be scripted (`every_country_sub_unit = { limit = { sub_unit_type = unit_type:cw_hq } … destroy_subunit = yes }`, see §11).
- Whether script effects (`add_subunit`, `create_sub_unit`) respect the limit is UNVERIFIED (effects normally bypass recruit checks).

---

## 8. `category = army_auxiliary` vs a brand-new category

Everything that references a unit category (grep for `army_auxiliary` outside unit files):

| Consumer | What it does with the category | army_auxiliary | New category `cw_hq_cat` |
|---|---|---|---|
| `unit_formation_preference/army.txt:33-35, 62-64` | `reserves = { 100 = army_auxiliary }` in both formations; front rows list only the 5 combat categories | HQ sits in reserves, never takes frontage | not listed → placement UNVERIFIED (must edit both formations) |
| `defines/graphic/00_graphics.txt:718-720` `FORMATION_PREFERENCE_BY_TAG_REAR = { army_auxiliary army_artillery … }` | 3D battle formation placement | rear | front by default (INFERRED) → add the key |
| `unit_categories/05_army_auxiliary.txt:31` `ai_weight = 0.25`, `startup_amount = 1` | AI army composition weight; starting regiments | shared with supply carts | own weight; `startup_amount` would spawn one at game start (INFERRED) |
| `NAI.AI_MINIMUM_AUXILIARY_RATIO = 0.15` (`00_defines.txt:1028`), `AI_UNIT_CATEGORY_WEIGHT_FROM_POWER = 10` (`:1029`), `AI_UNIT_CATEGORY_POWER_UTILITY = 0.08` (`:1475`) | AI keeps ≥15 % auxiliaries | HQ counts toward the ratio | AI has no rule for it |
| `exclude_from_combined_arms = yes` (`05_army_auxiliary.txt:33`); combined-arms concept `game_concepts_l_english.yml:2287` (bonus per additional category, none if ≥50 % one category) | auxiliaries don't count | neutral | **must** set `exclude_from_combined_arms = yes` or the HQ becomes a free extra category bonus |
| `prices/02_units.txt:86-98` `<cat>_build/_reinforce/_maintenance` + loc `economy_l_english.yml:637-639` | gold/manpower | exists | must be defined (engine likely requires the three keys — INFERRED) |
| `modifier_type_definitions/00_modifier_types.txt:88-93, 3561-3581` `<cat>_power`, `<cat>_build_cost_modifier`, `_reinforce_`, `_maintenance_` + icons `modifier_icons/00_modifier_icons.txt:1452,1546-1553` + loc | per-category modifiers | exist (`army_auxiliary_power = 0.25` in `static_modifiers/country.txt:9047`) | must be defined, or any reference errors (INFERRED) |
| `gfx/interface/icons/unit_category/<cat>.dds` (+ `unit_battle_category/`, `text_icons/`) | GUI icons (`GetSubUnitCategoryIcon`, `unit_overview.gui:804`) | exist | new dds files |
| `gfx/unit_illustrations/00_unit_illustrations.txt:1691-1697, 1731-1737` `trigger = { unit_category = army_auxiliary }` | 2D art | automatic | add entries or get `_default.dds` |
| `main_menu/gfx/unit_graphics/units/01_army.txt:168-174` `army_auxiliary = { schematic_name = unit_auxiliary_donkey_schematic … }` | 3D model keyed by **category** (or `age:category`, or gfx tag) | donkey cart automatically | must add a model entry (`00_units.info:4-5` "unit_category or unit_type") |
| `customizable_localization/subunit_types.txt:1440` `subunit_type_army_auxiliary` + `units_l_english.yml:370-374` | cultural regiment-type names | exists | key `subunit_type_<cat>` likely needed (UNVERIFIED) |
| GUI hard-coded breakdowns `datacontext = "[GetSubUnitCategory('army_auxiliary')]"` in `unit_overview.gui:818, 3229`, `shared/unit_tooltips.gui:131, 322`, `unit_template_lateralview.gui:540, 944`, `setup_condottieri.gui:387` | per-category rows | shown | invisible there unless GUI is overridden |
| `gui/filters/07_unit.txt:84-92` `unit_has_auxiliaries` (`total_sub_unit_category_in_unit:army_auxiliary > 0`) | army list filters | covered | not filterable |
| `country_interactions/lend_unit_to_ally.txt:100-103, 212-216` | treats all-auxiliary armies specially (`any_sub_unit = { count = all sub_unit_category = sub_unit_category:army_auxiliary }`, −20 AI weight) | an "HQ-only" army is "all auxiliary" | n/a |
| `traits/01_general.txt:14-15` `sub_unit_fraction:army_heavy_cavalry > 0.2` | general-trait eligibility | HQ dilutes fractions by 1 regiment | same |
| `loading_screen/sound/banks/windows/sb_world_logic.txt:169` | illustration sound events keyed by art name | n/a | n/a |

**Verdict**: `army_auxiliary` costs nothing and gets reserves placement, AI handling, art, model, icons, prices and GUI rows for free. A new category needs ≥10 companion definitions (prices, 4 modifier types + icons + loc, formation preferences, graphics define, illustration, 3D entry, customizable loc, GUI overrides) and has UNVERIFIED engine expectations. Use `army_auxiliary`.

Side effect to accept: the HQ is an "auxiliary" for `AI_MINIMUM_AUXILIARY_RATIO` and for `lend_unit_to_ally`; both are harmless at 1 regiment per army.

---

## 9. AI and unit types

- Unit types carry **no AI fields** at all (`ai_weight` 0 hits in `unit_types/`); the only AI inputs are the category `ai_weight` (`05_army_auxiliary.txt:31`) and defines:
```
	AI_MINIMUM_AUXILIARY_RATIO = 0.15 # minimum ratio of auxiliaries that AI will keep in their armies regardless of country bonuses
	AI_UNIT_CATEGORY_WEIGHT_FROM_POWER = 10 # how much power modifiers to unit categories influence AI army composition
```
(`00_defines.txt:1028-1029`),
```
	RECRUITMENT_TIME_BASE_DAYS = 10 # Base number of days to consider getting a new unit to a place
	RECRUITMENT_TIME_FACTOR = 0.1 # Multiplier for how significant recruitment time is for AI recruitment decisions
	SHIP_RECRUITMENT_COST_FACTOR = 0.2 # multiplier for how much we care about the cost of ships vs budget
	REGIMENT_RECRUITMENT_COST_FACTOR = 0.5 # multiplier for how much we care about the cost of regiments vs budget
```
(`:886-890`), `MAX_RECRUIT_DISTANCE = 10` (`:1037`), `AI_EARLY_GAME_MONTHS = 36` (`:779`, no recruitment in the first 36 months), and tech scoring `AI_UNLOCK_UNIT_SCORE_PER_AGE = 25`, `AI_UNLOCK_SPECIAL_UNIT_FACTOR = 3`, `AI_UNLOCK_UNIT_QUALITY_SCORE = 0.1 # extra score based on quality difference between a current unit and its potential upgrade` (`:1577-1580`).
- Which *unit type* inside a category the AI recruits is engine code; the quality-score define suggests it compares unit quality → a 0.25-power HQ will normally lose to supply carts; if the AI ever picks it, the hard `limit` caps the damage (INFERRED/UNVERIFIED).
- The AI does disband regiments on its own (`U:/logs/ai.log`: 3042 × `[AI Warning] AI tried to execute invalid command: disband_subunit.` in the current log) — a scripted HQ can be disbanded by AI reorganisation; the SPEC's monthly re-assignment covers it.
- Conclusion: give HQs to AI armies by script. Unit-scope effect `add_subunit = unit_type:a_feudal_levy` (`events/debug/000_johan_debug.txt:417-423`, inside `random_army = { … }`; loc `GAIN_SUBUNIT_EFFECT: "Gains a [TARGET_UNIT_TYPE.GetName]"` `effects_l_english.yml:2728`). Alternatives from location scope: `create_sub_unit = $type$` (`events/debug/qa_debug.txt:2405`, `WS:3600272327/…/sakuya_army_generator_effects.txt:15-17`) and
```
					create_sub_unit_with_owner = {
						type = a_supply_convoy
						owner = scope:new_conquistador
						origin = scope:location
						experience = 100
					}
```
(`events/colonization/conquistador.txt:76-81`).

---

## 10. Localization and GFX: the minimal set that avoids error.log spam

Localization (`main_menu/localization/english/units_l_english.yml`, pattern VERIFIED):
```
 a_wagenburg: "Wagenburg"
 a_wagenburg_desc: "$wagenburg_desc$"
```
(`units_l_english.yml:968-969`); `a_age_1_traditions_auxiliary_desc: "$unit_template_desc$"` (`:2685`). So: `cw_hq`, `cw_hq_desc`, `cw_hq_colonial`, `cw_hq_colonial_desc`, plus every `desc = "KEY"` used in the limit formula (reuse `SUBUNIT_LIMIT_BASE`, add `CW_HQ_LIMIT_AGE` …), plus `MODIFIER_TYPE_NAME_/DESC_cw_num_of_hq` if a modifier term is used. Per-category cost names only exist per category (`army_auxiliary_build: "Auxiliary Build Cost"` `economy_l_english.yml:637`); per-unit price keys (`a_clan_retainers_build`) have no loc in vanilla.

2D illustration (`in_game/gfx/unit_illustrations/readme.txt`): selection is by trigger + priority; vanilla already provides
```
army_auxiliary_1 = {
	texture = "gfx/interface/illustrations/units/army_auxiliary_1.dds"
	priority = 110000
	trigger = {
		unit_category = army_auxiliary
	}
}
```
(`00_unit_illustrations.txt:1691-1697`), `army_auxiliary` at 100000 (`:1731-1737`) and `fallback_default = { texture = ".../_default.dds"  priority = 0 }` (`:1793-1796`) → **no entry is required**. For own art, the DLC pattern:
```
	texture = "gfx/interface/illustrations/units/army_cavalry_a_caballeria_de_cuantia.dds"
	priority = 900000
	trigger = {
		is_unit_type = a_caballeria_de_cuantia
	}
```
(`dlc/D009_across_the_pillars/in_game/gfx/unit_illustrations/d009_unit_illustrations.txt:2-6`). Masks live in `…/units/masks/<same name>.dds` and fall through to `masks/_default.dds` (`readme.txt:44-46`). `error.log` reports at startup: missing texture files, unreachable entries, orphan masks (`readme.txt:48-51`).

3D model: keyed by category/tag/age:category in `main_menu/gfx/unit_graphics/units/01_army.txt` (`army_auxiliary = { schematic_name = unit_auxiliary_donkey_schematic … animation_state_machine_name = unit_auxiliary_donkey_mesh }`, `:168-174`); `00_units.info:4-5` allows `unit_category or unit_type` keys (`age_5_absolutism:a_militiamen = { entity = … }`). An `army_auxiliary` unit therefore renders as the donkey cart with no extra work.

`gfx_tags`: fade tags `light_tag medium_tag heavy_tag musket_tag rifle_tag` step art down by age; any other tag is an IDENTITY tag that pins specific art (`readme.txt:40-42`). Vanilla auxiliaries use `gfx_tags = { medium_tag }` (`2_unlocked_through_tech.txt:275`); camel auxiliaries use `{ auxiliary_tag medium_tag camel_auxiliary_tag }` (`3_camel_units.txt:621`). Use `{ medium_tag }`.

Icons: `GetUnitIcon(SubUnitType.Self)` (`army_builder.gui:1230`) and `GetSubUnitCategoryIcon` resolve from the category icon set `main_menu/gfx/interface/icons/unit_category/army_auxiliary.dds` — nothing per unit type needed (INFERRED from the data-function names).

---

## 11. Referencing the unit type from script and GUI

| Need | Syntax (scope) | Status / example |
|---|---|---|
| regiment is an HQ | `sub_unit_type = unit_type:cw_hq` (sub_unit) | VERIFIED `customizable_localization/subunit_types.txt:10`, `scripted_effects/unit_effects.txt:7`, `government_reforms/country_specific.txt:1978` |
| regiment category | `sub_unit_category = sub_unit_category:army_auxiliary` (sub_unit) | VERIFIED `country_interactions/lend_unit_to_ally.txt:102` |
| army has an HQ | `any_sub_unit = { OR = { sub_unit_type = unit_type:cw_hq  sub_unit_type = unit_type:cw_hq_colonial } }` (unit) | VERIFIED pattern `unit_effects.txt:5-10`; `count = all` variant `:41` |
| category share in an army | `sub_unit_fraction:army_heavy_cavalry > 0.2` (unit) — **categories only**, all 9 vanilla uses | VERIFIED `traits/01_general.txt:14-15, 70, 97`; per-type fraction UNVERIFIED |
| category count in an army | `total_sub_unit_category_in_unit:army_auxiliary > 0` (unit) | VERIFIED `gui/filters/07_unit.txt:84-92` |
| country-wide count of a type | `total_sub_unit_type_count:a_farfanes` (value, country) / `total_sub_unit_type_count:a_mamluk_unit_renaissance > 0` (trigger) | VERIFIED `government_reforms/country_specific.txt:1969`, `events/DHE/flavor_MAM.txt:1349`; `total_sub_unit_type_strength`, `total_sub_unit_count:<cat>` (`revolution_disaster.txt:40`), `total_sub_unit_strength` listed in `trigger_localization/country_triggers.txt:2704-2732` |
| iterate country regiments | `any_country_sub_unit = { sub_unit_type = unit_type:a_tofangchi  count > 10 }`, `… percent >= 0.1`; `every_country_sub_unit = { limit = { sub_unit_type = unit_type:a_tofangchi } add_subunit_experience = … }` (country) | VERIFIED `events/DHE/flavor_ira.txt:1202-1205, 282-285, 1214-1217` |
| destroy a regiment | `destroy_subunit = yes` (sub_unit); `destroy_unit = yes` (unit) | VERIFIED `scripted_effects/unit_effects.txt:41-50` |
| add a regiment to an army | `add_subunit = unit_type:cw_hq` (unit) | VERIFIED `events/debug/000_johan_debug.txt:419` |
| spawn in a location | `create_sub_unit = <type>` / `create_sub_unit_of_category = sub_unit_category:army_auxiliary` / `create_sub_unit_with_owner = { type owner origin experience }` (location) | VERIFIED `qa_debug.txt:2405, 1819`, `conquistador.txt:76-81` |
| unlocked by script | `has_unlocked_unit_trigger = { type = cw_hq }` / `unlock_unit_effect = { type = cw_hq }` | VERIFIED `country_triggers.txt:415-421`, `country_effects.txt:234-242` |
| illustration trigger | `is_unit_type = cw_hq`, `unit_category = army_auxiliary`, `has_gfx_tag = …`, `min_age = …` (unit-type scope) | VERIFIED `d009_unit_illustrations.txt:5`, `00_unit_illustrations.txt:137-138`, `readme.txt:17-23` |
| GUI | `UnitTypeItem.IsSpecialRegiment` (`army_builder.gui:1150`), `SubUnit.GetDefinition` (26 uses), `SubUnitType.GetCategory/GetAge/GetMaxStrength/GetName/NeedsAdvance/GetUnlocks`, `GetSubUnitCategory('army_auxiliary')` (`unit_overview.gui:818`), `PossibleSubUnitDefinition.GetMax/GetAvailableLimit` (`setup_mercenary_requirements.gui:892-894`) | VERIFIED (names from .gui files; a `SubUnit.GetDefinition.IsUnitType`-style comparison was not found — compare names or use scripted_gui triggers) |
| other unit-scope effects | `add_unit_modifier, add_unit_modifier_duration, add_unit_modifier_forever, remove_unit_modifier, add_morale, lock_unit, unlock_unit, add_food, set_unit_size, change_unit_owner, damage_unit_percent, set_as_commander, lend_unit_to_country, …` | VERIFIED names in `effect_localization/unit_effects.txt` (arguments: see doc 02) |

---

## 12. Copy-pasteable example

### 12.1 `in_game/common/unit_types/cw_headquarters.txt` (UTF-8 with BOM)
```
# CW: Army headquarters. Stats are ADDITIVE on top of army_auxiliary (05_army_auxiliary.txt).
cw_hq = {
	category = army_auxiliary          # reserves placement, donkey model, auxiliary art/icons for free
	age = "age_1_traditions"           # age icon only; no upgrades_to => same unit in every age
	is_special = yes                   # gold "special regiment" frame in the army builder
	buildable = yes                    # explicit (never rely on copy_from/defaults)
	levy = no

	max_strength = 0.1                 # 100 men (REGIMENT_SIZE = 1000, category max_strength = 0)
	combat_power = 0.25                # same as vanilla auxiliaries => ~0.025 total power
	# optional: food_storage_per_strength = -2990   # UNVERIFIED clamp; only if the HQ must not act as a supply cart

	construction_demand = cw_hq_construction   # near-zero goods (see 12.3)
	maintenance_demand = cw_hq_maintenance

	country_potential = {
		always = yes
	}
	# no location_potential / location_trigger => any owned location
	# no mercenaries_per_location       => no mercenary HQs
	# no upgrades_to                    => never obsolete

	limit = cw_hq_limit                 # country-scope script value (12.2)

	gfx_tags = { medium_tag }
}

# CW: Colonial headquarters. Defined in full (copy_from inheritance of limit/potentials is UNVERIFIED).
cw_hq_colonial = {
	category = army_auxiliary
	age = "age_3_discovery"
	is_special = yes
	buildable = yes
	levy = no

	max_strength = 0.1
	combat_power = 0.25

	construction_demand = cw_hq_construction
	maintenance_demand = cw_hq_maintenance

	country_potential = {
		current_age_or_later = { age = age_3_discovery }
		any_owned_location = { is_overseas_for_owner = yes }
	}
	location_potential = {
		is_overseas_for_owner = yes     # only recruitable overseas
	}

	limit = cw_hq_colonial_limit

	gfx_tags = { medium_tag }
}
```

### 12.2 `in_game/common/script_values/cw_values.txt` (country scope)
```
# CW: extra HQ slots by age (Traditions/Renaissance 0 ... Revolutions 4)
cw_hq_slots_from_age = {
	value = 0
	if = { limit = { current_age = age_3_discovery }   value = 1 }
	else_if = { limit = { current_age = age_4_reformation }  value = 2 }
	else_if = { limit = { current_age = age_5_absolutism }   value = 3 }
	else_if = { limit = { current_age = age_6_revolutions }  value = 4 }
}

# CW: extra HQ slots by size = floor(owned locations / 100)
cw_hq_slots_from_size = {
	value = num_locations
	divide = 100
	floor = yes
}

cw_hq_limit = {
	add = { value = 1  desc = "SUBUNIT_LIMIT_BASE" }
	add = {
		desc = "CW_HQ_LIMIT_AGE_AND_SIZE"
		value = cw_hq_slots_from_age
		max = cw_hq_slots_from_size        # "max = X": lowers the value to X if higher => min(age, size)
	}
	add = modifier:cw_num_of_hq            # optional knob (modifier type, see 12.4)
	min = { value = 1  desc = "CW_HQ_LIMIT_MIN" }
}

# CW: colonial HQs = one per 25 overseas locations, max 4, none before Discovery (INFERRED list arithmetic)
cw_hq_colonial_limit = {
	value = 0
	if = {
		limit = { current_age_or_later = { age = age_3_discovery } }
		every_owned_location = {
			limit = { is_overseas_for_owner = yes }
			add = 1
		}
		divide = 25
		floor = yes
		max = 4
	}
}
```
(`if/else_if/limit/floor/min/max`: `_script_values.info`; `max = X` semantics: "Sets the value to this number if it is currently higher"; `current_age` branches: `holy_war_values.txt:1-22`; `num_locations` as value: `advances/0_age_of_discovery.txt:588`; `add = modifier:…`: `…age_4_reformation.txt:204`; `every_owned_location` inside a value: INFERRED from the "Lists" section of `_script_values.info`.)

### 12.3 `in_game/common/goods_demand/cw_demands.txt` and `in_game/common/prices/cw_prices.txt`
```
cw_hq_construction = {
	paper = 0.01                 # near-zero; an empty block is UNVERIFIED
	category = regiment_construction
}
cw_hq_maintenance = {
	paper = 0.01
	category = regiment_maintenance
}
```
```
# CW: cancel the army_auxiliary price (02_units.txt:86-98). Pattern: a_clan_retainers_build (02_units.txt:184-187).
cw_hq_build       = { gold = -100  manpower = -1 }
cw_hq_reinforce   = { gold = -5    manpower = -1 }
cw_hq_maintenance = { gold = -1    manpower = -0.02 }
cw_hq_colonial_build       = { gold = -100  manpower = -1 }
cw_hq_colonial_reinforce   = { gold = -5    manpower = -1 }
cw_hq_colonial_maintenance = { gold = -1    manpower = -0.02 }
```
If a 0 total misbehaves in testing, use `gold = -99` / `manpower = -0.99` (1 gold, 1 man — effectively free).

### 12.4 Optional modifier type (`main_menu/common/modifier_type_definitions/cw_modifier_types.txt`)
```
cw_num_of_hq={
	decimals=0
	game_data={
		category=country
	}
}
```
(pattern `num_of_banner_cavalry`, `00_modifier_types.txt:13955-13960`; loc `MODIFIER_TYPE_NAME_cw_num_of_hq`, `MODIFIER_TYPE_DESC_cw_num_of_hq` as `modifier_types_l_english.yml:3747-3748`; optional icon entry in `main_menu/common/modifier_icons/`).

### 12.5 Localization (`main_menu/localization/english/cw_concentrated_warfare_l_english.yml`, UTF-8 BOM)
```
l_english:
 cw_hq: "Army Headquarters"
 cw_hq_desc: "A small staff of officers, couriers and engineers. Only armies led by a headquarters can besiege at full speed and fight at full strength."
 cw_hq_colonial: "Colonial Headquarters"
 cw_hq_colonial_desc: "A headquarters raised for service across the sea."
 CW_HQ_LIMIT_AGE_AND_SIZE: "Additional headquarters (by age, capped by owned locations / 100)"
 CW_HQ_LIMIT_MIN: "Minimum"
 MODIFIER_TYPE_NAME_cw_num_of_hq: "Number of Headquarters"
 MODIFIER_TYPE_DESC_cw_num_of_hq: "This impacts how many [ShowUnitDefinitionName('cw_hq')] [units|e] we can have at the same time."
```

### 12.6 Optional illustration (`in_game/gfx/unit_illustrations/cw_unit_illustrations.txt`)
```
cw_hq_art = {
	texture = "gfx/interface/illustrations/units/cw_hq.dds"   # + optional masks/cw_hq.dds
	priority = 900000
	trigger = { is_unit_type = cw_hq }
}
```
Without this file the HQ shows `army_auxiliary_1.dds` (generic auxiliary art) — no error.

---

## 13. Pitfalls

1. **Additive stats**: `copy_from = a_age_1_traditions_auxiliary` + `max_strength = 0.1` gives 150 men, not 100. Define with `category = army_auxiliary` and no `copy_from` (as the templates do), or subtract.
2. `limit` and `family` on the same unit = load-time error (`unit_families/readme.txt:10-11`).
3. A levy that points at a buildable unit, or a buildable unit with `levy = yes`, is ERRORLOGged (`levies/readme.txt:75-77`). Keep `levy` off and never reference `cw_hq` from `common/levies`.
4. Every `desc = "KEY"` inside the limit formula needs a loc key or the raw key is shown. `SUBUNIT_LIMIT_MIN` is worded for mercenary hiring ("Hiring Minimum", `units_l_english.yml:382`) — use an own key.
5. Omit `mercenaries_per_location`, otherwise HQs appear in mercenary companies.
6. Omit `hide = yes` (templates only) and do not set `empty`.
7. `num_locations` counts the country's own locations only; use `num_locations_owned_or_owned_by_subjects` if subject land should count toward slots.
8. The limit counts regiments **in production**, applies to mercenaries/templates/upgrades, and (INFERRED) does **not** disband anything when it shrinks; script-spawned HQs (`add_subunit`) probably ignore it → implement the monthly over-limit cleanup from the SPEC with `every_country_sub_unit`.
9. `copy_from` between `cw_hq` and `cw_hq_colonial`: no vanilla unit copies from a unit that has `limit`/`country_potential` → inheritance of those blocks is UNVERIFIED; define both fully.
10. Zero-cost totals are UNVERIFIED (vanilla only subtracts partially; the price system has `min`/`min_scale` fields). Test; fall back to 1 gold.
11. An empty goods demand (`{ category = … }` only) is UNVERIFIED; use `paper = 0.01`.
12. A **new category** without `exclude_from_combined_arms = yes` would count as an extra category for the combined-arms bonus (`game_concepts_l_english.yml:2287`) and, lacking an entry in `unit_formation_preference/army.txt`, has undefined battle placement; it also needs prices, four modifier types, icons and GUI overrides (§8). Only one army category may be `is_garrison` (`unit_categories/readme.txt:8`).
13. Auxiliary category means `supply_weight 0.2` and `food_storage_per_strength 3000` (300 food per 100 men) — the HQ doubles as a tiny supply cart unless offset (UNVERIFIED negative clamp).
14. `build_time_modifier` sign is INFERRED (positive = slower); the HQ should just use the category's 30 days.
15. `age` affects only the icon/template; but the GUI's age icon will show "Traditions" forever on the HQ — cosmetic; if undesirable, make per-age HQ copies with `upgrades_to_only` and a shared `family` limit (pattern `a_legionaries_1..4`, `D008_byzantine_unit_types.txt:1-15`).
16. `sub_unit_fraction:` takes a **category**, never a unit type; use `any_sub_unit` + `sub_unit_type` for the HQ check.
17. Files: vanilla unit files start with a UTF-8 BOM; `.gui` files do not. Loc keys for the unit are the bare unit key (`cw_hq`), not `unit_type_cw_hq`.
18. `error.log` currently contains no unit-type diagnostics for vanilla, so any `unit_type`/`illustration`/`gfx_tag` line after loading the mod is ours.

---

## 14. Recommendations for the mod

1. **Category**: `army_auxiliary`. Do not create a category.
2. **Definition**: as in §12.1 — no `copy_from`, explicit `buildable = yes`, `is_special = yes`, `age = "age_1_traditions"`, `max_strength = 0.1`, `combat_power = 0.25`, `gfx_tags = { medium_tag }`, no `upgrades_to`, no `mercenaries_per_location`, `limit = cw_hq_limit` as a **named** script value (avoids nesting trigger `limit = {}` inside the unit's `limit = {}` block and lets the GUI/events reuse the value).
3. **Free**: near-zero goods demand + negative per-unit prices (`cw_hq_build/_reinforce/_maintenance`); verify in game that the recruit tooltip shows 0 gold / 0 manpower; otherwise keep 1 gold.
4. **Limit formula**: `1 + min(age_slots, floor(num_locations/100)) + modifier:cw_num_of_hq`, `min 1`; expose `cw_num_of_hq` so game rules/events/decisions can shift it without touching the unit file. Colonial limit as a separate value on `cw_hq_colonial` (separate unit type, `location_potential = { is_overseas_for_owner = yes }`, gated by `current_age_or_later = { age = age_3_discovery }`).
5. **Counting / cleanup**: `total_sub_unit_type_count:cw_hq` for cached counters; `every_country_sub_unit = { limit = { sub_unit_type = unit_type:cw_hq } … }` for over-limit destruction (`destroy_subunit = yes`), choosing the smallest army via `ordered_*`/variables (doc 02).
6. **AI**: never rely on AI recruitment of the HQ. Insert with `add_subunit = unit_type:cw_hq` in unit scope from the monthly on_action; optionally restrict the *buildable* path to players (`country_potential = { is_ai = no }` — only if testing shows `add_subunit` ignores `country_potential`; otherwise keep `always = yes`).
7. **HQ presence check** (unit scope, for the `cw_no_hq` modifier): `NOT = { any_sub_unit = { OR = { sub_unit_type = unit_type:cw_hq  sub_unit_type = unit_type:cw_hq_colonial } } }`.
8. **GFX/loc**: ship only `cw_hq`/`cw_hq_desc`/`cw_hq_colonial`/`cw_hq_colonial_desc` + limit desc keys at first; add a 900000-priority `is_unit_type` illustration later with own art (plus mask) so the HQ is visually distinct from supply carts.
9. **Validation checklist after first load** (no game start by this agent): grep `U:/logs/error.log` for `cw_hq`, `unit_type`, `illustration`, `price`, `goods_demand`; open the army builder: HQ visible with gold frame, cost 0, limit tooltip breakdown with the three `desc` lines; recruit 1 over the limit → `BUILD_UNIT_REACHED_LIMIT` text; check reinforcement/maintenance in the ledger; drop below 100 locations and confirm the existing HQ survives (expected) so the cleanup script is really needed.

---

## 15. Open items to test in game (UNVERIFIED)

- Zero/negative total price acceptance (`cw_hq_build = { gold = -100 manpower = -1 }`).
- Empty goods-demand block; negative `food_storage_per_strength` clamp.
- `copy_from` inheritance of `limit`, `country_potential`, `buildable`, `hide`.
- Whether `add_subunit`/`create_sub_unit_with_owner` respect `limit` and `country_potential`.
- `every_owned_location = { limit = {…} add = 1 }` inside a script value (list arithmetic with a limit).
- Which unit type the AI recruits inside `army_auxiliary` when a free, limited HQ is available (watch `ai.log`/army compositions).
- `build_time_modifier` sign.
