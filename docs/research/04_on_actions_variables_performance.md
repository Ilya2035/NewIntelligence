# 04 — on_actions, pulses, variables, control flow, performance (EU5 1.4.7)

Research note for the *Concentrated Warfare* mod (`cw_` prefix). Everything below was read from the installed game files on 2026-11-04. Paths are relative to `C:\Program Files (x86)\Steam\steamapps\common\Europa Universalis V\game\` unless stated otherwise. Line numbers refer to the files with the UTF-8 BOM stripped (vanilla `on_action` files start with a BOM; `_hardcoded.txt` line 1 is `on_game_start`).

Legend: **VERIFIED** = seen in vanilla/workshop script (snippet quoted). **INFERRED** = follows from vanilla structure/comments but no explicit documentation. **UNVERIFIED** = not found in any file; do not rely on it without an in-game test.

There are no script-doc logs (`effects.log`, `triggers.log`) in `Documents/Paradox Interactive/Europa Universalis V/logs`, so the engine's trigger/effect inventory was reconstructed from `in_game/common/trigger_localization/*.txt` and `in_game/common/effect_localization/*.txt` (every key there is a real trigger/effect; keys that appear **only** there are marked "loc-only" below).

---

## 1. The on_action system

### 1.1 Anatomy (VERIFIED — `in_game/common/on_action/on_actions.info`)

```
in_game/common/on_action/on_actions.info:1-9, 14-19, 23-36, 44-62 (abridged)
on_action_name = {
	trigger = { ... }              # if false, nothing happens (events, on_actions, effect)
	weight_multiplier = { base = 1  modifier = { add = 1  trigger_conditions = yes } }
	events = { event_id_1  delay = { days = 365 }  event_id_2  delay = { months = { 6 12 } } ... }
	random_events = { chance_to_happen = 25  chance_of_no_event = { value = 0 ... }  100 = event_id_1  100 = 0 }
	first_valid = { event_id_1  event_id_2  fallback_event_without_trigger }
	on_actions = { on_action_1  on_action_2 }          # fire other on_actions, same rules (delays allowed)
	random_on_action = { 100 = on_action_1  100 = 0 }
	first_valid_on_action = { on_action_1  on_action_2 }
	effect = { ... }               # runs CONCURRENTLY with the events, not before them
	fallback = another_on_action   # called if nothing fired
}
```

Documented semantics worth remembering (all VERIFIED from the same file):

- `delay` applies to every entry listed after it; "For performance reasons, an event will only successfully fire if it is valid both when the on_action is executed AND once the delay is complete."
- `chance_to_happen` is checked **before** anything in `random_events` is evaluated; `chance_of_no_event` is a script value evaluated only if `chance_to_happen` passed.
- `effect` "can access the same default or saved scopes as the script chain/code functionality it was fired from" but "Scopes or local variables set in the effect here will not carry over to any event fired by the on_action."
- `fallback` loops can freeze time.
- Additional undocumented keys used by vanilla: `sample_count = N` inside `random_events` (`country_yearly.txt:62`, `:828`) — INFERRED: number of events drawn per evaluation.

### 1.2 Engine-called pulses (keys the C++ fires; none is referenced by any other script)

| Key | File | Root / cadence | Notes |
|---|---|---|---|
| `monthly_country_pulse` | `country_monthly.txt:2` | country, monthly | VERIFIED: root is a country (sub on_actions use `tag =`, `has_variable`, `is_real_country`). Vanilla trackers filter with `is_real_country = yes` (`:303`, `:332`), so **non-real countries (rebels, pirates…) are pulsed too** (INFERRED from the explicit filter). |
| `yearly_country_pulse` | `country_yearly.txt:1` | country, yearly | heavy flavor lists; `random_events` with `sample_count = 3`, `chance_to_happen = 50`. |
| `biyearly_country_pulse` | `country_biyearly.txt:4` | country, every 2 years | "primarily for religious flavor events", `chance_to_happen = 25`. |
| `four_yearly_country_pulse` | `country_four_yearly.txt:1` | country, every 4 years | contains the 50 %/25 % random split (see §5). |
| `country_pulse_for_high_infamy` | `country_pulse_for_high_infamy.txt:1` | country, monthly (comment `:20` "monthly pulse") | only fires while infamy is high (INFERRED from name; C++-gated). |
| `government_flavor_pulse`, `religion_flavor_pulse` | own files | country | engine-called; each has type-gated sub on_actions (`government_flavor_pulse_monarchy = { trigger = {...} }`). |
| `parliament_monthly_pulse` | `parliament_monthly_pulse.txt:1` | country, monthly "only active during an active parliament session" | |
| `in_regency_yearly_pulse` | `in_regency_yearly_pulse.txt:3` | `# root = country` | |
| `colonial_charter_monthly_pulse` | `colonial_charter_monthly.txt:3` | `# root = country, scope:target = colonial_charter` | |
| `on_exploration_monthly_pulse` | `exploration_mission_monthly.txt:3` | `# root = exploration` | |
| `on_settle_the_frontier_monthly_pulse` | referenced from `monthly_country_pulse` | country | script-chained, not engine-called. |
| `volcano_location_pulse`, `earthquake_location_pulse`, `weather_monthly_pulse` | `location_pulses.txt:5,23,38` | `# root = location`; monthly | "checks one random location each month" (`:22`) for earthquakes — vanilla deliberately avoids per-location monthly work. |
| `chinese_expedition_event_pulse` | `treasure_voyage.txt:4` | country | script-fired via `trigger_event_silently = { on_action = ... }` (`events/expeditions/treasure_fleet_events.txt:102-104`). |

**There is no daily, weekly or quarterly country pulse** in script (VERIFIED by absence: every key ending in `_pulse` across the folder is listed above or chained from them). Quarterly cadence must be built on top of `monthly_country_pulse` (§5.3).

### 1.3 Complete list of hardcoded on_actions (`in_game/common/on_action/_hardcoded.txt`, 148 keys)

Scope text is the vanilla comment (verbatim, abbreviated); "—" = no comment in the file.

| Line | Key | Scope (vanilla comment) |
|---|---|---|
| 1 | `on_game_start` | — (global; vanilla runs `every_country` loops here) |
| 316 | `on_game_started_after_lobby` | — (empty `{}` in vanilla; INFERRED global like `on_game_start`) |
| 321 | `on_siege_won` | "When a location with fort changes controller after a siege. root = country, scope:target = location, scope:character = leading general character" |
| 447 | `on_siege_lost` | — (INFERRED mirror of `on_siege_won` for the losing controller) |
| 494 | `on_location_occupied` | "When a location without fort changes controller after an occupation process; root = country, scope:target = location, scope:character = leading general character" |
| 620 | `on_location_lost` | — (INFERRED mirror of `on_location_occupied`) |
| 629 | `in_battle` | "every tick while a character is the supreme commander of a battle. root = character" |
| 633 | `on_new_age_global` | "on action called only once before each country" |
| 640 | `on_new_age` | "scope is country, this is done for ALL active countries when a new nation is picked" |
| 663 | `on_omen_god_selected` | — |
| 670 | `on_command_gained` | "root = character, scope:unit = unit" |
| 674 | `on_command_lost` | "root = character, scope:unit = unit" |
| 678 | `on_military_annex` | "fired before the annexation happens; root = country doing the annexing, scope:target = country being annexed" |
| 715 | `on_diplomatic_annex` | same as above |
| 757 | `on_civil_war_annex` | same |
| 789 | `on_colonize_annex` | same |
| 794 | `on_annex` | same |
| 901 | `on_military_annexed` | "fired after the annexation has happened; root = annexer, scope:target = annexed" |
| 904 | `on_diplomatic_annexed` | same |
| 907 | `on_civil_war_annexed` | same |
| 910 | `on_annexed` | same |
| 1092 | `on_annexation_start` | "root = country doing the annexing, scope:target = country being annexed" |
| 1112 | `on_annexation_cancel` | same |
| 1124 | `on_civil_war_start` | "root = original country which gets targeted by the civil war, scope:target = rebel country which declares the war, scope:war = the civil war, scope:rebel is the rebel" |
| 1264 | `on_revolt_start` | same pattern for revolts |
| 1277 | `on_loan_repaid` | "root = country, scope:target = loan, scope:owner = lender (check exists = scope:owner first)" |
| 1293 | `on_loan_taken` | same |
| 1297 | `on_loan_renewed` | same |
| 1301 | `on_bankruptcy` | "root = country" |
| 1326 | `on_civil_war_lost` | "root and scope:winner = winner, scope:loser = loser" |
| 1477 | `on_civil_war_won` | same |
| 1534 | `on_winning_war` | "root = country, scope:winner = country, scope:loser = country, scope:war = war" |
| 1875 | `on_join_war` | "root = country" (the joiner; `scope:war` is used in the body at `:1895`, `:1903`) |
| 1930 | `on_losing_war` | "root = country, scope:winner, scope:loser, scope:war" |
| 1955 | `on_pre_ending_war` | "root = country (after winning and losing, for both, but before peace terms were executed), scope:winner, scope:loser, scope:war" |
| 1959 | `on_pre_winning_war` | "root = country, scope:winner, scope:loser, scope:war" |
| 2035 | `on_pre_losing_war` | same |
| 2039 | `on_ending_war` | "root = country (after winning and losing, for both), scope:winner, scope:loser, scope:war" |
| 2351 | `on_pre_war_declared` | "root = country, scope:actor = country who declares the war, scope:recipient = country who gets declared on - fires before the war is actually created" |
| 2395 | `on_war_declared` | "root = country, scope:actor = country who declares the war, scope:recipient = country who gets declared on, scope:war = war" |
| 2657 | `on_accepted_call_to_arms` | "scope:actor = caller, scope:recipient = callee, scope:war = war" |
| 2686 | `on_rejected_call_to_arms` | same |
| 2716 | `on_took_location_in_peace_treaty` | "root = winner, scope:location = location, scope:winner = new owner, scope:loser = old owner" |
| 2886 | `on_battle_won_character` | "root = character" |
| 2956 | `on_battle_lost_character` | "root = character" |
| 2983 | `on_great_battle_won` | "root = actor, scope:actor = winning unit, scope:target = losing unit; float scopes: scope:killed_land_units, scope:killed_navy_units, scope:lost_land_units, scope:lost_navy_units, scope:war_score" |
| 3143 | `on_great_battle_lost` | same, from the loser's side |
| 3209 | `on_battle_won` | same as `on_great_battle_won` |
| 3335 | `on_battle_lost` | same as `on_great_battle_lost` |
| 3382 | `on_overrun_imprisoned` | "root = unit of prisoners, scope:winner = country that was victorious" |
| 3389 | `on_max_doom_reached` | "root = country" |
| 3396 | `on_colonial_charter_finished` | "root = country, scope:target = province, scope:actor = the country" |
| 3403 | `on_colonial_charter_failed` | "root = country, scope:target = province_definition, scope:attacker = the other country" |
| 3412 | `on_election` | "root = country" |
| 3423 | `on_becoming_free` | "root = country, scope:overlord = former overlord" |
| 3513 | `on_dependency_gained` | "root = country, scope:overlord = new overlord" |
| 3578 | `on_subject_created` | "root = country, scope:overlord = creator, scope:subject_type = subject type" |
| 3613 | `on_reform_change` | — |
| 3619 | `on_building_construction_started` | "root = building" |
| 3624 | `on_building_construction_ended` | "root = building" |
| 3629 | `on_building_built` | "root = building" |
| 3634 | `on_building_destroyed` | "root = building" |
| 3639 | `on_road_construction_started` | "root = country, scope:from = location, scope:to = location, scope:road_type" |
| 3644 | `on_road_construction_ended` | same |
| 3649 | `on_road_built` | same |
| 3654 | `on_bureaucracy_change` | "root = country" |
| 3660 | `on_bureaucracy_added` | "root = country, scope:bureaucracy_type" |
| 3666 | `on_bureaucracy_removed` | same |
| 3675 | `on_government_type_change` | "root = country; scope:from = old type; scope:to = new type" |
| 3725 | `on_new_ruler` | "root = country; scope:old_ruler and scope:new_ruler" |
| 3975 | `on_ruler_death` | "root = country; scope:old_ruler… fires the moment the character dies - use carefully" |
| 4001 | `on_ruler_death_delayed` | "root = country; scope:old_ruler… fires at the next daily tick" |
| 4172 | `on_made_saint` | "root = country, scope:recipient = character" |
| 4193 | `on_character_estate_change` | "root = character, scope:estate = estate type" |
| 4206 | `on_religion_changed` | "root = country, scope:old_religion" |
| 4580 | `on_culture_changed` | "root = country, scope:old_culture" |
| 4584 | `on_international_organization_creation` | "root = int org, actor = creator (optional), target (optional)" |
| 4589 | `on_international_organization_disbanding` | "sent just before an IO disbands; root = int org, actor = instigator (optional)" |
| 4649 | `on_international_organization_disbanded` | "sent to each country that's a member… root = country" |
| 4681 | `on_union_merging` | "root = the union IO…, scope:ruler = leader character; also called for a single Union" |
| 4698 | `on_union_formation` | "root = new union IO, scope:ruler; (optional) scope:first_leader, scope:second_leader" |
| 4814 | `on_union_split` | "scope:first_ruler, scope:second_ruler" |
| 4818 | `on_marriage_union_formation` | "root = union, scope:ruler, consorts list" |
| 4849 | `on_location_changed_rank` | "root = location, old_rank = location_rank, actor = country" |
| 4854 | `on_pre_location_changed_rank` | "root = location, new_rank, actor = country" |
| 4859 | `on_location_changed_owner` | "root = location, scope:loser = previous owner, scope:winner = new owner (can be null)" |
| 5348 | `on_raw_material_changed` | "root = location, scope:old_goods, scope:new_goods" |
| 5352 | `on_new_country_formed` | "root = newly formed country" |
| 5395 | `on_released_country` | "root = released country, scope:overlord" |
| 5443 | `on_international_organization_changed_leader` | "root = new_ruler, target = org, scope:old_ruler" |
| 5721 | `on_nation_changing` | — |
| 5728 | `on_regency_start` | — |
| 5762 | `on_regency_end` | — |
| 5766 | `on_cabinet_assigned` | "root = country, scope:target = character" |
| 5791 | `on_cabinet_removed` | "root = country, scope:target; called BEFORE on_cabinet_assigned on replacement; NOT fired on death" |
| 5807 | `on_institution_embraced` | "root = country, scope:target = institution" |
| 5826 | `on_character_marriage` | "root = primary character, scope:target = secondary" |
| 5838 | `on_character_divorce` | same |
| 5842 | `on_character_betrothal` | same |
| 5846 | `on_character_betrothal_broken` | same |
| 5850 | `on_character_betrothal_broken_by_death` | "root = character who died, scope:target = surviving betrothed" |
| 5854 | `on_character_betrothal_confirmed` | "root = primary, scope:target = secondary. Both adults" |
| 5858 | `on_work_of_art_created` | "root = work of art" |
| 5881 | `on_work_of_art_destroyed` | "root = work of art" |
| 5885 | `on_work_of_art_looted` | "root = work of art, scope:target = new location, scope:location = old location; NOT called by move_art" |
| 5981 | `on_work_of_art_moved` | same, called by `move_art` |
| 5985 | `on_character_moved_country` | "root = character, scope:target = new country, scope:owner = old country" |
| 6040 | `on_character_changed_religion` | "root = character, scope:old_religion" |
| 6064 | `on_parliament_started` | "root = country, scope:location = parliament seat" |
| 6068 | `on_parliament_passed` | "root = country, scope:target = parliament issue, scope:location" |
| 6085 | `on_parliament_failed` | same |
| 6089 | `on_parliament_abolished` | "root = country" |
| 6093 | `on_parliament_established` | "root = country" |
| 6097 | `on_io_parliament_started` | "root = io, scope:location" |
| 6101 | `on_io_parliament_passed` | "root = io, scope:target = issue, scope:location" |
| 6105 | `on_io_parliament_failed` | same |
| 6109 | `on_gift_sent` | "root, scope:actor = sender, scope:recipient = receiver, scope:target = amount of gold" |
| 6113 | `on_insult` | "root, scope:actor, scope:recipient" |
| 6117 | `on_unconditional_surrender` | "root, scope:actor, scope:recipient, scope:war" |
| 6137 | `on_royal_marriage` | "root, scope:actor, scope:recipient, scope:target_1, scope:target_2 (characters)" |
| 6144 | `on_noble_marriage` | "root, scope:actor = country, scope:recipient = character of actor, scope:target = the noble" |
| 6176 | `on_gain_great_power_status` | "root = country" |
| 6180 | `on_lose_great_power_status` | "root = country" |
| 6184 | `on_embrace_revolution` | "root = country" |
| 6219 | `on_lose_revolution` | "root = country" |
| 6238 | `on_become_revolution_target` | "root = country" |
| 6243 | `on_lose_revolution_target` | "root = country" |
| 6248 | `on_shatter_country` | "root = country" |
| 6274 | `on_shattered_country` | "(optional) actor = country, new_countries = list of countries" |
| 6305 | `on_mission_start` | "root = country" |
| 6308 | `on_mission_completion` | "root = country" |
| 6311 | `on_mission_abort` | "root = country" |
| 6317 | `on_mission_task_start` | "root = country" |
| 6320 | `on_mission_task_completion` | "root = country" |
| 6323 | `on_mission_task_bypass` | "root = country" |
| 6327 | `on_storm_reached_location` | "root = location; scope:weather_system" |
| 6333 | `on_capital_moved` | "root = country; scope:old_capital; scope:new_capital" |
| 6337 | `on_heir_selection_changed` | "root = country; scope:old_heir_selection; scope:heir_selection" |
| 6359 | `on_subject_type_changed` | "root = subject; scope:overlord; scope:subject_type; scope:old_subject_type" |
| 6392 | `on_international_organization_parliament_agenda_accepted` | "root = international_organization" |
| 6399 | `on_policy_changed` | "root = country" |
| 6417 | `on_international_organization_policy_changed` | "root = international_organization" |
| 6421 | `on_country_rank_change` | "root = country, scope:old_rank" |
| 6437 | `on_gain_hegemon_status` | "root = country, scope:target = hegemony" |
| 6441 | `on_lose_hegemon_status` | same |
| 6445 | `on_enforce_peace_accepted` | "happens before the war is ended, scope:actor, scope:recipient, scope:war" |
| 6454 | `on_enforce_peace_declined` | "scope:actor, scope:recipient, scope:war" |
| 6464 | `on_transfer_subject` | "after the transfer, root = subject, scope:overlord = new overlord, scope:former_overlord" |
| 6481 | `on_truce_broken` | "root = actor, scope:recipient = country the truce was broken with, scope:war" |

Engine-called keys that live **outside** `_hardcoded.txt` (so `_hardcoded.txt` is not the whole hook inventory): `on_character_birth` (`character.txt:1`, root = country, scope:character), `on_character_created` (`:25`, root = character, only from `create_character`), `on_character_death` (`character_death_pulses.txt:2`, root = country, scope:target = character), `on_estate_culture_changed` / `on_estate_religion_changed` (`estate_changes.txt`, root = country, scope:estate), `on_expedition_leader_replaced` (`expedition_leader_replaced.txt:1`), `on_exploration_success` (`exploration_mission_monthly.txt:53`), `on_scripted_relation_created` / `on_scripted_relation_broken` (`diplomatic_reactions.txt:1,56`, scope:scripted_relation_type, scope:recipient), `on_subject_subjugated` (`:59`, scope:overlord), `on_culture_group_merged` (`culture_unification.txt:1`), `on_heir_changed` (`inheritance_contract_on_actions.txt:40`), `on_market_withering_started` (mentioned in `loading_screen/common/defines/00_defines.txt:2024`).

### 1.4 Do same-key definitions in several files MERGE or override? → **MERGE** (VERIFIED by structure)

Six keys are defined twice in vanilla itself, always once in `_hardcoded.txt` and once in a file that sorts later:

| Key | Files |
|---|---|
| `on_game_start` | `_hardcoded.txt:1` (315 lines of effects) + `ai_personalities_setup.txt:9` |
| `on_winning_war` | `_hardcoded.txt:1534` (340 lines) + `religious_order_conquest.txt:5` |
| `on_ending_war` | `_hardcoded.txt:2039` + `religious_order_conquest.txt:9` |
| `on_took_location_in_peace_treaty` | `_hardcoded.txt:2716` + `religious_order_conquest.txt:1` |
| `on_royal_marriage` | `_hardcoded.txt:6137` + `diplomatic_reactions.txt:72` |
| `on_truce_broken` | `_hardcoded.txt:6481` + `diplomatic_reactions.txt:95` |

```
in_game/common/on_action/religious_order_conquest.txt:1-11
on_took_location_in_peace_treaty = {
	on_actions = { religious_order_conquest_candidate_pulse }
}

on_winning_war = {
	on_actions = { religious_order_conquest_offer_pulse }
}

on_ending_war = {
	on_actions = { religious_order_conquest_cleanup_pulse }
}
```

```
in_game/common/on_action/ai_personalities_setup.txt:1-11
# AI Personality on_action hooks.
# Historical assignments are in setup/countries/26_ai_personalities.txt.
...
on_game_start = {
	on_actions = { on_ai_personalities_game_start }
}
```

If the later definition replaced the earlier one, vanilla would lose the entire hardcoded `on_winning_war`/`on_game_start` bodies — so the engine **merges** entries of same-named on_actions across files (lists are concatenated). Supporting evidence: `error.log` contains no "duplicate"/"on_action" complaints after a session with both mods loaded, and the Community Mod Framework ecosystem relies on exactly this pattern (workshop Cheat Menu Pro, `3600272327/in_game/common/on_action/sakuya_cmm_sittings_cmm_on_actions.txt:1-6`):

```
# Hook this mod into CMF shared registration on_action.
cmf_on_mod_registration = {
	on_actions = {
		sakuya_cmm_sittings_on_register_cmf_mod
	}
}
```

No vanilla file contains a comment about merge semantics (searched `merge|overrid|duplicate|same key`). What is **not** verified: whether a duplicated `effect = {}` or `trigger = {}` block merges or replaces (vanilla never duplicates those — every second definition only adds list entries). **Rule for the mod: only ever add `on_actions = { ... }` entries to vanilla keys; put all logic (trigger/effect/events) in our own `cw_*` on_actions.**

Load order: files in a folder load alphabetically (`_hardcoded.txt` sorts first because `_` < letters); mod files with new names are simply additional files in the same virtual folder. Our file `in_game/common/on_action/cw_on_actions.txt` must therefore **not** reuse a vanilla file name (that would replace the file wholesale).

### 1.5 Exact hook syntax for the mod (VERIFIED pattern)

```
# in_game/common/on_action/cw_on_actions.txt   (UTF-8 with BOM like vanilla)

monthly_country_pulse      = { on_actions = { cw_monthly_pulse } }   # root = country (incl. non-real countries)
on_game_started_after_lobby = { on_actions = { cw_on_game_start } }  # vanilla body is empty; scope INFERRED global -> use every_country
on_new_age                  = { on_actions = { cw_on_new_age } }     # root = country, fired for every active country
on_war_declared             = { on_actions = { cw_on_war_declared } }# root = country; scope:actor, scope:recipient, scope:war
on_join_war                 = { on_actions = { cw_on_join_war } }    # root = joining country; scope:war
on_ending_war               = { on_actions = { cw_on_war_ended } }   # root = country, fired ONCE PER SIDE; scope:winner/loser/war
on_battle_won               = { on_actions = { cw_on_battle } }      # root = actor; scope:actor/target are UNITS; float scopes
on_battle_lost              = { on_actions = { cw_on_battle } }
on_siege_won                = { on_actions = { cw_on_control_changed } } # root = country; scope:target = location; scope:character = general
on_location_occupied        = { on_actions = { cw_on_control_changed } }

cw_monthly_pulse = {
	trigger = { is_real_country = yes }      # cheap gate -> skips the whole block for rebels/pirates/mercs
	effect = { cw_monthly_effect = yes }     # scripted effect in in_game/common/scripted_effects/cw_effects.txt
}
```

Scope facts behind the comments:

- `on_ending_war` is explicitly run for both sides: `_hardcoded.txt:2050-2052` "Fires for both winner and loser as root scope, so each side cleans up its own canals." Our cleanup must be idempotent.
- `on_join_war`: `_hardcoded.txt:1899-1912` uses `scope:war = { is_a_defender = root  defender_leader = { ... }  attacker_leader = { ... } }` — so `scope:war` is available and `root` is the joiner.
- `on_war_declared`: the body never compares `root` with `scope:actor`/`scope:recipient`; it uses `root = { remove_avatar = prev }` (`:2522`) in an IO-membership-gated block. Whether it fires once (root = actor) or once per participant is **UNVERIFIED** — always address `scope:actor` / `scope:recipient` explicitly and make the effect idempotent (e.g. guard with `limit = { this = scope:actor }` when something must happen once).
- `on_battle_won`: `_hardcoded.txt:3219-3227` `scope:actor.owner ?= { any_current_war = { is_in_war = scope:target.owner ... } }` and `:3230-3233` `scope:actor = { grant_special_unit_experience = { ... } }` (a unit-scope scripted effect, `scripted_effects/unit_effects.txt:1 "#root = unit"`). So both `scope:actor` and `scope:target` are units; `.owner` gives the country, `unit_location` the location (`:3267-3269`).
- `on_siege_won` / `on_location_occupied`: root = the country gaining control; vanilla sub-hooks test `scope:target = { has_variable = ... }` and `NOT = { owns = scope:target }` (`on_country_specific_pulse.txt:102-108`). A character→unit scope link for `scope:character` was **not found** (UNVERIFIED); to reach armies on the spot use the location: `scope:target = { every_unit_in_location = { limit = { owner = root  is_army = yes } ... } }` (`every_unit_in_location` 10 uses, `random_unit_in_location` at `_hardcoded.txt:5906-5919`, `any_unit_in_location = { count >= 1 owner = root }` at `events/DHE/flavor_hol.txt:1048-1050`).

### 1.6 Firing on_actions and delayed events from effects (VERIFIED)

`trigger_event` **does not exist** in EU5 script (0 uses). The effects are `trigger_event_silently` and `trigger_event_non_silently` (1320 / 1732 uses). Forms seen:

```
trigger_event_silently = { id = X }                        # 179x
trigger_event_non_silently = { id = X days = N }           # 139x
trigger_event_silently = { id = X days = { N M } }         # random delay, 33x
trigger_event_silently = { id = X months = N } / { id = X years = { N M } }
trigger_event_non_silently = { id = X days = $DAYS$ }      # scripted-effect parameter
trigger_event_silently = { on_action = on_albanian_migration }                      # country_four_yearly.txt:40-42
trigger_event_silently = { on_action = chinese_expedition_event_pulse  days = 15 }  # events/expeditions/treasure_fleet_events.txt:102-104
trigger_event_silently = { on_action = maghrebi_location_conversion  months = { 0 48 } } # events/culture/culture_maghrebi.txt:2150-2152
```

The silent/non-silent difference is not documented in script; INFERRED: `_silently` suppresses the player-facing notification (vanilla uses it for hidden/AI bookkeeping, `_non_silently` for shown events). Delays inside on_action lists: `delay = { months = { 0 36 } } # A bit of jitter...` (`country_yearly.txt:56`), `delay = { days = { 30 80 } }` (`_hardcoded.txt:3740`).

---

## 2. Variables API (all VERIFIED unless marked)

Variables live on any scope object: country (everywhere), international organization (`var:papal_authority`, `country_monthly.txt:119-123`), situation (`situation:hussite_wars.var:...`, `_hardcoded.txt:1895`), war (`every_current_war = { ... set_variable = teu_lit_first_war }`, `_hardcoded.txt:181-187`), location (`scope:target = { has_variable = MLO_local_library }`, `on_country_specific_pulse.txt:104-106`), character, religion, expedition. **Unit (army) variables: UNVERIFIED** — every vanilla place that tracks something per army stores it on `owner` (`unit_abilities/promote_to_farari.txt:21-28`, `scripted_effects/unit_effects.txt:19-33`).

### 2.1 Scalar variables

```
in_game/common/on_action/country_monthly.txt:307-326
		if = {
			limit = { oligarchic_capture_qualifies_trigger = yes }
			if = {
				limit = { NOT = { has_variable = oligarchic_capture_months_qualifying } }
				set_variable = {
					name = oligarchic_capture_months_qualifying
					value = 0
				}
			}
			change_variable = {
				name = oligarchic_capture_months_qualifying
				add = 1
			}
		}
		else = {
			if = {
				limit = { has_variable = oligarchic_capture_months_qualifying }
				remove_variable = oligarchic_capture_months_qualifying
			}
		}
```

| Effect / trigger | Verified forms (file) |
|---|---|
| `set_variable` | `{ name = X value = 0 }`; `{ name = X value = yes }`; **expiry**: `{ name = recently_had_any_western_schism_event years = 8 }` (31×), `{ name = recent_order_service value = yes days = 1825 }` (16×), `{ name = unlock_achievement_hearts_and_minds months = 1 }` (`country_interactions/improve_cultural_view.txt:75-78`), `{ name = hre_got_religion_enforced value = yes days = 3 }` (`country_interactions/hre.txt:1926-1929`); **flag form** `set_variable = court_wants_free_trade` (`events/DHE/flavor_BYZ.txt:4350`, 978× overall) and `{ name = formed_tag_$tag$ }` (`scripted_effects/on_action_effects.txt:3`); **scope value** `{ name = relic_hunt_found_relic value = scope:recovered_relic }` (`scripted_effects/expedition_effects.txt:233`), `{ name = war_of_religion_current_war value = scope:war }` (`_hardcoded.txt:2545-2547`); **computed** `{ name = character_bonus_artist_skill value = this.random_integer }` (`scripted_effects/character_effects.txt:205`) and `value = { value = ... add = ... }` script-value blocks (`scripted_effects/country_effects.txt:1660-1666` for local vars). |
| `change_variable` | `{ name = X add = 1 }`, `{ name = opportunities subtract = 1 }` (34×). `multiply`/`divide` inside change_variable: **UNVERIFIED** (0 uses) — compute with a script value and `set_variable` instead. |
| `clamp_variable` | `{ name = morale min = 0 max = 100 }` (186×), `{ name = opportunities min = 0 max = 4 }`. |
| `round_variable` | `{ name = X nearest = 1 }` (`missions/generic_capital_economy_mission_pack.txt:547-550`, single use). |
| `remove_variable` | `remove_variable = X` (1880×). |
| `has_variable` | `has_variable = X` (4787×); `NOT = { has_variable = X }`. A value-comparing form of `has_variable` is **UNVERIFIED** (0 uses) — compare with `var:`. |
| `exists = var:X` | 183× e.g. `exists = var:succession_crisis_pretender_variable`. |
| comparisons | `var:gt_diligence >= 25` (144×), `var:phase = 2`, `var:current_ruler_power_variable < 100`, `var:io_law_target = scope:policy` (object equality), `var:x != ...`. Comparing a variable that does not exist: use `has_variable` first or `?=` (vanilla: `situation:hussite_wars.var:hussite_wars_current_war ?= scope:war`, `_hardcoded.txt:1895`). |
| in script values | `value = var:total_num_prov_variable`, `add = var:...`, `value = prev.var:holy_war_participation` (`scripted_effects/holy_war_effects.txt:50`), `scope:actor.owner.var:land_units_killed` (`_hardcoded.txt:3257`). |
| variable as scope | `var:union_of_crowns_partner = { remove_trust_equilibrium = { ... target = root } }` (`country_four_yearly.txt:266-271`), `var:active_war = { save_scope_as = hw_current_war }` (`scripted_effects/holy_war_effects.txt:33`), `global_var:wallensteins_prison ?= { has_siege = yes ... }` (`country_monthly.txt:217-226`). |
| chained | `scope:target.var:favored_in_country ?= { remove_list_variable = {...} }` (`character_death_pulses.txt:36-38`). |

Expiry (`days/months/years` on `set_variable`) is the cheapest cooldown primitive: the variable disappears by itself, `has_variable` becomes false — ideal for the stance hysteresis (`set_variable = { name = cw_stance_lock months = 2 }`).

### 2.2 Local variables (effect-chain scratch, INFERRED lifetime = current effect execution)

```
in_game/common/scripted_effects/country_effects.txt:1548-1553
			set_local_variable = { name = trigger_recipient_event value = $trigger_recipient_event$ }	#Yes/no
			if = {
				limit = { local_var:trigger_recipient_event = yes }
				save_scope_as = rivalling_country
				$target$ = { trigger_event_silently = historical_rival_events.1 }
			}
```

`set_local_variable` (101×), `change_local_variable` (48×), `has_local_variable` (18×), `local_var:` (153×), `add_to_local_variable_list` (31×), `is_target_in_local_variable_list = { name = X target = prev }`. Vanilla uses them to cache expensive computations once per effect (`country_four_yearly.txt:280-293`, "Optimization - ... Otherwise, we would need to calculate the same culture percentages per each location"). The on_actions.info note says locals set in an on_action `effect` do not reach events fired by it.

### 2.3 Global variables

`set_global_variable = galileo_spawned` (flag), `set_global_variable = { name = albanian_migration_cooldown years = 10 }` + `NOT = { has_global_variable = albanian_migration_cooldown }` (`country_four_yearly.txt:24`, `:36-39`), `remove_global_variable = wallensteins_prison`, `global_var:X` (83×), `has_global_variable` (145×). Global lists: `add_to_global_variable_list = { name = pope_countries target = this }`, `has_global_variable_list = wokou_nation_list`, `is_target_in_global_variable_list = { name = hacw_hook_list target = this }`, `global_variable_list_size` (loc-only, syntax UNVERIFIED).

```
in_game/common/on_action/_hardcoded.txt:14-21
		if = {
			limit = { NOT = { has_global_variable_list = pope_countries } }
			every_country = {
				limit = { has_reform = government_reform:papacy_reform }
				add_to_global_variable_list = { name = pope_countries target = this }
				#In case we need multiple papacies with antipopes and such
			}
		}
```

### 2.4 Variable lists (persistent object lists on a scope)

```
in_game/common/on_action/religious_order_conquest.txt:38-43, 53-73, 86
					scope:winner = {
						add_to_variable_list = {
							name = ro_conquest_candidates
							target = scope:candidate_location
						}
					}
...
				scope:winner = {
					any_in_list = {
						variable = ro_conquest_candidates
						count > 0
					}
				}
...
				ordered_in_list = {
					variable = ro_conquest_candidates
					order_by = {
						value = local_control
						multiply = population
					}
					max = 1
					save_scope_as = ro_conquest_location
				}
...
			clear_variable_list = ro_conquest_candidates
```

| Operation | Verified form |
|---|---|
| add | `add_to_variable_list = { name = X target = <scope> }` (33×) |
| remove one | `remove_list_variable = { name = mfa_war_participants target = PREV }` (`decisions/flavor_decisions_various.txt:858-861`) |
| clear | `clear_variable_list = X` (10×) |
| membership | `is_target_in_variable_list = { name = trade_company_regions target = root.region }` (`building_types/trade_company_buildings.txt:34-37`) |
| exists | `has_variable_list = trade_company_regions` (23×) |
| size | `any_in_list = { variable = X count > 0 }` (above); `variable_list_size` exists (loc-only, syntax UNVERIFIED) |
| iterate | `every_in_list = { variable = visited_ports  owner ?= { ... } }` (`scripted_effects/country_effects.txt:1849-1856`), `random_in_list = { variable = X  limit = { this != scope:y }  save_scope_as = z }` (`events/culture/culture_greek.txt:451-462`), `ordered_in_list` (above) |

Do not confuse with **temporary (unsaved) lists** created during one effect/trigger evaluation: `add_to_list = source` (`country_interactions/appanage_call_to_war.txt:55-57`), `list_size = { name = rival_male_children value > 0 }`, `any_in_list = { list = rival_male_children ... }`, `every_in_list = { list = X limit = {...} remove_from_list = X }` (`country_monthly.txt:273-293`), `ordered_in_list = { list = appanages_to_be_annexed_list order_by = country_economical_base save_scope_as = ... }` (`events/character/dynastic.txt:1575-1579`). `list =` → temporary list, `variable =` → persistent variable list.

---

## 3. Control flow (VERIFIED)

| Construct | Verified example |
|---|---|
| `if / else_if / else` with `limit` | `country_monthly.txt:118-151` (papal authority ≥75 / <25 / else). |
| `switch` | `switch = { trigger = $location$  location:constantinople = { ... }  location:rome = { ... } }` (`scripted_effects/country_effects.txt:2947-2960`); `switch = { trigger = var:pilgrimage_holy_site.god  god:viracocha = { add_yanantin = -20 } ... }` (`religious_effects.txt:611-619`). Cases are object keys compared with the `trigger` value. |
| `while` | `while = { limit = { var:is_gathering_acllas > 0 }  change_variable = { name = is_gathering_acllas add = -1 } ... }` (`cabinet_actions/gather_acllas.txt:37-43`); `while = { count = 3  region:great_britain_region = { random_location_in_region = {...} } }` (`decisions/flavor_decisions_eng.txt:902-908`). |
| `random_list` | weights `1 = { set_personality = ... }` (`ai_personalities_setup.txt:21-29`); per-entry `modifier = { add = 20  scope:expedition = { var:morale >= 70 } }` (`events/expeditions/cape_route_to_india_events.txt:872-876`); `modifier = { factor = { value = 1 add = modifier:german_migration_attraction_modifier } }` (`country_four_yearly.txt:81-94`); per-entry `trigger = { current_age_or_later = { age = age_4_reformation } }` (`events/DHE/flavor_BYZ.txt:4348-4355`); empty entry `100 = {}`. |
| `random = { chance = N }` | `random = { chance = 50  trigger_event_non_silently = { on_action = four_yearly_country_pulse_50_percent } }` (`country_four_yearly.txt:67-72`); chance as script value `chance = { value = scope:target_leader.adm divide = 10 }` (`scripted_effects/expedition_effects.txt:394-397`). |
| `ordered_*` | `ordered_army = { limit = {...} order_by = num_subunits max = 1 check_range_bounds = no save_scope_as = target_army add_unit_modifier = {...} }` (`generic_actions/parliament.txt:1262-1272`); `position = 1` (`events/character/artist_events.txt:2579-2582`), `position = 0` (`flavor_dah.txt:187-189`); `max = { value = num_provinces divide = 4 ceiling = yes }` (`events/DHE/flavor_brapru.txt:760-768`); several `order_by` lines as tie-breakers (`scripted_effects/00_event_illustration_effects.txt:82-89`). |
| `every_* / random_*` | `limit = { ... }` everywhere; `random_pop = { weight = { base = 1 modifier = { add = pop_character_chance ... } } }` (`00_event_illustration_effects.txt:250-254`). `count = N` on `every_*`: **UNVERIFIED** (0 uses) — use `ordered_* = { max = N }`. |
| `any_*` counting | `any_army = { count > 3  owner = root  unit_location = {...} }` (`events/DHE/flavor_ENG.txt:22838-22844`); `any_sub_unit = { sub_unit_type = $sub_unit_type$ count = all }` (`scripted_effects/unit_effects.txt:41`); `calc_true_if = { any_unit = { is_army = yes }  amount >= 2 }` (`country_interactions/lend_unit_to_ally.txt:184-187`). |
| `trigger_if / trigger_else_if / trigger_else` | `owner = { trigger_if = { limit = { has_variable = mandekalu_exp } var:mandekalu_exp >= 150 } trigger_else = { has_variable = mandekalu_exp } }` (`unit_abilities/promote_to_farari.txt:21-28`); 1036 / 54 / 596 uses. `NOR` 633×, `NAND` 89×. |
| `?=` (null-safe scope) | `scope:winner ?= root` (`_hardcoded.txt:2043`), `ruler ?= { has_character_modifier = ... }` (`:2400`), `union ?= { ... }`; 13 278 uses. |
| `custom_tooltip` | one-liner `custom_tooltip = KEY` (3751×) inside triggers; block `custom_tooltip = { text = turn_japanese_clan_into_normal_tag.tt  if = {...} }` (`scripted_effects/country_effects.txt:755-760`) wraps effects under one tooltip line; `custom_description = { text = ... object = ... }`. |
| `hidden_effect` / `hidden_trigger` | `hidden_effect = { add_country_modifier = { modifier = fc_treatyconference_timer years = 10 } }` (`_hardcoded.txt:1674-1678`); `trigger = { hidden_trigger = { is_ai = no } }` (15×). |
| `save_scope_as` / `save_temporary_scope_as` | `save_scope_as = candidate_location` (`religious_order_conquest.txt:26`); `save_temporary_scope_as = target_clan` (`country_effects.txt:763`), 358× — temporary scopes exist only for the current effect evaluation (INFERRED from name). |
| cooldowns | `add_cooldown = { type = ai_spam_protection years = 4 }` (`_hardcoded.txt:61-64`), `add_cooldown = { type = ai_spam_protection days = { 1 1460 } }` (`country_four_yearly.txt:61-64`), `add_cooldown = { type = convert_religion years = 10 }` (`country_effects.txt:2825-2828`); `has_cooldown = join_a_league` (96×; also usable inside script values, `script_values/diplomatic_values.txt:3-9`); `remove_cooldown` (3×). The `type` is a free-form key — **no cooldown definition folder exists** (VERIFIED by absence). |
| AI/player tests | `is_ai = yes/no` (232×, e.g. `every_country = { limit = { is_ai = yes } ... }` `ai_personalities_setup.txt:15-16`); `is_human = yes/no` (87×, `country_interactions/improve_cultural_view.txt:71`). **`is_player` and `is_local_player` do not exist** (0 uses). |
| game rules | `has_game_rule = ai_personalities_random` tests a setting **flag**, not the setting name (`main_menu/common/game_rules/*.txt:467-481`: several settings share `flag = ai_personalities_random`). |

---

## 4. War-related triggers, scopes and strength comparisons (country scope unless stated)

### 4.1 Being at war

- **`at_war = yes/no`** (1108×). `is_at_war` **does not exist** (0 uses) — the SPEC's `is_at_war = yes` must become `at_war = yes`.
- `is_at_war_with = root` / `= scope:actor` / `= c:ENG` (400×): `_hardcoded.txt:1877-1882` `limit = { has_ruler = yes  is_at_war_with = ruler.employer }`.
- `has_truce_with = X` (215×), `is_enemy_of = X` (diplomatic "enemy" stance, 146×), `is_fighting_war_together_with = X` (21×), `is_in_defensive_war = yes` (10×), `is_in_losing_war = yes` (4×), `months_since_war > 12` (23×), `months_since_peace > 60` (4×), `war_exhaustion >= 5` (many), `in_civil_war`, `lowest_war_score < 0` (country, lowest score over all current wars):

```
in_game/common/country_interactions/appanage_request_levies.txt:63-68
			scope:actor = {	
				at_war = yes
				lowest_war_score < 0
				max_manpower > 0
				manpower_percentage < 0.1
			}
```

**Pitfall:** `any_enemy = { ... }` iterates the *diplomatic* enemy list, not war enemies — vanilla uses it with `at_war = no` (`disasters/time_of_troubles.txt:115-118`). War enemies are iterated with `any_country_at_war_with` / `every_country_at_war_with` / `random_country_at_war_with`:

```
in_game/common/cabinet_actions/byz_extensive_conscription.txt:8-10
		any_country_at_war_with = {
			religion.group != root.religion.group
		}
in_game/common/country_interactions/appanage_call_to_war.txt:55-57
				every_country_at_war_with = {
					add_to_list = source
				}
in_game/common/generic_actions/war_of_the_roses_actions.txt:56-57
				random_country_at_war_with = {
					limit = { is_rebel_country = yes }
```

Allies-in-war side: `any_country_together_in_war_with` (`_hardcoded.txt:5909`, single use; syntax otherwise UNVERIFIED), `is_fighting_war_together_with`.

### 4.2 War scope (`any_current_war`, `every_current_war`, `random_current_war`; `ordered_current_war` UNVERIFIED)

```
in_game/common/on_action/_hardcoded.txt:1903-1912
				scope:war = {
					is_a_defender = root
					defender_leader = {
						this != root
						is_member_of_international_organization = international_organization:hre
					}
					attacker_leader = {
						NOT = { is_member_of_international_organization = international_organization:hre }
					}
				}
in_game/common/on_action/_hardcoded.txt:181-187
			every_current_war = {
				limit = {
					c:LIT = {
						is_war_leader_of = prev
					}
				}
				set_variable = teu_lit_first_war
in_game/common/scripted_triggers/disaster_triggers.txt:248-251
				any_current_war = {
					is_civil_war_for = root
					attacker_leader ?= { rebel_category = pretender }
				}
```

War-scope triggers (from `trigger_localization/war_triggers.txt`, usage counts in brackets): `is_in_war = <country>` [24], `is_a_defender = <country>` [27], `is_an_attacker = <country>` [41], `is_no_cb_war` [29], `is_civil_war_for = <country>` [13], `can_join_as_attacker/defender = <country>`, `casus_belli ?= casus_belli:x` [35], `war_goal_type = superiority` [116], `war_length` (months, used in script values `value = scope:war.war_length`, `casus_belli/crusade_cb.txt:75`), `war_length_in_years > 4` (`generic_actions/hundred_years_war.txt:121-124`), `war_stalling_length(_in_years)` (loc-only), `land_war_*_casualties` / `navy_war_*_casualties` (loc-only), `war_score_of_country = { country = scope:actor value < 0 }` (`generic_actions/religious_orders.txt:308-312`), `war_score_in_war` (data function), `is_on_same_side = { country = root target = c:JAL }` (`events/DHE/flavor_ERE.txt:58`), `is_on_opposite_sides = { ... }`, `attackers_have_access_in` / `defenders_have_access_in`. Scope links: `attacker_leader`, `defender_leader` (used both as link `attacker_leader = { ... }` and comparison `attacker_leader = c:BOH`, `scripted_effects/situation_effects.txt:1553-1558`), `any_attacker / every_attacker / any_defender / every_defender` (`scripted_triggers/country_triggers.txt:937-953`), `any_war_participant / every_war_participant` (`_hardcoded.txt:2542`), `war_leader = { ... }` (2×). Country-side: `is_war_leader_of = <war>` (`generic_actions/red_turban_rebellions.txt:958`), `is_leading_largest_army_of = root`.

War-score data functions in script values (strings, VERIFIED): `"scope:recipient.war_score_in_war(scope:target)"` (`country_interactions/hre.txt:1837`), `"scope:actor.war_score_versus(scope:target.attacker_leader)"` (`generic_actions/guelphs_and_ghibellines.txt:504`), `"scope:war.war_score_of_country(scope:actor)"` (`religious_orders.txt:318`). `war_score`, `warscore`, `ticking_war_score` are **modifier/CB keys**, not triggers.

### 4.3 Strength comparison (what the "war stance" needs)

| Trigger | Verified usage |
|---|---|
| `relative_military_strength = { target = X value < 0.5 }` | `country_interactions/lend_unit_to_ally.txt:179-182`; `generic_actions/hundred_years_war.txt:1379-1382`. Loc (`RELATIVE_STRENGTH_TRIGGER`): "Has $COMPARATOR$ $NUM% of the total combined strength of them and [TARGET]" → 0.5 = equal, >0.5 = we are stronger. |
| `relative_strength = { target = X value > 0.5 }` | `country_interactions/italian_league_sponsor_interactions.txt:195-198` (58×; INFERRED: overall strength incl. economy, while `relative_military_strength` is military-only). |
| `military_strength < scope:actor.military_strength` | 6×; numeric, comparable across scopes. |
| `army_size > 0` (men in the army, loc "Has … men in the Army") | 28×; `regular_army_size > 0` (11×), `expected_army_size > 20` (23×), `army_size_percentage < 0.50` (10×), `potential_army_size < X` (3×), `navy_size > root.navy_size`. |
| `max_manpower > 0.5`, `manpower_percentage < 0.1`, `manpower` | many. |
| `num_regiments > 0` | `generic_action_ai_lists/military_list.txt:3` (2×). |
| `total_sub_unit_type_count:<unit_type_key>` | `total_sub_unit_type_count:a_mamluk_unit_renaissance > 0` (`events/DHE/flavor_MAM.txt:1349`); in script values `value = total_sub_unit_type_count:a_farfanes  divide = army_size` (`government_reforms/country_specific.txt:1969-1971`). **This is the country-wide HQ counter** (`total_sub_unit_type_count:cw_hq`). |
| `strength_vs_overlord`, `country_strength`, `io_total_military_strength`, `defensive_alliance_strength`, `offensive_alliance_strength`, `total_enemies` | exist (trigger_localization) but no script usage → syntax UNVERIFIED (probably `total_enemies > N`). |
| `has_unit = no` | is a **character** trigger (`character_interactions/grant_cabinet_right.txt:58`), not a country one. |

Armies and regiments:

```
in_game/common/generic_actions/parliament.txt:1262-1272
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
in_game/common/scripted_effects/unit_effects.txt:1-10
#root = unit
grant_special_unit_experience = {
	if = {
		limit = {
			any_sub_unit = {
				OR = {
					sub_unit_type = unit_type:a_mandekalu_infantry
					sub_unit_type = unit_type:a_mandekalu_cavalry
				}
			}
		}
```

Country→unit iterators: `every_army` (`events/colonization/conquistador.txt:108-110`), `any_army` (13×, with `count >`), `random_army`, `ordered_army` (4×), `any_unit = { is_army = yes }`, `every_unit`, `ordered_unit`; location→unit: `every_unit_in_location`, `any_unit_in_location = { count >= 1 owner = root }`, `random_unit_in_location = { limit = { owner ?= scope:target.owner } }` (`_hardcoded.txt:5916-5919`); siege→unit: `any_besieging_unit` (`country_monthly.txt:218-224`). Unit-scope triggers (`trigger_localization/unit_triggers.txt`): `is_army`, `is_moving`, `is_movement_locked`, `in_combat`, `in_retreat`, `in_siege` (`events/DHE/flavor_dan_corfitz_ulfeldt.txt:240-243` with `unit_location.owner = c:DAN`), `has_commander`, `num_subunits`, `sub_unit_count`, `sub_unit_fraction`, `sub_unit_strength`, `strength_percentage`, `morale_percentage`, `has_unit_modifier = X`, `has_levies`, `has_regulars`, `has_mercenaries`, `is_exiled`; links `owner`, `unit_location`. Sub-unit scope: `sub_unit_type = unit_type:x`, `sub_unit_category = sub_unit_category:army_auxiliary`, `is_regiment`, `is_levy`, `is_mercenary`, `subunit_strength`. Unit effects: `add_unit_modifier = { modifier = X days/years = N mode = replace|add_and_extend  [size = {script value}] }` (`events/government/D008_latinization_vs_hellenization.txt:413-417`), `remove_unit_modifier = X`, `add_subunit = unit_type:a_feudal_levy` (unit scope, `events/debug/000_johan_debug.txt:419`), `destroy_subunit = yes` (sub-unit scope), `destroy_unit = yes`, `create_sub_unit_of_category = sub_unit_category:army_heavy_infantry` (location scope, `tutorial_lessons/00_tutorial_lesson_military.txt:46-48`), `create_sub_unit_with_owner = { type = a_pikemen owner = scope:target_country }` (location scope). Permanent unit modifier: `days = -1` is the vanilla convention for country/religion/character modifiers (`country_monthly.txt:124-128`, 150+ uses) and the loc key `ADD_UNIT_MODIFIER_FOREVER` exists — INFERRED to work for `add_unit_modifier` too.

### 4.4 Recipe: our strength vs. the enemies of our most important war (INFERRED assembly of VERIFIED parts)

```
# country scope (AI), run from cw_monthly_pulse when at_war = yes
ordered_current_war = { ... }   # UNVERIFIED -> use random_current_war/every_current_war with a limit instead
every_current_war = {
	limit = { NOT = { is_civil_war_for = root } }
	save_temporary_scope_as = cw_war
	# enemy leader of this war
	if = {
		limit = { is_an_attacker = root }
		defender_leader = { save_scope_as = cw_enemy_leader }
	}
	else = { attacker_leader = { save_scope_as = cw_enemy_leader } }
}
if = {
	limit = { relative_military_strength = { target = scope:cw_enemy_leader value >= 0.55 } }   # ~1.2x
	set_variable = { name = cw_stance value = 1 }
}
else_if = {
	limit = { relative_military_strength = { target = scope:cw_enemy_leader value <= 0.33 } }   # <=0.5x
	set_variable = { name = cw_stance value = 4 }
}
```

(0.55 ≈ ours/(ours+theirs) for 1.2:1; 0.33 ≈ 1:2. `war_score_of_country = { country = root value < -10 }` and `war_exhaustion >= 5` are the verified "losing" signals; `months_since_war` is not a per-war length — use `war_length_in_years` inside the war scope.)

---

## 5. Performance: how vanilla limits per-tick work, and a schedule for the mod

### 5.1 Vanilla evidence

```
in_game/common/on_action/country_yearly.txt:5-7, 20-21, 933-935
		# Narrow-condition events moved out of events = {} to avoid universal trigger eval.
		# Each sub-on-action has a cheap outer trigger that skips the event entirely for
		# the ~295+ countries that can never satisfy it.
	# Tag-locked events — mutually exclusive, so first_valid_on_action pays at most one tag
	# check per non-matching country instead of evaluating all three event triggers.
# Each has a cheap top-level trigger so the engine skips the entire block (and the enclosed
# event trigger) for every country that cannot possibly satisfy the condition.
in_game/common/on_action/country_four_yearly.txt:67-79
		random = {
			chance = 50
			trigger_event_non_silently = {
				on_action = four_yearly_country_pulse_50_percent
			}
		}

		random = {
			chance = 25
			trigger_event_non_silently = {
				on_action = four_yearly_country_pulse_25_percent
			}
		}
```

- `_50_percent` / `_25_percent` sub-on_actions (`country_four_yearly.txt:213-249`) exist purely so that rarer flavor lists are only evaluated for a random half/quarter of the countries each pulse — a random split, not a deterministic schedule.
- Monthly `random_events` use `chance_to_happen = 5` (`country_monthly.txt:40`) and `8` ("monthly pulse, so on average maybe 1 event a year", `country_pulse_for_high_infamy.txt:20`); yearly `50`, biyearly `25`; `sample_count = 1..3` caps draws; `chance_of_no_event = { value = 50 }` (`colonial_charter_monthly.txt:21-23`).
- Heavy checks are moved to the four-yearly pulse: "it is on a 4 year check on purpose as it is a heavy check and should only touch on countries with the union of crowns inheritance" (`country_four_yearly.txt:252`).
- Expensive triggers are gated behind `is_ai = no` when only players need them: `events/culture/culture_maghrebi.txt:1490` "is_ai = no # Below trigger might be a bit too performance heavy"; `_hardcoded.txt:4153` "Only relevant for humans, purely informational, dont trigger event for all AI princes".
- Script-value formulas "have to be calculated every single time they're evaluated. Complex formulas can be performance intensive." (`script_values/_script_values.info:14`). Vanilla caches intermediate values in local variables (`country_four_yearly.txt:280-293`).
- `every_country` loops appear in on_actions only at `on_game_start` and in rare, event-driven hooks (`on_military_annex`, `on_annexed`, `on_religion_changed`, `on_location_changed_owner` — and the last one is really `every_country_in_religion` gated by `this = location:rome`, `_hardcoded.txt:4986-5002`). **Never** in a monthly pulse.
- Location pulses touch "one random location each month" (`location_pulses.txt:22`) rather than all ~30k locations.
- `events = { ... }` entries in a pulse evaluate every listed event's trigger for every country every pulse; that is why vanilla pushed narrow events into sub-on_actions with a cheap `trigger`.

### 5.2 Cost model for the mod (INFERRED from the above)

- `monthly_country_pulse` → `cw_monthly_pulse` runs ~300× per month. With `trigger = { is_real_country = yes }` the non-real countries cost one trigger each.
- Inside, `every_army = { ... }` costs one iteration per army in the world (a few hundred to ~1000 late game); testing `any_sub_unit = { sub_unit_type = unit_type:cw_hq }` per army is a linear scan of its regiments — cheap, but `every_army = { every_sub_unit = {...} }` doubles the nesting; avoid applying modifiers that are already present (`NOT = { has_unit_modifier = cw_no_hq }` guard) because `add_unit_modifier … mode = replace` every month on every army is pure churn.
- Country-wide counts should use `total_sub_unit_type_count:cw_hq` (one engine call) instead of script loops.
- Stance evaluation (`relative_military_strength` against a few countries) is cheap; war-scope loops (`every_current_war`) are small lists.
- Anything that must look at *other* countries' armies (e.g. enemies' stacks near ours) should be event-driven (`on_battle_*`, `on_siege_won`) rather than scanned monthly.

### 5.3 Recommended schedule

```
cw_monthly_pulse = {
	trigger = { is_real_country = yes }
	effect = {
		# 1. always (cheap): cached counters for the GUI
		cw_cache_limits = yes                       # set_variable cw_hq_limit_v / cw_hq_count_v via total_sub_unit_type_count:cw_hq

		# 2. at war: full monthly work
		if = {
			limit = { at_war = yes }
			cw_update_army_organization = yes       # every_army with has_unit_modifier guards
			if = {
				limit = { is_ai = yes }
				cw_ai_assign_hqs = yes
				cw_update_war_stance = yes          # only if NOT has_variable = cw_stance_lock (set with months = 2)
			}
			else = { cw_update_player_enemy_stance = yes }
		}
		# 3. at peace: quarterly, staggered per country so the work does not spike in one month
		else = {
			if = {
				limit = { NOT = { has_variable = cw_peace_cooldown } }
				set_variable = { name = cw_peace_cooldown months = 3 }   # expiry = quarterly cadence, no counter needed
				cw_update_army_organization = yes
				if = { limit = { is_ai = yes } cw_ai_assign_hqs = yes }
				if = { limit = { has_variable = cw_stance } remove_variable = cw_stance }
			}
		}
	}
}
```

Why this shape: `at_war` and `has_variable` are O(1); the `months = 3` expiry gives a per-country quarterly cadence that is automatically staggered (each country's timer starts the first month it is at peace), unlike `current_month = 1/4/7/10`, which would run every peaceful country in the same tick. The first run after a war ends happens immediately (no cooldown variable yet), which is desirable. If a deterministic phase is preferred, `script_values` support `modulo` (`_script_values.info:25`) and `current_month` (18 uses) exist.

Event-driven supplements (all hooks VERIFIED to exist and merge):

- `on_war_declared` / `on_join_war`: on `scope:actor`, `scope:recipient` and `root` run `cw_update_army_organization` once (guard with a short-expiry variable so a declaration involving many participants does not re-run per participant) and clear `cw_peace_cooldown`.
- `on_battle_won` / `on_battle_lost`: re-check only `scope:actor` and `scope:target` (units) — no loops.
- `on_siege_won` / `on_location_occupied`: `scope:target = { every_unit_in_location = { limit = { owner = root } ... } }`, i.e. only the stack that just took the location.
- `on_ending_war`: cleanup for `root` (runs once per side); remove `cw_stance*` when `at_war = no`.
- `on_new_age`: recompute the age slot limit for `root`; `on_game_started_after_lobby`: `every_country = { limit = { is_real_country = yes } cw_initial_hq = yes }` — a one-off loop, which is exactly how vanilla uses `every_country` (`_hardcoded.txt:54-56`, `ai_personalities_setup.txt:15-16`).
- A 7-day self-refiring hidden event per country at war (SPEC "weekly war ticker") is feasible (`type = country_event  hidden = yes  title/desc = empty_text` pattern, `events/ai_area_conqest_events/hidden_events_for_ai_conquest.txt:4-11`; `trigger_event_silently = { id = X days = 7 }`), but it multiplies the monthly cost ×4 for every warring country and risks duplicate chains. Prefer 30-day monthly work plus the event-driven hooks above; if a ticker is kept, guard it with `set_variable = { name = cw_tick_scheduled days = 6 }` + `NOT = { has_variable = cw_tick_scheduled }` in the event trigger and 14–15 days instead of 7.

---

## 6. Pitfalls

1. **Folder name is `on_action` (singular).** Cheat Menu Pro also ships an `in_game/common/on_actions/` folder whose only file contains the comment `#我删除了` ("I deleted") — treat the plural folder as not loaded (UNVERIFIED either way; vanilla only has `on_action`).
2. **Same key = merge, not override.** Redeclaring `monthly_country_pulse = { on_actions = { cw_monthly_pulse } }` adds to vanilla. Do **not** copy vanilla bodies into the mod; do not add `trigger = {}` / `effect = {}` / `events = {}` directly under a vanilla key (merge behaviour for those blocks is unverified) — put them in `cw_*` sub-on_actions.
3. **Global namespace.** All on_action keys share one namespace across all files; a `cw_` prefix avoids accidentally merging into a vanilla or other-mod on_action.
4. **`events = {}` lists evaluate every event trigger for every country** every pulse; keep mod logic in `effect = {}` behind a cheap on_action `trigger`.
5. **Effects and events fired by the same on_action run concurrently**; variables set in the `effect` block are not reliably visible to events fired from the same on_action (`on_actions.info:51`). Fire follow-up events from inside the effect instead.
6. **Delayed entries are re-validated when the delay ends** — an event with `days = N` may silently not fire if its `trigger` became false.
7. **Wrong trigger names in the SPEC:** `is_at_war` → `at_war`; `is_player` → `is_ai = no` (or `is_human = yes`); `trigger_event` → `trigger_event_silently` / `trigger_event_non_silently`; `count = N` on `every_*` is unverified (use `ordered_*` + `max`); `has_unit` is a character trigger.
8. **`any_enemy` is the diplomatic enemy list**, not war enemies (`every_country_at_war_with` is).
9. **`war_score`/`warscore` are not triggers**; use `lowest_war_score` (country), `war_score_of_country = { country = X value < N }` (war scope) or the data functions `war_score_in_war(war)` / `war_score_versus(country)` in script values.
10. **Unit-scope variables are unverified.** Track per-army state through unit modifiers (`has_unit_modifier`) or on the owner (vanilla pattern); `add_unit_modifier … mode = replace` with `days = 45` is self-expiring, so a missed month degrades gracefully.
11. **`on_ending_war` fires once per side; `on_war_declared` root is ambiguous** (no vanilla comparison of root vs scope:actor) — write idempotent effects keyed on `scope:actor`/`scope:recipient`.
12. **`monthly_country_pulse` includes non-real countries** (vanilla filters with `is_real_country = yes`); rebels/pirates must be excluded explicitly or they will get HQ bookkeeping (and the DESIGN says they must not be penalised).
13. **`has_game_rule` tests flags**, so a rule with three settings sharing a flag cannot be distinguished by that flag — give each setting its own flag.
14. **Cooldown `type` keys are free-form**; a typo creates a new, never-set cooldown and `has_cooldown` is silently false.
15. **Variable-list iteration uses `variable =`; temporary lists use `list =`**; mixing them yields an empty loop with no error.
16. Files must be UTF-8 **with BOM** like vanilla script (`country_monthly.txt:1` is a BOM-only line); the `error.log` of this session shows only localization duplicates for the workshop mods, i.e. no on_action errors to copy from.

---

## 7. Recommendations for the mod

1. **Hook file** `in_game/common/on_action/cw_on_actions.txt` exactly as in §1.5: ten vanilla keys, each containing only `on_actions = { cw_* }`; all logic in `cw_*` on_actions with cheap `trigger` blocks and scripted effects in `cw_effects.txt`.
2. **Schedule** (§5.3): monthly for countries at war (organization + AI HQ assignment + stance), quarterly-staggered via `set_variable = { name = cw_peace_cooldown months = 3 }` at peace, plus event-driven updates on `on_battle_won/lost` (two units), `on_siege_won`/`on_location_occupied` (units in `scope:target`), `on_war_declared`/`on_join_war`/`on_ending_war` (participants), `on_new_age` (limits), `on_game_started_after_lobby` (one-off `every_country`).
3. **Counters**: `total_sub_unit_type_count:cw_hq` / `:cw_hq_colonial` for country-wide HQ counts (no loops); cache into `cw_hq_count_v` etc. with `set_variable` for the GUI; `any_sub_unit = { sub_unit_type = unit_type:cw_hq }` per army; largest army via `ordered_army = { order_by = num_subunits max = 1 check_range_bounds = no }`.
4. **Per-army state** = unit modifiers only (`cw_no_hq` with `days = 45 mode = replace`, `cw_expeditionary` likewise), re-applied by the monthly/event passes; never rely on unit variables.
5. **Stance** stored as `var:cw_stance` (0–4) on the AI country with hysteresis via `set_variable = { name = cw_stance_lock months = 2 }`; the player's mirror `cw_enemy_stance` computed from `every_current_war` → `attacker_leader`/`defender_leader` (§4.4); comparisons through `relative_military_strength = { target = X value … }`, `war_score_of_country`, `war_exhaustion`, `war_length_in_years`.
6. **Use `?=`** for every scope that may be null (`scope:winner ?= root`, `var:x ?= {}`), and `has_variable` before `var:` comparisons.
7. **Keep `every_country` out of monthly work**; if a global sweep is ever needed, split it like vanilla (`random = { chance = 25 }` → sub-on_action) or spread it over `cw_peace_cooldown`.
8. **Testing hooks**: the structure above can be validated in-game with a debug decision that fires `trigger_event_silently = { on_action = cw_monthly_pulse }` on demand (`country_four_yearly.txt:40-42` pattern), and `error.log` must stay free of "Unknown trigger/effect" lines after the first month.
