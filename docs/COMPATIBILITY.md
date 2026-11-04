# Compatibility — New Intelligence: Battle v0.1 (EU5 1.4.7)

The mod was renamed from "Concentrated Warfare" (internal key prefix `cw_`, kept) to **"New Intelligence: Battle"** (collection "New Intelligence"). Mod root: `mods/new_intelligence_battle` in the repo `EU5-NewIntelligence`; junction `Documents/Paradox Interactive/Europa Universalis V/mod/new_intelligence_battle`. The mount-order evidence in §0 was recorded before the rename, under the old junction name `mod/concentrated_warfare`.

Audit date 2026-11-04. Scope: (A) the two workshop mods installed on this machine, (B) what breaks on a game patch and how to re-merge.
Tags: **VERIFIED** = read from files/logs on this machine (cited `file:line`), **INFERRED** = follows from verified facts + documented engine rules, **UNVERIFIED** = not testable without running the game or installing something.
Paths: `G` = `/c/Program Files (x86)/Steam/steamapps/common/Europa Universalis V/game`, `W` = `/c/Program Files (x86)/Steam/steamapps/workshop/content/3450310`, mod root = `mods/new_intelligence_battle` in this repo (junction `Documents/Paradox Interactive/Europa Universalis V/mod/new_intelligence_battle`); `in_game/…` / `main_menu/…` paths are relative to the mod root, `tools/…` and `docs/…` to the repo root.

## 0. Verdict

| Mod | File-level conflict | Script-key conflict | GUI conflict | Gameplay interaction | Load-order rule |
|---|---|---|---|---|---|
| Cheat Menu Pro (`sakuya` 1.7.0) | none | none | none (different layer corner, no shared type names) | cheat modifiers can mask our penalties; army generator spawns HQ-less armies | CW below (after) it |
| Simple Cheats (`mshp.simple_cheats` 1.0) | none with CW; its own `panels/left_panel.gui` is stale/mis-pathed | none | one shared type name (`stat_player_button`), identical body today | `sc_siege_ability` +10 % only | CW below (after) it |
| Vanilla patch | the 2 full-file overrides must be re-merged; partial defines/on_action appends survive unless keys are renamed | — | vanilla templates we `using =` may change | — | see §5 |

Environment (VERIFIED): game 1.4.7, hash `47c12bd63e`, branch `ud009/release/next`, built 2026-10-29 (`logs/code_revisions.log` `jomini_game_setup.cpp:162-165`); `logs/debug.log` `dlc_reloadable.cpp:390`: "Mod Cheat Menu Pro (sakuya) version 1.4.* successfully matched game version 1.4.7". Mount order in the last launch (debug.log `virtualfilesystem_physfs.cpp:596`, 2026-11-04 12:14): vanilla → `3600272327` → `3634102315` → `mod/concentrated_warfare` (the pre-rename junction, now `mod/new_intelligence_battle`; we load last = highest precedence). `playsets.json`: active playset "1" contains only Cheat Menu Pro; "Initial playset" has both cheat mods; both have `isAutomaticallySorted: true`, so the launcher may reorder — check the Mounted Data lines after every launcher change.
Only these two workshop mods are installed; Cheat Menu Pro's declared dependency `community_mod_framework 2.*` (`W/3600272327/.metadata/metadata.json` relationships) is **absent** (debug.log `jomini_effect.cpp:557`: `Unknown effect cmm_register_button_setting at common/scripted_effects/sakuya_cmm_sittings_cmm_effects.txt:3`) — the game tolerates it.

## 1. Our footprint (what can collide at all)

| Kind | Files / keys | Collision rule |
|---|---|---|
| Full-file overrides (VERIFIED: the only two mod paths that exist in `G/`) | `in_game/gui/single_unit_window.gui`, `in_game/common/location_ranks/00_default.txt` | same path in another mod = one of them loses entirely (lower in playlist wins, research 09 §3.1 [V-WEB]) |
| Partial defines | `loading_screen/common/defines/cw_ai_defines.txt` (NAI, 26 keys), `cw_war_defines.txt` (NWar, 10 keys) | per key, "the mod with the last loaded filename determines the final value" (research 09 line 189 [V-WEB]); partial override itself is UNVERIFIED in EU5 (TESTING.md E1) |
| On_action appends (`on_actions = { cw_* }` only) | 12 vanilla keys: `monthly_country_pulse`, `on_game_started_after_lobby`, `on_new_age`, `on_war_declared`, `on_join_war`, `on_ending_war`, `on_battle_won`, `on_command_gained`, `on_revolt_start`, `on_civil_war_start` (`in_game/common/on_action/cw_on_actions.txt:13-50`; `on_battle_lost` is deliberately not hooked), `monthly_country_pulse`/`on_war_declared`/`on_join_war`/`on_ending_war` again (`cw_stance_on_actions.txt:11-24`), `on_siege_won`, `on_location_occupied` (`cw_warscore_on_actions.txt:12-17`) | same-key on_action lists MERGE (research 04 §1.4, VERIFIED by vanilla structure) → never conflicts with other mods that also only append |
| New database keys | everything else is `cw_` (static modifiers 9, scripted GUIs 14 `cw_sgui_*`, unit types 2, prices 6, goods demand 2, decisions 2, auto modifier 1, subject stance 1, game rules 5, concepts 3, hint `hint_cw_army_without_hq`, events `cw_events`/`cw_tick`/`cw_stance`) | first definition wins, duplicates are dropped (research 09 line 183 [V-FILE]) → only a mod using the `cw_` prefix can collide |
| GUI | scripted-widget registry `in_game/gui/scripted_widgets/cw_scripted_widgets.txt` → windows `cw_war_stance_plate`, `cw_hq_overview_window`; own types `cw_hq_army_row`, `cw_hq_counter`, `cw_ov_number_text`, `cw_stance_state` | registry names and `type`/`template` names are global, "last one loaded wins" (research 09 line 187 [V-WEB]) |
| Localization | `main_menu/localization/{russian,english}/cw_*_l_*.yml`, all keys `cw_`/`CW_` | no `replace/` folder used → cannot override anyone, cannot be overridden |

## 2. Cheat Menu Pro (`W/3600272327`, "sakuya", v1.7.0, `supported_game_version` 1.4.*)

Ships (VERIFIED file list): `in_game/common/{biases,character_interactions,country_interactions,culture_groups,cultures,customizable_localization,generic_actions,languages,on_action,on_actions,scripted_effects,scripted_relations,scripted_triggers}`, `in_game/events/sakuya_*.txt`, 20 `in_game/gui/sakuya_*.gui` + `gui/shared/sakuya_types.gui`, registry `in_game/gui/scripted_widgets/sakuya_scripted_windows.txt` (18 windows), `main_menu/common/scripted_guis/*.txt` (23 700 keys), `main_menu/common/static_modifiers/*.txt` (934 keys), gfx, localization in 10 languages. No `loading_screen/`, no `unit_types`, `location_ranks`, `game_rules`, `defines`, `on_action` logic under vanilla keys, no `REPLACE:`/`INJECT:` anywhere (VERIFIED grep).

| Check | Result |
|---|---|
| Overrides a vanilla file by path | **none** (VERIFIED: every mod path tested against `G/`) |
| Touches our two overrides | no |
| `cw_`/`CW_` strings anywhere (txt/gui/yml, case-insensitive) | **0 hits** (VERIFIED) |
| Static modifier keys | all `sakuya_*`/`rch_*` (VERIFIED: 934 keys, none without prefix) |
| Scripted GUI keys | all `sakuya_*`/`rch_*`; one internal duplicate of its own (`sakuya_loc_mod_prosperity_ctrl_left`, debug.log `gamedatabase.h:409`) — not ours |
| On_action hooks | only CMF keys `cmf_on_mod_registration`, `cmf_on_callback` (`in_game/common/on_action/sakuya_cmm_sittings_cmm_on_actions.txt:2-6,15-19`); `in_game/common/on_actions/sakuya_mark_country_on_actions.txt` is empty (`#我删除了`) and in the wrong (plural) folder → no overlap with our 11 vanilla hooks |
| Event namespaces | `sakuya_mark_country`, `sakuya_truce` vs our `cw_events`, `cw_tick`, `cw_stance` |
| Scripted-widget names | 18 `sakuya_*_window`/`sakuya_hwl_screen` vs `cw_war_stance_plate`, `cw_hq_overview_window` |
| GUI type/template names | 42 defined by CMP; intersection with the 198 identifiers used by our `.gui` files = **empty** (VERIFIED `comm`) |
| HUD placement | `sakuya_button_window`: `layer = topbar`, `parentanchor = right|bottom`, `position = { -480 0 }` (`sakuya_button.gui:1-6`); our plate: `layer = topbar`, `parentanchor = top|hcenter`, `position = { 0 132 }`, 26 px high, ≤ 360 px wide (`cw_war_stance_plate.gui:20-21,68-74`) → different corners, no overlap (INFERRED from geometry; research 08 line 21-23 places alerts at y 40..130 and the pause banner at y 160) |
| Windows | all CMP windows are `windows_layer`, `parentanchor = center`, like our `cw_hq_overview_window` (`cw_hq_overview.gui:226-228`) → purely visual stacking when both are open |

Gameplay interactions (file facts VERIFIED, consequences INFERRED):
- Cheat country modifiers stack additively with our army-level penalties: `sakuya_cheat_modifiers.txt:96-97` (`discipline = 0.15`, `land_morale_modifier = 0.25`), `:117-119` (`land_morale = 999`, `land_morale_recovery = 999`), `:132-133` and `:1395` (`siege_ability = 999`, `assault_ability = 999`), `:1556-1588` (`sakuya_siege_ability_small/large` ±0.1 / ±100), `:1398` (`lack_of_control_impact_on_warscore = -10000`). With these active an HQ-less army sieges normally — expected for a cheat, not a bug; do not test balance with them on.
- Army generator (`in_game/common/scripted_effects/sakuya_army_generator_effects.txt`: 401 `unit_type:` references, `create_sub_unit_with_owner`) spawns armies without an HQ → they carry `cw_no_hq` until the monthly pass (AI / auto-HQ players) or the Headquarters tab adds one. Its unit list is hard-coded and does not include `cw_hq`/`cw_hq_colonial` (not a conflict; just not integrated).
- Truce/war cheats (`in_game/events/sakuya_truce_events.txt`: 4× `add_truce`, `sakuya_declare_war.gui`) go through vanilla war state → our `on_war_declared`/`on_ending_war` hooks fire normally (INFERRED).
- If the user ever installs CMF: it ships extracted vanilla types `in_game/gui/vanilla/cmf_single_unit_window_vanilla_types.gui` and `cmf_ingame_topbar_vanilla_types.gui` (research 09 line 403 [V-WEB]). Those duplicate `type`s from `single_unit_window.gui`; "last loaded wins" → whichever of CMF / our full copy loads later defines them. Harmless while both are vanilla-identical, a conflict if either is stale, and a hard conflict if CMF (or any mod) ships its own `in_game/gui/single_unit_window.gui`. UNVERIFIED (CMF not installed). SPEC/research recommendation stands: do not depend on CMF.

## 3. Simple Cheats (`W/3634102315`, "mshp.simple_cheats" 1.0, `supported_game_version` 1.*, git history 2025-12-31 … 2026-01-09)

Ships (VERIFIED): `in_game/common/scripted_guis/sc_*.txt` (keys `pcs_*`), `in_game/gui/panels/left_panel.gui`, `in_game/gui/simple_cheats_ui.gui`, `main_menu/common/static_modifiers/sc_modifiers.txt` + `sc_import_export_modifiers.txt` (31 `sc_*` keys), an **empty** `loading_screen/` directory (mounted, contains nothing → no defines). No on_actions, events, unit types, game rules, `REPLACE:`/`INJECT:`.

| Check | Result |
|---|---|
| Overrides a vanilla file by path | **none** — in 1.4.7 the vanilla left panel is `G/in_game/gui/panels/left_panel/left_panel.gui` (1030 lines, md5 `0302a8a2e9f32455649d084fc331ebae`); SC ships `in_game/gui/panels/left_panel.gui` (1083 lines, no BOM, md5 `a3b49abf53b807f41147e46557c0e4bf`, 377 diff lines) → stale copy at a path that no longer exists in vanilla (VERIFIED paths; research 09 line 424) |
| Consequence of the stale file | it is still parsed as an extra `.gui` and defines global names: templates `player_stat_bg` (:1), `text_single_positive_negative` (:64), `text_single_positive_zero_negative` (:76), `io_leader_button` (:1058); types `left_panel_bar` (:96), `left_panel` (:753), `stat_player_button` (:952), `stat_player` (:976). Its injection `simple_cheats_button = {}` (:725) is dead (the file is not the live left panel), which is why the window `simple_cheats_window` (`simple_cheats_ui.gui:55-58`, `windows_layer`, center) is opened by console `GUI.CreateWidget` (research 09 line 424). INFERRED: with "last loaded wins" its 8 non-`sc_` definitions may replace the live vanilla ones — a Simple Cheats ↔ vanilla issue, not ours |
| Shared GUI names with CW | exactly one: `stat_player_button`, used by `cw_hq_overview.gui:100` and `cw_war_stance_plate.gui:98`. SC's body (`panels/left_panel.gui:952-974`) is byte-identical to vanilla (`panels/left_panel/left_panel.gui:890-912`) → no visible effect today (VERIFIED with `diff`). If a future patch changes that type and SC is not updated, our plate/overview button could pick up SC's stale version depending on load order (INFERRED) — keep CW below SC |
| `cw_`/`CW_` strings | **0 hits** (VERIFIED) |
| Static modifiers / scripted GUIs | `sc_*` / `pcs_*` only (own duplicate `pcs_instant_research_add` at `sc_scripts.txt:314` and `:340`, engine drops the second — not ours) |
| Touches our two overrides / defines / on_actions | no |

Gameplay interactions: `sc_siege_ability = { siege_ability = 0.10 }` (`sc_modifiers.txt:157-159`) slightly offsets `cw_no_hq` (−0.90) — negligible. `pcs_reset_modifiers` (`sc_reset.txt`) removes only `sc_*` country/location modifiers → never strips `cw_*`. `pcs_destroy_enemy_forts` (`sc_scripts.txt:461-475`) deletes all enemy forts → sieges and war worth of forts change, our scripts unaffected.

## 4. Load order and what to tell users

1. Put **New Intelligence: Battle last (lowest) in the playset**, after Cheat Menu Pro, Simple Cheats and any UI mod. Reasons: GUI `type`/`template` definitions are last-loaded-wins (§3 `stat_player_button`), our two full-file overrides must be the final provider of their paths, and partial defines are last-filename-wins. Last launch already had this order (VERIFIED, §0).
2. Hard incompatibilities (any mod that ships one of these paths): `in_game/gui/single_unit_window.gui` (army window), `in_game/common/location_ranks/00_default.txt`. Resolution = manual merge of our marked blocks (§5) into the other mod's copy, or a compatibility patch mod loaded after both.
3. Soft overlaps: mods setting the same `NAI`/`NWar` defines (last filename wins per key — our files are named `cw_*`, a `zz_*` file in another mod overrides ours); mods that remove or rename unit category `army_auxiliary`, the ages `age_1_traditions`/`age_3_discovery`, `location_rank:` keys or the five continent keys (`continent:europe|asia|africa|america|oceania`, used by the colonial-HQ theatre logic) break script silently (errors only in `error.log`).
4. Safe: mods that only append to `monthly_country_pulse`/`on_war_declared`/… (lists merge), mods adding unit types, cheat mods (penalties may be masked, §2).
5. Requires a **new game** (HQ grant on `on_game_started_after_lobby`). Removing the mod mid-campaign: unit/country modifiers self-expire within a year (SPEC §15); saved `cw_hq` regiments of an unknown type on load — UNVERIFIED. Ironman/achievements: UNVERIFIED (mod changes `common/`, assume disabled).

## 5. Vanilla patching — what to re-merge and how

### 5.1 Pinned vanilla state (1.4.7, VERIFIED with `md5sum`/`wc` on 2026-11-04; identical to `tools/vanilla_overrides.txt`)

| Vanilla file | md5 | lines | bytes | Our copy | Delta |
|---|---|---|---|---|---|
| `G/in_game/gui/single_unit_window.gui` | `0e6eb35ea9298cf60e44ed2e3e757ee1` | 5301 | 143 783 | 6047 lines, 181 140 bytes, no BOM (vanilla has none either) | +748 / −2 lines in 5 hunks |
| `G/in_game/common/location_ranks/00_default.txt` | `eac46655d8a16252ac3f316c0bc1ec5d` | 212 | 3 978 | 216 lines, 4 611 bytes, BOM kept | +4 lines |

(sha256 of the vanilla `.gui` is recorded in our header, `in_game/gui/single_unit_window.gui:3`.)

Our blocks, all fenced `# CW BEGIN … / # CW END …` (`grep -n "# CW " in_game/gui/single_unit_window.gui`):

| # | Block | Our lines | Vanilla anchor (1.4.7) | Unified-diff hunk |
|---|---|---|---|---|
| 1 | header comment | 1-17 | before vanilla line 1 | `@@ -0,0 +1,17 @@` |
| 2 | tab bar (`header_secondary_tabs` with two `button_secondary_tab_alt`) | 3713-3756 | blank line 3695, right after the unit card (`}` at 3694, `widget = {` at 3696) | `@@ -3695,0 +3713,45 @@` |
| 3 | gate 1 (one line replaced) | 3759-3765 | 3697 `visible = "[SingleUnitWindow.Vars.NotExistOrHasValue( 'tab', 'actions' )]"` | `@@ -3697 +3759,7 @@` |
| 4 | gate 2 (one line replaced) | 4084-4090 | 4016, same `visible` string | `@@ -4016 +4084,7 @@` |
| 5 | headquarters tab content | 5134-5804 | after 5058 (closing `}` of the actions content) | `@@ -5058,0 +5133,672 @@` |

`00_default.txt`: one `local_war_score_efficiency = <v>  # CW: …` line inserted inside `rank_modifier` of each rank, after vanilla lines 4 (megalopolis `-0.4`), 79 (city `-0.25`), 145 (town `0.25`), 193 (rural_settlement `1.0`).

### 5.2 Procedure (Git Bash; `patch`, `diff`, `md5sum`, `git apply` are all present in `/usr/bin`, VERIFIED)

Do step 0 **now**, while 1.4.7 is still installed, and commit the result; steps 1-7 after every game update.

```bash
cd /c/Users/fyrno/PycharmProjects/EU5-NewIntelligence          # repo root (tools/ lives here)
M=mods/new_intelligence_battle                               # mod root
G="/c/Program Files (x86)/Steam/steamapps/common/Europa Universalis V/game"

# 0. (once per game version) keep our delta as patches and a pinned vanilla copy
mkdir -p tools/patches tools/cache/vanilla_1.4.7            # tools/cache is gitignored; tools/patches is not
cp "$G/in_game/gui/single_unit_window.gui" "$G/in_game/common/location_ranks/00_default.txt" tools/cache/vanilla_1.4.7/
diff -u "$G/in_game/gui/single_unit_window.gui" $M/in_game/gui/single_unit_window.gui > tools/patches/single_unit_window.patch
diff -u "$G/in_game/common/location_ranks/00_default.txt" $M/in_game/common/location_ranks/00_default.txt > tools/patches/location_ranks.patch

# 1. detect the change
bash tools/check_vanilla_overrides.sh                        # prints CHANGED/OK per file against tools/vanilla_overrides.txt

# 2. see what Paradox changed (helps judge whether anchors moved)
diff -u tools/cache/vanilla_1.4.7/single_unit_window.gui "$G/in_game/gui/single_unit_window.gui" | less

# 3. rebase: fresh vanilla copy + our patch (dry run first)
cp "$G/in_game/gui/single_unit_window.gui" $M/in_game/gui/single_unit_window.gui
patch --dry-run -p0 $M/in_game/gui/single_unit_window.gui < tools/patches/single_unit_window.patch
patch -p0 $M/in_game/gui/single_unit_window.gui < tools/patches/single_unit_window.patch   # rejects land in *.rej
# same two lines for in_game/common/location_ranks/00_default.txt with location_ranks.patch

# 4. resolve *.rej by hand: re-insert the failed # CW block at its anchor (§5.1), delete the .rej/.orig files
# 5. re-pin
md5sum "$G/in_game/gui/single_unit_window.gui" "$G/in_game/common/location_ranks/00_default.txt"; wc -l "$G/in_game/gui/single_unit_window.gui" "$G/in_game/common/location_ranks/00_default.txt"
#    -> update tools/vanilla_overrides.txt (md5, lines, game hash from logs/code_revisions.log) and the header of single_unit_window.gui (line 2-3)
# 6. static checks
bash tools/validate.sh
# 7. in-game: open an army -> both tabs work; open a navy -> vanilla window; no 'single_unit_window.gui' or 'cw_' lines in logs/gui.log and logs/error.log
```

If `git apply` is preferred, generate the patch with repo-relative labels on both sides (`diff -u --label a/in_game/gui/single_unit_window.gui --label b/in_game/gui/single_unit_window.gui "$G/in_game/gui/single_unit_window.gui" in_game/gui/single_unit_window.gui`) and apply with `git apply --reject -p1 <patch>` (`--3way` is not available: the vanilla pre-image is not a blob in this repo).

### 5.3 Post-patch checklist beyond the two files (cheap greps, all against `G/`)

- Defines still exist with the same names (renamed keys fail silently; dry-run on 1.4.7 = 36 keys, no output): `for k in $(grep -h -E '^\s+[A-Z][A-Z0-9_]+\s*=\s*[^{]' loading_screen/common/defines/cw_*.txt | sed -E 's/^\s*([A-Z0-9_]+).*/\1/'); do grep -q -E "^\s*$k\s*=" "$G/loading_screen/common/defines/00_defines.txt" || echo "MISSING define $k"; done`. Vanilla 1.4.7 values and line numbers are in the comments of `cw_ai_defines.txt` / `cw_war_defines.txt`; `NAI` starts at `00_defines.txt:565`, `NWar` at `:2665` (research 09 line 189).
- Our 12 hooked on_action keys still fire from code: `grep -n -E '^(monthly_country_pulse|on_game_started_after_lobby|on_new_age|on_war_declared|on_join_war|on_ending_war|on_battle_won|on_command_gained|on_revolt_start|on_civil_war_start|on_siege_won|on_location_occupied)\b' "$G/in_game/common/on_action/"*.txt`.
- Vanilla GUI templates our **new** GUI relies on (`using =` / widget types; VERIFIED locations in 1.4.7): `bg_text_mask_container_brown`, `bg_window_default_alt`, `bg_market_card`, `bg_cabinet_card_frame`, `bg_paper_card`, `bg_main_inner_alt`, `bg_frame_squared_brown` (`main_menu/gui/shared/backgrounds.gui`); `button_secondary_tab_alt`, `header_secondary_tabs`, `ui_direction_button_holder_right` (`main_menu/gui/shared/main_menu_buttons.gui`); `stat_player_button` (`in_game/gui/panels/left_panel/left_panel.gui:890`); `Animation_Show_Hide_UI` (`in_game/gui/shared/animation.gui`); `unit_card_actions` (`in_game/gui/unit_overview.gui`); `country_flag_very_small` (`in_game/gui/shared/coat_of_arms.gui`); `icon_text_2rows` (`in_game/gui/shared/standard_types.gui`); `Font_Type_Headers`, `Font_Size_Small` (`loading_screen/gui/preload/fonts.gui`); `bg_frame_squared_brown`, `Scrollbar_Vertical_Small` (`loading_screen/gui/custom_loading_screen.gui`); `button_regular` (`loading_screen/gui/shared/defaults.gui`); plus `tooltip_title_icon_size`, `window_margin_alt`, `subunit_illustration`, `color_military_texture`, `SubUnit_tooltip`, `button_close_alt`, `button_checkbox`, `window_header_alt`, `divider_solid_gold`, `scroll_list`, `TooltipTextBlock`, `OneOrSeveralTimedModifiers`. One-liner (search the whole `G/`, five templates live in `loading_screen/gui/`; dry-run on 1.4.7 = no output): `for t in <names>; do grep -r -q -E "^\s*(type|template)\s+$t\b" "$G" --include=*.gui || echo "MISSING template $t"; done`.
- Data functions used by the GUI (`SingleUnitWindow.Vars`, `SingleUnitWindow.GetSelectedUnit`, `AccessPlayerUnits`, `Unit.GetSubUnits`, `GetScriptedGui(...).IsShown/IsValid/Execute`, `GetVariableSystem`): re-run `dump_data_types` in the console after the patch and grep `logs/data_types/` (research 09 §7.2).
- Script keys referenced by our content (unit category `army_auxiliary`, ages, `location_rank:*`, `continent:*`, traits used by the stance logic, `institution:*`): `bash tools/validate.sh` rebuilds `tools/cache/vanilla_script_keys.txt` from the new game files and reports unknown keys.
- Re-check the two cheat mods only if they update (§2-3 are pinned to CMP 1.7.0 / SC git `2c09e3a`): `find "$W/<id>" -type f | while read f; do rel="${f#$W/<id>/}"; [ -f "$G/$rel" ] && echo "OVERRIDES $rel"; done` and `grep -r -i -l '\bcw_' "$W"`.

## 6. Open items (UNVERIFIED until an in-game session)

- Partial defines override from a mod file (TESTING.md E1) — if it does not work, the fallback is a full copy of `00_defines.txt`, which becomes a third full-file override subject to §5.
- Game-rule `defines = {}` blocks (`main_menu/common/game_rules/cw_game_rules.txt:49, 107`) restoring vanilla NAI/NWar values when a rule is off (research 11 line 296-310: documented, never used by vanilla).
- Whether a mis-pathed extra `.gui` (Simple Cheats) really overrides live types — only matters if `stat_player_button` ever diverges.
- Achievement/ironman status with the mod enabled.
