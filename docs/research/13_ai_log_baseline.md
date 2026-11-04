# 13 — Log baseline (vanilla reference) and `tools/log_stats.sh`

Written 2026-11-04 from the EU5 1.4.7 logs in `C:\Users\fyrno\Documents\Paradox Interactive\Europa Universalis V\logs` (Git Bash path `/c/Users/fyrno/Documents/Paradox Interactive/Europa Universalis V/logs`). Tags: **VERIFIED** = read from a file quoted as `file:line`; **INFERRED** = derived from verified facts; **UNVERIFIED** = plausible, not checked.

All counts below come from one frozen copy of the logs taken at **13:03:11** wall-clock (last `game.log` line `[13:03:07]`); the game was still running, so the live files are larger now. The full metric dump of that copy is in §8 and is the "vanilla" side of future comparisons.

## 0. Usage — `tools/log_stats.sh`

```bash
bash tools/log_stats.sh                        # report from the live logs directory
bash tools/log_stats.sh -d DIR                 # report from a copied/snapshotted logs directory
bash tools/log_stats.sh --tsv > base.tsv       # machine-readable "metric<TAB>value" (what §8 shows)
bash tools/log_stats.sh --compare base.tsv     # live logs vs a saved TSV: metric | base | now | delta
bash tools/log_stats.sh --snapshot NAME        # copy ai/game/perf/pause/error/gui/setup logs + metrics.tsv
                                               #   to tools/log_snapshots/NAME/   (--with-debug: debug.log too)
bash tools/log_stats.sh --player "Бранденбург" # also count wars declared by / on that localised country name
EU5_LOG_DIR=/other/logs bash tools/log_stats.sh      # other logs directory;  EU5_SNAPSHOT_DIR=... other snapshot root
```

Protocol for a vanilla-vs-mod comparison (same bookmark 1337, same player country, same speed, ≥ 15 game years each):

1. Play the **vanilla** session, quit to desktop, then *before launching the game again* run `bash tools/log_stats.sh --snapshot vanilla_<date>_<TAG>`.
2. Play the **mod** session the same way, then `bash tools/log_stats.sh --compare tools/log_snapshots/vanilla_<date>_<TAG>/metrics.tsv` (and `--snapshot mod_<date>_<TAG>` to keep it).
3. Read §9 for which metrics should move and why; compare *per-game-year* rates, not raw totals.

`*.log` is git-ignored (`.gitignore:10`), so a snapshot folder keeps only `metrics.tsv` + `continue_game.json` under version control; the copied logs stay local. The script runs in ~3 s, reads `debug.log` with `grep -c` only, and never writes into the game's logs directory. Requires Git Bash (GNU awk 5, grep 3, coreutils) — all present on this machine.

## 1. What the logs on disk actually cover — read first

- **The game truncates every log at start-up.** VERIFIED: every file begins at the same launch — `debug.log:1` `[12:12:47] Mounted Data: …/clausewitz/loading_screen`, `game.log:1` `[12:12:55]`, `gui.log:1` `[12:12:53]`, `multiplayer.log:1` `[12:12:51]`, `ai.log:1` `[12:13:49]`, `dedicated_server.log:1` `[12:13:50]`. The 2.4 MB `ai.log` / 5 MB `game.log` / 95 MB `debug.log` named in the task were the *previous* session and are gone; nothing older survives except `crashes/Europa Universalis V20261030_113930/logs/` (game **1.4.6**, `meta.yml:3`, `Mod_1: Cheat Menu Pro` `meta.yml:39`), which holds only `debug.log` (507 MB) and `error.log` — no `ai.log`/`game.log`, so no older gameplay baseline exists. ⇒ **Snapshot or export after every session.**
- **One session, new game.** `setup.log:3` `[12:13:49][initialize_from_bookmark.cpp:2955]` (bookmark init = new game, not a loaded save); `game.log:2831-2835` are the post-init "Savegame reparation applied 0 fixes" / "Cached data recalculation complete" lines that every new game prints (VERIFIED), i.e. no save was loaded during the session.
- **Identity** (VERIFIED): game `1.4.7` (`continue_game.json:5` `rawGameVersion`), exe `47c12bd63e` branch `ud009/release/next` built 2026-10-29 (`setup.log:1-2`, `code_revisions.log:2-5`); player **BRA** (`multiplayer.log:38` `New Country: BRA`; host name `multiplayer.log:12`); session save id `autosave_0ec4b6f2-8a17-4d35-ab93-e833561b276f` (`continue_game.json:2`); game dates **1337-04-01 → 1353-06-01** in the snapshot (`performance_degradation.log:5` first in-game row, last row), speed 4 from `[12:15:53]` (`dedicated_server.log:4`), played with constant manual pausing: 231 toggles, **913 s unpaused** out of ~47 min wall-clock (computed from `dedicated_server.log`, cross-checked by an independent awk pass).
- **Mods mounted** (VERIFIED, `debug.log:15972-15979` at `[12:13:29]`, repeated `debug.log:85969-85976` at `[12:14:03]`): `workshop/content/3450310/3600272327` = **Cheat Menu Pro** 1.7.0, `…/3634102315` = **Simple Cheats** 1.0, and `mod/concentrated_warfare` = this mod's folder (junction, `mod/concentrated_warfare -> /c/Users/fyrno/PycharmProjects/EU5-ConcentratedWarfare`). `playsets.json` (active playset "1") lists only Cheat Menu Pro — why the engine mounted three is UNVERIFIED; the mount lines are authoritative.
- **Was gameplay vanilla?** INFERRED yes, with these verified facts: (a) at 12:13:29 the mod folder contained only `.metadata/*` (11:55) and `main_menu/common/static_modifiers/cw_unit_modifiers.txt` (12:04); every other mod file was written 12:30–12:52 (file mtimes) — an unused static modifier changes nothing; (b) no `cw_` script/GUI/unit key appears in any log (`grep -c cw_` after excluding the engine files below = 0 in `debug.log`, `error.log`, `gui.log`, `game.log`); (c) the only `concentrated_warfare` mentions are the 6 mount lines; (d) the army-window errors that start at `[12:58:59]` cite **vanilla** line numbers (`single_unit_window.gui:3449 ('single_unit_window')` = vanilla `lateralview = {`; the mod copy starts with a 13-line header, so its numbers are shifted) ⇒ the mod's GUI override was *not* hot-loaded; (e) the two cheat mods ship GUI, scripted GUIs, events, static modifiers and loc only — no `defines`, no AI or unit files (file listing of both workshop folders). Whether the player *used* cheats is UNVERIFIED (not logged). Label this baseline **"quasi-vanilla: vanilla gameplay + cheat-UI mods"**.
- **`cw_` false positives**: `debug.log:9833-9883` "Key … defined in multiple files: 'localization/cw_core_l_russian.yml', 'localization/cw_settings_l_russian.yml'" are **engine** files (`clausewitz/loading_screen/localization/cw_core_l_russian.yml`, `cw_settings_l_russian.yml`), not this mod. Filter with `grep 'cw_' … | grep -v 'cw_core_l_\|cw_settings_l_'` (the script does).

## 2. Log inventory and line formats

Common format (VERIFIED on every file): `[HH:MM:SS][source.cpp:LINE]: message`, CRLF line endings, wall-clock time only — no game date on any line. Multi-line messages continue without a prefix (`game.log` production dumps, `error.log`/`debug.log` "Data flow path" blocks), so count by *timestamped* lines. Game time must be joined from `NEW YEAR:` markers (`game.log`) or the date column of `performance_degradation.log`; the script does both.

| File | Lines @13:03 | Content (session 2026-11-04) | Notes |
|---|---|---|---|
| `ai.log` | 3 935 | 3 931 `[AI Warning] AI tried to execute invalid command: <kind>.` + 3 `AI posting invalid commands: move_unit` | sources `game_command.cpp:154` (3 932), `ai_tick_context.cpp:655` (3); §3 |
| `game.log` | 13 991 timestamped (+1 704 continuation) | 479 `WAR:`, 42 `CIVIL WAR:`, 67 `REVOLT:`, 10 `COLONISATION:`, 9+3 `DISASTER:`, 8+1 `SITUATION:`, 4 `EXPLORATION:`, 16 `NEW YEAR:` + noise (§4.3) | the only gameplay event log; §4 |
| `performance_degradation.log` | 1 header + 82 CSV rows | one row every ~31 s (median): frame time, memory, GUI widgets, **game date** | §5 |
| `dedicated_server.log` | 234 | `Setting game started`, `Changing game speed to: N`, `Pause Toggled! Paused: true/false, PlayerID: 1` | pause/speed timeline → unpaused seconds; §6 |
| `multiplayer.log` | ~270 | session/lobby setup, `New Country: BRA` (`:38`) | player identity; §6 |
| `setup.log`, `code_revisions.log`, `system.log` | 24 / 12 / 15 | exe build + bookmark royal marriages / git hashes / CPU-GPU | version check; §6 |
| `error.log` + `error.1-5.log` | 7 906 + 5×~19 000 | GUI/loc data errors; rotates at 1 MB, 5 generations kept | mod errors must be grepped across all six; §7 |
| `gui.log` | 267 | font loading, GUI template errors (`gui/sakuya_test.gui` = Cheat Menu Pro) | 0 `cw_`; §7 |
| `debug.log` | 656 216 (70 MB) | mounts, loc/data-system spam, trigger validation, section timings | grep-only; §7 |
| empty / tiny | `warning.log`, `message.log`, `memory.log`, `database_conflicts.log`, `custom_automated_stats.log`, `hardware_checker.log`, `pdxsdk.log` 0 B; `graphics.log` 166 B; `ecs.log` 7 KB (asset warnings) | nothing for us | |

## 3. `ai.log`

**Templates.** The exe contains exactly three AI-log strings (VERIFIED, `grep -a` on `binaries/eu5.exe`): `[AI Warning] AI tried to execute invalid command: {}.`, `AI posting invalid commands: {}`, `[AI Warning] Ai tried to take too many loans` (0 occurrences this session). Nothing else is ever written here, so `ai.log` cannot tell what the AI *did* — only which generated commands failed validation (meaning INFERRED: a command object was built by an AI routine and rejected by `game_command.cpp:154`; it is a churn/robustness indicator). Examples: `ai.log:1` `[12:13:49][game_command.cpp:154]: [AI Warning] AI tried to execute invalid command: change_trade_capacity.`; `ai.log:2933` `[12:54:36][ai_tick_context.cpp:655]: AI posting invalid commands: move_unit`.

**Kinds and counts** (snapshot; 3 931 total, 27 distinct kinds):

| kind | count | army-related? | kind | count | army-related? |
|---|---:|---|---|---:|---|
| set_cabinet_action | 2 101 | | raise_all_levies | 19 | yes |
| disband_subunit | 602 | yes | take_over_siege | 14 | yes |
| change_trade_capacity | 308 | | set_unit_activity | 8 | yes |
| diplomaticactioncommand | 178 | | detach_unit | 7 | yes |
| toggle_can_attach_to | 161 | yes | add_bureaucracy | 3 | |
| upgrade_rgo | 144 | | asssume_siege_control (sic) | 3 | yes |
| transfer_occupation | 120 | yes | disband_unit, invite_scholars, split_unit | 2 each | split/disband yes |
| perform_generic_action | 118 | | attach_unit, cancel_construction, consolidate, decision_taken, production_methods, replace_rival, use_unit_ability | 1 each | attach/consolidate/use_unit_ability yes |
| build_road | 64 | | `AI posting invalid commands: move_unit` | 3 | yes |
| merge_army | 42 | yes | | | |
| move_unit | 26 | yes | | | |

Army-related subset (script constant `ARMY_KINDS`: move_unit merge_army split_unit attach_unit detach_unit toggle_can_attach_to set_unit_activity take_over_siege asssume_siege_control transfer_occupation disband_subunit disband_unit raise_all_levies use_unit_ability consolidate) = **1 009 = 25.7 %**. Rates: **243 invalid commands per game year**, **258 per unpaused minute** (4.3 per unpaused second); the per-minute rate was stable through the session (166 → 774 per 5-min wall-clock bucket as the player paused less). Per-year distribution in §4.2. INFERRED: `set_cabinet_action` (53 %) and `disband_subunit` (15 %) dominate; `disband_subunit` is the one to watch once HQ regiments exist (AI trying to disband 100-man auxiliaries), and `merge_army`/`split_unit`/`attach_unit`/`detach_unit`/`toggle_can_attach_to` (213 total) are the AI army-management churn the `NAI` define changes may move.

## 4. `game.log`

**4.1 Templates.** The exe's complete set of `KIND:` log strings (VERIFIED by `grep -a` on `eu5.exe`): `WAR: {} declared war on {} `, `CIVIL WAR: {} against {}`, `REVOLT: {} against {}`, `COLONISATION: {} starts colonising {}`, `DISASTER: {} starts in {}` / `DISASTER: {} ends in {}`, `SITUATION: {} starts on {}` / `SITUATION: {} ends on {}` / `SITUATION: {} ends`, `EXPLORATION: {} discovered {}`, `NEW YEAR: {}`. **There is no PEACE / BATTLE / SIEGE / OCCUPATION / TRUCE log line in 1.4.7** (the only hits for those words are loc keys and event-file names, e.g. `game.log:6` `peace_take_over_market_center_select_location`, `game.log:784` namespace `battle_for_the_strait_events`); the 14 `siege` hits in `debug.log` are `Section: Key: "siege_manager"` save-writer timings. Caveat: the exe scan covered 8-bit strings only (UTF-16 templates would be missed — UNVERIFIED, but every found template is 8-bit). Countries appear by **localised name** (Russian UI), e.g. `game.log:2846` `[12:16:23][diplomatic_action_war.cpp:482]: WAR: Хиэнуки declared war on Мори ` (trailing space), `game.log:9106` `[rebel_manager.cpp:1618]: CIVIL WAR: Претенденты на корону against Византия`, `game.log:9432` `[rebel_manager.cpp:540]: REVOLT: Маху against Маху`, `game.log:2840` `[country.cpp:6344]: DISASTER: fate_of_the_phoenix starts in BYZ` (tag, not name), `game.log:2837` `[situation_manager.cpp:384]: SITUATION: Битва за пролив starts on 1 мая, 1337`, `game.log:13923` `[exploration.cpp:394]: EXPLORATION: Кастилия discovered TOOLTIP:AREA,azores_sea_area L; Азорское море!!`, `game.log:7877` `[gamestate.cpp:1005]: NEW YEAR: 1338`.

**4.2 Baseline counts** (1337-04-01 → 1353-06-01, 5 901 game days = 16.2 years): wars declared **479** (29.6/year; 358 distinct attackers, 341 distinct defenders; top attackers Маджапахит 5, Виджаянагар 4, Камата 4, Пинья 4, Энъя 4, Юань 4; player BRA declared 0 wars and was attacked 0 times), civil wars **42**, revolts **67**, colonisations 10 (all Швеция), disasters 9 started / 3 ended, situations 8 / 1, explorations 4, `NEW YEAR` 16 (1338…1353). Per game year (1337 = Apr–Dec, 1353 = Jan–Jun only; AI columns are `ai.log` lines joined on wall-clock time):

| year | wars | civil wars | revolts | AI invalid cmds | …of which army |
|---|---:|---:|---:|---:|---:|
| 1337 | 14 | 0 | 0 | 204 | 3 |
| 1338 | 51 | 0 | 0 | 237 | 67 |
| 1339 | 35 | 0 | 0 | 193 | 42 |
| 1340 | 74 | 1 | 0 | 259 | 73 |
| 1341 | 96 | 4 | 4 | 361 | 182 |
| 1342 | 29 | 8 | 4 | 276 | 87 |
| 1343 | 6 | 2 | 6 | 321 | 126 |
| 1344 | 7 | 2 | 4 | 231 | 41 |
| 1345 | 8 | 0 | 4 | 203 | 36 |
| 1346 | 26 | 3 | 6 | 208 | 29 |
| 1347 | 47 | 1 | 8 | 237 | 55 |
| 1348 | 4 | 2 | 5 | 222 | 51 |
| 1349 | 9 | 5 | 1 | 184 | 13 |
| 1350 | 18 | 2 | 6 | 202 | 43 |
| 1351 | 11 | 2 | 5 | 263 | 105 |
| 1352 | 12 | 4 | 4 | 195 | 23 |
| 1353 | 32 | 6 | 10 | 135 | 33 |

War declarations are bursty (96 in 1341 vs 4 in 1348 — the early-game truce cycle, INFERRED), so compare multi-year windows, never single years.

**4.3 Noise kinds** (counted on the snapshot): `unknown db name definition from loc/ux 'D008_pronoia'` + `Trying to use ShowDBDefinitionName when there is no game state` 5 690 each (`game.log:2847-2848`, `data_factory_hooks.cpp:3381/3386`, a DLC loc bug, fires on every war line's tooltip); `Object of type 'country' is not valid for 'CL_tt'/'CL_ACC'` 834 (`game.log:13026`, `jomini_custom_text.h:93`); event loading at start: 419 `>=== NAMESPACE > 'x' is set to #N` + 409 `Events loaded events/….txt' #N` (`game.log:9-10`); 230 production-method profit dumps, each a multi-line block ending `===> Profit: N%, N` + `#####…` (`game.log:872`, `production_methods.cpp:545`); 9 `Optimization warning: Database static size differs` (`game.log:2806`); 5 `Message type … is overridden` (`game.log:1-5`); misc loc-key warnings. None of it is gameplay; the script ignores it.

## 5. `performance_degradation.log`

CSV, header `performance_degradation.log:1`: `"Total Time","Average Delta","MinDelta","MaxDelta","Audio Events:","Ecs entities","Ecs entities capacity","GUI widgets","Game Data","Memory Usage (MB)","Memory Usage (Virtual) (MB)","Number of CityGfx","Number of CityGfx::Instances","Old Entities:","Print Debug duration (ms)","Total number of Gfx units","Total number of Trade wagons"` (17 columns; the first four are quoted). `Total Time` = seconds since launch, `Average Delta` = mean frame time (s) over the sample window, `Game Data` = game date `YYYY_MM_DD` (`1_01_01` while in the main menu, rows 2-4). Baseline: 80 in-game rows, launch→last row 2 944 s, **mean frame 10.17 ms** (max 17.2 ms), worst single stall 4.42 s, memory 6.6–13.5 GB (drops from 11.5 to 7.0 GB around 1344-12 — UNVERIFIED cause, probably a cache flush), GUI widgets up to 303 653, ECS entities ≤ 9 490. Speed: 3.18 game days per sampled second (intervals that include pauses) and **6.46 game days per unpaused second** at speed 4 — the number to compare for TESTING.md §6 (same speed setting required).

## 6. Small session logs

- `dedicated_server.log:1` `[12:13:50][jominiapplication.cpp:508]: Setting game started: yes`, `:2` `Changing game speed to: 2`, `:4` `Changing game speed to: 4`, then only `Pause Toggled! Paused: true|false, PlayerID: 1` lines. The first toggle is `Paused: false` ⇒ the game starts paused (VERIFIED); the script integrates unpaused time from these lines.
- `multiplayer.log:30-41` session block with `New Country: BRA`; `:12` `host player: ZXC Онигири ZXC 1000-7`. Single-player sessions still write it.
- `setup.log:1-2` exe git version/build timestamp; `:3+` bookmark royal marriages. `code_revisions.log` game/clausewitz hashes (`2026.43.0`). `system.log` hardware.

## 7. `error.log`, `gui.log`, `debug.log`

- **`error.log` rotates at ~1 MB and keeps 5 generations** (`error.1.log` … `error.5.log`; VERIFIED by timestamps: at 13:03 they covered 12:55:39→13:02:25, i.e. ~93 600 lines in 7.5 min). Two vanilla floods fill it: (1) `[12:55:37-39]` ~31 000 lines of `FetchData failed for 'AddTextIf(EqualTo_string('Кукуруза', GOODS.GetNameWithNoTooltip), …)'` (Russian goods-name loc, `pdx_data_localize_helper.cpp:315`); (2) from `[12:58:59]` whenever an army window is open: a 12-line block per frame — `error.log:1-14`: `FetchData failed for 'UIAction.IsVisible' - gui/single_unit_window.gui:2914` + `gui/shared/buttons.gui:177: No context supplied (Use SetDataContext), wanted context of type 'UIAction' for 'UIAction.IsEnabled'` + data-flow path through vanilla `single_unit_window.gui:3449/3645/3696/3888-3910` (`unit_mercenary_contracts_ongoing`) — 142 blocks per second at 13:03. Consequences: **mod errors can be rotated away within minutes**; grep all six files (`grep -h 'cw_' error.log error.[1-5].log | grep -v 'cw_core_l_\|cw_settings_l_'`), close army windows while collecting, and expect the same vanilla blocks in mod runs (the mod's `single_unit_window.gui` copy will shift the cited line numbers by +13 and add its own context).
- **`gui.log`** (267 lines): font loading (`gui.log:1`), then GUI parse errors — 95 `gui/sakuya_test.gui:N - Could not find template`, 18 `Widget cannot have a position in a layout`, … (Cheat Menu Pro); a handful of vanilla `failed reading property` lines. 0 `cw_`. Mod GUI syntax errors will show here (TESTING.md §4).
- **`debug.log`** (656 216 lines; grep only): top kinds are GUI data-system spam — 95 904 `gui/government_lateralview.gui:N ('X')`, 85 948 `gui/shared/windows.gui:N`, 42 984 `gui/single_unit_window.gui:N` (the same army-window flood), 21 253 `Data error in loc string`, 14 454 `Skipped member: Color`, 9 585 `Failed converting statement … LR_PREP`, 3 969 `Adding trigger after PostInitAndValidate …` (`jomini_trigger.cpp`), 7 328 `Promote 'X' returned nullptr`; by source `pdx_data_localize_helper.cpp` 275 686, `pdx_data_localize.cpp` 21 253, `pdx_data_factory.cpp` 19 984, `pdx_gui_data_manager.cpp` 18 509. Useful mod-health lines it *does* carry: `Mounted Data:` (which mods/folders loaded), `File 'x' should be in utf8-bom encoding` (37, all Cheat Menu Pro files — `debug.log:15826` `events/sakuya_truce_events.txt`), `Duplicate localization key` (166), `Key 'x' defined in multiple files` (771), `Define 'X' … not specified. Maybe a define macro is missing` (23 vanilla ones, e.g. `TRUST_BROKEN_TRUCE` `debug.log:107`), `PostValidate of trigger 'x' returned false at file:line` (3, `debug.log:15929`). The script reports all of these; for the mod run `debug_bom_warnings`, `debug_cw_lines`, `debug_postvalidate_false` must not grow.
- The "database first definition wins" drops mentioned in SPEC §0 would also land in `debug.log` (UNVERIFIED this session — nothing duplicated).

## 8. Baseline metrics (TSV of the 13:03:11 snapshot — the `--compare` input)

Saved by `bash tools/log_stats.sh -d <snapshot> --player "Бранденбург" --tsv`; copy into a file to use with `--compare`.

```
#	session
game_version	1.4.7
exe_hash	47c12bd63e
exe_branch	ud009/release/next
wallclock_first	12:12:47
wallclock_last	13:03:07
mods_mounted_count	3
mods_mounted	Cheat Menu Pro | Simple Cheats | Concentrated Warfare — Штабы и стратегия
player_country	BRA
game_speed_last	4
unpaused_seconds	913
pause_toggles	231
unpaused_when_log_ended	1
#	performance
perf_samples_ingame	80
game_date_first	1337_04_01
game_date_last	1353_06_01
game_days_elapsed	5901
perf_total_time_s	2944
perf_frame_ms_mean	10.17
perf_frame_ms_max	17.20
perf_maxdelta_s_max	4.42
perf_mem_mb_min	6651
perf_mem_mb_max	13526
perf_gui_widgets_max	303653
perf_ecs_entities_max	9490
perf_days_per_s_sampled	3.18
game_days_per_unpaused_s	6.46
#	game_log
game_log_lines	13991
wars_declared	479
wars_per_game_year	29.6
wars_distinct_attackers	358
wars_distinct_defenders	341
wars_declared_by_player	0
wars_declared_on_player	0
civil_wars	42
revolts	67
colonisations_started	10
disasters_started	9
disasters_ended	3
situations_started	8
situations_ended	1
explorations	4
new_year_markers	16
top_attackers	Маджапахит:5, Виджаянагар:4, Камата:4, Пинья:4, Энъя:4, Юань:4, Ёсими:3, Вага:3, Дайвьет:3, Десмонд:3
#	ai_log
ai_log_lines	3935
ai_invalid_commands_total	3931
ai_invalid_commands_army	1009
ai_invalid_commands_army_pct	25.7
ai_invalid_per_game_year	243.1
ai_invalid_per_unpaused_min	258.34
ai_posting_invalid_total	3
ai_other_warnings	0
ai_other_lines	1
ai_unparsed_lines	0
ai_invalid_cmd.set_cabinet_action	2101
ai_invalid_cmd.disband_subunit	602
ai_invalid_cmd.change_trade_capacity	308
ai_invalid_cmd.diplomaticactioncommand	178
ai_invalid_cmd.toggle_can_attach_to	161
ai_invalid_cmd.upgrade_rgo	144
ai_invalid_cmd.transfer_occupation	120
ai_invalid_cmd.perform_generic_action	118
ai_invalid_cmd.build_road	64
ai_invalid_cmd.merge_army	42
ai_invalid_cmd.move_unit	26
ai_invalid_cmd.raise_all_levies	19
ai_invalid_cmd.take_over_siege	14
ai_invalid_cmd.set_unit_activity	8
ai_invalid_cmd.detach_unit	7
ai_invalid_cmd.add_bureaucracy	3
ai_invalid_cmd.asssume_siege_control	3
ai_invalid_cmd.disband_unit	2
ai_invalid_cmd.invite_scholars	2
ai_invalid_cmd.split_unit	2
ai_invalid_cmd.attach_unit	1
ai_invalid_cmd.cancel_construction	1
ai_invalid_cmd.consolidate	1
ai_invalid_cmd.decision_taken	1
ai_invalid_cmd.production_methods	1
ai_invalid_cmd.replace_rival	1
ai_invalid_cmd.use_unit_ability	1
ai_posting_invalid.move_unit	3
#	by_year
year.1337.wars	14
year.1337.civil_wars	0
year.1337.revolts	0
year.1337.ai_invalid	204
year.1337.ai_invalid_army	3
year.1338.wars	51
year.1338.civil_wars	0
year.1338.revolts	0
year.1338.ai_invalid	237
year.1338.ai_invalid_army	67
year.1339.wars	35
year.1339.civil_wars	0
year.1339.revolts	0
year.1339.ai_invalid	193
year.1339.ai_invalid_army	42
year.1340.wars	74
year.1340.civil_wars	1
year.1340.revolts	0
year.1340.ai_invalid	259
year.1340.ai_invalid_army	73
year.1341.wars	96
year.1341.civil_wars	4
year.1341.revolts	4
year.1341.ai_invalid	361
year.1341.ai_invalid_army	182
year.1342.wars	29
year.1342.civil_wars	8
year.1342.revolts	4
year.1342.ai_invalid	276
year.1342.ai_invalid_army	87
year.1343.wars	6
year.1343.civil_wars	2
year.1343.revolts	6
year.1343.ai_invalid	321
year.1343.ai_invalid_army	126
year.1344.wars	7
year.1344.civil_wars	2
year.1344.revolts	4
year.1344.ai_invalid	231
year.1344.ai_invalid_army	41
year.1345.wars	8
year.1345.civil_wars	0
year.1345.revolts	4
year.1345.ai_invalid	203
year.1345.ai_invalid_army	36
year.1346.wars	26
year.1346.civil_wars	3
year.1346.revolts	6
year.1346.ai_invalid	208
year.1346.ai_invalid_army	29
year.1347.wars	47
year.1347.civil_wars	1
year.1347.revolts	8
year.1347.ai_invalid	237
year.1347.ai_invalid_army	55
year.1348.wars	4
year.1348.civil_wars	2
year.1348.revolts	5
year.1348.ai_invalid	222
year.1348.ai_invalid_army	51
year.1349.wars	9
year.1349.civil_wars	5
year.1349.revolts	1
year.1349.ai_invalid	184
year.1349.ai_invalid_army	13
year.1350.wars	18
year.1350.civil_wars	2
year.1350.revolts	6
year.1350.ai_invalid	202
year.1350.ai_invalid_army	43
year.1351.wars	11
year.1351.civil_wars	2
year.1351.revolts	5
year.1351.ai_invalid	263
year.1351.ai_invalid_army	105
year.1352.wars	12
year.1352.civil_wars	4
year.1352.revolts	4
year.1352.ai_invalid	195
year.1352.ai_invalid_army	23
year.1353.wars	32
year.1353.civil_wars	6
year.1353.revolts	10
year.1353.ai_invalid	135
year.1353.ai_invalid_army	33
#	errors
error_log_lines	7906
error_log_rotated_files	5
error_log_lines_all	93642
error_log_cw_lines	0
error_top_sources	[pdx_gui_data_manager.cpp:362]:344, [pdx_gui_data_manager.cpp:245]:343, [pdx_data_localize_helper.cpp:315]:5
gui_log_lines	267
gui_log_cw_lines	0
debug_log_lines	656216
debug_cw_lines	0
debug_concentrated_warfare_mentions	6
debug_bom_warnings	37
debug_duplicate_loc_keys	166
debug_loc_keys_multi_defined	771
debug_define_missing	23
debug_postvalidate_false	3
debug_loc_data_errors	21253
```

(`log_dir` and `report_time` rows omitted; the `--compare` output marks string metrics as `changed`, numeric ones with absolute and % delta.)

## 9. What to compare in a mod run, and how to read it

| metric (script key) | vanilla | expected with the mod | why / caveat |
|---|---:|---|---|
| `error_log_cw_lines`, `gui_log_cw_lines`, `debug_cw_lines`, `debug_bom_warnings`, `debug_postvalidate_false` | 0 / 0 / 0 / 37 / 3 | 0 / 0 / 0 / 37 / 3 | hard health gates: any `cw_` line = script or GUI error; BOM warnings must stay = the cheat mods' 37 (or 0 without them) |
| `mods_mounted` | 3 | the CW line must be present | if `Concentrated Warfare` is missing the run is vanilla |
| `ai_invalid_cmd.disband_subunit` (per year ≈ 37) | 602 | **watch** | AI disbanding 100-man HQ regiments would show up here or as HQs vanishing (SPEC §6 `cw_cleanup_excess_hqs`); INFERRED |
| `ai_invalid_cmd.merge_army / split_unit / attach_unit / detach_unit / toggle_can_attach_to` | 42 / 2 / 1 / 7 / 161 | should change after the `NAI` define overrides | the only log trace of AI army-management activity; direction unknown, magnitude per game year is what matters; INFERRED |
| `ai_invalid_cmd.transfer_occupation / take_over_siege / asssume_siege_control` | 120 / 14 / 3 | likely ↓ | fewer armies able to siege (no HQ) ⇒ fewer siege hand-overs; INFERRED |
| `ai_invalid_per_game_year` | 243 | similar | sanity check that the AI still runs its routines; a collapse (≪ 100) or explosion (≫ 500) means something broke |
| `wars_per_game_year`, `civil_wars`, `revolts` | 29.6 / 2.6 / 4.1 per year | similar (±30 %) | the mod does not target war *declaration*; a big drop may mean war-worth/define changes deter the AI (DESIGN §4); bursty — use ≥ 15 years |
| `perf_frame_ms_mean`, `game_days_per_unpaused_s` | 10.17 ms / 6.46 d/s | ≤ +10 % / ≥ −10 % | TESTING §6; same speed, same date window, similar pausing; `perf_mem_mb_max` 13.5 GB |
| `wars_declared_by_player`, `wars_declared_on_player` (with `--player`) | 0 / 0 | — | only to document what the player did |

Pitfalls (all VERIFIED above): logs are truncated at every launch; `error.log` rotates in minutes under the army-window flood; AI counts scale with the number of AI countries and the date (1337–1353 Old World AI count is roughly constant — INFERRED) so keep the same window; the baseline includes two cheat-UI mods; `cw_core_l_*` engine files are not mod hits; wall-clock buckets are meaningless with manual pausing — always use the per-game-year or per-unpaused-minute rates the script prints.

## 10. Save games on disk (sessions, no logs survive for any of them)

`…/Europa Universalis V/save games/` (32 files, 2026-10-26 → 11-04): manual saves `SP_<TAG>_<YYYY_MM_DD>_<session-uuid>.eu5` — `SP_ZMW_1337_11_30 … 1339_05_16` (uuid `470c3276`, Oct 28), `SP_BUG_1371_08_24` (`f93ad2ee`, Oct 28), `SP_BUG_1519_06_08` (`07343b1c`, Oct 30 — the crash-day session, 1.4.6), `SP_ENG_1358_04_02` (`f113f662`, Nov 1), `SP_MOS_1356_08_23 / 1377_07_09 / 1453_07_09` and `SP_RUS_1487_09_02` (`5db768b1`, Nov 2-4 — Muscovy→Russia, latest Nov 4 00:58, probably the session whose 2.4 MB `ai.log` the task referred to; INFERRED), plus `autosave_<uuid>[_1|_2].eu5` triplets per session including `fa6c595e` (Oct 26, no manual save). The analysed session is **`0ec4b6f2` (BRA, autosave only, 12:50–12:54 and later)**. Only this one has logs; a save file cannot regenerate `ai.log`/`game.log` for the others.

## 11. Gaps and recommendations

1. **No battle / siege / peace / occupation metrics exist in any vanilla log** (§4.1). To measure the mod's core claims (sieges only by HQ armies, capital-centric war score, stance changes) the mod must log them itself: an on_action-driven `log` effect (the key `log` is in `tools/cache/vanilla_script_keys.txt`, but no vanilla usage was found — UNVERIFIED that it writes to `game.log` in EU5; test with `on_siege_won`/`on_battle_won`/`on_ending_war` and a `CW:`-prefixed message). If it works, put the logging into a separate tiny **telemetry mod** (`cw_telemetry`, no gameplay changes) so that *vanilla + telemetry* and *full mod* can be compared with the same counters; extend `log_stats.sh` with a `CW:` section then.
2. Keep every future session: `bash tools/log_stats.sh --snapshot <vanilla|mod>_<date>_<TAG>` right after quitting (one line, before the next launch).
3. For a cleaner vanilla reference, play one session with **no workshop mods** at all (cheat-UI mods add GUI noise, loc duplicates and BOM warnings, and make "did the player cheat" unknowable), same country and speed, ≥ 20 game years, minimal pausing (the AI runs only while unpaused, so 913 unpaused seconds is a thin sample).
4. When reading `error.log` during mod tests, close the army window first (vanilla flood, §7) and grep all six error files; prefer `gui.log` for GUI syntax errors and `debug.log` `Mounted Data:` lines to confirm the mod is loaded.
