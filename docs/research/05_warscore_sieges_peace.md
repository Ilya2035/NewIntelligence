# 05 - Warscore from occupation, sieges/occupation, location ranks, peace (EU5 1.4.7)

Research doc for the *Concentrated Warfare* (`cw_`) mod. Everything below was read from the installed game
(`<EU5>/game/...`, abbreviated `G/`), the two workshop mods and the user's logs. No game file was modified.

Legend: **VERIFIED** = seen verbatim in files / logs. **INFERRED** = deduced from file evidence (formula shape,
semantics not spelled out). **UNVERIFIED** = plausible but no file evidence; needs an in-game test.

Paths: `G/` = `C:\Program Files (x86)\Steam\steamapps\common\Europa Universalis V\game`,
`DEF` = `G/loading_screen/common/defines/00_defines.txt`,
`LOC` = `G/main_menu/localization/english`, `SM` = `G/main_menu/common/static_modifiers`,
`MTD` = `G/main_menu/common/modifier_type_definitions/00_modifier_types.txt`,
`LOGS` = `C:\Users\fyrno\Documents\Paradox Interactive\Europa Universalis V\logs`.

---

## 1. Warscore: what it is made of

### 1.1 Sources (VERIFIED by localization + defines)

The war-score tooltip (`LOC/diplomacy_l_english.yml` ~2645-2661) lists exactly these buckets:

```
 BATTLES_SCORE: "From $SIZE|Y$ [battles|e]: ... $VAL|+=2%/$"
 OCCUPATION_SCORE_HEADER: "Occupations and Blockades"
 OCCUPATION_SCORE: "[occupations|e] and [blockades|e]: ... $VAL|+=%/$"
 WARSCORE_FROM_TICKING: "$SIDE$ Ticking: $VAL|+=2%/$\n"          # line 2658
 WARSCORE_FROM_BONUSES: "$SIDE$ Bonuses: $VAL|+=2%/$\n"          # line 2659
 WARSCORE_OCCUPATION: "$WHO$ $ADJ$ Occupation of $NAME$: $VAL|+=2$\n"   # 2660, one entry per location
 WARSCORE_B_OCCUPATION: "$WHO$ $ADJ$ Control of $NAME$: $VAL|+=2$\n"    # 2661 (blockades)
```

Caps / knobs (`DEF`, section `NDiplomacy`, lines 2432-2439; `NWar` 2666-2669):

```
DEF:2432	DEFAULT_WARGOAL_TICKINGWARSCORE_BONUS = 2   # warscore per month once a side holds the war goal
DEF:2433	WARGOAL_MAX_TICKING_WAR_SCORE = 25
DEF:2434	WARGOAL_MAX_BONUS = 50
DEF:2435	DEFAULT_WARGOAL_BATTLESCORE_BONUS = 3       # battle score bonus from winning battles
DEF:2436	SUPERIORITY_WARGOAL_WARSCORE_THRESHOLD = 10
DEF:2437	WARSCORE_MAX_FROM_BATTLES = 50
DEF:2438	BATTLE_RESULT_SCALE = 25
DEF:2439	BATTLE_RESULT_CAP = 25
DEF:2666	MAX_WAR_SCORE = 100
DEF:2669	OCCUPATION_VALUE_SCALE = 2.0  #at 1.0 you need 100% of the occupied land to get 100% warscore, higher requires less..
DEF:2427	MONTHS_BEFORE_TOTAL_OCCUPATION = 60  # Before this many months ... you cannot gain 100% warscore by just occupying the warleader
```

- Battle warscore scales down with age (`LOC/interfaces_l_english.yml:330 AGE_BATTLE_WAR_SCORE_IMPACT`, hint at
  `hints_l_english.yml:982`: "up to 50% at the beginning"). A CB may override the cap:
  `casus_belli/readme.txt:20  max_warscore_from_battles = <int> to override NDefines::NDiplomacy::WARSCORE_MAX_FROM_BATTLES`.
- Complete victory rule (`LOC/interfaces_l_english.yml:1459`): *"If the war goal is not fulfilled, it is only possible
  to get +100.00 war score (complete victory) if the winning side controls all of the losing side's locations, and the
  losing side controls no towns_or_cities."*  -> urban locations already matter more than rural ones in the 100% rule.
- Wargoal ticking: per wargoal `ticking_war_score = <float> #Default 1` (`wargoals/readme.txt:39`); vanilla uses 0.5
  almost everywhere -> 1 warscore/month, capped at 25 (INFERRED: `2 * 0.5`).

### 1.2 "War worth" of a location = the per-location warscore value (VERIFIED defines, INFERRED formula)

`DEF` `NWar` 2685-2701:

```
	WAR_WORTH_BASE = 2
	WAR_WORTH_TAX_BASE_SCALE = 0.13
	WAR_WORTH_TAX_BASE_CAP = 6 # cap on the tax-base contribution so a single economic stat can no longer dominate war worth
	WAR_WORTH_BUILDING_SCALE = 0.025
	WAR_WORTH_BUILDING_CAP = 10
	WAR_WORTH_POPULATION_SCALE = 0.02
	WAR_WORTH_POPULATION_CAP = 4
	WAR_WORTH_COUNTRY_CAPITAL = 5
	WAR_WORTH_PROVINCE_CAPITAL = 1
	WAR_WORTH_PORT = 1
	WAR_WORTH_FORT_BASE = 0.5
	WAR_WORTH_FORT_LEVEL_SCALE = 0.25
	WAR_WORTH_DEVELOPMENT_SCALE = 0.05 #scaled to (this location's development - average development of taker)
	WAR_WORTH_DEVELOPMENT_MIN = -1
	WAR_WORTH_DEVELOPMENT_MAX = 5
```

The same quantity is what the peace screen breaks down per location (`LOC/diplomacy_l_english.yml:1453-1461`):

```
 PEACECOST_PROV_BASE: "Base: $VAL|V$"
 PEACECOST_PROV_TAX: "[tax_base|e]: $VAL|<+=$"
 PEACECOST_PROV_PORT: "[port|e]: $VAL|<+=$"
 PEACECOST_C_CAP: "[capital|e]: $VAL|<+=$"
 PEACECOST_PROV_CAP: "[province_capital|e]: $VAL|<+=$"
 PEACECOST_PROV_RGO: "[rgo|e]: $VAL|<+=$"
 PEACECOST_PROV_DEVELOPMENT: "[development|e]: $VAL|<+=$"
 PEACECOST_PROV_CITIZENS: "[population|e]: $VAL|<+=$"
 PEACECOST_PROV_BUILDINGS: "[buildings|e]: $VAL|<+=$"
```

and the location panel shows it as "War Score of <loc>" (`LOC/interfaces_l_english.yml:4767-4769`,
`LOC/diplomacy_l_english.yml:3351 LOCATION_WAR_WORTH_VALUE_EXISTS: "[Location.GetWarWorth|2]"`; tooltip data function
`Location.GetWarWorthTooltip` in `G/in_game/gui/shared/location_tooltips.gui:4148`; map mode
`interfaces_l_english.yml:7248 MAPMODE_WARSCORE ... "Brighter green indicates a higher intrinsic war score"`).
It is only visible with spy-network intel >= `DEF:2659 INTEL_THRESHOLD_LOCATION_WAR_WORTH = 25`.

**INFERRED formula** (shape from the defines; exact rounding unknown):

```
worth = WAR_WORTH_BASE(2)
      + min(TAX_CAP 6,  0.13 * tax_base)
      + min(BUILDING_CAP 10, 0.025 * building value)      # tooltip row "buildings"
      + min(POP_CAP 4,  0.02 * population)                # "population"
      + [rgo term, no define - UNVERIFIED how it is computed]  # tooltip row "rgo"
      + 5 if country capital + 1 if province capital + 1 if port
      + (0.5 + 0.25*fort_level) if fort (no tooltip row -> may only apply in some contexts, UNVERIFIED)
      + clamp(0.05 * (dev - taker's average dev), -1, +5)  # "development", depends on the TAKER
```

Consequences (INFERRED): a rural location in 1337 is roughly `2 + small tax + tiny pop` ~ 2-4; a town ~ 4-8; a city
with buildings ~ 10-20; the capital gets only a flat `+5`. **Base = 2 is the single biggest reason rural land counts.**

### 1.3 Occupation warscore (INFERRED)

```
occupation_score(side) ~= 100 * OCCUPATION_VALUE_SCALE * sum(worth of enemy locations this side controls)
                                                        / sum(worth of all enemy-side locations)
```
capped by `MAX_WAR_SCORE`, blocked from 100% before `MONTHS_BEFORE_TOTAL_OCCUPATION` months, and further scaled by
control (next section). The comment on `OCCUPATION_VALUE_SCALE` ("at 1.0 you need 100% of the occupied land to get
100% warscore") is the only direct evidence for the ratio form.

### 1.4 Control impact on warscore (VERIFIED modifier, INFERRED mechanics)

```
MTD:5233  lack_of_control_impact_on_warscore={ percent=yes game_data={ category=country } }
LOC/modifier_types_l_english.yml:277  MODIFIER_TYPE_DESC_lack_of_control_impact_on_warscore:
   "This impacts the effect that low [control|e] has on [war_score|e]."
G/in_game/common/age/00_default.txt:12   lack_of_control_impact_on_warscore = 0.1   (age_1_traditions, inside modifier = { })
                               :72   = 0.2   :133 = 0.4   :196 = 0.6   :264 = 0.8   :340 = 1.0
```
The age `modifier = { }` block is applied to every country in that age (INFERRED). INFERRED meaning: the war worth
counted for occupation is reduced by `(1 - control) * lack_of_control_impact`, so in early ages low-control (remote,
colonial) land is still worth nearly full, by Age of Revolutions a 20%-control location counts ~20%. There is no
PEACECOST row for control, so this most likely affects the **occupation score**, not peace cost.

### 1.5 Efficiency modifiers (VERIFIED) - these touch **peace cost only**

```
MTD:6646 global_war_score_efficiency={ percent=yes game_data={ category=country } }
MTD:6653 war_score_vs_other_religion_efficiency={ color=good percent=yes game_data={ category=country } }
MTD:6661 local_war_score_efficiency={ percent=yes game_data={ category=location } }
LOC/modifier_types_l_english.yml:697 "...how much [war_score|e] it will cost for this [country|e] to take territory."
LOC/modifier_types_l_english.yml:701 "...how much [war_score|e] it will cost for this [location|e] to be taken in a [peace_treaty|e]."
```
Vanilla usage: `SM/location.txt:2175-2183 stronghold_city_modifier = { local_max_control = 0.2  local_war_score_efficiency = -0.25 ... }`
(the only location use), `G/in_game/common/advances/0_age_of_absolutism.txt:356 global_war_score_efficiency = 0.4`,
`estate_privileges/clergy_estate.txt:208 war_score_vs_other_religion_efficiency = 0.10`.

How efficiency is applied (VERIFIED wording, `LOC/diplomacy_l_english.yml:1467`):
`PEACE_COST_EFFICIENCY_MODIFIER: "The total of $VAL|2G$ is divided by $DIV|V2$ due to an efficiency of $EFF|+=2%$"`
-> `cost = worth_sum / (1 + efficiency)`. Positive efficiency = cheaper; `-0.25` on a stronghold city = 1.33x price.
Other efficiency terms (`DEF:2377-2388`): `PEACE_COST_EFFICIENCY_UNOCCUPIED_FORT = -0.15`,
`..._FORT_NEVER_SIEGED = -0.18`, `..._FOR_SAME_CULTURE = 0.10`, `..._FOR_SAME_RELIGION = 0.10`,
`..._FOR_NON_TARGET = -0.5`, `..._FOR_DECISIVE_DEFENDER = 0.25`, `..._VS_RIVAL = 0.33`,
`PEACE_COST_SIZE_DISCOUNT_THRESHOLD = 100 / _PER_UNIT = 0.001 / _MAX = 0.5` (big owners get cheaper to chip),
`PEACE_COST_EFFICIENCY_FOR_REVOLT_WAR = 5.0`. Localized rows `PEACE_COST_UNOCCUPIED`, `PEACE_COST_FORT_NEVER_SIEGED`,
`PEACE_COST_ON_SMALL_NATION` ("is a big part of <country>", no define found), lines 1470-1479.

---

## 2. Answer (a): best levers to make rural ~0, towns small, cities more, capital a lot

| Lever | Affects occupation score? | Affects peace cost? | Status | Notes |
|---|---|---|---|---|
| **Defines `NWar.WAR_WORTH_*`** | yes (INFERRED, same quantity) | yes | VERIFIED values; override method INFERRED | The only lever that changes *both*. `WAR_WORTH_BASE 2 -> ~0.2`, `WAR_WORTH_COUNTRY_CAPITAL 5 -> 25-40`, `WAR_WORTH_PROVINCE_CAPITAL 1 -> 2-3`, `WAR_WORTH_PORT 1 -> 2`, raise `BUILDING`/`POP` scales+caps (urban-only signals). Rural locations have little tax/pop/buildings, so dropping BASE alone nearly zeroes them. |
| **`rank_modifier.local_war_score_efficiency` per location rank** | no | yes | VERIFIED modifier + slot (`location_ranks/readme.txt:4 rank_modifier`) | e.g. `rural_settlement: +1.0` (half price), `town: 0`, `city: -0.3`, `megalopolis: -0.5`. Must stay `> -1.0` (division by `1+eff`). Requires replacing `location_ranks/00_default.txt` (see section 3). |
| **Hardcoded static modifier `capital`** (`SM/location.txt:454`) | no | yes | VERIFIED slot | Add `local_war_score_efficiency = -0.6` to `capital = { ... }` -> capital 2.5x more expensive. Needs full-file replacement of `SM/location.txt` (first-key-wins rule, section 3). Also `province_capital` (`:470`) and `historical_capital` (`:484`). |
| **Scripted bonus warscore** `add_bonus_warscore` | adds to "Bonuses" bucket | no | VERIFIED effect | Fire from `on_siege_won` / `on_location_occupied` when `scope:target = { is_capital = yes }`. Bonuses bucket is capped (`WARGOAL_MAX_BONUS = 50`, INFERRED that it applies here) and is **one-off** (does not disappear when the capital is retaken). |
| `lack_of_control_impact_on_warscore` (country modifier) | yes | no | VERIFIED modifier | Secondary: raising it early makes colonial / low-control land count less for occupation. Could be added to `auto_modifiers/country.txt`-style global modifier (format verified at `G/in_game/common/auto_modifiers/country.txt:9-20`). |

**Recommendation**: do the defines change (primary, both systems), plus the rank `local_war_score_efficiency`
(secondary, peace-only fine tuning), plus a capital `add_bonus_warscore` only if play-testing shows the capital still
is not decisive. Do **not** rely on `local_war_score_efficiency` alone: it leaves the occupation score untouched, so
AI carpet-sieging rural land would still give full warscore.

Defines override method: the vanilla defines folder already holds several files that are merged
(`G/loading_screen/common/defines/00_defines.txt`, `graphic/00_graphics.txt`, `jomini/*.txt` - VERIFIED listing), so a mod
file `loading_screen/common/defines/zz_cw_defines.txt` containing only `NWar = { WAR_WORTH_BASE = 0.2 ... }` should
override those keys (INFERRED from CK3/Vic3 Jomini behaviour; neither workshop mod ships defines, so **test in game**
and check `LOGS/error.log`; fallback = ship a full copy of `00_defines.txt`, which breaks on every patch).
Script cannot read defines directly (no `define:` usage anywhere in `G/in_game/common/script_values/` - VERIFIED
negative; `GetDefine('NCombat','SIEGE_MEMORY')` exists only as a **localization/GUI** data function, `LOC/units_l_english.yml:1895`).

---

## 3. Answer (b): can a mod redefine only one location rank in a new file?

**No - first definition wins and the duplicate is dropped (VERIFIED in the user's `LOGS/debug.log`):**

```
[20:12:42][gamedatabase.h:409]: Duplicated key sakuya_loc_mod_food_capacity will not be created from file: common/static_modifiers/sakuya_cheat_modifiers.txt:3812
[20:12:42][gamedatabase.h:409]: Duplicated key sakuya_loc_mod_food_capacity_neg will not be created from file: common/static_modifiers/sakuya_cheat_modifiers.txt:3833
[20:12:42][gamedatabase.h:409]: Duplicated key sakuya_cabinet_efficiency_max will not be created from file: common/static_modifiers/sakuya_cheat_modifiers.txt:5507
```
In Cheat Menu Pro's `main_menu/common/static_modifiers/sakuya_cheat_modifiers.txt` the keys are defined at lines
3376/3383/450 (kept) and again at 3812/3833/5507 (rejected). So for a generic Jomini database (`gamedatabase.h`)
the **earlier** definition survives, the later one is silently not created, and the message goes to **debug.log**, not
`error.log` (error.log / error.1-5.log contain zero "duplicate/already defined" lines - VERIFIED; `database_conflicts.log`
is 0 bytes).

Implications (INFERRED: files inside one folder are read in alphabetical order across vanilla+mods):
- A mod file `location_ranks/zz_cw_ranks.txt` redefining `city` loads after `00_default.txt` -> **ignored**.
- A mod file named `location_ranks/00_a_cw.txt` might win the race, but `00_default.txt`'s `city` would then be the
  dropped duplicate and the rank **list order** changes (`readme.txt:1  #Note: logic assumes that anything below a rank in
  the list is worse`; `upgrade_from = city` chains) -> fragile, do not do it.
- **Correct approach: ship `<mod>/in_game/common/location_ranks/00_default.txt`** (same relative path replaces the
  vanilla file entirely - standard Paradox behaviour, INFERRED, no workshop example overrides a vanilla path).
  Keep all four ranks and their order; only add `local_war_score_efficiency` lines.
- Exception: `on_action` keys are legitimately duplicated across vanilla files (`on_ending_war`, `on_winning_war` in
  `_hardcoded.txt` + `religious_order_conquest.txt`; `on_royal_marriage`, `on_truce_broken` in `_hardcoded.txt` +
  `diplomatic_reactions.txt` - VERIFIED) and produce **no** "Duplicated key" log line -> on_actions are merged, so the
  mod can add its own `on_siege_won = { effect = { ... } }` file without touching `_hardcoded.txt`. Same for `genes`
  (`accessory_genes`) and `languages` sub-blocks (VERIFIED duplicates, no log line).
- Localization duplicates are reported separately (`pdx_localize.cpp:221 Duplicate localization key ...`), many in
  vanilla Russian loc - harmless.

Location rank file format (VERIFIED `G/in_game/common/location_ranks/readme.txt:1-17`):

```
#<location rank id> = {
#   color = <named color>
#   rank_modifier = <modifier>                      # Modifier applied to the location
#   country_modifier = <modifier>                   # Modifier applied to the country
#   capital_country_modifier = <modifier>           # ... if the location is the capital of that country
#   is_established_city = <yes/no>                  # Locations with a city status are treated as non rural.
#   build_time = <int>  frame_tier = <int>  tier = <int>   # tier: diplomatic acceptance / picking new capital
#   construction_demand = <goods demand>  allow = <trigger>  max_rank = <yes/no>  show_in_label = <yes/no>
#   institution_spawn_chance_factor = <float>  ai_construct_weight = <scripted float>
```
Vanilla ranks (`00_default.txt`): `megalopolis` (l.2, tier 4, `upgrade_from = city`, allow `is_capital = yes` l.59),
`city` (l.77, tier 3, `upgrade_from = town`), `town` (l.143, tier 2), `rural_settlement` (l.192, tier 1,
`show_in_label = no`, no `is_established_city`). `rank_modifier` already carries ordinary location modifiers
(`local_max_control`, `movement_cost`, `local_frontage_allowed` ...), so `local_war_score_efficiency` (category
location) fits there.

---

## 4. Answer (c): sieges and occupation

### 4.1 Defines (VERIFIED, `DEF` NCombat 528-562, NCombat 452/471, NLocation 1945-1951)

```
DEF:528	DAYS_PER_SIEGE_PHASE = 30
DEF:529	MIN_DAYS_PER_SIEGE_PHASE = 7
DEF:530	DAYS_PER_SIEGE_PHASE_WITHOUT_FORT = 15
DEF:531	SIEGE_DISEASE_IMPACT = 0.05
DEF:532	SIEGE_MAX_FORT_LIMIT_BONUS = 8
DEF:533	SIEGE_REGIMENTS_FOR_ARTILLERY = 2
DEF:534	SIEGE_MEMORY = 11
DEF:535	SIEGE_WIN = 20
DEF:536	SIEGE_GARRISON_SURRENDER_THRESHOLD = 0.05
DEF:537	MAX_BREACH = 3
DEF:538	BREACH_REPAIR_PER_DAY = 0.01
DEF:555	SIEGE_DAYS_PER_PHASE = 1				# assault dice re-roll interval in daily ticks
DEF:557	ASSAULT_ATTACKER_LOSS = 2.5     :558 ASSAULT_ATTACKER_MORALE_LOSS = 3.0
DEF:559	ASSAULT_DEFENDER_LOSS = 0.03    :560 ASSAULT_DEFENDER_MORALE_LOSS = 0.3
DEF:561	ASSAULT_DICE_MODIFIER = 5       :562 ASSAULT_WIDTH_LIMIT = 1
DEF:452	GARRISON_AFTER_OCCUPATION = 0.010
DEF:471	FOOD_PERCENTAGE_LOST_AT_OCCUPATION = 0.9
DEF:1949	CAPITAL_FLIP_SPEED = 0.04   :1950 FORT_FLIP_SPEED = 0.033   :1951 FLIP_REVERT_SPEED = 0.033
DEF:2673	PARTICIPATION_SCORE_SIEGE = 0.01 	# Per regiment engaged in sieges that are able to progress
DEF:2676	PARTICIPATION_SCORE_UNFORTIFIED_MULT = 0.1
```
Siege outcome losses (`DEF:540-553`): supply shortage 0.02 / impact 1, food 0.03 / 2, water 0.05 / 3, defender
desertion 0.1 / 2, breach 0.05 / 2.

### 4.2 How a siege works (VERIFIED localization)

- Start: *"A siege occurs when an army arrives in a location when the controller and the army are enemies"*;
  unfortified location *"will take about a month"* (`LOC/game_concepts_l_english.yml:375`).
- Progress gate: *"For a siege to progress there needs to be at least as many men besieging it as the number of men
  in the garrison. For a location without fortifications, there needs to be at least #V 100#! men."* (same line;
  `LOC/units_l_english.yml:1849 SIEGE_TOO_FEW_MEN_TOOLTIP`, `:1881 TOO_FEW_MEN_INFO: "Needs at least
  [Siege.GetLocation.GetMenNeededForSiege|V] ... to [occupy|e]"`). The 100 is not a define in `00_defines.txt`
  (grep for UNFORTIFIED/MIN_MEN found nothing) - hardcoded.
- Each phase a die is rolled and modified (`LOC/units_l_english.yml:1868 SIEGE_CHANCE_EXPLANATION`, "natural 1 =
  disease outbreak"). Dice modifiers shown in the UI: Siege Accumulation (`:1895`, max `SIEGE_MEMORY`), Blockade
  (`:1897` "-1 if port not blockaded"), Fortifications (`:1899` "-1 per fort level"), Breaches (`:1901`), Artillery
  (`:1914-1924`: bonus from regiment count * artillery_barrage vs fort level, "further divided by
  [SIEGE_REGIMENTS_FOR_ARTILLERY]"). Outcomes: Surrender / Defenders Desert / Breach / Fortress Damaged / Status Quo.
- Phase length: `:1879 SIEGE_PHASE_TITLE: "Siege phases are [Siege.GetPhaseSize] ([Siege.GetSiegeFortDefenseDifference]) days long due to:"`
  with `:1903 SIEGE_DEFENSIVE` ("A positive value makes a siege last longer") and `:1908 SIEGE_ABILITY_TOTAL`.
  INFERRED: `phase_days = max(MIN 7, DAYS_PER_SIEGE_PHASE 30 * (1 + fort_defense - siege_ability))` (sign/multiplicative
  vs additive UNVERIFIED). Unfortified: `OCC_PHASE_TITLE "This occupation takes [Siege.GetPhaseSize] day due to:"`
  -> `15 * (1 + occupation_time)` (INFERRED).

### 4.3 What the modifiers do (VERIFIED definitions + descriptions)

```
MTD:5985  siege_ability={ percent=yes game_data={ category=unit } }
LOC/modifier_types_l_english.yml:503  "This impacts how quickly that [armies|e] can [siege|e]."
MTD:5963  occupation_time={ percent=yes game_data={ category=location } }
LOC:4542  "This impacts how quickly it takes to [siege|e] a [location|e] without [fortifications|e]."
MTD:5970  max_siege_memory={ decimals=0 game_data={ category=location } }   LOC:4545 "max siege progress accumulated"
MTD:~5992 assault_ability={...}  LOC:505 "This impacts how well an [army|e] can perform an [assault|e]."
```
Vanilla `siege_ability` usages (category unit, but applied through country/character/unit modifiers):
`SM/country.txt:388-394 army_maintenance_reverse_mod = { siege_ability = -1.0  monthly_prestige = -0.05 }`
(comment `#multiplied by 1-maintenance` -> 0% maintenance = -100% siege ability: **a -100% siege_ability is a vanilla
state**, which supports the mod's "-90% without HQ" plan), `SM/country.txt:6073-6081 sco_desertion_among_balliol = {
global_defensive = -0.25 siege_ability = -0.25 army_movement_speed = -0.25 discipline = -0.10 }`,
`G/in_game/common/auto_modifiers/country.txt:479-486 army_tradition = { scales_with = {...} land_morale_modifier = 0.2 siege_ability = 0.1 }`,
`SM/character.txt:884 siege_ability = 0.10` (general traits). `occupation_time` usages: `SM/location.txt:313
location_size_impact { occupation_time = 0.0025 }`, `:445 development { occupation_time = 0.01 }` (per dev point),
`:2213-2225 rot_timur_scare { local_defensive = -0.5 occupation_time = -0.5 ... }`;
`G/in_game/common/script_values/location_values.txt:35-38 multiply = { value = 1 add = "scope:location.modifier:occupation_time" }`
(confirms `1 + occupation_time` multiplicative use, at least in AI defensibility scoring).
Unit-category static modifiers exist as examples for the mod's HQ-less modifier: `SM/unit.txt:32-38 in_siege = {
game_data = { category = unit } experience_decay = -0.03 monthly_experience_gain = 0.10 }`, `:85-91
extensive_training_modifier = { game_data = { category = unit } discipline = 0.05 ... }`; effects
`add_unit_modifier` / `add_unit_modifier_duration` / `add_unit_modifier_forever` are localized in
`G/in_game/common/effect_localization/unit_effects.txt:14-28` (VERIFIED names; no vanilla script usage found).

### 4.4 Assault rules (VERIFIED `LOC/units_l_english.yml:2105-2113`, `unit_categories`)

```
 ASSAULT_NOT_MERCES: "Unless there is a breach, [mercenaries|e] will refuse to join an assault."
 ASSAULT_TOO_WEAK: "There are not enough [army_light_infantry] or [army_heavy_infantry] available in this siege to assault."
 ASSAULT_IS_DEFENDER / ASSAULT_INTERRUPTED (battle) / ASSAULT_NOT_IN_COMMAND / ASSAULT_TOO_LOW_MORALE
```
Only categories with `assault = yes` can assault: `G/in_game/common/unit_categories/00_army_light_infantry.txt:4` and
`01_army_heavy_infantry.txt:4`; artillery has `bombard = yes` (`04_army_artillery.txt:3`); readme `:5-8`:
`assault = yes/no`, `bombard = yes/no`, `auxiliary = yes/no #Default no`, `is_garrison = yes/no`. Unit types can set
`assault`/`bombard`/`auxiliary` individually (`G/in_game/common/unit_types/readme.txt:13-15`). AI assaults when
strength ratio >= `DEF:1446 AI_ASSAULT_FORT_NO_BREACH_STRENGTH_NEEDED = 3` / `:1447 ..._BREACH_... = 1.5`.

### 4.5 Can a unit with 0 combat regiments (only an HQ regiment) siege? - UNVERIFIED

Evidence: the only stated gate is *men* (>= garrison, >= 100 unfortified). The HQ is planned as a 100-man regiment, so
alone it would sit exactly at the unfortified threshold (`>=` per the wording "at least") - but whether an `auxiliary = yes`
category's men count toward `GetMenNeededForSiege` is not stated anywhere; `army_auxiliary` has `max_strength = 0`,
`combat_speed = 0.1`, `exclude_from_combined_arms = yes` (`05_army_auxiliary.txt:9-33`), i.e. it is a real regiment
with men. **Test in game** with a lone HQ on (a) an unfortified enemy location, (b) a fort with a 150-man garrison.
Design-wise it is safer to make the HQ unable to siege alone (e.g. 99 men, or require `siege_ability` to be driven by
the rest of the stack).

### 4.6 Occupation side effects and hooks (VERIFIED)

- Hardcoded location modifiers: `SM/location.txt:355 under_siege = { hostile_food_multiplier = -1.0 ...
  constructions_stalled = yes }`, `:369 is_occupied = { local_monthly_prosperity = -0.025 local_monthly_control = -0.002 ... local_garrison_growth = -1.0 }`;
  country: `SM/country.txt:499 total_occupied = { monthly_war_exhaustion = 0.4 }`, `:7558 demoralised_by_loss_of_capital = { land_morale_modifier = -0.1 }`.
- Province-capital cascade: `LOC/game_concepts_l_english.yml:140` *"When this location gets occupied during a war, the
  remaining locations of the province fall automatically in the hands of the invader over a short period of time"*
  (speeds `CAPITAL_FLIP_SPEED` / `FORT_FLIP_SPEED` / `FLIP_REVERT_SPEED`, INFERRED mapping). Zone of control:
  `LOC/game_concepts_l_english.yml:1883`.
- On-actions (`G/in_game/common/on_action/_hardcoded.txt`):
  ```
  319 # When a location with fort changes controller after a siege.
  320 # root = country, scope:target = location, scope:character = leading general character
  321 on_siege_won = {
  447 on_siege_lost = {
  492 # When a location without fort changes controller after an occupation process
  493 # root = country, scope:target = location, scope:character = leading general character
  494 on_location_occupied = {
  6332 #root = country; scope:old_capital = old capital location; scope:new_capital = new capital location
  6333 on_capital_moved = {
  1533 #root = country, scope:winner = country, scope:loser = country, scope:war = war
  1534 on_winning_war = {        (also on_losing_war 1930, on_pre_ending_war 1955, on_ending_war 2039)
  ```
- Siege scope access from a location: `G/in_game/common/on_action/country_monthly.txt:218-222
  has_siege = yes  siege = { any_besieging_unit = { owner = { ... } } }`; siege-scope triggers `has_breach`, `in_assault`
  (`G/in_game/common/trigger_localization/siege_triggers.txt:1,8`); unit trigger `in_siege`
  (`unit_triggers.txt:134`); script values `besieger_strength` / `garrison_strength`
  (`G/in_game/common/script_values/garrison.txt:37-43`); effect `add_breach` (3 vanilla uses).

---

## 5. Answer (d): peace - land cost, ticking warscore, capital

### 5.1 Structure (VERIFIED readmes)

CB -> wargoal -> treaties. `G/in_game/common/casus_belli/readme.txt:16  war_goal_type = <war goal ID>`; example
`conquest.txt:5-23 cb_conquer_province = { years = 15 create_enabled = {...} province = { any_location_in_province = { is_core_of = scope:actor } } war_goal_type = conquer_province }`;
hardcoded `00_hardcoded.txt:3-9 cb_none = { declare_enabled = { can_declare_no_cb_war_on = scope:target } no_cb = yes war_goal_type = superiority }`.
CB-level AI hooks: `readme.txt:21-23 ai_subjugation_desire`, `ai_cede_location_desire = <script value> #root = country; scope:location; scope:war`,
`antagonism_reduction_per_warworth_defender`; `:30-33 allow_white_peace`, `required_*_peace_treaties`.

Wargoals (`G/in_game/common/wargoals/readme.txt:1-40`): types `take_province, superiority, naval_superiority,
defend_capital, enforce_military_access, independence, take_capital, take_border, take_country`; per side
`conquer_cost = <float> # factor applied to warscore cost of taking land in peace deal`, `subjugate_cost`, `release_cost`,
`antagonism`, `allowed_locations = { <triggers> } # scope:loser, scope:winner, scope:war, scope:location`,
`allowed_subjugation`; `ticking_war_score = <float> #Defaut 1`. Examples (`00_default.txt`):

```
  1 take_country = { type = take_country  attacker = { conquer_cost = 0.5 subjugate_cost = 0.5 } defender = { } }
 26 conquer_province = { type = take_province attacker = { conquer_cost = 0.75 subjugate_cost = 0.75 } defender = { } ticking_war_score = 0.5 }
105 take_capital = { type = take_capital attacker = { conquer_cost = 0.5 subjugate_cost = 0.5 } defender = { } ticking_war_score = 0.5 }
356 take_border = { type = take_border attacker = { conquer_cost = 0.8 subjugate_cost = 0.8 } ... ticking_war_score = 0.5 }
```
Descriptions (`LOC/diplomacy_l_english.yml`): `:2440 take_province` "bonus war score from occupying the target province
... ticking war score from occupying and holding every location in the province"; `:2442 take_capital` "**take the
enemy capital province** ... ticking war score from occupying all the locations in the province"; `:2444
defend_capital`; `:2448 superiority` (ticking once >10 battle score); `:2632 WG_ATT_CONQUER_COST_FACTOR: "[conquer|e] cost for attacker: $VAL|-=%V$"`.
So "taking the capital" is valued through (i) `WAR_WORTH_COUNTRY_CAPITAL`, (ii) the `take_capital` wargoal ticking
(+2/month * 0.5, max 25) which requires the **whole capital province**, (iii) `demoralised_by_loss_of_capital`.
There is no extra peace discount for the capital beyond its war worth.

### 5.2 Land cost in a peace (INFERRED chain, each link VERIFIED)

```
cost(location) = war_worth(location, taker)              # section 1.2 rows PEACECOST_PROV_*
               * wargoal conquer_cost (attacker/defender side)   # PEACE_WARGOAL_MODIFIER "[war_goal] $NAME$: $VAL|2-=%$"
               * treaty-type / subject-type modifiers            # PEACE_TREATY_TYPE_MODIFIER, PEACE_RETURN_CORE_MULTIPLIER
               / (1 + sum of efficiencies)                       # PEACE_COST_EFFICIENCY_MODIFIER (local+global+religion+define terms)
sum over treaties <= war score; MIN_WARSCORE_TO_DEMAND = 10 (DEF:2373); max 100 (TOTAL_COST_OF_PEACE_TEXT)
```
Script can read the engine's number directly: `scope:target.location_peace_cost(scope:loser|scope:winner)`
(`G/in_game/common/peace_treaties/dismantle_fort.txt:4-10`, `disband_kontor.txt:6`; trigger/value listed in
`trigger_localization/location_triggers.txt:746`). Cores: `DEF PEACE_REVOKE_CORE_MULT = 0.25`,
`PEACE_RETURN_CORE_MULT = 0.5` (NWar 2719-2722 area). Hardcoded land treaties (not scriptable, only localized):
`PEACE_TREATY_CEDE_CITY` (single location, `LOC/diplomacy_l_english.yml:1279`), `PEACE_TREATY_CEDE_PROVINCE :1271`,
`PEACE_TREATY_CEDE_AREA :1276`, `PEACE_TREATY_RETURN_CORE :1290`, `PEACE_TREATY_REVOKE_CORE :1282`,
`PEACE_TREATY_RELEASE :1265`, `PEACE_TREATY_ANNEX_REVOLTER :1334`; grep of `type = take_province|annex|cede` in
`peace_treaties/*.txt` found nothing - scripted treaties use `category = country/location/province/area` and
`effect = { annex_country = {...} }` (`hafsid_annexation.txt:30-36`). Scripted treaty format (`peace_treaties/readme.txt:53-58`):
`cost = script value (scope:winner/loser/war/target)`, `base_antagonism`, `ai_desire`, `ai_force_add`;
`blocks_full_annexation`, `are_targets_exclusive`, `select_trigger = { looking_for_a = location ... }`.
Peace screen rule `PEACE_TREATY_RELEASE_TAKE_WAR_GOAL_FIRST: "To take this land we should take the [war_goal] first."` (`:1366`).

### 5.3 Ending wars / AI (VERIFIED defines)

`DEF:2297 CALL_FOR_PEACE_THRESHOLD_MONTHS = 60`, `:2298 CALL_FOR_PEACE_WARSCORE_LIMIT = 67`,
`:2300-2304 UNCONDITIONAL_SURRENDER_*` (`_WARSCORE_LIMIT = -90`, `_HOPELESS_STRENGTH_COMPARISON = 20`),
`:2717 YEARS_SINCE_LAST_WAR_ACTION_BEFORE_WHITE_PEACE = 3`; AI: `:1100 PEACE_OFFER_WAR_SCORE_THRESHOLD = 50`,
`:1102 PEACE_OFFER_OCCUPATION_PERCENTAGE_THRESHOLD = 0.25`, `:1206 EXPECTED_WAR_SCORE_BASE = 25`,
`:1211 MINIMUM_WAR_SCORE_TO_CONSIDER_DEFEAT = -50`, `:1222 IDEAL_WARSCORE_DIFFERENCE_THRESHOLD_TO_CONSIDER_PEACE = 20`,
`:1492 AI_CONQUER_LOCATION_TREATY_WAR_WORTH_FACTOR = 0.5 # How much AI cares about war worth when picking locations`,
`:1106 HEAVILY_OUTNUMBERED_RATIO = 0.40`. Country modifier `expected_warscore_modifier` (`MTD:13501`, ai=yes).
Join rules: `G/in_game/common/join_war_rules/readme.txt:3 join_war_disabled_trigger = <trigger> root = joining country, scope:war, scope:first_leader, scope:second_leader`.
Script access to warscore: value `war_score_versus(<country>)` on a country
(`G/in_game/common/generic_actions/guelphs_and_ghibellines.txt:504 value = "scope:actor.war_score_versus(scope:target.attacker_leader)"`),
war link `war_with_country(<country>)` and effect
`G/in_game/common/unit_abilities/raid_clan_holdings.txt:67-71 "war_with_country(root.owner)" = { add_bonus_warscore = { country = root.owner amount = 20 } }`;
effect `white_peace` (effect_localization/war_effects.txt:1); war-scope links `attacker_leader`, `defender_leader`,
`casus_belli` (`peace_treaties/hafsid_annexation.txt:10-21`), country list `every_current_war` (`_hardcoded.txt:181`).

---

## 6. Answer (e): triggers / links in location scope (all VERIFIED unless noted)

| Trigger / link | Example (file:line) | Meaning |
|---|---|---|
| `is_capital = yes` | `G/in_game/common/location_ranks/00_default.txt:59` (allow, root = location); `building_types/capital_buildings.txt:23` | location is a country capital (`LOC/triggers:2289 "Is the [capital]"`) |
| `counts_as_capital = yes` | `building_types/capital_buildings.txt:19` | capital **or historical capital** (`LOC/triggers:2294`) |
| `is_province_capital = yes` | `building_types/manpower_buildings.txt:403`; `generic_actions/columbian_exchange.txt:578` | province capital |
| `location_rank = location_rank:city` | `building_types/unique_buildings.txt:4693`; `country_interactions/hre.txt:2235 OR = { location_rank = location_rank:city location_rank = location_rank:megalopolis }` | exact rank (loc key `rank` -> `LOCATION_RANK_TRIGGER "Is a $NAME$"`) |
| `rank_index >= 1` | `building_types/hre_buildings.txt:21`; `missions/generic_capital_economy_mission_pack.txt:195 rank_index <= 2`; value use `attribute_columns/05_location.txt:186` | numeric rank; INFERRED 0 = rural_settlement, 1 = town, 2 = city, 3 = megalopolis (list position; `tier` is 1-4) |
| `is_city = yes` / `no` | `building_types/situation_buildings.txt:26`; `decisions/coal_prospecting.txt:10` | urban (`is_established_city = yes` ranks: town/city/megalopolis) - `LOC/triggers:2489 "Is an [town_or_city]"` |
| `original_location_rank`, `can_become_rank` | loc only (`location_triggers.txt:165, 270`) | rank at campaign start / upgrade possible |
| `is_port = yes` | `building_types/coastal_forts.txt:20`; `avatars/hindu.txt:14` | has port |
| `is_coastal = yes` | `building_types/common_buildings.txt:103` | coastal |
| `has_fort = yes` | `building_types/unique_buildings.txt:3045`; `peace_treaties/dismantle_fort.txt:25` | fortified |
| `has_siege = yes` + `siege = { any_besieging_unit = {...} }` | `on_action/country_monthly.txt:218-222` | under siege, enter siege scope |
| `controller`, `owner` links | `casus_belli/01_event_triggered.txt:135 scope:recipient.capital.controller = scope:recipient` | occupier / owner |
| `is_core_of = <country>` | `casus_belli/conquest.txt:10` | core |
| `has_building = building_type:x` | `building_types/capital_buildings.txt:1227` | building present |
| `in_zone_of_control`, `local_control`, `max_control`, `garrison_strength`, `location_peace_cost(a\|b)` | `trigger_localization/location_triggers.txt:450, 378-392, 836, 746` | names verified via loc table; `location_peace_cost` used in `dismantle_fort.txt:7` |
| `location_modifier_greater_or_equal`, `has_location_modifier` | `location_triggers.txt` key list | read a modifier value (e.g. `fort_level`) |
| from country: `capital = { ... }`, `every_owned_location`, `any_owned_location` | `_hardcoded.txt:689`; `casus_belli/conquest.txt:9` | iterate / reach locations |

No `is_occupied`, `is_under_siege`, `occupied_by`, `is_urban`, `is_rural`, `has_location_rank` triggers exist in
vanilla script (grep negative) - use `controller != owner`, `has_siege`, `is_city = no`, `location_rank`.
GUI side: `Location.GetRank`, `Location.HasRank`, `Location.HasSiege`, `Location.HasFort`, `Location.GetFortLevel`,
`Location.GetGarrison`, `Location.GetWarWorthTooltip` (counts from `G/in_game/gui/*.gui`).

---

## 7. Pitfalls

1. **First-key-wins database rule** (section 3): any "patch file" that redefines a vanilla key in `location_ranks`,
   `static_modifiers`, `wargoals`, `casus_belli`, `peace_treaties`, `age`, `auto_modifiers` ... is silently dropped;
   look in `debug.log` for `gamedatabase.h:409 Duplicated key`, **not** in `error.log`. Replace whole files instead
   (same relative path) and re-diff them after every game patch.
2. `local_war_score_efficiency` only changes **peace cost**; the occupation warscore still uses raw war worth. A
   rural-cheap/city-expensive peace with unchanged war worth would let the AI reach high warscore by carpet-sieging
   villages and then buy cities cheaply - the opposite of the design goal. Change `WAR_WORTH_*` first.
3. Efficiency is a divisor `1/(1+eff)`: values `<= -1.0` are undefined; stacking the mod's negative rank efficiency
   with `stronghold_city_modifier -0.25`, `PEACE_COST_EFFICIENCY_UNOCCUPIED_FORT -0.15`, `_FORT_NEVER_SIEGED -0.18`,
   `_FOR_NON_TARGET -0.5` can approach -1. Keep rank values >= -0.5 and test a stronghold megalopolis capital.
4. `WAR_WORTH_DEVELOPMENT_SCALE` is relative to the **taker's** average development: with a tiny `WAR_WORTH_BASE`, a
   developed taker (e.g. Venice) sees rural land at `max(-1, ...)` -> possibly 0 or negative contributions. Clamp by
   keeping BASE >= 0.25 and check that no location ends up with worth <= 0 (unknown engine behaviour, UNVERIFIED).
5. The complete-victory rule already needs "losing side controls no towns_or_cities"; making rural land worth ~0 while
   `OCCUPATION_VALUE_SCALE = 2.0` stays means occupying **half the urban worth** yields 100% occupation score.
   Consider lowering `OCCUPATION_VALUE_SCALE` to ~1.3-1.5 at the same time.
6. `take_capital` ticking needs the whole capital **province**, not just the capital location; with HQ-gated sieges
   the AI may never complete it -> wars stall into `CALL_FOR_PEACE_THRESHOLD_MONTHS = 60` white peaces. Watch
   `YEARS_SINCE_LAST_WAR_ACTION_BEFORE_WHITE_PEACE = 3` too: if HQ-less AI stacks cannot progress sieges, "war
   action" may stop and wars auto-end.
7. `siege_ability -90%` and `army_maintenance_reverse_mod -1.0` stack additively (INFERRED): a half-maintenance
   HQ-less AI army can reach <= -100% siege ability. Decide what the floor is (`MIN_DAYS_PER_SIEGE_PHASE = 7` caps the
   fast side, nothing documented caps the slow side).
8. A lone 100-man HQ may itself satisfy the ">= 100 men" unfortified gate and occupy villages (section 4.5) - if so the
   HQ must be prevented from sieging alone (men < 100 or an `occupation_time` style location penalty when only
   auxiliaries are present - UNVERIFIED whether auxiliaries count).
9. `add_bonus_warscore` is one-shot and the "Bonuses" bucket is capped (`WARGOAL_MAX_BONUS = 50`, INFERRED to apply);
   it cannot model "capital retaken".
10. `lack_of_control_impact_on_warscore` lives inside each `age` entry's `modifier = {}`; `age` is a database ->
    changing the curve means replacing `G/in_game/common/age/00_default.txt` (very large, patch churn) or adding the
    delta through a global country modifier instead.
11. Defines partial-override is INFERRED from Jomini conventions, not verified for EU5. Validate with the location
    panel "War Score of X" number after loading the mod.
12. War worth is intel-gated (`INTEL_THRESHOLD_LOCATION_WAR_WORTH = 25`); testers without a spy network will see "?"
    for enemy locations - use the own-country values or the warscore map mode.

## 8. Recommendations for the mod

1. **Warscore rework = defines first.** Ship `in_game`-independent `loading_screen/common/defines/zz_cw_defines.txt`:
   `NWar = { WAR_WORTH_BASE = 0.25  WAR_WORTH_COUNTRY_CAPITAL = 30  WAR_WORTH_PROVINCE_CAPITAL = 2  WAR_WORTH_PORT = 2
   WAR_WORTH_BUILDING_SCALE = 0.05 WAR_WORTH_BUILDING_CAP = 15  WAR_WORTH_POPULATION_SCALE = 0.03
   WAR_WORTH_POPULATION_CAP = 6  WAR_WORTH_TAX_BASE_CAP = 6  OCCUPATION_VALUE_SCALE = 1.5 }` (starting values; tune
   against the in-game "War Score of <location>" readout for a village / town / city / capital of one test country).
   If partial defines do not apply, fall back to a full `00_defines.txt` copy and note the game version in `.metadata`.
2. **Rank-based peace pricing**: replace `in_game/common/location_ranks/00_default.txt` keeping everything, adding
   `local_war_score_efficiency = 1.0` (rural_settlement), `0.25` (town), `-0.25` (city), `-0.4` (megalopolis) inside
   `rank_modifier`. Megalopolis is capital-only in vanilla (`allow ... is_capital = yes`), so it doubles as a capital tax.
3. **Capital premium in peace**: replace `main_menu/common/static_modifiers/location.txt` only if a capital efficiency
   malus is really wanted (`capital = { ... local_war_score_efficiency = -0.5 }`); otherwise rely on
   `WAR_WORTH_COUNTRY_CAPITAL` which already feeds both systems. Prefer the define.
4. **Capital events**: add `in_game/common/on_action/cw_siege_on_actions.txt` with `on_siege_won = { effect = {...} }`
   and `on_location_occupied = { effect = {...} }` (on_actions merge; root = country, scope:target = location) to
   (a) apply `demoralised_by_loss_of_capital`-like country modifiers, (b) optionally
   `"war_with_country(scope:target.owner)" = { add_bonus_warscore = { country = root amount = 10 } }` when
   `scope:target = { is_capital = yes }`, (c) set the war-stance variables used by the top-bar plate.
5. **HQ gating via modifiers, not via siege rules**: the engine has no scriptable "can siege" flag; use a unit
   modifier (`category = unit`) with `siege_ability = -0.9` plus `discipline`/`land_morale_modifier` penalties, applied
   with `add_unit_modifier` (names verified in `effect_localization/unit_effects.txt`, usage pattern UNVERIFIED - test
   on a monthly country pulse over `every_army`-style lists). Document the stacking with `army_maintenance_reverse_mod`.
6. **Keep wars resolvable**: either (a) give the AI's main army an HQ automatically (the AI side of the mod), or
   (b) soften the HQ-less siege malus for unfortified locations (`occupation_time` is a *location* modifier, so it
   cannot be used per army; only `siege_ability` can) so that HQ-less stacks still occupy villages slowly. Re-check
   `CALL_FOR_PEACE_*` behaviour in a 20-year observer test.
7. **Warscore tooling for testing**: use the war-score map mode (`MAPMODE_WARSCORE`), the location panel value
   (`Location.GetWarWorth`), and the `location_peace_cost(scope:loser|scope:winner)` script value inside a debug
   scripted GUI (format as `G/in_game/common/scripted_guis/economy_satisfaction_target.txt:1-27`: `key = { effect = { root = { ... } } }`,
   fields per `scripted_guis.info:1-13`) to print worth/cost for a selected location.
8. Verify (in order): defines partial override -> war worth numbers; rank efficiency -> peace cost numbers; lone HQ
   siege test; `-100%` siege ability behaviour; AI war durations with the HQ malus. Record all in `docs/research/`.
