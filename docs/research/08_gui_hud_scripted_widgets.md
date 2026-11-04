# 08 — GUI: HUD "war stance" plate, custom windows via scripted widgets, GUI data functions

Scope: EU5 1.4.7 (Jomini/Caesar). Everything below was read from the game install, the two workshop mods
(Cheat Menu Pro = **CMP**, Simple Cheats = **SC**) and the user's logs. Tags: **VERIFIED** (seen in files),
**INFERRED** (follows from verified facts, not directly observed), **UNVERIFIED** (plausible, not seen).

Paths are relative to `…/Europa Universalis V/game/` unless noted. `CMP/` = `workshop/content/3450310/3600272327/`,
`SC/` = `workshop/content/3450310/3634102315/`. Playset check (`Documents/…/playsets.json`): the active playset
("1") contains **only CMP**; SC is in the inactive "Initial playset", so SC's runtime behaviour is **not** confirmed
by the logs, only its syntax is.

---

## 0. TL;DR

* Scripted widgets = a `.txt` registry in `gui/scripted_widgets/` mapping `gui/<file>.gui = <widget name>`. The
  widget's root **must** have a data-function `visible`. CMP proves the registry works from `in_game/gui/scripted_widgets/`.
* Open/close state of custom windows: client-side `GetVariableSystem` (`Set/Clear/Toggle/Exists/HasValue`). Game
  state (stance, HQ counts): script variables set by `scripted_guis`/on_actions and read in GUI with
  `GetPlayer.MakeScope.GetVariable('name').GetValue|.IsSet|.GetCountry`.
* The HUD top bar is 40 px tall (`@topbar_height = 40`), alerts occupy y = 40..130 between x = 627 and
  `W-487`; the "paused" banner sits at y = 160 (top|hcenter). A 26-px plate at `parentanchor = top|hcenter`,
  `position = { 0 132 }` does not overlap anything.
* An army list without C++: `datamodel = "[AccessPlayerUnits]"` (global, items are `Unit`), row data via
  `Unit.GetName / GetLocation / GetCommander / GetSubUnitCounts / GetSubUnits`. Custom alerts and custom message
  types are **not** scriptable (C++ ids); use the plate + a window + events instead.

---

## 1. Sources examined

| What | Path |
|---|---|
| Scripted-widget docs | `main_menu/gui/scripted_widgets/_scripted_widgets.info` (only vanilla file in that folder; no `in_game/gui/scripted_widgets/` exists in vanilla) |
| CMP registry + windows | `CMP/in_game/gui/scripted_widgets/sakuya_scripted_windows.txt`, `CMP/in_game/gui/sakuya_button.gui`, `sakuya_management.gui`, `sakuya_kawashiro.gui`, `sakuya_army_generator.gui`, `sakuya_declare_war.gui`, `shared/sakuya_types.gui` |
| CMP scripted guis | `CMP/main_menu/common/scripted_guis/sakuya_*.txt` (11 files, ~23 500 `scope = country` entries) |
| SC | `SC/in_game/gui/simple_cheats_ui.gui`, `SC/in_game/gui/panels/left_panel.gui`, `SC/in_game/common/scripted_guis/sc_*.txt` |
| Vanilla HUD | `in_game/gui/hud_topbar.gui` (2548 l.), `ingame_topbar.gui` (669 l.), `common_topbar.gui` (empty stub), `alertmanager.gui` (8073 l.), `messages.gui` (2453 l.), `outliner.gui`, `message_log.gui` |
| Vanilla templates | `main_menu/gui/shared/{backgrounds,main_menu_windows,main_menu_buttons,labels,main_menu_cooltip_types,main_menu_standard_types}.gui`, `loading_screen/gui/shared/defaults.gui`, `loading_screen/gui/preload/fonts.gui`, `in_game/gui/shared/{animation,standard_types,war_tooltips,combat_tooltips}.gui`, `in_game/gui/cooltip*.gui` |
| War / unit GUI | `war_lateralview.gui`, `war_viewer.gui`, `wars_ledger.gui`, `multi_unit_window.gui`, `single_unit_window.gui`, `unit_overview.gui` |
| Script side | `in_game/common/scripted_guis/scripted_guis.info` + `economy_satisfaction_target.txt`, `in_game/common/alert_descriptions/00_default.txt`, `main_menu/gui/messagetypes/00_messagetypes.txt`, `in_game/common/customizable_localization/*` |
| Logs | `Documents/Paradox Interactive/Europa Universalis V/logs/{gui,error,error.1-5,game,debug}.log` |

---

## 2. (a) Scripted widgets — exact mechanics

### 2.1 Registry format and the `visible` rule — VERIFIED

`main_menu/gui/scripted_widgets/_scripted_widgets.info` (whole file):

```
Scripted widgets are a way of creating widgets without needing to define them inside an existing .gui file.

A scripted widget is declared following this format within a .txt file inside this folder:
gui/scripted_widget_file_name.gui = scripted_widget_name

Note: The scripted widget inside the .gui file is required to have a 'visible' attribute.
'visible = yes' does not work, the boolean must be returned by a function.
As a workaround, 'visible = "[EqualTo_CFixedPoint('(CFixedPoint)0', '(CFixedPoint)0')]"' works as an equivalent to 'visible = yes'.
```

CMP registry, `CMP/in_game/gui/scripted_widgets/sakuya_scripted_windows.txt:1-4` (18 entries total, one per window):

```
gui/sakuya_test.gui = sakuya_window
gui/sakuya_kawashiro.gui = sakuya_kawashiro_window
gui/sakuya_button.gui = sakuya_button_window
gui/sakuya_alpha.gui = sakuya_alpha_window
```

* The left side is the `.gui` path relative to the package's `gui/` root (`gui/x.gui`, not `in_game/gui/x.gui`).
* The right side is the **`name = "..."` of a top-level widget/window** in that file (see 2.3).
* The file may start with a UTF-8 BOM (CMP's does) — harmless.

### 2.2 `in_game` vs `main_menu` placement — contradiction resolved

* Vanilla keeps only the `.info` under `main_menu/gui/scripted_widgets/` — there are **no** vanilla scripted widgets, so the
  folder location in vanilla is documentation, not a working example (VERIFIED: `find … -iname scripted_widgets` returns only that folder).
* CMP puts its registry in `in_game/gui/scripted_widgets/` and its windows in `in_game/gui/` — VERIFIED that these files load
  (gui.log parses `gui/sakuya_*.gui` with line-exact warnings, e.g. `gui.log:36 gui/sakuya_change_name.gui:199 - Unknown vertical anchor…`),
  and the mod is enabled in the active playset. That the windows are instantiated at runtime is **INFERRED** (no explicit
  "scripted widget created" log line exists; debug.log only shows VFS enumeration).
* EU5 content is split into three cumulative packages (`loading_screen` → `main_menu` → `in_game`); `in_game` GUI files use
  templates from `main_menu/gui/shared/*` (VERIFIED, e.g. `bg_window_default_alt` is defined in `main_menu/gui/shared/backgrounds.gui:5473`
  and used by `in_game` files). Hence a registry in **either** package is enumerated from the merged VFS (INFERRED); a window that
  references in-game-only data (`GetPlayer`, `AccessPlayerUnits`) must guard itself with `visible = "[GetPlayer.IsValid]"`
  (CMP does exactly this, `sakuya_button.gui:11`).
* **Recommendation:** copy the CMP layout — `in_game/gui/scripted_widgets/cw_scripted_widgets.txt` + `in_game/gui/cw_*.gui`.
  Using `main_menu/gui/scripted_widgets/` for in-game windows is UNVERIFIED.

### 2.3 Two ways to declare the root widget — both VERIFIED (CMP)

Bare window, `CMP/in_game/gui/sakuya_button.gui:1-11`:

```
window = {
	name = "sakuya_button_window"
	layer = topbar
	parentanchor = right|bottom
	widgetanchor = left|bottom
	position = { -480 0 }
	size = { 50 94 }
	allow_outside = yes
	movable = yes
	datacontext = "[GetPlayer]"
	visible = "[GetPlayer.IsValid]"
```

Type + instance, `CMP/in_game/gui/sakuya_management.gui:596-604` and `:728`:

```
 type sakuya_government_window = window {
 name = "sakuya_government_window"
 block "window_position" { parentanchor = center position = { 0 0 } }
 size = { 844 650 }
 movable = yes
 allow_outside = yes
 visible = "[GetVariableSystem.Exists('sakuya_government_visible')]"
 enabled = "[GetVariableSystem.Exists('sakuya_government_visible')]"
 …
sakuya_government_window = { datacontext = "[GetPlayer]" }
```

The registry entry (`gui/sakuya_management.gui = sakuya_government_window`) refers to the `name` property; the top-level
instance line at the end of the file is what actually creates the widget. Also VERIFIED: a window type may omit `layer`
entirely (`sakuya_management.gui`, `sakuya_kawashiro.gui`); CMP's floating button uses `layer = topbar`.

### 2.4 `visible` and `enabled` on the root

* `visible` must be a data function (2.1). CMP uses `GetVariableSystem.Exists(...)` for windows and `GetPlayer.IsValid`
  for the always-on button. Pair it with `enabled = "[same]"` so a hidden window never swallows input (CMP pattern).
* `visible = "[EqualTo_CFixedPoint('(CFixedPoint)0', '(CFixedPoint)0')]"` = "always on" (from the .info).

### 2.5 Two variable systems — never mix them up

| | `GetVariableSystem` (GUI) | script variables (`set_variable`) |
|---|---|---|
| Lives in | client UI, per player, not saved, not synced | game state, saved, synced |
| Write | `[GetVariableSystem.Set('k','v')]`, `.Clear('k')`, `.Toggle('k')`, `.SetIf(…)` | `scripted_gui` effect / on_action / event |
| Read | `[GetVariableSystem.Exists('k')]`, `.HasValue('k','v')` | `[X.MakeScope.GetVariable('k').GetValue]`, `.IsSet`, `.GetCountry`, `.GetCharacter`, `.GetLocation`, … |
| Use for | which window/tab is open, hover state | stance, HQ counts, enemy leader |

Vanilla usage counts in `in_game/gui`+`main_menu/gui` (VERIFIED): `GetVariableSystem.Exists` 109, `.HasValue` 99, `.Set` 56,
`.Toggle` 33, `.Clear` 11, `.SetIf` 1. CMP example of a window toggle, `sakuya_button.gui:46-53`:

```
action_tooltip = {
	click_type = left
	click_mode = single
	click_modifier = default
	title = "SAKUYA_OPEN_TT"
	on_action = "[GetVariableSystem.Toggle('sakuya_main_visible')]"
	on_action = "[GetVariableSystem.Set( 'sakuya_tabs', 'windows' )]"
}
```

Views also expose their own C++ var systems (`SingleUnitWindow.Vars.NotExistOrHasValue('tab','actions')`,
`single_unit_window.gui:3697`; `MapModeSelectorVars.Exists('hover')`, `ingame_topbar.gui:465`) — read-only for us.

### 2.6 Alternative: console-driven widgets (SC) — not recommended

`SC/in_game/gui/simple_cheats_ui.gui:1-3` and `:64-69`:

```
types simple_cheats_tab {
	type simple_cheats_button = button_panel_tab_alt {
        onclick = "[ExecuteConsoleCommand('GUI.CreateWidget gui/simple_cheats_ui.gui simple_cheats_window')]"
…
	button_close_alt = {
		parentanchor = right|top
		position = { -10 10 }
		blockoverride "close_onclick" {
			onclick = "[ExecuteConsoleCommand('GUI.ClearWidgets simple_cheats_window')]"
```

In vanilla, `ExecuteConsoleCommand` only appears in editor/debug files (`cd_pop_editor.gui`, `institution_editor.gui`,
`port_editor.gui`, `road_editor.gui`, `setup_editor.gui`, `ui_library.gui`, `main_menu/gui/console.gui`,
`debug/frontend_gui_workbench.gui`) — VERIFIED. Whether `GUI.CreateWidget` works without `-debug_mode` is UNVERIFIED, and
SC is not in the active playset. Additionally SC overrides `in_game/gui/panels/left_panel.gui`, but in 1.4.7 the vanilla file is
`in_game/gui/panels/left_panel/left_panel.gui` (VERIFIED) — the override is stale and its tab button (`left_panel.gui:725
simple_cheats_button = {}`) would be a second, orphaned copy of the panel. Do not copy this approach.

### 2.7 `scripted_guis` — definition and GUI call sites

Vanilla doc `in_game/common/scripted_guis/scripted_guis.info` (whole file):

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

Locations that load (VERIFIED): vanilla `in_game/common/scripted_guis/`, CMP `main_menu/common/scripted_guis/`,
SC `in_game/common/scripted_guis/`. Scope values seen: `country` (23 542 — vanilla+mods), `location` 8, `province` 5,
`region` 4, `area` 3, `religion` 2, `culture` 2, `character` 2. **No `scope = unit`/`army` anywhere** — a unit-scoped
scripted_gui is UNVERIFIED.

CMP definitions, `CMP/main_menu/common/scripted_guis/sakuya_management_sgui.txt:235-253`:

```
sakuya_mgmt_government_self = {
 scope = country
 is_shown = { always = yes }
 is_valid = { is_human = yes  }
 effect = { set_variable = { name = sakuya_government_country value = root } }
}
…
sakuya_mgmt_government_target_valid = {
 scope = country
 is_shown = { always = yes }
 is_valid = { is_human = yes exists = var:sakuya_government_country }
}
```

GUI call sites (all VERIFIED):

| Purpose | Expression | Source |
|---|---|---|
| run effect | `[GetScriptedGui('sakuya_mgmt_government_self').Execute(GuiScope.SetRoot(GetPlayer.MakeScope).End)]` | `sakuya_management.gui:14` |
| enable button | `enabled = "[GetScriptedGui('sakuya_gov_editor_open_add_reform').IsValid(GuiScope.SetRoot(GetPlayer.MakeScope).End)]"` | `sakuya_management.gui:55` |
| show widget | `visible = "[GetScriptedGui('sakuya_show_if_eastern').IsShown(GuiScope.SetRoot(Player.MakeScope).End)]"` | `CMP/in_game/gui/sakuya_test.gui:4446` |
| negated | `[Not(GetScriptedGui('sakuya_geo_has_exploration').IsShown(GuiScope.SetRoot(GetPlayer.MakeScope).End))]` | `sakuya_geopolitics.gui:217` |
| extra scopes | `[GetScriptedGui('subtract_one_percent').Execute(GuiScope.SetRoot(TaxRateSetting.GetEstate.GetCountry.MakeScope).AddScope('estate_type', TaxRateSetting.GetEstate.GetType.MakeScope).End)]` | vanilla `economy_lateralview.gui:1710`, paired with `saved_scopes = { country estate_type }` in `economy_satisfaction_target.txt` |
| evaluate a script_value | `raw_text = "[GuiScope.AddScope('estate_type', …MakeScope).AddScope('country', …MakeScope).ScriptValue('current_target_satisfaction')|%0]"` | `economy_lateralview.gui:1742` |

`Execute` from the GUI runs the effect for the local player; `is_valid = { is_human = yes }` is CMP's guard.

---

## 3. HUD geometry — where things live (VERIFIED)

Constants, `in_game/gui/ingame_topbar.gui:5-20`:

```
@alerts_height = 90
@states_height = 40

# this must be in sync with outliner.gui and message_log.gui
@topbar_height = 40
@panel_bar_height = 90
@panel_decor_square_size = 55
@panel_decor_width_size = 55
@panel_decor_height_size = 90

@left_panel_width = 570
@right_panel_width = 400
@panel_x = 0

@lateralview_margin_bottom = 0
@outliner_collapsed_width = 30
```

Root HUD widget, `ingame_topbar.gui:99-102`: `widget = { size = { 100% 100% } name = "ingame_topbar" layer = topbar …`.
Inside it (same file): alerts `vbox` (`:175-199`) with `margin_left = @[left_panel_width + panel_x*2 + panel_decor_square_size + 2]`
(= 627), `margin_right = @[right_panel_width + outliner_collapsed_width + panel_x*2 + panel_decor_square_size + 2]` (= 487),
`margin_top = @topbar_height`, `maximumsize = { -1 130 }`, containing `alert_manager = { size = { -1 @alerts_height } }`;
then `topbar = { size = { 100% @topbar_height } … }` (`:201-213`), `left_panel` at `position = { @panel_x @topbar_height }`
size `{ 570 100% }` (`:216-219`), `right_panel` at right, size `{ 430 100% }` (`:233-236`), and the middle indicators
(`:609-612`):

```
	# Middle screen indicators
	flowcontainer  = {
		visible = "[Not(TutorialHasVar('intro_hide_ui_4'))]"
		position = { 0 160 }
		parentanchor = top|hcenter
		ignoreinvisible = yes
```

The top bar itself, `hud_topbar.gui:133-143`:

```
	type topbar = widget {
		name = "HUD TopBar"

		datacontext = "[InGameTopbar.GetPlayer]"
		visible = "[And(Not(TutorialHasVar('intro_hide_ui_3')), Not(IsLobbyOpen))]"

		parentanchor = top
		alwaystransparent = no
		filter_mouse = all

		layer = bottom
```

Three sections in an `hbox`: `"Top Bar Section 1"` (`:177`, `using = left_topbar_section_size` = 570+0-20 = **550 px**, estates),
`"Top Bar Section 2"` (`:380`, an expanding `scrollarea` with the stats `stat_gold … stat_sailors` + research),
`"Top Bar Section 3"` (`:1896`, `using = right_topbar_section_size` = 400+30+0-20 = **410 px**, `using = speed_bar` =
date + speed buttons + pause). The sections use `max_update_rate = 4` (`:178`, `:381`) — copy this on the plate.

Alerts: `alertmanager.gui:6 @alert_wide = 45`, banner `size = { @alert_wide 70 }` (`:272`), `alert_manager = alerts_layout`
(`:534-547`) with `righttoleft = no #left side` → banners flow from x = 627 rightwards, ≈43 px each. The outliner occupies the
right edge under the top bar; the message log is `layer = messages` (`message_log.gui:130`).

**Free spots for a plate** (INFERRED from the numbers above): (A) `top|hcenter`, y = 132..158 — between the alert band
(ends at 130) and the paused banner (starts at 160); (B) inside the alert band at its right end
(`parentanchor = top|right`, `position = { -495 44 }`) — collides only with ≥16 simultaneous alerts; (C) overriding
`hud_topbar.gui` to insert into Section 2 — rejected (breaks every other UI mod and every patch).

Layer names used by vanilla (VERIFIED by `layer = …` usage): `bottom`, `topbar`, `lateralview`, `outliner`, `messages`,
`middle`, `windows_layer`, `top`, `confirmation`, `map_marker`, `tutorial`, `sidemenu`, `debug`, `loadsave`. The layer
list itself is not in any script file (C++), so the exact z-order is UNVERIFIED; the names strongly imply
`bottom < topbar < lateralview < … < windows_layer < top < confirmation`.

Hide-UI integration: `in_game/gui/shared/animation.gui:125-145` `template Animation_Show_Hide_UI` with states `hide_ui`/`show_ui`
and overridable blocks `on_hide_ui` / `on_show_ui` (used by every HUD part, e.g. `ingame_topbar.gui:183-194`).

---

## 4. (b) Skeleton — top-bar "enemy war stance" plate

Assumptions about the script side (other docs): the player's country carries `cw_enemy_stance` (number 0..4:
0 unknown, 1 offensive, 2 defensive, 3 waiting, 4 harassing) and optionally `cw_main_enemy` (country target),
refreshed monthly / on war start.

### 4.1 Registry — `in_game/gui/scripted_widgets/cw_scripted_widgets.txt`

```
gui/cw_war_stance_plate.gui = cw_war_stance_plate
gui/cw_hq_overview.gui = cw_hq_overview_window
```

### 4.2 `in_game/gui/cw_war_stance_plate.gui`

```
# Concentrated Warfare - enemy war-stance plate (scripted widget, see cw_scripted_widgets.txt)
@cw_plate_w = 280
@cw_plate_h = 26

types CW_StancePlateTypes
{
	# One state = icon + label; each instance overrides visible/icon/text
	type cw_stance_state = hbox {
		spacing = 6
		block "state_visible" { visible = "[Not(GetPlayer.MakeScope.GetVariable('cw_enemy_stance').IsSet)]" }
		icon = {
			size = { 22 22 }
			block "state_icon" { texture = "gfx/interface/icons/military_stances/normal_military_stance.dds" }
		}
		text_single = {
			autoresize = yes
			align = left|nobaseline
			using = Font_Size_Small
			default_format = "#color_white"
			block "state_text" { text = "CW_STANCE_UNKNOWN" }
		}
	}
}

window = {
	name = "cw_war_stance_plate"
	layer = topbar
	parentanchor = top|hcenter
	widgetanchor = top|hcenter
	position = { 0 132 }                      # alerts end at 130, paused banner starts at 160
	size = { @cw_plate_w @cw_plate_h }
	allow_outside = yes
	max_update_rate = 4
	datacontext = "[GetPlayer]"
	# scripted widget: visible MUST be a data function
	visible = "[And3(GetPlayer.IsValid, Not(IsLobbyOpen), GetPlayer.GetDiplomacy.IsAtWar)]"

	using = Animation_Show_Hide_UI
	blockoverride "on_hide_ui" { alpha = 0 }
	blockoverride "on_show_ui" { alpha = 1 }

	button = {                                 # whole plate is clickable -> opens the HQ overview
		size = { 100% 100% }
		using = top_bar_bg
		tooltip = "CW_STANCE_PLATE_TT"           # loc may embed [Country.GetName], see section 8
		action_tooltip = {
			click_type = left
			click_mode = single
			title = "CW_OPEN_HQ_OVERVIEW"
			on_action = "[GetVariableSystem.Toggle('cw_hq_overview_visible')]"
		}

		hbox = {
			margin = { 8 0 }
			spacing = 10
			text_single = { autoresize = yes using = Font_Size_Small default_format = "#yellow_titles" text = "CW_STANCE_PREFIX" }

			cw_stance_state = {
				blockoverride "state_visible" { visible = "[EqualTo_CFixedPoint(GetPlayer.MakeScope.GetVariable('cw_enemy_stance').GetValue, '(CFixedPoint)1')]" }
				blockoverride "state_icon" { texture = "gfx/interface/icons/military_stances/aggressive_military_stance.dds" }
				blockoverride "state_text" { text = "CW_STANCE_OFFENSIVE" }
			}
			cw_stance_state = {
				blockoverride "state_visible" { visible = "[EqualTo_CFixedPoint(GetPlayer.MakeScope.GetVariable('cw_enemy_stance').GetValue, '(CFixedPoint)2')]" }
				blockoverride "state_icon" { texture = "gfx/interface/icons/military_stances/defensive_military_stance.dds" }
				blockoverride "state_text" { text = "CW_STANCE_DEFENSIVE" }
			}
			cw_stance_state = {
				blockoverride "state_visible" { visible = "[EqualTo_CFixedPoint(GetPlayer.MakeScope.GetVariable('cw_enemy_stance').GetValue, '(CFixedPoint)3')]" }
				blockoverride "state_icon" { texture = "gfx/interface/icons/military_stances/passive_military_stance.dds" }
				blockoverride "state_text" { text = "CW_STANCE_WAITING" }
			}
			cw_stance_state = {
				blockoverride "state_visible" { visible = "[EqualTo_CFixedPoint(GetPlayer.MakeScope.GetVariable('cw_enemy_stance').GetValue, '(CFixedPoint)4')]" }
				blockoverride "state_icon" { texture = "gfx/interface/icons/military_stances/siege_raider_military_stance.dds" }
				blockoverride "state_text" { text = "CW_STANCE_HARASSING" }
			}
			cw_stance_state = {                   # 0 or unset = unknown
				blockoverride "state_visible" { visible = "[Or(Not(GetPlayer.MakeScope.GetVariable('cw_enemy_stance').IsSet), EqualTo_CFixedPoint(GetPlayer.MakeScope.GetVariable('cw_enemy_stance').GetValue, '(CFixedPoint)0'))]" }
				blockoverride "state_icon" { texture = "gfx/interface/icons/ai_dispositions/wary.dds" }
				blockoverride "state_text" { text = "CW_STANCE_UNKNOWN" }
			}
		}
	}
}
```

Every data function above is VERIFIED elsewhere: `And3/Or/Not` (hud_topbar), `GetPlayer.IsValid` (CMP), `IsLobbyOpen`,
`GetPlayer.GetDiplomacy.IsAtWar` (`Player.GetDiplomacy.IsAtWar`, 19 uses), `EqualTo_CFixedPoint` (158 uses),
`X.MakeScope.GetVariable('k').GetValue` (`attribute_columns/country.gui:1513`), `.IsSet` (`panels/left_panel/left_panel.gui:1010`),
`top_bar_bg` (`backgrounds.gui:6150`), `Font_Size_Small` (`loading_screen/gui/preload/fonts.gui`), `action_tooltip/on_action`
(2619 `on_action` uses in vanilla), `max_update_rate`, `Animation_Show_Hide_UI`. Icons exist (VERIFIED `ls`):
`gfx/interface/icons/military_stances/{aggressive,defensive,normal,passive,siege_raider,supportive}_military_stance.dds`,
`icons/ai_dispositions/{planning_war,wary,alarmed,…}.dds`, `icons/alerts_icons/military.dds`, `icons/icon_warning.dds`.
Texture paths are written relative to `gfx/…` (the engine resolves across packages; CMP uses `gfx/interface/sakuya/*.dds`
stored under `main_menu/gfx/`).

Variant using script instead of numeric compare (keeps the state logic in script): five scripted_guis
`cw_stance_is_offensive … cw_stance_is_unknown` with `scope = country`, `is_shown = { <trigger> }`, and
`visible = "[GetScriptedGui('cw_stance_is_offensive').IsShown(GuiScope.SetRoot(GetPlayer.MakeScope).End)]"` (pattern VERIFIED,
`sakuya_test.gui:4446`). Trigger body: `exists = var:cw_enemy_stance` is VERIFIED (`sakuya_management_sgui.txt:252`);
`var:cw_enemy_stance = 1` as a comparison trigger is INFERRED (Jomini convention) — test once.

Rich tooltip instead of `tooltip = "KEY"` — VERIFIED structure, `hud_topbar.gui:1916-1940` (trimmed):

```
tooltipwidget = {
	ContextualTooltipType = {
		blockoverride "title_icon" {
			icon = {
				using = tooltip_title_icon_size
				texture = "gfx/interface/icons/players.dds"
			}
		}
		blockoverride "title_text" {
			text = "PLAYERS_SYNC_TT_TITLE"
		}
		blockoverride "tooltip_content" {
			TooltipTextBlock = {
				blockoverride "text" {
					text = "[GetMultiplayerSyncInfo]"
```

Showing the enemy's name on the plate: `text = "[GetPlayer.MakeScope.GetVariable('cw_main_enemy').GetCountry.GetName]"`
(pattern VERIFIED, `CMP/in_game/gui/sakuya_government_editor.gui:22`; `GetVariable(X).GetCountry` 37 vanilla uses), or a
flag via `country_flag_small = { datacontext = "[GetPlayer.MakeScope.GetVariable('cw_main_enemy').GetCountry]" }`
(`country_flag_small` with a Country datacontext VERIFIED in `wars_ledger.gui:137-139`).

Alternative stance source without a player-side variable: iterate wars —
`datamodel = "[GetPlayer.GetDiplomacy.GetCurrentWars]"` (`Country.GetDiplomacy.GetCurrentWars` as datamodel VERIFIED,
`shared/country_tooltips.gui:1066`), item context `War` (`war_tooltips.gui:231 text = "[War.GetName]"`), then
`War.GetAttackerWarLeader` / `War.GetDefenderWarLeader` (VERIFIED, `wars_ledger.gui:203/339`) `.MakeScope.GetVariable('cw_stance').GetValue`.
Which side is "the enemy" needs `GetPlayer.IsEnemy(Country.Self)` (12 uses, e.g. `war_lateralview.gui:28`).

---

## 5. (c) Skeleton — "Headquarters overview" window

### 5.1 What is feasible without C++ (VERIFIED unless noted)

| Need | Data function | Source |
|---|---|---|
| all player units (armies + navies) | `datamodel = "[AccessPlayerUnits]"`, item ctx `Unit` | `multi_unit_window.gui:438`, `single_unit_window.gui:5283` |
| armies only | `visible = "[Unit.IsArmy]"` (118 uses) / `Unit.IsNavy` | same files |
| name / location / commander | `Unit.GetName`, `Unit.GetNameWithNoTooltip`, `Unit.GetLocation` (→ `Location.GetName`), `Unit.GetCommander`, `Unit.HasLeader` | counts: 5 / 5 / 14 / 15 / 8 |
| size | `Unit.GetNumSubUnits`, `GetDataModelSize(Unit.GetSubUnits)` (`unit_overview.gui:2998`), `Unit.GetVisualStrength`, `Unit.GetMoraleFloat` | |
| composition by category | `datamodel = "[Unit.GetSubUnitCounts]"` → `SubUnitCounts.GetCategory`, `.GetCount`, `GetSubUnitCategoryIcon(SubUnitCounts.GetCategory)` | `shared/combat_tooltips.gui:3324-3332` |
| per-regiment | `datamodel = "[Unit.GetSubUnits]"` → item ctx `SubUnit` (INFERRED name; `SubUnit.GetDefinition.GetName/.GetNameWithNoTooltip/.IsRegiment`, `SubUnit.GetStrength`, `.IsLevy`, `.IsMercenary` are VERIFIED functions) | `unit_overview.gui:2998` (size only) |
| "contains an HQ regiment" | `EqualTo_string(SubUnit.GetDefinition.GetNameWithNoTooltip, Localize('cw_hq_regiment'))` — string-compare-to-Localize pattern VERIFIED (`[EqualTo_string(CharacterInteractionItem.GetInteraction.GetNameWithNoTooltip, Localize('marry_lowborn'))]`), applied to SubUnit = INFERRED | |
| country totals (HQ count / limit / colonial HQs) | `[GetPlayer.MakeScope.GetVariable('cw_hq_count').GetValue|0]` etc. | pattern `country.gui:1513`; `|0` format `expeditions_lateralview.gui:81` |
| a script-built list of armies | `datamodel = "[GetPlayer.MakeScope.GetList('cw_hq_armies')]"` + `Scope.GetCountry` — VERIFIED only for **country** items (`panels/organization/middle_kingdom.gui:347-354`); `Scope.GetUnit` UNVERIFIED (only `Scope.GetCountry`, `Scope.GetInternationalOrganization` exist in vanilla GUI) | |
| per-unit script variable | `Unit.MakeScope.GetVariable(...)` — UNVERIFIED (only `Location.MakeScope`, `Country.MakeScope`, `InternationalOrganization.MakeScope`, `Character…MakeScope` seen) | |
| ready-made row | `unit_card = {}` with `datacontext = "[Unit.GetLocation]"` on the hbox | `multi_unit_window.gui:444-447`; `type unit_card = hbox` at `unit_overview.gui:1946` |

Conclusion: the list, per-row composition and country totals are fully feasible; the per-army HQ flag is feasible through
the sub-unit list (INFERRED) and is best **double-sourced** by the mod's own unit modifier (not readable in GUI → UNVERIFIED)
— so rely on the regiment-type comparison and keep the HQ regiment's localized name unique.

### 5.2 `in_game/gui/cw_hq_overview.gui` (skeleton)

```
types CW_HQOverviewTypes
{
	type cw_hq_army_row = hbox {
		visible = "[Unit.IsArmy]"
		spacing = 10
		using = bg_market_card                              # as in multi_unit_window.gui:441-442
		using = bg_cabinet_card_frame
		icon = { size = { 24 24 } texture = "gfx/interface/icons/alerts_icons/military.dds" }
		text_single = { size = { 220 24 } autoresize = no elide = right align = left|nobaseline
			text = "[Unit.GetNameWithNoTooltip]" default_format = "#yellow_titles" }
		text_single = { size = { 160 24 } autoresize = no elide = right align = left|nobaseline
			datacontext = "[Unit.GetLocation]" text = "[Location.GetName]" default_format = "#subtle_name" }
		text_single = { size = { 60 24 } autoresize = no align = right|nobaseline
			text = "[GetDataModelSize(Unit.GetSubUnits)]" }
		# HQ flag: any sub-unit whose localized type name equals the HQ regiment name
		hbox = {
			datamodel = "[Unit.GetSubUnits]"
			item = {
				icon = {
					size = { 24 24 }
					texture = "gfx/interface/icons/military_stances/supportive_military_stance.dds"
					visible = "[EqualTo_string(SubUnit.GetDefinition.GetNameWithNoTooltip, Localize('cw_hq_regiment'))]"
					tooltip = "CW_HAS_HQ_TT"
				}
			}
		}
	}

	type cw_hq_overview_window = window {
		name = "cw_hq_overview_window"
		parentanchor = center
		size = { 820 600 }
		movable = yes
		allow_outside = yes
		visible = "[GetVariableSystem.Exists('cw_hq_overview_visible')]"
		enabled = "[GetVariableSystem.Exists('cw_hq_overview_visible')]"

		widget = {
			size = { 100% 100% }
			using = bg_window_default_alt
			widget = {                                        # close button, CMP sakuya_kawashiro.gui:17-30
				parentanchor = right
				position = { -5 5 }
				size = { 40 40 }
				ui_direction_button_holder_right = {}
				button_close_alt = {
					blockoverride "close_on_action" { on_action = "[GetVariableSystem.Clear('cw_hq_overview_visible')]" }
				}
			}
			vbox = {
				using = window_margin_alt
				spacing = 5
				window_header_alt = { blockoverride "header_text" { text = "CW_HQ_OVERVIEW_TITLE" } }
				text_single = { autoresize = yes text = "CW_HQ_SUMMARY" }   # loc embeds Country.MakeScope.GetVariable(...)
				vbox = {
					using = layoutpolicy_expanding
					using = bg_main_inner_alt
					scrollbox = {
						using = layoutpolicy_expanding
						blockoverride "scrollbox_content" {
							vbox = {
								spacing = 6
								margin = { 10 10 }
								datamodel = "[AccessPlayerUnits]"
								item = { cw_hq_army_row = {} }
							}
						}
					}
				}
			}
		}
	}
}

cw_hq_overview_window = { datacontext = "[GetPlayer]" }
```

Template provenance (VERIFIED definitions): `bg_window_default_alt` `main_menu/gui/shared/backgrounds.gui:5473`;
`bg_main_inner_alt` `:4897`; `window_header_alt` `main_menu/gui/shared/main_menu_windows.gui:173` (overridable block
`header_text`); `window_margin_alt` `:41`; `layoutpolicy_expanding` `:28`; `button_close_alt` `main_menu_buttons.gui:1128`
(blocks `close_on_action`, `close_properties`, `close_title`); `ui_direction_button_holder_right` `:1085`;
`header_main_tabs` `:967` + `button_main_tab_alt` `:1051` (tabs, used by CMP `sakuya_army_generator.gui:46-62` with
`onclick` + `down = "[GetVariableSystem.HasValue('k','v')]"`); `button_regular`/`button_regular_red`
`loading_screen/gui/shared/defaults.gui:385/398`; `text_single` `labels.gui:5`; scrollbox usage with
`blockoverride "scrollbox_content"` `sakuya_management.gui:617-619`. Alternative list container with fixed row height:
`addrow = 45 setitemsizefromcell = yes datamodel = … item = {…}` (`wars_ledger.gui:105-111`).

For tabs inside the window (e.g. "Home HQs / Colonial HQs"): CMP pattern — each tab button `onclick =
"[GetVariableSystem.Set('cw_hq_tab','colonial')]"`, `down = "[GetVariableSystem.HasValue('cw_hq_tab','colonial')]"`, content
`visible = "[GetVariableSystem.HasValue('cw_hq_tab','colonial')]"` (`sakuya_management.gui:91`, `sakuya_army_generator.gui:49-53`).

A floating opener button (if the plate is hidden in peace): copy `CMP/in_game/gui/sakuya_button.gui` (`layer = topbar`,
round `button` with `block "button_texture"`, `modify_texture`, `icon` + `using = button_panel_tab_icon_effect`,
template at `main_menu_buttons.gui:447`).

---

## 6. (d) Verified data-function patterns

| Pattern | Example (verbatim) | Where |
|---|---|---|
| player country | `[GetPlayer]`, `[GetPlayer.IsValid]`, `[GetPlayer.Self]` (74), `[IsPlayerValid]` | CMP `sakuya_button.gui:10-11`; `hud_topbar.gui:1743` |
| datacontext → type name | `datacontext = "[InGameTopbar.GetPlayer]"` then children use `Country.Exists` / `Country.GetEconomy` | `hud_topbar.gui:136,186,839` |
| `Player.` global | `[Player.GetDiplomacy.IsAtWar]`, `[Player.GetCurrentResearch.IsActive]` (510 `[Player.` uses) | `hud_topbar.gui:1808`, `unit_overview.gui` |
| capital | `GetPlayer.GetCapital` (3 uses) | grep `in_game/gui` |
| enemy test | `[And(Not(Country.GetDiplomacy.IsSubject), GetPlayer.IsEnemy(Country.Self))]` | `war_lateralview.gui:28` |
| at war | `Country.GetDiplomacy.IsAtWar` (19), `Player.GetDiplomacy.GetOverlord`, `.GetSubjects`, `.IsRival(X)`, `.GetOpinionOf` | counts in `in_game/gui` |
| wars list | `datamodel = "[Country.GetDiplomacy.GetCurrentWars]"` → `[War.GetName]`, `War.GetAttackerWarLeader`, `War.GetDefenderWarLeader`, `War.GetWarScore`, `War.IsCivilWar`, `War.GetWarGoal` | `country_tooltips.gui:1066`, `wars_ledger.gui:203,339` |
| war ledger | `datamodel = "[WarsLedger.GetWars]"` → `WarItem.GetWar`, `WarItem.OnClick`, `WarItem.GetAttackerTroops` | `wars_ledger.gui:109-125,370` |
| war view objects | `WarLateralView.GetEnemyLeader`, `.GetFriendlyLeader`, `.IsPlayerInWar`, `.IsPlayerAttacker`, `.GetAttackerParticipantsFlattened` | `war_lateralview.gui:735,661,1976` (view-local contexts, not global) |
| script var (number) | `text = "[InteractionTarget.GetCountry.MakeScope.GetVariable('rtr_yuan_allegiance').GetValue]"` | `attribute_columns/country.gui:1513` |
| script var compare | `visible = "[LessThan_CFixedPoint(InternationalOrganizationsView.GetInternationalOrganization.GetVariable('phase'), '(CFixedPoint)2')]"` | `panels/organization/crusade.gui:789` |
| script var math | `[Multiply_CFixedPoint(…MakeScope.GetVariable('hindu_pop_count').GetValue, '(CFixedPoint)1000')\|K+0]` | `panels/disaster/decline_of_majapahit.gui:113` |
| script var exists | `visible = "[InternationalOrganization.MakeScope.GetVariable('iberian_union_active').IsSet]"` | `panels/left_panel/left_panel.gui:1015` |
| script var → object | `GetVariable(X).GetCountry` 37, `.GetCharacter` 22, `.GetRebel` 36, `.GetLocation` 10, `.GetPolicy` 8, `.GetReligion` 3, `.GetDiseaseOutbreak` 20 | grep `in_game/gui` |
| script var (CMP) | `[GetPlayer.MakeScope.GetVariable('sakuya_government_country').GetCountry.GetName]` | `sakuya_government_editor.gui:22` |
| conditional string | `[Select_CString(GetPlayer.MakeScope.GetVariable('sakuya_rename_target_country').IsSet, …GetCountry.GetNameWithFlag, Localize('RENAME'))]` | `sakuya_change_name.gui:169` |
| variable list | `datamodel = "[…GetLeaderCountry.MakeScope.GetList('visited_countries')]"` + `datacontext = "[Scope.GetCountry]"` | `middle_kingdom.gui:350-353` |
| script value | `GuiScope.AddScope('country', X.MakeScope).ScriptValue('name')` | `economy_lateralview.gui:1742` |
| customizable loc | `[…GetCountry.Custom('sakuya_gov_editor_desc_manila_galleon_reform')]`; vanilla `[InteractionTarget.GetLocation.Custom('GetShugoProvinceName')]` | `sakuya_government_editor.gui:5588`; `attribute_columns/location.gui:589` |
| localize in expression | `[Localize('age_1_traditions')]` (207 vanilla uses) | `sakuya_government_editor.gui:2384` |
| string compare | `[EqualTo_string(Country.GetDiplomacy.GetSubjectType.GetNameKey, 'colonial_nation')]` | `in_game/gui` |
| modifier text | `raw_text = "[ShowModifierEffect('sc_global_population_growth_add')]"` (vanilla: `ShowModifierEffect('coastal')`) | `SC/…/simple_cheats_ui.gui:96` |
| list helpers | `GetDataModelSize` 411, `DataModelHasItems` 156, `IsDataModelEmpty` 349, `DataModelFirst(list,'(int32)3')`, `DataModelSkipFirst` | grep |
| numeric helpers | `EqualTo_CFixedPoint` 158, `GreaterThan_CFixedPoint` 383, `FixedPointToFloat` 683, `EqualTo_int32` 194, `ObjectsEqual` 137, `Add_float`, `Multiply_float`, `Min_float` | grep |
| text helpers | `Concatenate` 22, `Select_CString` 86, `AddTextIf` 15, `AddLocalizationIf(cond,'KEY')` 62 | grep |
| game state flags | `IsGamePaused`, `IsObserving`, `IsObservingWithoutSelectedCountry`, `IsLobbyOpen`, `GameIsMultiplayer`, `TutorialHasVar('intro_hide_ui_4')` | `hud_topbar.gui`, `ingame_topbar.gui` |
| widget state | `PdxGuiWidget.ToggleContextMenu`, `PdxGuiWidget.SetHighlightCountry(Country.Self)`, `OpenDiplomacy(Country.Self)`, `PanToCountry(Country.Self)` | `sakuya_types.gui:116,125,137,176` |
| coat of arms | `datacontext = "[GetCountryCoatOfArms(Country.Self)]"` + `CoatOfArmsWrapper.GetTexture('(int32)192','(int32)128')` | `sakuya_types.gui:185-188` |
| units | `AccessPlayerUnits`, `Unit.IsArmy/IsNavy/GetLocation/GetCommander/GetName/GetNumSubUnits/GetSubUnitCounts/GetSubUnits/GetMoraleFloat/GetVisualStrength`, `SubUnitCounts.GetCategory/.GetCount`, `SubUnit.GetDefinition.GetName/.IsRegiment`, `SubUnitType.GetName/.GetCategory/.IsSpecialRegiment` | see §5 |
| view var systems | `SingleUnitWindow.Vars.NotExistOrHasValue('tab','actions')`, `ForeignCountryView.Vars.HasValue('diplomacy','actions')` | `single_unit_window.gui:3697` |

Format suffixes seen: `|0` (int), `|2%`, `|%0`, `|K+0` (thousands, signed), `|-=2%`, `|V`, `|U` (upper-case), `|0+=`, `|V2%`.

---

## 7. Alerts and message types — can they complement the plate?

* `in_game/common/alert_descriptions/00_default.txt` (138 entries) holds **only** `title`, `texture`, `priority`
  (`green|yellow|orange|red|blue|purple`), optional `hint`, `game_concept` — zero `trigger`/`is_shown`/`effect` keys
  (VERIFIED by grep). Alert ids (`can_intervene_in_rival_war`, `has_unraised_levies_in_war`, …) are C++ names:
  **custom alerts are not scriptable** (INFERRED, high confidence). Entry format, `:1-6`:

```
annexing_disloyal_subject = {
	title = "ALERT_ANNEXING_DISLOYAL_SUBJECT_TITLE"
	hint = "hint_has_disloyal_subjects"
	texture = "alerts_icons/alert_annexing_disloyal"
	priority = yellow
}
```

  The alert GUI (`alertmanager.gui:534-547`) is fed by `datacontext = "[InGameTopbar.AccessAlertManager]"`; per-alert
  widgets are named after the alert id (`:657 name = "member_leaving_union"`, `_action`, `_tooltip`). You *can* re-skin an
  existing alert's texture/priority, nothing more.
* `main_menu/gui/messagetypes/00_messagetypes.txt` entries (`MAJOR_EVENT_INFO={ log=no onmap=no popup=yes idle=no option=no
  pausepopup=yes message_category = geopolitics }`, `:1-9`) are C++ message ids with display flags; the user's
  `Documents/…/messagetypes_custom.txt` stores per-player overrides of the same keys. No script effect such as
  `send_interface_message/send_interface_toast/custom_message` exists in `in_game/events` or `in_game/common`
  (grep = 0; only `custom_tooltip` 7042 and `show_as_tooltip` 510). **Custom toasts are UNVERIFIED/unavailable**; the
  scriptable notification is a `country_event` (7929 `type = country_event`).
* Message popups live on `layer = top` (`messages.gui:6`) with windows `basic_message_popup`, `character_message_popup`,
  `location_message_popup`, `country_message_popup`, `research_message_popup` (`messages.gui:728-828`).

So: plate + window + (optional) events. No alert, no toast.

---

## 8. Localization and text

* Loc files: `main_menu/localization/<lang>/<name>_l_<lang>.yml` (vanilla: 132 english files there; `in_game/localization/`
  contains only `jomini`). CMP uses `main_menu/localization/english/…_l_english.yml`, header ` l_english:` with UTF-8 BOM
  (VERIFIED). Keys must be unique across *all* files — game.log:10232+ logs `Duplicate localization key … defined in both
  'localization/russian/Cheat_menu_1.6_l_russian.yml' and 'localization/russian/cheat_menu_l_russian.yml'`.
* `text = "KEY"` auto-localizes; `raw_text = "…"` is literal and may contain data functions (`SC simple_cheats_ui.gui:96`,
  CMP `sakuya_kawashiro.gui:66`); `text = "[DataFn]"` is also valid (`country.gui:1513`).
* Loc strings are evaluated against the widget's datacontext: `POWER_TEXT: "[Country.GetName] is the #V ##[Country.GetGreatPowerRank]#! Power…"`,
  `SCOPE_COUNTRY: "[Country.GetFlagIconWithNoTooltip] [Country.GetName|U]"` (vanilla english loc). Variables in loc:
  `favor_heir_ct: "… [SCOPE.sCountry('actor').MakeScope.GetVariable('favored_heir').GetCharacter.GetName] …"`,
  `rot_plan_invasion_bt: "… [recipient.MakeScope.GetVariable('rot_conquest_ambition').GetRegion.GetName] …"`,
  `vote_in_election_desc_hre: "$vote_in_election_desc$[GetUniqueInternationalOrganization('hre').Custom('GetHREElectionDescription')]"`.
  So `CW_HQ_SUMMARY: "HQs: [Country.MakeScope.GetVariable('cw_hq_count').GetValue|0] / [Country.MakeScope.GetVariable('cw_hq_limit').GetValue|0]"`
  is an INFERRED (two verified halves) loc line for a widget whose datacontext is the player (`datacontext = "[GetPlayer]"`).
* Formatting: `#T title#!`, `#bold`, `#Y`, `#G 5#!`, `#V`, `$OTHER_KEY$`, `$VAL|2R$`, `[war|e]` concept links, `@warning_icon!`
  icons, `\n` (vanilla `alerts_l_english.yml`, `ALERT_AT_WAR_WITH: "#T War#!\nWe are currently at [war|e] with $DATA$."`).
  `default_format = "#yellow_titles"` (360 uses), `"#subtle_name"`, `"#color_white"`, `"#high"`, `"#color_red"` are the usual
  widget-level formats.
* Customizable localization (`in_game/common/customizable_localization/*.txt`): `key = { type = country text = { trigger = {…}
  localization_key = … } text = { localization_key = … fallback = yes } }` (vanilla `00_customizable_localization.txt:1-13`,
  CMP `sakuya_mark_country_status.txt:3-55`), called as `Country.Custom('key')` in GUI or loc. A `cw_stance_name` custom loc
  (triggers on `var:cw_enemy_stance`) is the cleanest way to get a single text widget for 5 states. Scope mismatch is logged:
  error.log `Wrong scope input for custom loc CL_tt, expected country, got international_organization`.
* Fonts: `Font_Size_{Small,Medium,…}`, `Font_Type_{Flavor,Headers}` are templates in `loading_screen/gui/preload/fonts.gui:21,55,59`.
  `fontsize_min` must be 1..14 (`gui.log: main_menu_lists.gui:247 - Illegal Property Value: 'fontsize_min' should be greater than 0 and less than 15`);
  CMP's `fontsize_min = 18` (`sakuya_management.gui:607`) is therefore illegal.

---

## 9. Tooltips, buttons, cards — reusable vanilla building blocks (VERIFIED definitions)

* Tooltip types (`main_menu/gui/shared/main_menu_cooltip_types.gui`): `ContextualTooltipType` (:1734, blocks
  `title_icon`/`title_text`/`tooltip_content`), `SimpleContextualTooltipType` (:987), `TooltipOnlyTextType` (:1086),
  `BasicFunctionalTooltip` (:1567), `LeftClickButtonTooltip` (:1548, block `onclick_text`, used by SC), `TooltipTextBlock`
  (:1931), `TooltipTableColumn` (:1814, blocks `column_datamodel`/`field_text`), `TooltipRowList`, `TooltipScrolledRowList`,
  `TooltipConditionListType`. Properties: `tooltip = "KEY|[fn]"`, `tooltip_enabled = "[fn]"`, `tooltipwidget = { … }`,
  `tagtooltip_enabled = yes`, `action_tooltip = { click_type click_mode click_modifier title on_action enabled }`.
  In-game extras: `in_game/gui/cooltip_types.gui` (`tooltip_delayed_block`, `tooltip_blocklist_content`).
  **There is no `tooltip_ne/tooltip_se/tooltip_ws` template in EU5** (gui.log: 87× `Could not find template 'tooltip_ne'` from CMP).
* Buttons (`main_menu_buttons.gui` / `defaults.gui`): `button_regular(_red|_yellow)`, `button_regular_alt(_green|_red|_yellow)`,
  `button_icon`, `button_close(_alt)`, `button_main_tab(_alt)`, `button_panel_tab_alt`, `button_square_plus/minus`,
  `button_checkbox(_alt)`, `button_pin`, `button_goto`. Button text: `text = "KEY"` + `blockoverride "button_text_properties" { default_format = "#yellow_titles" }`
  (`wars_ledger.gui:125-128`). Sounds: `using = snd_UI_close` (`loading_screen/gui/shared/sounds.gui:64`).
* Backgrounds (`backgrounds.gui`): `bg_window_default(_alt)`, `bg_main_inner_alt`, `top_bar_bg` (:6150, graphical-culture
  overlay), `bg_circle_hud_dark_blue` (:505). Cards: `bg_market_card`, `bg_cabinet_card_frame` (`multi_unit_window.gui:441-442`).
* Indicator plate look (same as the pause banner): `type base_indicator = widget` `main_menu/gui/shared/main_menu_standard_types.gui:139-151`
  (`pause_bg.dds` corner-stretched + graphical-culture pattern); `paused_indicator = base_indicator` `in_game/gui/shared/standard_types.gui:831`.
  A plate derived from `base_indicator` with a `text` block override is an INFERRED but low-risk alternative to `top_bar_bg`.
* Custom types: declare them inside `types <UniqueGroupName> { type cw_x = widget { … block "name" {…} } }` and instantiate
  with `cw_x = { blockoverride "name" {…} }` (CMP `shared/sakuya_types.gui:5-63`). `types` group names and `type` names are global — prefix `cw_`.

---

## 10. Pitfalls

### 10.1 From the user's logs (all lines are from `Documents/…/logs/`)

| Log line | Meaning / fix |
|---|---|
| `gui.log:36 gui/sakuya_change_name.gui:199 - Unknown vertical anchor in 'center|top', will use top` / `:39 … 'left|center'` | Anchors are `left|right|hcenter` × `top|bottom|vcenter`; write `hcenter|top`, `left|vcenter` |
| `gui.log:50 gui/sakuya_government_editor.gui:24323 - Failed parsing localized text: administrative_clergy_policy_desc` + `:51 failed reading property` | A loc string referenced by `text =` has invalid `[…]` syntax → the whole property is dropped; validate loc |
| `gui.log:86-97 … 'use_global_input_instance' is not a valid widget/type/property` | CK3/V3 property, not in EU5 |
| `gui.log:98 gui/sakuya_test.gui:12819 - Could not find template 'layoutpolicy_fixed'`; `:106 … 'tooltip_ne'` (87×) | Non-existent templates; use `layoutpolicy_horizontal = fixed` and real tooltip types (§9) |
| `gui.log … gui/sakuya_test.gui:5269 - Widget cannot have a position in a layout` (also vanilla `shared/cards.gui:4755`) | `position` is ignored for children of `hbox/vbox/flowcontainer`; use `margin`, `expand = {}`, spacer widgets |
| `gui.log … gui/sakuya_geopolitics.gui:39 - Property 'spacing'(272) not handled` | `spacing` only on layout containers, not on `widget`/`window` |
| `gui.log … gui/sakuya_alpha.gui:178 - Failed setting property 'alwaystransparent'(470)` | not valid inside `modify_texture` |
| `gui.log … main_menu_lists.gui:247 - Illegal Property Value: 'fontsize_min' should be greater than 0 and less than 15` | keep `fontsize_min` ≤ 14 |
| `error.log:1373 Reloadable widget [gui/alertmanager.gui]:[discard_stash] still registered when its context is destroyed` | vanilla, harmless (on exit) |
| `error.N.log … gui/shared/location_tooltips.gui:759: No context supplied (Use SetDataContext), wanted context of type 'Container' for 'LOCATION.GetProvince.GetName'` | a loc string used a scope the widget's datacontext does not provide; always set `datacontext` before `text = "KEY"` that embeds `[Type.Fn]` |
| `error.log … Promote 'CHARACTER' returned nullptr, in 'CHARACTER.IsFemale'` (450×, vanilla russian nickname loc) | same class of bug — type name in loc must match the context |
| `game.log:10232 Duplicate localization key. Key 'SAKUYA_OPEN_TT' is defined in both …` | unique keys across files |
| `debug.log … File 'common/static_modifiers/sakuya_management_modifiers.txt' should be in utf8-bom encoding` | save every `.txt`/`.yml`/`.gui` as UTF-8 **with BOM** |
| `error.log … Wrong scope input for custom loc CL_tt, expected country, got international_organization` | customizable_localization `type` must match the object it is called on |

### 10.2 Structural

1. `visible = yes` on a scripted-widget root silently never shows the widget (info file). Always a data function; add `enabled` too.
2. GUI variables (`GetVariableSystem`) are client-only and unsaved: never derive game logic from them; use them only for open/closed/tab state.
3. Top-level `.gui` instances are created for **every** file under `gui/` of an enabled mod; a mod file with the same relative path as a vanilla
   file replaces it wholesale (SC's stale `panels/left_panel.gui` shows how a path change in a patch silently orphans an override).
4. A scripted window with `datacontext = "[GetPlayer]"` exists in the lobby/observer too — guard with `GetPlayer.IsValid`, `Not(IsLobbyOpen)`.
5. `GetVariable('x').GetValue` on an unset variable: behaviour UNVERIFIED — always check `.IsSet` first (the plate does).
6. Scripted-gui `IsShown/IsValid` in `visible/enabled` are evaluated every GUI update: keep triggers trivial, throttle with `max_update_rate`.
7. `GetVariableSystem` keys are global across mods: prefix everything (`cw_`). Same for `types` groups, `type` names, templates, loc keys.
8. Hide-UI hotkey: without `Animation_Show_Hide_UI` your plate stays on screen when the player hides the HUD.
9. Layer z-order is C++-defined (not in files): if the plate is covered by the outliner/lateral views, try `layer = middle` or `windows_layer` (UNVERIFIED order).
10. UI scaling changes absolute coordinates; test the plate position at 100 % and 125 % UI scale and at 1920×1080 / 2560×1440.

---

## 11. Recommendations for the mod

1. **Stack:** `in_game/gui/scripted_widgets/cw_scripted_widgets.txt` → `in_game/gui/cw_war_stance_plate.gui` + `cw_hq_overview.gui`;
   scripted guis in `in_game/common/scripted_guis/cw_gui.txt` (vanilla location); loc in `main_menu/localization/<lang>/cw_gui_l_<lang>.yml`
   (UTF-8 BOM; russian + english). Optional floating opener button cloned from `sakuya_button.gui`.
2. **Stance plate:** script writes `cw_enemy_stance` (0..4) and `cw_main_enemy` on the player's country (monthly + on war declared);
   GUI reads them with `GetPlayer.MakeScope.GetVariable(...)`; five `cw_stance_state` instances toggled by `EqualTo_CFixedPoint`;
   `visible` requires `GetPlayer.GetDiplomacy.IsAtWar`. Position `top|hcenter`, `{ 0 132 }`, 26 px high, `layer = topbar`,
   `Animation_Show_Hide_UI`, `max_update_rate = 4`. Tooltip = `ContextualTooltipType` with the enemy name/flag and the
   stance explanation; left click toggles `cw_hq_overview_visible`.
3. **HQ overview:** `AccessPlayerUnits` rows filtered by `Unit.IsArmy`; HQ flag via `Unit.GetSubUnits` + `EqualTo_string(SubUnit.GetDefinition.GetNameWithNoTooltip, Localize('cw_hq_regiment'))`
   (give the HQ regiment a unique localized name in every language); totals/limits from country variables (`cw_hq_count`,
   `cw_hq_limit`, `cw_colonial_hq_count`, `cw_colonial_hq_limit`) written by the same script that enforces the limits;
   tabs via `GetVariableSystem.HasValue('cw_hq_tab', …)`.
4. **Do not** touch `hud_topbar.gui`/`ingame_topbar.gui`/`alertmanager.gui`; do not rely on alerts or message types (not scriptable);
   do not use `ExecuteConsoleCommand` widgets.
5. Icons: reuse `gfx/interface/icons/military_stances/*.dds`, `ai_dispositions/{planning_war,wary}.dds`, `alerts_icons/military.dds`,
   `unit_status/*.dds`; custom art goes to `main_menu/gfx/interface/cw/` (CMP convention: `in_game/gfx` is wrong — CMP left a note file there saying so).
6. Validate after every change: `gui.log` must show no `cw_*.gui` lines; `error.log` no `cw_` data errors. Keep `fontsize_min ≤ 14`,
   no `position` in layouts, correct anchors.
7. For the 4th army-window tab ("Headquarters") the same primitives apply, but it requires overriding
   `single_unit_window.gui` (tabs are `SingleUnitWindow.Vars.NotExistOrHasValue('tab', …)`, `:3697`) — a 5301-line vanilla file; weigh
   compatibility cost (separate research topic).

---

## 12. Open questions (UNVERIFIED)

* Runtime proof that a registry in `main_menu/gui/scripted_widgets/` creates in-game windows (CMP uses `in_game`).
* `scope = unit` for scripted_guis; `Unit.MakeScope`; `Scope.GetUnit` on variable lists; reading unit modifiers from GUI.
* `var:x = N` comparison syntax inside `is_shown` triggers (only `exists = var:x` is verified).
* Exact layer z-order; `GUI.CreateWidget` console command outside debug mode; behaviour of `GetValue` on an unset variable.
* Whether `GetScriptedGui(...).IsShown` is re-evaluated only on data change or every frame (performance of 5 states × 1 plate is negligible either way).
