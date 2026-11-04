# 09 — External modding documentation, mod packaging & debug workflow (EU5 1.4.7)

Research doc for the **Concentrated Warfare** mod (`cw_` prefix). Scope: Part A = what the public documentation (EU5 wiki, Paradox forum, GitHub, Community Mod Framework) says about script syntax, file loading/override rules, metadata and debugging; Part B = what the local installation (game files, two workshop mods, logs) actually shows. Game build on this machine: **1.4.7** (`logs/code_revisions.log`: `game_branch: ud009/release/next`, `clausewitz_release_tag: 2026.43.0`, `continue_game.json`: `"rawGameVersion": "1.4.7"`).

Evidence labels used throughout:

| Label | Meaning |
|---|---|
| **[V-FILE]** | Verified in game / workshop-mod files or logs on this machine (path:line given). Strongest evidence. |
| **[V-WEB]** | Verified on a fetched web page (URL given). Wiki pages are community-written and often flagged "last verified for 1.0–1.3". |
| **[INFERRED]** | Reasonable inference from V-FILE/V-WEB facts; not directly observed. |
| **[UNVERIFIED]** | Not confirmed anywhere; needs an in-game test (collected in §11). |

---

## 1. Source index

### 1.1 Fetched successfully

| Source | URL | Notes |
|---|---|---|
| Wiki: Modding hub | https://eu5.paradoxwikis.com/Modding | Folder layout, `-debug_mode`, `script_docs`, `dump_data_types`, encoding. |
| Wiki: Mod structure | https://eu5.paradoxwikis.com/Mod_structure | `metadata.json` fields incl. `relationships`, `game_custom_data.replace_paths`, thumbnail. |
| Wiki: Mod files load order | https://eu5.paradoxwikis.com/Mod_files_load_order | ASCII order, `INJECT:`/`REPLACE:` family, events/GUI/localization/defines rules. Flagged "last verified 1.1". |
| Wiki: Mod compatibility | https://eu5.paradoxwikis.com/Mod_compatibility | Same rules restated + on_action limits. |
| Wiki: Mod (install/playsets) | https://eu5.paradoxwikis.com/Mod | Mod folder path, playsets. |
| Wiki: Effects | https://eu5.paradoxwikis.com/Effects | 642 KB page, "generated from the script documentation (_script_docs_ console command)". |
| Wiki: Triggers | https://eu5.paradoxwikis.com/Triggers | 484 KB page, same provenance, "last verified 1.1". |
| Wiki: Scope / Scope link | https://eu5.paradoxwikis.com/Scope , https://eu5.paradoxwikis.com/Scope_link | Scope types list, links (`attacker_leader`, `unit_location`, `continent`…). |
| Wiki: On actions | https://eu5.paradoxwikis.com/On_actions | Block syntax, "only a new `on_actions` block can be added to existing on actions". |
| Wiki: Defines | https://eu5.paradoxwikis.com/Defines | Partial override rule, example `01_mod_defines.txt`. |
| Wiki: Localization | https://eu5.paradoxwikis.com/Localization | `_l_<lang>.yml`, UTF-8-BOM, `replace/` folder, formatting codes. |
| Wiki: Modifier types / Modifier modding | https://eu5.paradoxwikis.com/Modifier_types , https://eu5.paradoxwikis.com/Modifier_modding | `common/modifier_type_definitions`, `STATIC_MODIFIER_NAME_<key>`. |
| Wiki: Scripted gui / GUI script / Interface modding guide | https://eu5.paradoxwikis.com/Scripted_gui , https://eu5.paradoxwikis.com/GUI_script , https://eu5.paradoxwikis.com/Interface_modding_guide | SGUI block, `GetScriptedGui('x').Execute(...)`, `scripted_widgets`, `GUI.CreateWidget`. |
| Wiki: Console commands | https://eu5.paradoxwikis.com/Console_commands | Command list incl. `script_docs`, `dump_data_types`/`DumpDataTypes`, `reload`, `effect`, `trigger`, `observe`, `YesMan`. |
| Wiki: Unit modding / War modding / Script value | https://eu5.paradoxwikis.com/Unit_modding , https://eu5.paradoxwikis.com/War_modding , https://eu5.paradoxwikis.com/Script_value | `limit` script value on unit types, wargoal `ticking_war_score`, CB `max_warscore_from_battles`. |
| Wiki: Patch 1.4 / 1.4.X / Developer diaries | https://eu5.paradoxwikis.com/Patch_1.4 , https://eu5.paradoxwikis.com/Patch_1.4.X , https://eu5.paradoxwikis.com/Developer_diaries | 1.4.5 released 2026-10-28, 1.4.6 2026-10-30, 1.4.7 2026-11-03. |
| Wiki: Community Mod Framework / Toolkit | https://eu5.paradoxwikis.com/Community_Mod_Framework , https://eu5.paradoxwikis.com/Community_Mod_Toolkit | Feature list, hook names, covered GUI files. |
| CMF GitHub + wiki | https://github.com/Europa-Universalis-5-Modding-Co-op/community-mod-framework (wiki pages: `Improved-Vanilla-Top-Level-Widget-Overrides`, `On-Action-Hooks`, `Basic-Setup`, `Utility-Effects-and-Triggers`, `Dependency-Check-Popup`, `Mod-Detection`) | Raw metadata: https://raw.githubusercontent.com/Europa-Universalis-5-Modding-Co-op/community-mod-framework/main/.metadata/metadata.json |
| Community Mod Toolkit GitHub + wiki | https://github.com/Europa-Universalis-5-Modding-Co-op/community-mod-toolkit (wiki `Mod-Template`) | Template metadata: https://raw.githubusercontent.com/Europa-Universalis-5-Modding-Co-op/community-mod-toolkit/main/.metadata/metadata.json |
| Caesar's CMF fork (Steam page bbcode) | https://github.com/CaesarVincens/eu5-community-mod-framework/blob/main/STEAM_PAGE.bbcode | "load-order agnostic, but place before/above other mods". |
| SteamDB 1.4.7 notes (via search) | https://steamdb.info/patchnotes/26377361/ | "AI armies no longer stop short of their destination when their movement is locked". |

### 1.2 Not reachable from this environment (cite only)

| Source | URL | Status |
|---|---|---|
| Tinto Talks #85 "Modding" (2025-10-22) | https://forum.paradoxplaza.com/forum/developer-diary/tinto-talks-85-22nd-of-october-modding.1864004 | Forum returns a Cloudflare "Validating browser…" page to fetchers; web.archive.org is blocked for this tool. Search snippets only: EU5 is "not exactly" the most moddable game "at least not at release"; example overrides the **`situation_panel_main_content` block** to add widgets to a situation panel (block/blockoverride GUI mechanism). **[INFERRED from snippets]** |
| Tinto Talks #46 "Military objectives" (2025-01-15) | https://forum.paradoxplaza.com/forum/index.php?threads/1726045 | Same block. Snippets: "the military AI is using the same building blocks as the player can use with the UI"; wartime objectives shown include *Carpet Siege* and *Blockade Ports*; "a lot of sub-objective and supporting objectives … primarily used by the AI, like join units, maintain troop levels"; player can use "Chase target". |
| Tinto Talks #113 "AI Disposition & Achievements" (2026-06-17, 1.3) | https://forum.paradoxplaza.com/forum/index.php?threads/1929503 | Same block. Title only. |
| eu5db.com changelog (diffed from game files) | https://eu5db.com/changes | `ECONNRESET` ×3. |
| GitHub dumps of `effects.log` / `triggers.log` for EU5 | — | **None found.** Two extended searches returned only CK3 repos. The wiki's own `Module:Script_docs/Effects` + `/Triggers` Lua modules are the public dump (https://eu5.paradoxwikis.com/Module:Script_docs/Triggers). Authoritative 1.4.7 dump must be generated locally with `script_docs` (§7). |

Wiki page names are case-sensitive: `/Scopes`, `/Modifiers`, `/Scripted_GUI` return 404; use `/Scope`, `/Modifier_types`, `/Scripted_gui`. **[V-WEB]**

---

## 2. Mod packaging

### 2.1 Folder layout **[V-FILE + V-WEB]**

A mod mirrors the three stage folders of `<game>/game/`: `loading_screen/`, `main_menu/`, `in_game/` (+ `.metadata/`). Wiki Mod structure: "The three top folders are `in_game`, `loading_screen` and `main_menu`"; load order "`loading_screen` first (pre-menu), then `main_menu`, then `in_game`"; wrong nesting (extra `game/` level, `in_game/on_action` without `common/`) is "not read and do[es] not produce errors". **[V-WEB]**

What the engine actually mounts (one mod active in the last session):

```
logs/debug.log (2026-11-03 20:12)
[20:12:39][dlc_reloadable.cpp:390]: Mod Cheat Menu Pro (sakuya) version 1.4.* successfully matched game version 1.4.7.
[20:12:41][virtualfilesystem_physfs.cpp:596]: Mounted Data: C:/Program Files (x86)/Steam/steamapps/workshop/content/3450310/3600272327/main_menu
[20:12:45][virtualfilesystem_physfs.cpp:596]: Mounted Data: C:/Program Files (x86)/Steam/steamapps/workshop/content/3450310/3600272327/in_game
```
**[V-FILE]** → each stage folder of the mod is mounted as an overlay on the corresponding game stage; a mod file with the same relative path shadows the vanilla file.

Where vanilla keeps what the mod will touch **[V-FILE, `ls`]**:

| Content | Vanilla folder |
|---|---|
| defines | `game/loading_screen/common/defines/00_defines.txt` (+ `graphic/`, `jomini/`); engine extras in `jomini/loading_screen/common/defines/` |
| static modifiers, modifier type defs, script_values, game_rules, scripted_lists, scripted_triggers (menu-stage) | `game/main_menu/common/` (`static_modifiers`, `modifier_type_definitions`, `script_values`, `game_rules`, `scripted_lists`, `scripted_triggers`, …) |
| localization | `game/main_menu/localization/<lang>/*_l_<lang>.yml` (langs: braz_por english french german japanese korean polish russian simp_chinese spanish turkish); `game/in_game/localization/` contains only `jomini/` |
| scripted effects/triggers, on_action, unit_types, casus_belli, wargoals, scripted_guis, AI script folders, events | `game/in_game/common/...`, `game/in_game/events/` |
| GUI | `game/in_game/gui/*.gui` (e.g. `single_unit_window.gui`, `ingame_topbar.gui`, `military_objective_groups.gui`), `game/main_menu/gui/` (shared templates, `scripted_widgets/_scripted_widgets.info`) |
| on_action folder name | **`common/on_action`** (singular) — `ls game/in_game/common | grep on_action` → only `on_action` |

Workshop mods as structural examples **[V-FILE]**:
- Cheat Menu Pro (`…/workshop/content/3450310/3600272327`): `in_game/common/{scripted_effects,scripted_triggers,on_action,customizable_localization,generic_actions,…}`, `in_game/gui/*.gui`, `in_game/gui/scripted_widgets/sakuya_scripted_windows.txt`, `main_menu/common/{scripted_guis,static_modifiers}`, `main_menu/gfx/…`, `main_menu/localization/<lang>/…` (sub-folders like `english/1.7/` are fine).
- Simple Cheats (`…/3634102315`): `in_game/common/scripted_guis/*.txt`, `in_game/gui/simple_cheats_ui.gui`, `in_game/gui/panels/left_panel.gui`, `main_menu/common/static_modifiers/*.txt`, `.metadata/{metadata.json,thumbnail.png}`.

Note: Cheat Menu Pro puts `scripted_guis` under `main_menu/common/` and the engine still parses them (`debug.log`: `Duplicated key … will not be created from file: common/scripted_guis/sakuya_cheat_sgui.txt:27052`) **[V-FILE]**, i.e. `common/<db>` folders are read from any mounted stage. Vanilla keeps `scripted_guis` in `in_game/common/scripted_guis/` (`scripted_guis.info` lives there) — use that.

### 2.2 `metadata.json` schema

Keys the executable's metadata parser knows (string search in `binaries/eu5.exe`, 272 MB) **[V-FILE]**:

```
…pdx_mod_dlc_interface/pdx_mod_metadata.cpp … replace_paths … "Badly formatted game_custom_data, failed to read '{}' array entr…"
… game_custom_data . relationships . provider_id . short_description . supported_game_version …
```
Hit counts (word-bounded): `replace_paths` 1, `supported_game_version` 2, `game_custom_data` 3, `relationships` 2, `rel_type` 1, `display_name` 1, `resource_type` 1, `short_description` 2, `picture` 1, `thumbnail` 6, `remote_file_id` 1, `affects_checksum` 1 (appears in the DLC-manifest string table next to `steam_id.pdx_id.archive`), **`game_id` 0**, `multiplayer_synchronized` 0, `long_description` 0.

Wiki Mod structure **[V-WEB]**: `name`; `id` ("an identifier for recognition"); `version` ("x.x.x or x.x format, with integers"); `supported_game_version` ("may use `*` as a wildcard (e.g., `1.0.*`)"); `short_description` ("used as the initial description in the Steam upload"); `tags` (list); `relationships` = list of `{ rel_type: "dependency" (only option), id, display_name ("shown if the target can't be found"), resource_type: "mod"|"dlc", version (wildcards ok) }`; `game_custom_data` "currently supports only `replace_paths`, a list of paths to stop loading. A path like `events` affects only that folder, not its subfolders."; `.metadata/thumbnail.png` "must be smaller than 1MB and is recommended to be 512x512".

Real examples on disk **[V-FILE]**:

`…/3600272327/.metadata/metadata.json` (Cheat Menu Pro, loads fine on 1.4.7):
```json
{
    "name": "Cheat Menu Pro",
    "id": "sakuya",
    "version": "1.7.0",
    "game_id": "eu5",
    "supported_game_version": "1.4.*",
    "short_description": "a Cheat menu,made by Xier",
    "tags": [ "utility", "cheat" ],
    "relationships": [ {
            "rel_type": "dependency",
            "id": "community_mod_framework",
            "display_name": "Community Mod Framework",
            "resource_type": "mod",
            "version": "2.*" } ],
    "game_custom_data": {}
}
```
`…/3634102315/.metadata/metadata.json` (Simple Cheats): `"id" : "mshp.simple_cheats"`, `"version" : "1.0"`, `"supported_game_version": "1.*"`, `"tags" : ["Gameplay","Utilities"]`, `"relationships" : []`, `"game_custom_data" : {}`, `"picture": "thumbnail.png"` — **no `game_id`**, loads fine.

Toolkit template (https://raw.githubusercontent.com/…/community-mod-toolkit/main/.metadata/metadata.json) **[V-WEB]**: `"name": "[Mod Name] Dev"`, `"id": "[modname].dev"`, `"version": "0.1"`, `"game_id": "eu5"`, `"supported_game_version": "1.1.*"`, full tag list (= `create_mod_tags.json` SteamRef names), `"relationships": []`, `"game_custom_data": {}`. CMF's own (main branch) **[V-WEB]**: `"id": "community_mod_framework.dev"`, `"version": "2.4.1"`, `"supported_game_version": "1.3.*"`, custom key `"cmf_last_updated_game_version": "1.3.10"` (unknown keys are tolerated).

DLC manifests use a *different* schema (`game/dlc/D000_shared/D000_shared.dlc.json`: `"replace_path": []`, `"supported_version": ""`, `"dependencies": []`, `"affects_save_compatibility"`, `"mp_synced"`) **[V-FILE]** — do not copy DLC keys into a mod.

Dependency semantics **[V-FILE]**: Cheat Menu Pro declares CMF `2.*` as dependency, CMF is **not** installed (`workshop/content/3450310/` holds only `3600272327` and `3634102315`), yet the mod loaded; the only consequence was `[jomini_effect.cpp:557]: Unknown effect cmm_register_button_setting at common/scripted_effects/sakuya_cmm_sittings_cmm_effects.txt:3` in `debug.log`. → `relationships` is informational (launcher/Workshop), not enforced by the game.

Version matching **[V-FILE]**: `"1.4.*"` → "successfully matched game version 1.4.7". A mismatch only warns: `main_menu/localization/english`: `MODS_GUI_MOD_UNSUPPORTED_GAME_VERSION: "$BULLET$$MOD$ supports a game version different to the current one, could provoke problems. \n"`.

### 2.3 Tags **[V-FILE]**

`game/main_menu/create_mod_tags.json` (`SteamRef` values, the strings Steam Workshop expects): Advancements, Alternative history, Balance, Characters, Culture & Art, Diplomacy, Events, Fixes, Flags, Gameplay, Government and Estates, Historical, International Organizations, Loading Screen, Map, Military, Missions, Overhaul, Religion, Sound, Textures, Trade and Economics, Translation, User Interface, Utilities. The in-game tool shows them as toggles (`main_menu/gui/mod_tools.gui:318 datamodel = "[ModToolsGui.Tags]"`). Free-form tags (Cheat Menu Pro's `"utility","cheat"`) do not break loading **[V-FILE]**; whether they survive a Workshop upload is **[UNVERIFIED]**.

### 2.4 The `metadata.json` to use for Concentrated Warfare

Current file `C:\Users\fyrno\PycharmProjects\EU5-ConcentratedWarfare\.metadata\metadata.json` already matches the verified schema; recommended final content (no dependencies, Steam-valid tags):

```json
{
	"name": "Concentrated Warfare — Штабы и стратегия",
	"id": "concentrated_warfare",
	"version": "0.1.0",
	"game_id": "eu5",
	"supported_game_version": "1.4.*",
	"short_description": "Headquarters regiments, concentrated AI armies, war stances and a warscore rework. Штабы армий, концентрация войск ИИ, стадии войны и переработка очков войны.",
	"tags": [ "Gameplay", "Military", "Balance", "User Interface" ],
	"relationships": [],
	"game_custom_data": {},
	"picture": "thumbnail.png"
}
```
Notes: `game_id` is ignored by `eu5.exe` (0 string hits) but used by CMF/toolkit conventions — harmless, keep. `picture` is a parser-known key and Simple Cheats uses it; the wiki says `.metadata/thumbnail.png` is picked up by name anyway (512×512, <1 MB). Keep `id` stable forever (it is what other mods/CMF would reference). Non-ASCII `name` is **[UNVERIFIED]** for Workshop upload — if the uploader complains, move the Russian part into `short_description`. Only add a `relationships` entry if the mod really requires CMF (see §6); a submod would point at `"id": "concentrated_warfare"`. Bump `version` on every Workshop upload (toolkit's uploader can gate on it).

### 2.5 Local registration / playsets **[V-FILE]**

- Local mods: `%USERPROFILE%\Documents\Paradox Interactive\Europa Universalis V\mod\<folder>` (wiki) — here `mod\concentrated_warfare` is a **symlink** to the PyCharm project (created 2026-11-04 01:30, *after* the last game session). The last session logged `[dlc_reloadable.cpp:727]: No directories mounted to search for mods` and `No subdirs mounted for game dir from candidates: ../game/mod …` — meaning no local mod directory contained mods at that time. Whether the in-game manager follows a symlink is **[UNVERIFIED]**; fallback = directory junction (`mklink /J`) or a real copy.
- Playsets live in `Documents/…/playsets.json`: `{"file_version":"1.0.0","playsets":[{"name":"1","isActive":true,"isAutomaticallySorted":true,"orderedListMods":[{"path":"C:/Program Files (x86)/Steam/steamapps/workshop/content/3450310/3600272327/","isEnabled":true}],"DLC":[{"paradoxAppId":"d000_shared","isEnabled":true}, …]}]}` — absolute paths, order = load order, `isAutomaticallySorted` flag. Editing this file by hand is plausible but **[UNVERIFIED]**.
- There is no separate launcher: mods are managed in the main menu ("Dlcs and Mods View", wiki /Mod) via `main_menu/gui/mod_tools.gui`: fields `mod_version`, `mod_supp_version`, tag toggles, buttons `MOD_CREATE_MOD_STUB` ("Creates a mod stub in the target folder, under your game documents folder…") and `MOD_UPLOAD_NEW_MOD`; `MOD_BACKEND_NOT_AVAILABLE_STEAM` if Steam is absent **[V-FILE loc + gui]**.

---

## 3. How files load and override

### 3.1 File order **[V-WEB, wiki Mod_files_load_order, "last verified 1.1"]**
- "All files are loaded in ASCII order" — `00_foo.txt` before `01_bar.txt`; "Files in subfolders are loaded after files in the parent folder"; "It does not matter whether that file is from the base game or a mod."
- Direct file overwrite = same relative path: "A mod's file takes precedence over base game or DLC file"; between mods, "a file from a mod lower in the playlist takes precedence over one from higher in the playlist"; "Whichever file has the highest precedence is used, as if the other files did not exist."
- Game objects "are loaded in the order they are defined" (affects on-screen ordering).

### 3.2 Database objects: `INJECT:` / `REPLACE:` family **[V-WEB + V-FILE]**

Wiki keyword table (verbatim): `INJECT:` "Appends the injected script at the end of an existing entry. Errors if the specified entry does not exist."; `REPLACE:` "Replaces an existing entry with a new one. Errors if the specified entry does not exist"; `TRY_INJECT:`/`TRY_REPLACE:` "Same … but does not error if the specified entry does not exist"; `INJECT_OR_CREATE:`/`REPLACE_OR_CREATE:` "… if the specified entry does not exist, it creates it". "The `INJECT:` and `REPLACE:` keywords can only be used on top-level blocks in a file." "Most defined game objects require the use of these keywords or else require a direct file overwrite." Processing: "first by operation type, then by filename": `INJECT_OR_CREATE -> REPLACE_OR_CREATE -> TRY_INJECT -> TRY_REPLACE -> INJECT -> REPLACE`; "Operation priority therefore takes precedence over file loading order". Repeatable blocks are appended (a second `wargoal_scores` block is added, not merged); "most trigger and effect blocks" can be injected only if not already defined; for scripted effects/triggers `INJECT:` "results in the original effect/trigger being overwritten as though it was `REPLACE:`"; "not possible to inject into a sub-block". Folder list on the wiki is "TBA"; folders in `<top_folder>/common/` mostly support it, "Other folders **do not** support the `INJECT:` and `REPLACE:` keywords".

All six keyword strings exist in `eu5.exe` (`INJECT:` `REPLACE:` `TRY_INJECT:` `TRY_REPLACE:` `INJECT_OR_CREATE:` `REPLACE_OR_CREATE:`) **[V-FILE]**, and Paradox's own DLC uses them:
```
game/dlc/D009_across_the_pillars/in_game/common/government_reforms/d009_country_specific.txt:435: INJECT:crown_castile_reform = {
game/dlc/D009_across_the_pillars/in_game/common/genes/D009_genes_accessories.txt:3:  INJECT_OR_CREATE:headwear = {
game/dlc/D008_fate_of_the_phoenix/main_menu/gfx/portraits/portrait_modifiers/D008_beards.txt:55: INJECT:beards = {
```
Duplicate keys *without* keyword: engine drops the later one — `[gamedatabase.h:409]: Duplicated key sakuya_loc_mod_prosperity_ctrl_left will not be created from file: common/scripted_guis/sakuya_cheat_sgui.txt:27052` **[V-FILE]** → **first definition wins; a mod cannot override a vanilla object by simply redefining it** (**[INFERRED]** for mod-vs-vanilla; confirmed for duplicates inside one mod). Use `REPLACE:`/`INJECT:` or a full-file override. `logs/database_conflicts.log` exists (0 bytes here) and is the likely place such conflicts are reported **[INFERRED]**.

### 3.3 Events, GUI, localization, defines, on_actions **[V-WEB unless noted]**
- Events: "When multiple events share the same ID, the first one loaded _wins_"; "Sub-folders are always loaded _after_ files in the main events folder".
- GUI: `type`/`template` definitions "can be overwritten … the **last one loaded** based on **mod load order** (playlist position) _wins_. File names have no effect"; "The `types` container … does not need to be unique and has no overwriting logic at all." Top-level windows: CMF wiki — "To override a top-level widget, you have to replace the entire `.gui` file that defines it."
- Localization: file name "must end with `_l_<language>`", `.yml` in UTF-8-BOM or "the game simply ignores the file"; "later loaded localization keys DO NOT overwrite the previously defined ones. But the replace folder _wins_" → vanilla key overrides go to `<stage>/localization/<lang>/replace/*_l_<lang>.yml`. (The Localization page also claims files are "processed in reverse alphabetical order (from Z to A)" — contradictory with the above; irrelevant if all new keys are unique and overrides use `replace/`.) Duplicates inside a mod are logged: `[pdx_localize.cpp:221]: Duplicate localization key. Key 'STATIC_MODIFIER_NAME_sakuya_mercenary_small' is defined in both 'localization/russian/Cheat_menu_1.6_l_russian.yml' and 'localization/russian/cheat_menu_l_russian.yml'.` **[V-FILE]**
- Defines: "create a new file in <mod>/loading_screen/common/defines/ that loads after the base game files" (example `01_mod_defines.txt`); "Defines use a unique replacement mechanic that allows for replacing any single defines without replacing the whole define category"; "the mod with the last loaded filename determines the final value". Block syntax (wiki + `00_defines.txt:125 NCountry = {`): `NAI = { HUNT_ARMIES_MAX_SPLINTERS = 2 }`. Blocks in `00_defines.txt` **[V-FILE]**: NGame(1) NCityAudio(28) NAlertAudio(35) NJominiMap(58) NGUI(68) NText(113) NCountry(125) NMercenary(337) NUnit(364) NCombat(448) **NAI(565)** NCulture(1610) NCharacter(1678) … NLocation(1914) NMarket(1979) NEconomy(2072) NDiplomacy(2232) **NWar(2665)** NWorkOfArt(2728) NDynasty(2753) NColony(2771) … Partial override from a mod is **[UNVERIFIED]** locally (no mod on this machine ships defines).
- on_actions (wiki On_actions + Mod_compatibility): "Only a new `on_actions` block can be added to existing on actions"; replacing `trigger`/`effect` of a vanilla on_action requires replacing the whole file and "produces errors and overwrites any base game `effect`". Append pattern (used by CMF and Cheat Menu Pro, `…/3600272327/in_game/common/on_action/sakuya_cmm_sittings_cmm_on_actions.txt:1-12`) **[V-FILE]**:
```
# Hook this mod into CMF shared registration on_action.
cmf_on_mod_registration = {
	on_actions = {
		sakuya_cmm_sittings_on_register_cmf_mod
	}
}

sakuya_cmm_sittings_on_register_cmf_mod = {
	effect = {
		sakuya_cmm_sittings_register_cmf_mod = yes
	}
}
```
  The `-debug_mode` file watcher hot-reloads "except files such as on_action" (wiki Modding).
- `replace_paths` (wiki): stops loading a vanilla folder entirely (non-recursive). Not needed for this mod.
- Encoding: engine warns for script files without BOM — `[lexer.cpp:513]: File 'common/scripted_guis/sakuya_1_7_sgui.txt' should be in utf8-bom encoding (will try to use it anyways)` **[V-FILE]**; vanilla `.txt`/`.gui` start with a BOM (`00_defines.txt`, `left_panel.gui` diff shows `﻿template`). Save **everything** as UTF-8-BOM.

---

## 4. Script syntax facts the mod needs

### 4.1 Unit / sub-unit effects

| Effect | Scope → target | Evidence |
|---|---|---|
| `add_subunit = unit_type:<key>` — "Adds a subunit to a Unit" | unit → unit_type | **[V-FILE]** `game/in_game/events/debug/000_johan_debug.txt:419 add_subunit = unit_type:a_feudal_levy`; loc entry `effect_localization/unit_effects.txt:46`; wiki Effects |
| `create_sub_unit_with_owner = { type = <unit_type> owner = <country> origin = <location> experience = <n> }` — "spawns a subunit in location" | location | **[V-FILE]** `in_game/events/colonization/conquistador.txt:68-73`; `revolution_disaster.txt:249 create_sub_unit_with_owner = { type = a_sharpshooters owner = scope:target_country }`; Cheat Menu Pro `sakuya_army_generator_effects.txt:34-38`; wiki ("owner = country", "origin = location (for generating culture)") |
| `create_sub_unit = <unit_type>` (also `create_num_sub_unit`, `create_sub_unit_of_category`, `create_num_sub_unit_of_category`) | location | **[V-FILE]** Cheat Menu Pro `sakuya_army_generator_effects.txt:15-16 $location$ = { create_sub_unit = $type$ }`; names on wiki Effects; exe strings |
| `add_unit_modifier = { modifier = <static_modifier> days/months/years = <n> mode = replace \| add_and_extend }` — "add a modifier to a unit" | unit | **[V-FILE]** `in_game/common/generic_actions/parliament.txt:1268-1272` (`mode = replace`), `000_johan_debug.txt:264-267` (`days = 127 mode = add_and_extend`); exe string table `extend.add_and_extend`; loc entries `add_unit_modifier_duration`, `add_unit_modifier_forever` (`unit_effects.txt:21-33`) → omitting a duration = permanent **[INFERRED]** |
| `remove_unit_modifier = <name>`; `change_unit_modifier_size` | unit | **[V-FILE]** `000_johan_debug.txt:293`; wiki |
| `destroy_unit = yes`, `set_unit_size = 0.01`, `change_unit_owner = c:FIN`, `damage_unit_percent = 0.07`, `damage_unit_morale_percent = 0.2`, `add_morale = 0.1`, `add_food = 10`, `lock_unit = 30`, `unlock_unit = yes` | unit | **[V-FILE]** `000_johan_debug.txt:417-442` |
| `set_as_commander = <character>`, `remove_commander` | unit / none | **[V-FILE]** `conquistador.txt:123-128 random_army = { limit = { has_commander = no } set_as_commander = scope:target }` |
| `add_subunit_morale = { value = … }`, `add_subunit_strength(_percentage)`, `add_subunit_experience`, `change_subunit_type`, `destroy_subunit` | sub_unit | **[V-FILE]** `conquistador.txt:108-116 every_army = { every_sub_unit = { add_subunit_morale = { … } } }`; wiki names |
| `add_country_modifier = { modifier = <static_modifier> days/months/years = <n> mode = … }`, `remove_country_modifier`, `change_country_modifier_size`; `add_location_modifier`, `remove_location_modifier` | country / location | **[V-WEB]** wiki Effects; `parliament.txt:1255-1258` shows `modifier = parliament_approved_militarization years = 3 mode = add_and_extend` |
| `set_variable = { name = <v> value = <scope/value/flag:x> days = <n> }`, `change_variable = { name = <v> <op> = <value> }`, `add_to_variable_list = { name = <v> target = <scope> }` | none | **[V-WEB]** wiki Effects (Variable effects) |
| `transfer_location_occupation = <country>` (location), `change_siege_progress` (siege), `remove_breach`, `garrison_sortie = yes` (siege), `add_bonus_warscore` (war), `add_war_exhaustion`/`set_war_exhaustion`, `white_peace = <war>`, `take_over_all_wars`, `declare_war_with_cb`, `join_war_against = { war = … target = … call_in_subjects = yes/no ignore_rules = yes/no notify_opposing_side = yes/no }`, `leave_war = { war = … actor = … }` | various | **[V-WEB]** wiki Effects |
| **`merge_unit`** | — | **NOT an effect.** Exe context: `…dock_navy.merge_unit.gfx/cursors/…`; only use in scripts is `in_game/gui/map_markers.gui:726 cursor = "merge_unit"` **[V-FILE]**. Absent from wiki Effects. |
| **`split_unit`** | — | Exe string sits among UI actions `disband_unit.disband_subunit.transfer_subunit.split_unit.rename_unit…` → UI action, not an effect **[INFERRED]**. |
| **`create_unit`** | — | Exe string only; zero uses in any `.txt` under `in_game`/`dlc`; not on wiki → **[UNVERIFIED]**, assume it does not exist. Use `create_sub_unit_with_owner` (a sub-unit created in a location where the owner has no unit forms a new unit; `conquistador.txt:66-80` builds a 6-regiment army + supply unit this way). |

Merging/splitting armies by script therefore has no direct effect; the HQ design must work with `add_subunit`, `create_sub_unit_with_owner`, `destroy_subunit`, `change_subunit_type` and unit modifiers (and AI defines, §4.8).

### 4.2 Iterators (country ↔ unit ↔ sub_unit) **[V-WEB + V-FILE]**

Wiki (verbatim): `every_army` / `random_army` / `ordered_army` "Iterate through all armies in a country" (country → unit); `every_unit`/`ordered_unit`/`random_unit`/`any_unit` "Iterate through all units in a country"; `every_sub_unit`/`ordered_sub_unit`/`random_sub_unit`/`any_sub_unit` "Iterate through all subunits in a unit" (unit → sub_unit); `every_country_sub_unit`/`random_country_sub_unit`/`ordered_country_sub_unit` "Iterate through all subunits in all units in a country"; `every_unit_in_location`/`ordered_unit_in_location`/`any_unit_in_location` (location → unit); `every_besieging_units`/`ordered_besieging_units`/`random_besieging_units` (siege → unit); `every_participating_units` (combat_side → unit); `every_mercenary_sub_unit`.

Ordered syntax (wiki, verbatim):
```
ordered_army = {
 limit = { <triggers> }
 order_by = script_value
 (position = int)
 (min = int)
 (max = script_value)
 (check_range_bounds = no)
 <effects>
}
```
Vanilla example **[V-FILE]** `game/in_game/common/generic_actions/parliament.txt:1262-1272`:
```
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
`order_by` candidates = any unit-scope value trigger or (inline) script value. Vanilla uses named values (`order_by = population` ×308, `military_strength` ×14, `country_total_army_levy_size` ×3) and inline blocks (`country_interactions/hre.txt:2232 order_by = { value = population if = { limit = {…} … } }`, `decisions/coal_prospecting.txt:43-46 order_by = { value = relative_raw_material_price multiply = -1 }`). Unit-scope values that exist (`in_game/common/trigger_localization/unit_triggers.txt` keys) **[V-FILE]**: `num_subunits`, `sub_unit_count`, `sub_unit_strength`, `sub_unit_fraction`, `morale_percentage`, `strength_percentage`, `experience_percentage`, `food_percentage`, `prisoner_strength`; wiki adds `unit_strength`, `unit_modifier_strength(<key>)`. Note `random_` iterators take `weight = { <mtth> }` instead of `order_by`; "random_ is not allowed" inside script values (wiki Script_value).

### 4.3 Triggers

| Trigger | Scope | Evidence |
|---|---|---|
| `is_ai = yes/no` — "country is run by AI" | country | **[V-FILE]** `in_game/common/on_action/ai_personalities_setup.txt:16 limit = { is_ai = yes }`, `building_types/common_buildings.txt:24 is_ai = no` (82 files) |
| `num_locations` — "Checks if a country has a certain amount of owned locations" (value); also `num_locations_owned_or_owned_by_subjects(_or_below)` | country | **[V-FILE]** `in_game/common/advances/0_age_of_discovery.txt:588 divide = num_locations` (used as a value); wiki. **`num_owned_locations` does not exist** (0 hits, not on wiki). |
| `any_owned_location = { … }` (+ `count`/`percent`), `every_owned_location`, `random_owned_location` | country → location | **[V-FILE]** 188 files; Cheat Menu Pro `sakuya_army_generator_effects.txt:67-75` |
| `has_unit_modifier = <name>`, `unit_modifier_strength(<key>)` | unit | **[V-FILE]** `parliament.txt:1263`, `events/disaster/D008_fate_of_the_phoenix.txt:571`; wiki |
| `num_subunits` ("How many sub units does this unit have?"), `sub_unit_count`, `sub_unit_fraction`, `sub_unit_strength`, `is_army`, `is_navy`, `in_combat`, `in_siege`, `in_retreat`, `is_movement_locked`, `is_exiled`, `has_commander`, `has_levies`, `has_regulars`, `has_mercenaries`, `morale_percentage`, `strength_percentage`, `food_percentage` | unit | **[V-FILE]** `trigger_localization/unit_triggers.txt`; `conquistador.txt:124 has_commander = no` |
| `sub_unit_type = unit_type:<key>` — "Checks if a sub_unit is of a specific type"; `sub_unit_category = sub_unit_category:army_auxiliary`; `is_levy`, `is_mercenary`, `is_condottieri` | sub_unit | **[V-FILE]** `government_reforms/country_specific.txt:1978 limit = { any_sub_unit = { sub_unit_type = unit_type:a_farfanes } }`; `country_interactions/lend_unit_to_ally.txt:92-100,212` |
| `total_sub_unit_type_count:<unit_type>` (value), `total_sub_unit_count:<category>` (value) | country | **[V-FILE]** `country_specific.txt:1969 value = total_sub_unit_type_count:a_farfanes`; `hegemons/1_naval_hegemon.txt:5-6 total_sub_unit_count:navy_heavy_ship > 0` — ideal for "how many HQ regiments does this country have" |
| `army_size`, `regular_army_size` ("army size of regulars (maximum strength)"), `army_size_percentage`, `expected_army_size`, `army_maintenance` | country | **[V-WEB]** wiki; `parliament.txt:1261 limit = { regular_army_size > 0 }` **[V-FILE]** |
| `at_war`, `is_at_war_with = <country>`, `is_enemy_of = <country>`, `is_in_losing_war`, `is_fighting_war_together_with`, `war_score_in_war(<war>)`, `war_score_versus(<country>)`, `months_since_war`, `war_exhaustion` | country | **[V-WEB]** wiki Triggers; `is_at_war_with` in 157 files **[V-FILE]** |
| `is_war_leader_of = <war-scope>` — "Checks if the current country scope is a war leader of the target war" | country | **[V-FILE]** `country_interactions/ask_for_access_for_war_side.txt:58 is_war_leader_of = root`, `on_action/_hardcoded.txt:184 is_war_leader_of = prev`. **`is_war_leader`/`war_leader` do not exist** as triggers/links (exe: 0 hits). |
| `is_in_war = <country>` ("Is the target country in the war?"), `war_score_of_country(<country>)`, `war_score_of_country_side`, `war_length`, `war_goal_type`, `war_stalling_length`, `is_no_cb_war` | war | **[V-WEB]** wiki |
| `has_siege` (location), `besieger_strength` (siege), `in_assault` | location/siege | **[V-WEB]** wiki |
| `location_peace_cost`, `is_capital`, `has_location_modifier`, `location_modifier_strength`, `location_rank = location_rank:city` | location | **[V-WEB]** wiki; `hre.txt:2235` **[V-FILE]** |
| `is_overseas_for_owner = yes/no`, `would_be_overseas_for = <country>` | location | **[V-FILE]** `building_types/plantation_buildings.txt:17`, `colonial_charter_goals/form_colonial_nation.txt:12` |

Comparison operators `< <= = != > >=` (wiki Triggers); inside `NOT = { }` comparisons invert. Iterators "examine only one of the relevant scopes" unless `count = N` / `percent = x` is given (wiki).

### 4.4 War scopes and links **[V-WEB wiki Scope_link + V-FILE]**

- country → war: `any_current_war` / `every_current_war` / `random_current_war` / `ordered_current_war` "Iterate through all wars of a country" (**[V-FILE]** `country_interactions/appanage_call_to_war.txt:14-17`):
  ```
  any_current_war = {
  	OR = {
  		attacker_leader = scope:actor
  		defender_leader = scope:actor
  ```
  and `:88 random_current_war = {`; `war_with_country(<country>)` "Gets the current war of the country scope against the specified target country" (link, country → war); `civil_war` (country → war).
- war → country links: `attacker_leader`, `defender_leader`, `original_attacker_leader`, `original_defender_leader`; `war_goal_province` (war → province, "falls back to the defender's capital"); `ask_for_access_for_war_side.txt:125 add = "opinion(scope:war.defender_leader)"` **[V-FILE]**.
- war → country iterators: `every_war_participant` / `ordered_war_participant` / `random_war_participant` / `any_war_participant` "Iterate through all participants of a war"; `ordered_attacker`, `ordered_defender`, `random_attacker`, `random_defender`, `any_attacker`, `any_defender`.
- country → country: `every_enemy` / `any_enemy` "Iterate through all Enemy countries"; `every_enemy_war_leader` / `random_enemy_war_leader` "countries which are leading a war against the scope"; `every_country_at_war_with`, `every_country_together_in_war_with` "an ally in any of the country scope's wars"; links `overlord`, `top_overlord`, `largest_army` (country → unit), `capital` (→ location).
- none → war: `every_war` / `ordered_war` / `random_war` / `any_war` "all wars going on globally".
- unit links: `owner` (→ country), `unit_location`, `unit_destination`, `unit_next_location` (→ location), `leader` (unit → character); sub_unit links: `owning_unit`, `owner`, `subunit_home`, `controller`.
- Scope syntax (wiki Scope): `root` "The head of the current top scope", `prev` "The previous scope", `this`, `scope:name` "Reference a previously saved scope via its name"; `save_scope_as = x` **[V-FILE]** `conquistador.txt`, `parliament.txt:1267`; `c:TAG` "Scope to the specified country TAG"; `continent:europe`, `unit_type:x`, `sub_unit_category:x`, `location_rank:city`, `modifier:x`, `societal_value:x` literal links **[V-FILE]**.
- Scope types that exist (wiki Scope list, relevant subset): `country, character, location, province, area, region, continent, sub_continent, unit, subunit (sub_unit), unit_type, sub_unit_category, war, siege, combat, combat_side, casus_belli, peace_treaty, military_stance, mercenary, rebel, pop, market, international_organization, age, value, bool, none`.

### 4.5 Continents / overseas **[V-FILE]**
```
in_game/common/scripted_triggers/exploration_triggers.txt:16   capital.continent = continent:europe
in_game/common/scripted_triggers/exploration_triggers.txt:52   continent = continent:europe      # location scope
in_game/common/scripted_triggers/country_triggers.txt:1233     capital.continent = scope:defender.capital.continent
```
`continent` is a link from location/area/province/region/sub_continent (wiki Scope_link); iterators `any/every/random_location_in_continent`, `any_ownable_location_in_continent`, `any_region_in_continent`, `any_sub_continent(_in_continent)`; `sub_continent` is used 331× in vanilla vs `continent` 293×. There is **no** `is_on_continent` / `same_continent` trigger (0 vanilla hits). For "unit is overseas": combine `unit_location = { is_overseas_for_owner = yes }` or `unit_location.continent != owner.capital.continent` — individual pieces verified, the combination is **[UNVERIFIED]**. Define `AI_WESTERN_COLONIZATION_CONTINENTS = { "europe" }` (`00_defines.txt` NAI block, line ≈645) shows continent keys are plain strings like `europe`.

### 4.6 On-actions relevant to the mod

Vanilla hardcoded list with line numbers in `game/in_game/common/on_action/_hardcoded.txt` **[V-FILE]**: `on_game_start`(1) `on_game_started_after_lobby`(316) `on_siege_won`(321) `on_siege_lost`(447) `on_location_occupied`(494) `in_battle`(629) `on_civil_war_start`(1124) `on_civil_war_lost`(1326) `on_civil_war_won`(1477) `on_winning_war`(1534) `on_join_war`(1875) `on_losing_war`(1930) `on_pre_ending_war`(1955) `on_pre_winning_war`(1959) `on_pre_losing_war`(2035) `on_ending_war`(2039) `on_pre_war_declared`(2351) `on_war_declared`(2395) `on_battle_won_character`(2886) `on_battle_lost_character`(2956) `on_great_battle_won`(2983) `on_great_battle_lost`(3143) `on_battle_won`(3209) `on_battle_lost`(3335). Pulses: `monthly_country_pulse` (`country_monthly.txt:2`), `biyearly_country_pulse` (`country_biyearly.txt:4`), `yearly_country_pulse` (wiki; file `country_yearly.txt`).

Scopes (wiki On_actions) **[V-WEB]**: `on_war_declared` root country, `scope:actor`, `scope:recipient`, `scope:war` (**[V-FILE]** `_hardcoded.txt:2395-2412` uses `scope:actor`/`scope:recipient`); `on_winning_war`/`on_losing_war`/`on_ending_war`/`on_pre_*`: `scope:winner`, `scope:loser`, `scope:war`; `on_battle_won`/`on_battle_lost`: root = winning unit's actor, `scope:actor` (winning unit), `scope:target` (losing unit), float scopes for killed/lost land & navy, `scope:war_score`; `on_siege_won`: root country, `scope:target` (location), `scope:character`; `on_location_occupied`: root country, `scope:target`, `scope:character`; `on_command_gained`/`on_command_lost`: root character, `scope:unit`; `on_join_war`: country; `in_battle`: character, every tick while supreme commander.
Block syntax (wiki): `trigger`, `weight_multiplier`, `events`/`random_events`/`first_valid`, `on_actions`/`random_on_action`/`first_valid_on_action`, `effect` ("runs alongside any events fired … doesn't share scopes or variables with them"), `fallback`, `delay` (`months = { 6 12 }`).

### 4.7 Scripted GUI, scripted widgets, GUI overrides

Official template `game/in_game/common/scripted_guis/scripted_guis.info` **[V-FILE]** (verbatim):
```
scripted_gui_key = {
	scope = < string >			# What scope type this SGUI is available to
	is_shown = { trigger }		# Determines whether the SGUI is shown / available to a player
	is_valid = { trigger }		# Determines whether the SGUI can be used by a player
	effect = { effect }			# Determines what will happen when the SGUI element is activated
	saved_scopes = { scopes }	# List of strings corresponding to scopes you want event targets for in triggers / effects
	notification_key = < key >	# Notification key when this SGUI is activated (default jomini_scripted_gui_confirm)
	confirm_title = {}			# Confirmation window title for this SGUI
	confirm_text = {}			# Confirmation window text for this SGUI
	ai_is_valid = { trigger }	# Whether this SGUI is available to the AI or not (default false)
	ai_chance = { }				# The chance that the AI will activate this SGUI (script value between 1 and 100)
	ai_frequency = {}			# Named value determining how frequently the AI will evaluate this SGUI (in months)
}
```
GUI side (wiki Scripted_gui) **[V-WEB]**: `onclick = "[GetScriptedGui('my_scripted_gui').Execute(GuiScope.SetRoot(GetPlayer.MakeScope).End)]"`, `visible`/`enabled` via `.IsShown(...)`/`.IsValid(...)`, extra scopes via `.AddScope('target_country', …)` matching `saved_scopes`; functions `Execute, IsShown, IsValid, BuildTooltip, ExecuteTooltip, IsShownTooltip, IsValidTooltip`.

Scripted widgets — official `game/main_menu/gui/scripted_widgets/_scripted_widgets.info` **[V-FILE]** (verbatim):
```
Scripted widgets are a way of creating widgets without needing to define them inside an existing .gui file.

A scripted widget is declared following this format within a .txt file inside this folder:
gui/scripted_widget_file_name.gui = scripted_widget_name

Note: The scripted widget inside the .gui file is required to have a 'visible' attribute.
'visible = yes' does not work, the boolean must be returned by a function.
As a workaround, 'visible = "[EqualTo_CFixedPoint('(CFixedPoint)0', '(CFixedPoint)0')]"' works as an equivalent to 'visible = yes'.
```
Mod usage **[V-FILE]** `…/3600272327/in_game/gui/scripted_widgets/sakuya_scripted_windows.txt:1 gui/sakuya_test.gui = sakuya_window` (18 windows). The folder is `in_game/gui/scripted_widgets/` (vanilla only has the `.info` under `main_menu/gui/scripted_widgets/`; the wiki guide: "This folder is not in the vanilla files but without it your window will not appear", file must be UTF-8-BOM). Console fallback: `GUI.CreateWidget gui/mymod_interface.gui mymod_window`, `GUI.ClearWidgets mymod_window` — the user already did `GUI.CreateWidget gui/simple_cheats_ui.gui simple_cheats_window` (`Documents/…/console_history.txt`) **[V-FILE]**.

GUI file facts **[V-FILE]**: `game/in_game/gui/single_unit_window.gui` opens with `types SingleUnitWindowTypes` (line 2) and selects tabs through a window variable (`:3697 visible = "[SingleUnitWindow.Vars.NotExistOrHasValue( 'tab', 'actions' )]"`, values seen: `'actions'`, `'formation'`); `ingame_topbar.gui` has file-local templates (lines 26-76) and four top-level `widget = {` blocks (99, 648, 654, 659). GUI constants `@name = value` are file-scoped (CMF wiki). gui.log reports parse problems, e.g. `gui/sakuya_change_name.gui:199 - Unknown vertical anchor in 'center|top', will use top for vertical anchor` **[V-FILE]**.

Interface modding guide **[V-WEB]**: in debug mode use **UI Bounds** (2D Tools), `Alt+LMB` cycles widgets under cursor, `Alt+RMB` opens the source file; "the changes you are making in the files will be visible immediately"; prefer adding a `type` referenced from a one-line vanilla edit — "a lot easier to keep updated with changing vanilla files and to keep compatible with other mods".

### 4.8 Modifiers, unit types, defines, AI script surface

- Static unit modifier example `game/main_menu/common/static_modifiers/unit.txt:85-91` **[V-FILE]**:
  ```
  extensive_training_modifier = {
  	game_data = { category = unit }

  	discipline = 0.05
  	experience_decay = -0.025
  	monthly_experience_gain = 0.1
  }
  ```
  `D008_fate_of_the_phoenix_modifiers.txt:309-315` adds `decaying = yes` inside `game_data`. Loc keys: `STATIC_MODIFIER_NAME_<key>`, `STATIC_MODIFIER_DESC_<key>` (wiki Modifier_modding; Cheat Menu Pro loc uses `STATIC_MODIFIER_NAME_sakuya_…` **[V-FILE]**). Wiki: "Modifiers can be applied … using `add_<type>_modifier = { }`", duration `years/months/weeks/days`, `size` multiplies strength; category decides the applicable effect.
- Modifier types that exist in `game/main_menu/common/modifier_type_definitions/` **[V-FILE]** (grep): `siege_ability`, `discipline`, `land_morale`, `land_morale_modifier`, `land_morale_recovery`, `land_morale_attrition_cost`, `land_morale_movement_cost`, `morale_recovery_in_friendly`, `land_unit_attrition`, `local_army_attrition`, `local_hostile_attrition`, `global_hostile_attrition`, `max_attrition`, `occupation_time`, `owner_gets_vision_when_occupied`, `max_siege_memory`, `global_war_score_efficiency`, `local_war_score_efficiency`, `lack_of_control_impact_on_warscore`, `expected_warscore_modifier`, `war_score_vs_other_religion_efficiency`, `convert_occupied_territory_price_cost_modifier`. Unknown types fail loudly: `[pdx_persistent_reader.cpp:289]: Error: "Unknown modifier type: colonial_maintenance_cost. It is either invalid, or a potential dynamic modifier type definition missing from the database…" in file: "common/static_modifiers/sakuya_cheat_modifiers.txt" near line: 397` **[V-FILE]**. New types go to `common/modifier_type_definitions` (wiki: fields `decimals`, `color = neutral|good|bad`, `percent = yes`, `boolean = yes`, `prefix`/`suffix`, `game_data`).
- Unit type count limit — `limit` script value, country scope **[V-FILE]** `game/in_game/common/unit_types/1_uniques_for_age_4_reformation.txt:199-205`:
  ```
  limit = {
  	value = {
  		value = 2
  		desc = "SUBUNIT_LIMIT_BASE"
  	}
  	add = modifier:num_of_banner_cavalry
  }
  ```
  and `:72-77` (`value = num_provinces`), `1_uniques_for_age_6_revolutions.txt:23-31` (`multiply = { value = societal_value:quality_vs_quantity … }`). Wiki Unit_modding: "`limit` is a script value that can be used to limit the amount of a subunit that a country may have"; other fields `category`, `copy_from`, `max_strength` ("the amount of men in the subunit"), `age` (required), `buildable`, `levy`, `country_potential`, `location_potential`/`location_allow`, `unlock_unit` (advance), `upgrades_to`, `gfx_tags`, loc `<key>` + `<key>_desc`.
- Script values (wiki Script_value) **[V-WEB]**: `common/script_values/`, operators `value add multiply divide min max` evaluated in order ("no order of operations like PEMDAS"), `if = { limit = {…} value = … } else_if else`, inline blocks are "interchangeable" with named values, `every_` iterators allowed (`every_owned_location = { add = tax_base }`), "random_ is not allowed", "A value should never depend on itself directly". `floor`/`round` operators: **[UNVERIFIED]**.
- Defines of interest, `game/loading_screen/common/defines/00_defines.txt` NAI block (starts line 565; line = 564 + offset) **[V-FILE names/values; semantics INFERRED from names/comments]**: `AI_PERFORMANCE_ATTACH_UNIT_MAX_DISTANCE = 200` (838), `HUNT_ARMIES_MAX_RADIUS = 20` (994), `HUNT_ARMIES_WIN_CHANCE_SPLIT = 0.99` (997), `HUNT_ARMIES_MAX_SPLINTERS = 6` (998), `HUNT_ARMIES_DESIRED_STRENGTH_MULT = 1.5` (1000), `HUNT_ARMIES_AI_MAX_NUM_OBJECTIVES = 5` (1004), `MAXIMUM_ALLOWED_NUMBER_OF_EACH_OBJECTIVE = 20` (1013), `MAXIMUM_ALLOWED_SIDE_OBJECTIVES = 10` (1014), `CARPET_SIEGE_REQUIRED_WIN_CHANCE = 0.8` (1016), `CARPET_SIEGE_CONFRONT_FACTOR = 0.5` (1017), `CARPET_SIEGE_MAX_ARMIES = 10` (1021), `AI_NAVAL_INVASION_PORT_PREFERENCE = 5.0` (1022), `RATIO_OVER_SUPPLY_TARGET_TO_SPLIT = 1.3` (1026), `RELEVANT_ARMY_MIN_RAW_STRENGTH = 0.025` (1038), `AI_HOSTILE_BORDER_MIN_SUBUNITS = 3` (1061), `AI_AWAIT_REINFORCING_ARMY_DISTANCE_MAX/MIN = 35/20` (1131-1132), `AI_STICK_TO_SIEGE_TIME_FACTOR = 0.003` (1134), `AI_WAIT_FOR_JOINING_UNIT_STRENGTH_THRESHOLD = 0.33` (1135), `AI_LAND_ARMY_MERGE_THRESHOLD = 0.80` (1137), `AI_ATTACH_FRONTAGE_SCORE_WEIGHT = 0.5` (1138), `AI_ATTACH_MIN_FRONTAGE_ROOM = 1.0` (1139), `AI_MILITARY_ARMY_ASSIGNMENT_PROXIMITY_FACTOR = -1` (1147), `DEFAULT_REGULAR_ARMY_PREFERENCE = 1` (1254), `LEVY_ARMY_PREFERENCE_FACTOR = 0.5`, `MERCENARY_ARMY_PREFERENCE_FACTOR = 1.33` (1259-1260), `AI_WESTERN_COLONIZATION_CONTINENTS = { "europe" }` (645), `AI_EAGER_COLONIZER_TAGS = { "SWE" "POR" "KUR" }` (643). Wiki Defines additionally lists `AI_SUPPLY_LIMIT_TARGET (0.95)`, `AI_RECOVER_MORALE_THRESHOLD (66)`, `AI_RETREAT_DICE_MARGIN (3)`, `AI_ASSAULT_FORT_BREACH_STRENGTH_NEEDED (1.5)`, `EXPECTED_WAR_SCORE_BASE (25)`, `PEACE_OFFER_WAR_SCORE_THRESHOLD (50)`. NWar block: lines 2665-2727.
- AI script surface (what is scriptable at all) **[V-FILE]**: `in_game/common/ai_personalities/00_ai_personalities.txt` (header: "Each personality shifts the country's behavioral profile via AI-only modifiers … Willingness / Tolerance / Priorities"; modifier keys such as `aggressiveness_modifier`, `carefulness_modifier`, `win_war_chance_threshold`, `ai_months_between_wars`, `expected_warscore_modifier`, `mercenary_units_preference_modifier`, `manpower_importance_modifier`); `on_action/ai_personalities_setup.txt` (assigns personalities to `is_ai = yes` countries, game rule `ai_personalities_random`); `ai_scripted_expansion_score/` and `ai_scripted_expansion_target/` (readme: `attacker_potential`, `target_trigger`, `score`, `multiplier`, `never_attack`; `candidate_list`, `casus_belli`, `ignore_antagonism`, `sort_value` — tied to `EXPANSION_TARGET_SCORE_NEEDED_TO_PICK`); `ai_diplochance/`; `generic_action_ai_lists/`; `unit_categories` `ai_weight` and casus belli `ai_selection_desire`/`ai_subjugation_desire`/`ai_cede_location_desire` (wiki); `ai_is_valid`/`ai_chance`/`ai_frequency` on scripted GUIs; `ai_will_do` on actions. **Army movement/objective logic itself is hardcoded** — only the NAI defines above, the objective UI (`military_objective_groups.gui`, 545 lines) and Tinto Talks #46's "AI uses the same objective building blocks as the player" are the levers. The wiki "AI" modding page is a red link (not written). Patch notes 1.4.x contain no AI-army rework: 1.4.7 "AI armies no longer stop short of their destination when their movement is locked", 1.4 "Updated holy war AI…", "Leadership is no longer auto-granted to the most powerful country" **[V-WEB]**. A third-party mod "REAI: Rational Empire AI [1.3]" claims to make the AI "consolidate its military into 2 main, powerful armies" (https://catalogue.smods.ru/?p=432989) — **[UNVERIFIED]**, but worth reading its files for which defines it touches.

---

## 5. Patch 1.4 facts relevant to the mod **[V-WEB]**
- 1.4 "Río Salado" shipped as 1.4.5 with *Across the Pillars* on 2026-10-28 (checksum 200c); 1.4.6 hotfix 2026-10-30; 1.4.7 2026-11-03 (SteamDB 26377361). The installed build is 1.4.7 (`setup.log` build timestamp 2026-10-29, exe dated Nov 3).
- Warfare lines (wiki Patch_1.4): "Large empires are now easier to chip away at once they have been beaten"; "an unoccupied fort no longer slaps you with the full penalty when you have actually committed to a siege"; "the victor of a defensive war now earns a decisive-defender discount"; "A location at 27% control contributes 27% of its military weight even with strong government modifiers" (control gating of military weight — interacts with a warscore rework); cavalry nerf: "infantry becomes more competitive sooner and cleanly overtakes cavalry by the Reformation", "Flanking bonuses have also been brought down"; new camel cavalry/auxiliary units.
- Modding lines: 1.4 "Updates to the Mod Manager to improve usability"; 1.4.7 "Fixed CTD when retrieving a location owner from UI when using mods."
- Relevant dev diaries (wiki Developer_diaries): #46 Military objectives (2025-01-15, threads/1726045), #22 Armies and combat (threads/1696537), #23 Logistics and sieges (threads/1697510), #56 Diplomacy/warfare update (threads/1733172), #104 "1.2 Military and Misc. Changes" (threads/1917017), #113 AI Disposition (threads/1929503), #85 Modding (threads/1864004), 1.1 "Levy, mercenary & regular" unit-type rework (threads/1894259). All on forum.paradoxplaza.com (fetch-blocked; read in a browser).

---

## 6. Community Mod Framework (CMF) — what it is, and whether to depend on it

Facts **[V-WEB]**:
- Repo https://github.com/Europa-Universalis-5-Modding-Co-op/community-mod-framework (ISC licence), Workshop id 3692202776 (from README via search), authors Bahmut/Pickle; a separate "Caesar's Version" fork exists (CaesarVincens). "The framework is designed to be invisible when no dependent mods are active."
- Features: Community Mod Menu (settings registration API: toggles, sliders, dropdowns, buttons, text, lists; browser-based CMM Visual Editor), Action Bar, Custom Alerts, Mod Banners (lobby), Mod Action Log, `is_host` trigger, `cmf_is_mod_active = { mod_id = x }` / `cmf_was_mod_active_at_game_start`, `cmf_suppress` (silences "used but never set" warnings), NAND/NOR/XOR GUI macros, Dependency Check Popup (drop-in `main_menu/gui/cmf_dependency_check.gui`, "entirely self-contained", offers Enable / Open Workshop / Ignore when CMF is missing).
- On-action hooks (wiki On-Action-Hooks): `on_game_start_after_lobby(_human_country)`, `on_game_load(_human_country)`, `on_game_load_after_lobby(_human_country)`, `cmf_on_country_transfer` (`scope:old_country`, `scope:new_country`), `cmf_yearly_human_country_pulse`, `cmf_monthly_human_country_pulse`, plus `cmf_on_mod_registration` and `cmf_on_callback` (used by Cheat Menu Pro, **[V-FILE]**; `var:cmf_callback` carries the flag of the clicked setting). Pattern: `cmf_yearly_human_country_pulse = { on_actions = { your_mod_on_yearly } }`.
- "Improved Vanilla Top-Level Widget Overrides": CMF ships extracted `types`/`templates`/constants for 7 vanilla files under `in_game/gui/vanilla/`: `cmf_foreign_country_lateralview_vanilla_types.gui`, `cmf_government_lateralview_vanilla_types.gui`, **`cmf_ingame_topbar_vanilla_types.gui`**, `cmf_location_window_vanilla_types.gui`, `cmf_outliner_entries_vanilla_types.gui`, **`cmf_single_unit_window_vanilla_types.gui`**, `cmf_technology_lateralview_vanilla_types.gui` — "your override only needs the top-level widget itself"; "reduces the chance of conflicts … but doesn't eliminate them"; two mods overriding the same top-level widget still conflict. CMF "doesn't itself override the vanilla files" (wiki) but its Steam page says it "makes several changes to GUI files" and should load "before/above any other mods".
- Versions: main-branch metadata says `2.4.1`, `supported_game_version "1.3.*"`, `cmf_last_updated_game_version "1.3.10"`; a mod listing dated Oct 2026 shows a "1.4 Río Salado" build (unfetched) — current 1.4.7 compatibility **[UNVERIFIED]**. Dependency declaration: `{"rel_type":"dependency","id":"community_mod_framework","display_name":"Community Mod Framework","resource_type":"mod","version":"2.*"}` **[V-FILE Cheat Menu Pro]**.

Assessment: **do not make Concentrated Warfare depend on CMF.** Reasons: (1) nothing we need is CMF-only — new windows come from `scripted_widgets`, settings can be game rules (`main_menu/common/game_rules`), pulses are vanilla on_actions; (2) its value for us (extracted types for `ingame_topbar.gui`/`single_unit_window.gui`) is exactly the part most likely to go stale between patches, and the dependency is not enforced by the game anyway (Cheat Menu Pro ran without it, producing `Unknown effect` lines); (3) it edits GUI files other mods fight over. Optional later: a tiny `cw_cmm` **submod** that registers CMM toggles through `cmf_on_mod_registration`, guarded so the main mod never references `cmm_*` effects.

---

## 7. Debug workflow (concrete, for this machine)

1. **Launch**: Steam → EU5 → Properties → Launch Options: `-debug_mode` (wiki: "activates the console and dev tools, enables hotloading of mod file changes (except files such as on_action), and adds a button that opens error.log"). The wiki also documents `--ignore-disable-mods-on-crash` ("If the game crashes during loading resources, it will load with all mods disabled the next time" — this flag forces the same playset) **[V-WEB, exact semantics per wiki]**. Debug mode cannot be re-enabled from the console once turned off.
2. **Console**: `` ` `` on QWERTY (Alt+C / Shift+Alt+C on other layouts). Commands verified as strings in `eu5.exe` **[V-FILE]** and documented on the wiki **[V-WEB]**: `script_docs` (alias `script_documentation`) "Prints script documentation" → `Documents/Paradox Interactive/Europa Universalis V/docs/` (effects, triggers, scopes, event targets, on_actions, modifiers…); `dump_data_types` (alias `DumpDataTypes`) "dumps the registered data types" → `logs/data_types/` (GUI data functions such as `SingleUnitWindow.*`, `InGameTopbar`, `UnitDetailsView`); `reload [file name]` "Reloads assets"; `switchlanguage`; `effect [{effect script}]`; `run [{effect file}]` ("execute effect file in /run"); `trigger [{trigger script}]`; `event [eventid] [target]`; `test_event_trigger`; `observe` (`ob`); `ai [TAG]` "Create/disable AI for tag"; `YesMan`; `error` "Show errors in log"; `Log.ClearErrorLog` "Clears out error.log and resets the error count"; `gamelog`; `helplog` (prints all commands to game.log); `GUI.CreateWidget gui/x.gui window`; `GUI.ClearWidgets window`; `gui_animation_editor`; `portrait_editor` (`pe`); `debug_mode` (toggle). Neither `docs/` nor `logs/data_types/` exists yet on this machine → **run `script_docs` and `dump_data_types` first**; they are "the most reliable technical documentation you can get" (wiki Modding) and the only 1.4.7-accurate effect/trigger list (no public GitHub dump exists).
3. **Logs** (`C:\Users\fyrno\Documents\Paradox Interactive\Europa Universalis V\logs\`) **[V-FILE]**: `error.log` (rotates at 1 MB into `error.1.log`…`error.5.log`; in the last session it was 100 % vanilla Russian-localization spam — 455× `Data error in loc string 'dynastic.14.b.nickname'` / `FetchData failed for 'Select_CString(CHARACTER.IsFemale, 'Ложная', 'Ложный')'`, plus `location_suffix_russian`, a Wwise event and one `Reloadable widget [gui/alertmanager.gui]:[discard_stash] still registered` — none from the installed mods); `debug.log` (95 MB; contains mod mounting, `Unknown effect …`, `Unknown modifier type …`, `Duplicated key …`, `should be in utf8-bom encoding`, duplicate-localization lines); `gui.log` (GUI parse warnings with `file.gui:line`); `game.log` (5 MB); `ai.log` (2.4 MB — AI decisions, use it to validate army-concentration changes); `database_conflicts.log`, `warning.log`, `message.log` (empty here); `performance_degradation.log`; `multiplayer.log`; `ecs.log`. Because of the loc spam, grep `debug.log` for mod issues (`grep -a -iE "cw_|Unknown|Duplicated|utf8-bom" debug.log`) or play in English, or `Log.ClearErrorLog` right after loading and reproduce.
4. **Hot reload**: debug-mode file watcher reloads changed files including mods; `.gui` edits show immediately; `on_action` (and probably database structure changes) need a restart.
5. **GUI debugging**: UI Bounds (2D Tools), `Alt+LMB` cycle widgets, `Alt+RMB` open source; `gui.log` for parse errors; `dump_data_types` output to find `SingleUnitWindow`/`InGameTopbar` functions.
6. **Static validation before launching**: the project already has `tools/validate.sh` + `tools/validate.pl` (builds `tools/cache/vanilla_script_keys.txt` from vanilla `common`/`events`/`dlc`/`jomini` keys and validates the mod) **[V-FILE]**; extend it to flag `visible = yes` in scripted widgets, missing BOMs, and `merge_unit`/`create_unit`/`num_owned_locations`/`is_war_leader`-style non-existent names.
7. **Playset**: enable the mod in the main-menu mod manager (creates/updates `playsets.json`); confirm in `debug.log` that `…/concentrated_warfare/in_game` and `/main_menu` (and `/loading_screen` if defines are shipped) are "Mounted Data" and that "Mod Concentrated Warfare (concentrated_warfare) version 1.4.* successfully matched game version 1.4.7" appears.

---

## 8. Pitfalls

1. **Stale full-file GUI overrides**: Simple Cheats ships `in_game/gui/panels/left_panel.gui` (based on an older vanilla; 490 diff lines, no BOM), but in 1.4.7 the vanilla file is `in_game/gui/panels/left_panel/left_panel.gui` **[V-FILE]** — the override no longer shadows anything (hence the user's manual `GUI.CreateWidget`). Worse, a mis-pathed `.gui` is still loaded and its `template`/`type` definitions may override the live ones (last-loaded wins) **[INFERRED]**. Pin vanilla copies to a patch and diff them on every update.
2. Folder is `common/on_action` (singular). Cheat Menu Pro's `common/on_actions/` file is emptied with a "#我删除了" ("I deleted it") comment — the plural folder is dead **[V-FILE + INFERRED]**.
3. Duplicate keys are dropped, not merged (`Duplicated key … will not be created`). Modifying a vanilla object (unit type, static modifier, CB, wargoal, on_action trigger/effect) needs `REPLACE:`/`INJECT:` or a full-file override — plain redefinition silently loses **[V-FILE + INFERRED]**.
4. Unknown modifier type / unknown effect are only logged (`debug.log`/`error.log`), the game keeps running with the block ignored — easy to miss.
5. UTF-8-BOM everywhere (`.txt`, `.gui`, `.yml`); the `.yml` without BOM is *silently ignored* (wiki).
6. Localization overrides only via `localization/<lang>/replace/`; duplicate keys inside the mod are logged as errors; keep every key `cw_`/`CW_`-prefixed. Mod localization lives under `main_menu/localization/<lang>/` (vanilla layout); Russian spam in `error.log` comes from vanilla, not from mods.
7. `supported_game_version` mismatch is a warning, not a block; `relationships` are not enforced.
8. `metadata.json` tags should be the `SteamRef` strings from `create_mod_tags.json`; `name` with Cyrillic/em dash is untested on upload.
9. Scripted widget windows need `visible = "[…function…]"`, never `visible = yes` (official `.info`).
10. GUI anchor values like `'center|top'` are invalid (gui.log warnings in Cheat Menu Pro).
11. `merge_unit`, `split_unit`, `create_unit`, `num_owned_locations`, `is_war_leader`, `is_on_continent`, `same_continent` do **not** exist (see §4). Use `add_subunit`/`create_sub_unit_with_owner`, `num_locations`, `is_war_leader_of = <war>`, `capital.continent = …`.
12. Wiki accuracy: most pages are flagged "last verified for 1.0–1.3"; the load-order page is 1.1. Treat §3 rules as hypotheses to confirm with a 10-minute test mod (§11).
13. Defines must be in `loading_screen/common/defines/` with a filename sorting after `00_defines.txt` (e.g. `zz_cw_defines.txt`); only the keys listed are replaced.
14. A symlinked `Documents/…/mod/concentrated_warfare` may not be scanned; use a junction or copy if the manager does not list the mod.
15. `error.log` rotates every few minutes under the vanilla loc spam; load-time errors vanish from it — read `debug.log`.
16. Forum dev diaries (Tinto Talks) cannot be fetched by tools (Cloudflare); keep manual notes in `docs/research/` after reading them in a browser.

---

## 9. Recommendations for the mod

1. **Packaging**: keep the current `.metadata/metadata.json` (§2.4); add `main_menu/localization/english/cw_l_english.yml` + `russian/cw_l_russian.yml` (BOM, `cw_`-prefixed keys), `main_menu/common/static_modifiers/cw_unit_modifiers.txt`, `in_game/common/{scripted_effects,scripted_triggers,script_values,on_action,unit_types,scripted_guis}/cw_*.txt`, `in_game/gui/cw_*.gui` + `in_game/gui/scripted_widgets/cw_scripted_widgets.txt`, `loading_screen/common/defines/zz_cw_defines.txt`. No `relationships`, no `replace_paths`.
2. **HQ regiment** = a new `unit_types` entry (`cw_headquarters`, `max_strength = 100`, own `category` or `army_auxiliary`, `buildable = yes`, `limit = { value = 1 add = { value = num_locations divide = 100 } add = <age term> }` — pattern verified in vanilla `limit` blocks; exact operators to confirm via `script_docs`). Count per country via `total_sub_unit_type_count:cw_headquarters`; detect in an army via `any_sub_unit = { sub_unit_type = unit_type:cw_headquarters }` (both **[V-FILE]** patterns). Cost 0 is a unit-category price question (`<key>_build/_reinforce/_maintenance` per wiki Unit_modding).
3. **"No HQ" penalty** = static modifier `cw_no_hq = { game_data = { category = unit } siege_ability = -0.9 discipline = -0.1 land_morale_modifier = -0.1 }` (all three type names exist **[V-FILE]**), applied/removed in `monthly_country_pulse` (`cw_monthly = { on_actions = … }` hook appended by plain redefinition, as CMF/Cheat Menu Pro do) with `every_army = { if = { limit = { NOT = { any_sub_unit = { sub_unit_type = unit_type:cw_headquarters } } } add_unit_modifier = { modifier = cw_no_hq months = 2 mode = replace } } else = { remove_unit_modifier = cw_no_hq } }`. No positive HQ modifier, per design. Also react in `on_battle_won`/`on_siege_won`/`on_war_declared` where immediate re-evaluation matters.
4. **Colonial HQ** = second unit type `cw_colonial_headquarters` with `limit` based on owning locations where `is_overseas_for_owner = yes` (count via `any_owned_location = { count >= 1 is_overseas_for_owner = yes }` / a script value with `every_owned_location`), and a small `cw_colonial_hq_bonus` unit modifier applied only when `unit_location = { is_overseas_for_owner = yes }` (combination **[UNVERIFIED]**, pieces verified).
5. **AI**: first measure with `ai.log` + observer, then tune NAI defines in `zz_cw_defines.txt` — candidates `RATIO_OVER_SUPPLY_TARGET_TO_SPLIT`, `HUNT_ARMIES_MAX_SPLINTERS`, `HUNT_ARMIES_WIN_CHANCE_SPLIT`, `CARPET_SIEGE_MAX_ARMIES`, `AI_LAND_ARMY_MERGE_THRESHOLD`, `AI_ATTACH_*`, `AI_PERFORMANCE_ATTACH_UNIT_MAX_DISTANCE`, `AI_AWAIT_REINFORCING_ARMY_DISTANCE_*`, `AI_HOSTILE_BORDER_MIN_SUBUNITS`, `AI_NAVAL_INVASION_PORT_PREFERENCE`. Script-side: give the AI its HQs for free in `on_game_started_after_lobby` + yearly pulse (`create_sub_unit_with_owner` into `largest_army.unit_location`, or `ordered_army = { order_by = num_subunits max = 1 add_subunit = unit_type:cw_headquarters }`), so the AI never lacks one in its main stack; overseas fighting is preserved by giving colonial HQs to countries with overseas locations.
6. **War stance** = country variable (`set_variable = { name = cw_stance value = flag:offensive }`) recomputed monthly for `is_ai = yes` countries from `any_current_war`, `war_score_in_war(<war>)`, `army_size` vs enemy, `is_in_losing_war`; show for the player via a scripted-widget plate (own `.gui`, `visible` via a function) rather than editing `ingame_topbar.gui`; read it in GUI through the data functions found in `dump_data_types` output (**[UNVERIFIED]** names).
7. **Warscore rework**: start with wargoal/CB fields (`ticking_war_score`, `max_warscore_from_battles`, `conquer_cost`), the `NWar` defines and the modifier types `local_war_score_efficiency` / `lack_of_control_impact_on_warscore`; change vanilla wargoals with `REPLACE:`/`INJECT:` rather than copying files. (Details in the warfare research doc.)
8. **GUI 4th tab**: `single_unit_window.gui` is a `types` container with tab state in `SingleUnitWindow.Vars('tab')` — the tab strip is a `type` inside it, so try a **type override from our own `.gui` file** (last-loaded type wins per wiki) before resorting to a full-file copy; keep a pinned copy of the 1.4.7 vanilla file in `docs/vanilla_refs/` for diffing on each patch. Avoid CMF.
9. **Process**: run `script_docs` + `dump_data_types` on 1.4.7 before writing script; store the generated `docs/` and `logs/data_types/` under `docs/research/raw/` (outside the game dir) and grep them; extend `tools/validate.pl` with the non-existent-name list from §4.
10. **Versioning**: bump `"version"` on each Workshop upload; keep `"supported_game_version": "1.4.*"` and re-diff vanilla GUI/unit files at every hotfix.

---

## 10. Verbatim log evidence (for reference)

```
logs/debug.log
[20:12:39][dlc_reloadable.cpp:435]: Switching to playset index 2, Name: 1
[20:12:39][dlc_reloadable.cpp:390]: Mod Cheat Menu Pro (sakuya) version 1.4.* successfully matched game version 1.4.7.
[20:12:39][dlc_reloadable.cpp:727]: No directories mounted to search for mods
[jomini_effect.cpp:557]: Unknown effect cmm_register_button_setting at common/scripted_effects/sakuya_cmm_sittings_cmm_effects.txt:3
[pdx_persistent_reader.cpp:289]: Error: "Unknown modifier type: colonial_maintenance_cost. It is either invalid, or a potential dynamic modifier type definition missing from the database.: colonial_maintenance_cost, near line: 397" in file: "common/static_modifiers/sakuya_cheat_modifiers.txt" near line: 397
[gamedatabase.h:409]: Duplicated key sakuya_loc_mod_prosperity_ctrl_left will not be created from file: common/scripted_guis/sakuya_cheat_sgui.txt:27052
[lexer.cpp:513]: File 'common/scripted_guis/sakuya_1_7_sgui.txt' should be in utf8-bom encoding (will try to use it anyways)
[pdx_localize.cpp:221]: Duplicate localization key. Key 'SAKUYA_OPEN_TT' is defined in both 'localization/russian/Cheat_menu_1.6_l_russian.yml' and 'localization/russian/cheat_menu_l_russian.yml'.

logs/gui.log
[20:13:10][pdx_gui_datatypes_reader.cpp:1100]: gui/sakuya_change_name.gui:199 - Unknown vertical anchor in 'center|top', will use top for vertical anchor
[20:12:44][pdx_gui_localize.cpp:302]: gui/shared/geopolitics_tooltips.gui:526 - Failed parsing localized text: COLONIAL_MAINTENANCE_FOR_COLONY_HEADER   (vanilla)

logs/error.log (head)
[00:57:53][pdx_data_localize_helper.cpp:315]: FetchData failed for 'Select_CString(CHARACTER.IsFemale, 'Ложная', 'Ложный')'
[00:57:53][pdx_data_localize.cpp:207]: Data error in loc string 'dynastic.14.b.nickname'
[00:57:53][pdx_data_callstack.cpp:67]: Promote 'CHARACTER' returned nullptr, in 'CHARACTER.IsFemale'
[pdx_gui_context.cpp:249]: Reloadable widget [gui/alertmanager.gui]:[discard_stash] still registered when its context is destroyed (status[2])

Documents/…/console_history.txt
GUI.CreateWidget gui/simple_cheats_ui.gui simple_cheats_window
```

---

## 11. Claims that still need in-game verification

1. The in-game mod manager lists a **symlinked** local mod folder (else junction/copy; or hand-edit `playsets.json`).
2. **Partial defines override** from `loading_screen/common/defines/zz_cw_defines.txt` (e.g. set `NAI = { HUNT_ARMIES_MAX_SPLINTERS = 1 }`, confirm via behaviour/`ai.log`).
3. `REPLACE:`/`INJECT:` are accepted in `unit_types`, `static_modifiers`, `wargoals`, `casus_belli`, `on_action`; and that a plain same-key redefinition of a vanilla object is dropped (first wins) rather than overriding.
4. Appending to a vanilla on_action by plain redefinition (`on_war_declared = { on_actions = { cw_on_war_declared } }`) fires (CMF/Cheat Menu Pro rely on it).
5. A scripted-widget window declared in `in_game/gui/scripted_widgets/cw_scripted_widgets.txt` appears without console commands when `visible` is a function.
6. A `type` defined in `single_unit_window.gui` can be overridden from a separate mod `.gui` file (wiki "last loaded wins"), making a full-file copy unnecessary for the 4th tab.
7. A mis-pathed `.gui` file (Simple Cheats case) is loaded at all and overrides templates — relevant for compatibility warnings.
8. `add_unit_modifier` without duration is permanent (loc entry `add_unit_modifier_forever` suggests it); `mode = replace` semantics.
9. `unit_location = { is_overseas_for_owner = yes }` and `unit_location.continent = owner.capital.continent` work from unit scope.
10. `total_sub_unit_type_count:<type>` on country scope with a **mod-defined** unit type; whether a unit-scope equivalent (`sub_unit_count`) takes a type argument.
11. `limit` script value on a unit type with `num_locations`-based terms and an age term (`current_age_or_later = { age = age_3_discovery }` seen in `conquistador.txt:64` as a trigger) correctly caps recruitment of `cw_headquarters`; whether a zero-cost category is accepted.
12. Localization: first-vs-last duplicate behaviour and the `replace/` folder in 1.4.7.
13. `supported_game_version` mismatch = warning only; tag strings outside `create_mod_tags.json` and non-ASCII `name` on Workshop upload.
14. `-debug_mode` hot-reload coverage in 1.4.7 (which folders), what `reload` accepts, and whether `script_docs` writes to `Documents/…/docs/`.
15. CMF's current Workshop build supports 1.4.7 (GitHub main says 1.3.*) — only relevant if a CMM submod is made.
16. Script-value operators `floor`/`round`/`ceiling` exist (needed for "per 100 locations").
17. The exact NAI define semantics (`RATIO_OVER_SUPPLY_TARGET_TO_SPLIT`, `AI_LAND_ARMY_MERGE_THRESHOLD`, `HUNT_ARMIES_*`) — names verified, behaviour inferred; validate with observer games and `ai.log`.
