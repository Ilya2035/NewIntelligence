# 07 — EU5 GUI research: the army window and a 4th "Headquarters" tab

Scope: EU5 1.4.7 (Caesar/Jomini). Game root `G = C:\Program Files (x86)\Steam\steamapps\common\Europa Universalis V\game`.
Workshop examples: Cheat Menu Pro `CMP = ...\workshop\content\3450310\3600272327`, Simple Cheats `SC = ...\3634102315`.
Every claim is tagged **VERIFIED** (seen in files, path:line given), **INFERRED** (derived from verified facts) or **UNVERIFIED**.

---

## 0. TL;DR

* The army window is `lateralview = { name = "single_unit_window" widgetid = "single_unit_window" }` in `G/in_game/gui/single_unit_window.gui:3449-3451` (5301 lines, 143 KB). Its bound object is the global window context **`SingleUnitWindow`**; the unit is reached through `SingleUnitWindow.GetSelectedUnit` (46 uses) / `SingleUnitWindow.AccessSelectedUnit` (datacontext) and then the `Unit` context. **VERIFIED**
* Vanilla has **no visible tab buttons** in this window, but the tab *plumbing* already exists: content is gated by `SingleUnitWindow.Vars.NotExistOrHasValue( 'tab', 'actions' )` (lines 3697, 4016) and a commented-out second tab `HasValue( 'tab', 'formation' )` (line 5066). "Formation" is a *separate* lateral view (`single_unit_formation_window.gui`) opened by `OpenLateralView('single_unit_formation')` (line 4642); "Details" is a `select_menu_fullscreen_right` (`single_unit_detail_window.gui:1-8`, mostly commented out). **VERIFIED**
* Vanilla tab idiom (used by 30+ windows): `header_main_tabs`/`header_secondary_tabs` containers holding `button_main_tab_alt`/`button_secondary_tab_alt` buttons whose `on_action` is `<Window>.Vars.Set('tabvar','x')`, `down` is `<Window>.Vars.HasValue(...)`, and each content `vbox` has `visible = "[<Window>.Vars.HasValue('tabvar','x')]"`. **VERIFIED** (`maritime_lateralview.gui:413-446`, `unit_overview.gui:1-29`, `decisions_lateralview.gui:716-720`).
* Minimal-diff plan: copy `single_unit_window.gui` into the mod (`<mod>/in_game/gui/single_unit_window.gui`, full-file override — there is no partial override for widgets inside a file), insert a `header_secondary_tabs` row with 2+ `button_secondary_tab_alt` ("Actions" / "Headquarters"; optionally "Formation" and "Details" as *navigation* buttons that call `OpenLateralView('single_unit_formation')` / open the details menu), wrap the existing illustration+actions blocks in `NotExistOrHasValue('tab','actions')` (already done by vanilla) and add one new `vbox` with `visible = "[SingleUnitWindow.Vars.HasValue('tab','headquarters')]"`. Recipe in §4.
* Scripted GUIs are called from .gui as `[GetScriptedGui('key').Execute(GuiScope.SetRoot(GetPlayer.MakeScope).End)]`, `.IsValid(...)`, `.IsShown(...)`; extra scopes via `.AddScope('name', X.MakeScope)`. **VERIFIED** (`economy_lateralview.gui:444,1710`, CMP: 23 849 / 23 643 / 2 158 uses). Script variables are read as `X.MakeScope.GetVariable('name').GetValue|IsSet|GetCountry|GetCharacter|GetLocation`. **VERIFIED**. `Unit.MakeScope` is **UNVERIFIED** (never used in vanilla or CMP GUI; `Siege.MakeScope`, `Location.MakeScope`, `Country.MakeScope`, `Player.MakeScope` are verified).
* New windows can be added *without overriding vanilla files* via `scripted_widgets` (`<mod>/in_game/gui/scripted_widgets/<any>.txt` → `gui/<file>.gui = <widget_name>`; the widget **must** have a function-valued `visible`). **VERIFIED** (`G/main_menu/gui/scripted_widgets/_scripted_widgets.info`, CMP `in_game/gui/scripted_widgets/sakuya_scripted_windows.txt`).

---

## 1. GUI load model and mod file placement

| Fact | Status | Evidence |
|---|---|---|
| In-game windows live in `G/in_game/gui/*.gui`; shared templates in `G/in_game/gui/shared/*.gui` **and** `G/main_menu/gui/shared/*.gui` (buttons, backgrounds, colors, windows, tooltips) **and** `G/loading_screen/gui/preload/fonts.gui` + `G/loading_screen/gui/shared/defaults.gui` (fonts, `button_regular`). | VERIFIED | `ls` of the folders; `fonts.gui:16-57`; `defaults.gui:385-396` |
| A mod mirrors the layout: `<mod>/in_game/gui/...`, `<mod>/main_menu/common/...`, `<mod>/in_game/common/scripted_guis/...` + `<mod>/.metadata/metadata.json`. | VERIFIED | CMP tree; SC tree |
| Any `.gui` file dropped into `in_game/gui/` (incl. subfolders, incl. `shared/`) is loaded; mods add new `types ... { type x = ... }` and `template` blocks in their own files. | VERIFIED | CMP `in_game/gui/shared/sakuya_types.gui:5-7` defines `types SakuyaCoATypes { type character_frame_medium_sakuya = widget {` |
| A *top-level widget* in a new file is only instantiated if it is registered as a scripted widget (or spawned by console `GUI.CreateWidget`). | VERIFIED | `_scripted_widgets.info` (full text below); SC `simple_cheats_ui.gui:3` `onclick = "[ExecuteConsoleCommand('GUI.CreateWidget gui/simple_cheats_ui.gui simple_cheats_window')]"`; `:68` `GUI.ClearWidgets simple_cheats_window` |
| Overriding a vanilla file = copy with the **same relative path**; the whole file is replaced. SC ships `in_game/gui/panels/left_panel.gui` but vanilla is at `in_game/gui/panels/left_panel/left_panel.gui` → SC's override is at the wrong path and would load as an *extra* file (its `simple_cheats_button` injection is dead). | VERIFIED (paths) / INFERRED (consequence) | `find G -name left_panel.gui` → `panels/left_panel/left_panel.gui`; SC file list |
| Lateral-view names (`OpenLateralView('single_unit_formation')`, `IsLateralViewOpened('unit_overview')`) are **code-defined**; there is no script registry (grep of `single_unit_formation` outside the two gui files finds only a tutorial comment). A mod therefore **cannot add a new lateral view name**; new content must live inside an existing lateral view or in a scripted-widget window. | VERIFIED (no registry found) / INFERRED | `grep -rn single_unit_formation G --include=*.txt` → only `tutorial_lessons/00_tutorial_lesson_military.txt:147` |

`G/main_menu/gui/scripted_widgets/_scripted_widgets.info` (verbatim, VERIFIED):
```
Scripted widgets are a way of creating widgets without needing to define them inside an existing .gui file.
A scripted widget is declared following this format within a .txt file inside this folder:
gui/scripted_widget_file_name.gui = scripted_widget_name
Note: The scripted widget inside the .gui file is required to have a 'visible' attribute.
'visible = yes' does not work, the boolean must be returned by a function.
As a workaround, 'visible = "[EqualTo_CFixedPoint('(CFixedPoint)0', '(CFixedPoint)0')]"' works as an equivalent to 'visible = yes'.
```
CMP puts its registry at `CMP/in_game/gui/scripted_widgets/sakuya_scripted_windows.txt` (vanilla folder is under `main_menu/gui/`); both locations load (the CMP windows exist in gui.log). **VERIFIED**:
```
gui/sakuya_button.gui = sakuya_button_window
gui/sakuya_army_generator.gui = sakuya_army_generator_window
```
and `CMP/in_game/gui/sakuya_button.gui:1-11`:
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
Window `layer` values seen in vanilla: `confirmation`(14) `top`(13) `map_marker`(3) `lateralview`(3) `bottom`(3) `loadsave`(2) `windows_layer`(1, SC uses it) `tutorial` `topbar`(CMP) `sidemenu` `outliner` `middle`. **VERIFIED** (grep).

Scripted-GUI definitions: vanilla `G/in_game/common/scripted_guis/economy_satisfaction_target.txt`; SC uses `in_game/common/scripted_guis/`; CMP uses `main_menu/common/scripted_guis/` — all three load (**VERIFIED** existence; INFERRED that both folders are read). Format from `G/in_game/common/scripted_guis/scripted_guis.info` (VERIFIED):
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
`scope =` values used by CMP (VERIFIED): `country` (×23k), `location`, `province`, `region`, `area`, `religion`, `culture`, `character`. **`scope = unit` is UNVERIFIED** (never used by vanilla/CMP/SC).

---

## 2. Anatomy of the army window (`single_unit_window.gui`)

### 2.1 Window, datacontext, header — VERIFIED
`G/in_game/gui/single_unit_window.gui:3449-3451`:
```
lateralview = {
	name = "single_unit_window"
	widgetid = "single_unit_window"
```
`lateralview` is a `widget` type with blocks `panel_header`, `panel_content`, `lateralview_topbuttons_extra` (`G/in_game/gui/shared/windows.gui:1155-1205`):
```
	type lateralview = widget {
		size = { 100% 100% }
		...
		vbox = {
			using = lateralview_margins
			widget = {
				using = layoutpolicy_expanding
				vbox = {
					using = layoutpolicy_expanding
					block "panel_header" {}
					hbox = {
						using = layoutpolicy_expanding
						widget = {
							using = layoutpolicy_expanding
							vbox = {
								using = layoutpolicy_expanding
								block "panel_content" {}
```
Datacontext: there is **no explicit `datacontext` on the window**; functions are called on the global `SingleUnitWindow` object. Inner containers bind the unit explicitly (`:3660-3661`):
```
					hbox = {
						datacontext = "[SingleUnitWindow.AccessSelectedUnit]"
						datacontext = "[SingleUnitWindow.AccessSelectedUnit.GetLocation]"
```
after which children use `Unit.` and `Location.` (e.g. `:4017-4066` `datacontext = "[SingleUnitWindow.GetSelectedUnit]"` then `text = "[Unit.GetMaintenanceCost|+=0]"`).

Header (`:3510-3521`, `3570-3576`): `window_header_alt` with `blockoverride "window_header_alt_color_texture" { using = color_default_brown_texture }`, `blockoverride "header_text_object"` containing `country_flag_small` + `header_title { text = "[SingleUnitWindow.GetSelectedUnit.GetNameWithNoTooltip]" }` + an `editbox` for renaming toggled by `SingleUnitWindow.Vars.Toggle('edit_name')`.

Top buttons (`:3453-3506`): `button_minimize` rename (`texture = "gfx/interface/buttons/flats/rename_new.dds"`) and collapse/expand (`SingleUnitWindow.ToggleCompactView`, `IsCompactViewEnabled`, `input_action = "toggle_window_collapse"`).

### 2.2 Content layout (top → bottom) — VERIFIED
`:3644-3648` the root content container:
```
	blockoverride "panel_content" {
		vbox = {
			using = layoutpolicy_expanding
			using = bg_main_inner_notabs_alt
			using = window_main_tabs_margin_alt
```
1. **Unit card** (`:3650-3692`): `widget name = "single_unit_main_content"` → `hbox { datacontext unit/location; using = bg_market_card; using = bg_cabinet_card_frame; unit_card = {...}; unit_card_right_buttons = {...} }` (`unit_card` type defined in `unit_overview.gui:1946`).
2. **Illustration block** (`:3696-3706`, gated by the tab var):
```
			widget = {
				visible = "[SingleUnitWindow.Vars.NotExistOrHasValue( 'tab', 'actions' )]"
				layoutpolicy_horizontal = expanding
				size = { -1 220 }
				masked_threecolor_icon = {
					size = { 100% 100% }
					texture = "[GetSubunitIllustration(SingleUnitWindow.GetSelectedUnit.GetVisualSubunit)]"
					mask =  "[GetSubunitIllustrationMask(SingleUnitWindow.GetSelectedUnit.GetVisualSubunit)]"
					primary_color = "[GetCountryUnitPrimaryColor(SingleUnitWindow.GetPlayer, SingleUnitWindow.GetSelectedUnit.GetVisualSubunit.GetDefinition)]"
```
   inside it: status strip (`:3713-3880`): `OneOrSeveralTimedModifiers` (`:3723-3728`), in-transport / hidden-visible / exiled / retreating icons; then **commander** (`:3890-3990`): `hbox { datacontext = "[SingleUnitWindow.GetSelectedUnit.GetCommander]" ... character_frame_medium_with_labels_and_abilities = { enabled = "[Character.CanGiveUnitBonus]" ...}` + `header_button_left` "remove commander" (`on_action = "[Unit.RemoveCommander]"`).
3. **Actions content** (`:4006-4016`):
```
			vbox = {
				using = layoutpolicy_expanding
				using = bg_secondary_inner_alt
				### ACTIONS CONTENT
				vbox = {
					using = layoutpolicy_expanding
					margin = {5 5}
					spacing = 5
					visible = "[SingleUnitWindow.Vars.NotExistOrHasValue( 'tab', 'actions' )]"
```
   containing: stats row (`:4017-4185`: maintenance ducats/manpower/sailors, food piechart `Unit.GetFoodPercentage`, artillery), **actions grid** (`:4349+`, `unit_action_category` blocks filtered by `UnitActionItem.IsCategory('main_actions'|'deattach_builder_actions'|'temporary_actions')`), **combat / siege / flanks** (`:4472-4700`, `card_header_button_04` siege card, `UnitFlankInfo` ×4 with `GetUnitBox('left'|'center'|'right'|'reserves')`), **regiments list** (`:4696-4800`, `filtered_sorted_list { datacontext = "[SingleUnitWindow.GetSubUnitsSortSearch]" ... datamodel = "[SingleUnitWindow.GetSubUnits]" item = { widget { using = bg_paper_card ... datacontext = "[SubUnit.GetDefinition]" using = subunit_illustration ... } }`).
4. **Commented-out "formation" tab** (`:5058-5168`): `# visible = "[SingleUnitWindow.Vars.HasValue( 'tab', 'formation' )]"` with `BoxUnit` widgets — proof the designers planned in-window tabs keyed on `Vars 'tab'`.
5. Trailing templates: `reinforcement_rate_tootlip` (`:5177`), `subunit_illustration` (`:5216`), and `select_menu_left { name = "single_unit_select_unit" }` (`:5257`, unit picker, `datamodel = "[AccessPlayerUnits]"`).

Types defined at the top of the file (`types SingleUnitWindowTypes`, `:2`): `UnitFlankInfo`(118) `CombatProgress`(407) `SiegeProgress`(628) `occupation_block`(888) `siege_modifier`(1153) `siege_block`(1190) `unit_category_secondary_icon`(2136) `unit_action_category`(2562) `unit_mercenary_contracts_ongoing`(2910); templates `toggle_unit_action_icon`(3072) `unit_formation_texture`(3138) `army_strength_texture`(3142) `navy_strength_texture`(3146). **VERIFIED**

### 2.3 The three sibling windows — VERIFIED
* `single_unit_formation_window.gui:1-3`: `lateralview = { name = "single_unit_formation_window" widgetid = "single_unit_formation_window"`, context object `SingleUnitFormationWindow` (`GetSelectedUnit`, `AccessSelectedUnit`, `GetBalanceAction`, `ChangeUnitBox(SubUnit.Self,'left')`, `CanChangeUnitBox`, `ChangeAllUnitsOfCategoryBox`, `ChangeAllUnitsOfTypeBox`). Header `blockoverride "header_text" { text = "FORMATION_TAB" }` (`:8-10`). Opened from the army window by `header_button_right { action_tooltip { title = "OPEN_FORMATION_TAB" on_action = "[OpenLateralView('single_unit_formation')]" } }` (`single_unit_window.gui:4636-4643`).
* `single_unit_detail_window.gui:1-8`: `select_menu_fullscreen_right = { blockoverride "menu_setup" { name = "unit_details_window" } blockoverride "close_on_action" { on_action = "[UnitDetailsView.OnClose]" }` — body commented out; defines `template BoxUnit` (`:73-318`) used by the formation window.
* `multi_unit_window.gui:1-2`: `lateralview_unattached = { name = "multi_unit_window"`, object `MultiUnitWindow` (`AccessUnitItems`, `AccessFilteredUnitItems`, `GetAllActionItems`, `HasOneUnitItem`, `AccessFirstUnitItem.AccessUnit`, `GetUnitsSortSearch`, `Vars.Toggle('edit_name')`); quick actions: `datacontext = "[MultiUnitWindow.AccessFirstUnitItem.AccessUnit.GetQuickUnitActions]" datacontext = "[Pin('unit_actions')]" ... datamodel = "[QuickUnitActions.AccessList]" item = { unit_action_item = { visible = "[PinCollection.IsPinnedWithDefaultValue( UnitActionItem.GetKey, UnitActionItem.IsPinnedByDefault)]" } }` (`:252-264`).

---

## 3. The vanilla tab mechanism — VERIFIED

### 3.1 Per-window variable store `Vars`
Every lateral-view context object exposes `Vars` with `Set`, `Toggle`, `SetOrToggle`, `Clear`, `Exists`, `HasValue`, `NotExistOrHasValue`. Seen on `SingleUnitWindow` (`Toggle`, `Exists`, `Clear`, `NotExistOrHasValue`, `HasValue` — lines 3469/3559/3627/3697/5066), on `MaritimeLateralView` (`Set`, `maritime_lateralview.gui:425`), `UnitOverview` (`Set`, `unit_overview.gui:12`), the generic `LateralView` (`decisions_lateralview.gui:716-720`) and `GameLobby.Vars.SetOrToggle`. `SingleUnitWindow.Vars.Set(...)` itself is **INFERRED** (same `Vars` object type; `Set` is verified on four other windows).

`decisions_lateralview.gui:716-720`:
```
							down = "[LateralView.Vars.NotExistOrHasValue('subtab','decisions')]"
							...
								on_action = "[LateralView.Vars.Set('subtab','decisions')]"
```
Global (window-independent) store: `GetVariableSystem.Set('k','v') / HasValue / Exists / Toggle / Clear` — `game_rules.gui:39-41`:
```
							on_action = "[GetVariableSystem.Set( 'gamerules_page', 'general_rules' )]"
						down = "[Or(Not(GetVariableSystem.Exists('gamerules_page')), GetVariableSystem.HasValue( 'gamerules_page', 'general_rules' ))]"
```
(CMP uses `GetVariableSystem` ~8 000 times, incl. `GetVariableSystem.Toggle('sakuya_main_visible')`, `sakuya_button.gui:48-49`). `AuxVars.Toggle(key)/Clear/Exists` is a third, hover-scratch store (`automation_lateralview.gui:1722-1723`).

### 3.2 Tab header containers and buttons
`G/main_menu/gui/shared/main_menu_buttons.gui`:
* `type header_main_tabs = widget` (`:967-1005`): `using = button_main_tab_props` (`layoutpolicy_horizontal = expanding size = { -1 45 }`, `:372-375`), leather/dark-blue backgrounds, `hbox { using = button_main_tab_hbox_props block "content" {} }` (`margin 15/15, margin_top 5, spacing 5`, `:365-370`).
* `type header_secondary_tabs = widget` (`:1280-1298`): fade background, `hbox { block "secondary_tabs_margin" { using = button_secondary_tab_hbox_props } block "content" {} }`.
* `type button_main_tab_alt_base = button` (`:1008-1049`): `using = button_main_tab_texture` (`gfx/interface/buttons/main_tab_alt.dds`, `frame_grid = {4 1}`, `:356-363`), `gfxtype = togglepushbuttongfx`, frames up/hover/pressed/down, inner `hbox { margin = { 5 0 } margin_top = 4 text_single { block "tab_text"{ visible = no text = "" } using = Font_Type_Headers ... } }`.
* `type button_main_tab_alt = button_main_tab_alt_base` (`:1051+`): `size = { -1 40 }`, brown multiply + `tab_selection_texture` (`selected_tab_up_texture_sides1_alt.dds`, `:377-383`).
* `type button_secondary_tab_alt = button_main_tab_alt_base` (`:1715-1736`): `size = { -1 40 } using = button_secondary_tab_alt_color` (blue multiply, `:434-445`) + selection texture.
* `type button_panel_tab_alt = button` (`:1739-1760`): square icon tab (`gfx/interface/buttons/panel_tabs_alt.dds`, `frame_grid = { 4 1 }`), used by SC for its left-panel button.

Canonical usage, `G/in_game/gui/maritime_lateralview.gui:413-446` (secondary tabs *inside* the content vbox):
```
			header_secondary_tabs = {
				blockoverride "content" {
					button_secondary_tab_alt = {
						using = layoutpolicy_expanding
						blockoverride "tab_text"{
							text = "MARITIME_SUBTAB_COASTS"
						}
						tooltipwidget = {
							using = SubTabCoastsTooltip
						}
						action_tooltip = {
							title = "OPEN_TAB"
							on_action = "[MaritimeLateralView.Vars.Set( 'low_tab', 'coasts' )]"
						}
						down = "[MaritimeLateralView.Vars.NotExistOrHasValue( 'low_tab', 'coasts' )]"
					}
```
followed by (`:448-456`) `vbox { using = layoutpolicy_expanding using = bg_secondary_inner_alt vbox { using = layoutpolicy_expanding visible = "[MaritimeLateralView.Vars.NotExistOrHasValue( 'low_tab', 'coasts' )]" ...` and (`:692`) `visible = "[MaritimeLateralView.Vars.HasValue( 'low_tab', 'privateers' )]"`.

Main tabs *above* the content (`G/in_game/gui/unit_overview.gui:212-221`):
```
	blockoverride "panel_content" {
		header_main_tabs = {
			blockoverride "content" {
				using = military_main_tabs
			}
		}
		vbox = {
			visible = "[UnitOverview.Vars.NotExistOrHasValue( 'subtab', 'army' )]"
			using = layoutpolicy_expanding
			using = window_main_tabs_margin_alt
			using = bg_main_inner_image_alt
```
with the button template (`unit_overview.gui:1-14`): `button_main_tab_alt = { layoutpolicy_horizontal = expanding ... down = "[And(IsLateralViewOpened('unit_overview'), UnitOverview.Vars.NotExistOrHasValue( 'subtab', 'army' ))]" ... blockoverride "on_action_left" { on_action = "[UnitOverview.Vars.Set( 'subtab', 'army' )]" } blockoverride "text" { text = "ARMY_OVERVIEW" } }` (the `on_action_left`/`text` blocks come from `using = automated_tab`, `automation_lateralview.gui:1720-1770`; a plain button uses `action_tooltip { title = "OPEN_TAB" on_action = ... }` + `blockoverride "tab_text"`).

Background pairing: `bg_main_inner_alt` (with tabs) vs `bg_main_inner_notabs_alt` (no tabs) — `G/main_menu/gui/shared/backgrounds.gui:4897` and `:5371-5389`; secondary: `bg_secondary_inner_alt` (`:5017`) vs `bg_secondary_inner_notabs_alt` (`:5392-5412`). The army window uses the *notabs* main bg (`:3646`) and the *with-tabs* secondary bg (`:4008`).

---

## 4. Recipe: adding the "Headquarters" tab (minimal diff)

Approach: full-file override of `single_unit_window.gui` (only option for in-window integration; §1). Keep a diff/patch file in the repo so the override can be re-applied after game patches (file is 5301 lines; vanilla 1.4.7 line numbers below).

### Step 1 — copy
`copy "G\in_game\gui\single_unit_window.gui" "<mod>\in_game\gui\single_unit_window.gui"` (no rename; same relative path).

### Step 2 — insert the tab bar
Insert **after** the unit-card `vbox` (ends at `:3693`, the `}` closing `# UNIT CARD`) and **before** the illustration `widget = { visible = "[SingleUnitWindow.Vars.NotExistOrHasValue( 'tab', 'actions' )]"` (`:3696`):
```
			# CW: unit window tabs (vanilla already gates content on Vars 'tab'/'actions')
			header_secondary_tabs = {
				blockoverride "content" {
					button_secondary_tab_alt = {
						using = layoutpolicy_expanding
						blockoverride "tab_text" { text = "CW_UNIT_TAB_ACTIONS" }
						action_tooltip = { title = "OPEN_TAB" on_action = "[SingleUnitWindow.Vars.Set( 'tab', 'actions' )]" }
						down = "[SingleUnitWindow.Vars.NotExistOrHasValue( 'tab', 'actions' )]"
					}
					button_secondary_tab_alt = {
						using = layoutpolicy_expanding
						visible = "[SingleUnitWindow.GetSelectedUnit.IsArmy]"
						blockoverride "tab_text" { text = "CW_UNIT_TAB_HQ" }
						action_tooltip = { title = "OPEN_TAB" on_action = "[SingleUnitWindow.Vars.Set( 'tab', 'headquarters' )]" }
						down = "[SingleUnitWindow.Vars.HasValue( 'tab', 'headquarters' )]"
					}
					button_secondary_tab_alt = {
						using = layoutpolicy_expanding
						blockoverride "tab_text" { text = "FORMATION_TAB" }
						action_tooltip = { title = "OPEN_FORMATION_TAB" on_action = "[OpenLateralView('single_unit_formation')]" }
						down = "[IsLateralViewOpened('single_unit_formation')]"
					}
				}
			}
```
All pieces are vanilla-verified: `header_secondary_tabs`/`button_secondary_tab_alt`/`tab_text`/`action_tooltip`+`OPEN_TAB` (`maritime_lateralview.gui:413-427`), `OpenLateralView('single_unit_formation')` + `OPEN_FORMATION_TAB` (`single_unit_window.gui:4636-4643`), `IsLateralViewOpened('x')` (`maritime_lateralview.gui:30`). `IsLateralViewOpened('single_unit_formation')` returning true while that view is open is **INFERRED** (same key as `OpenLateralView`). Because the formation window is a *different* lateral view, this third button is navigation, not a real tab — acceptable, or omit it. (Optional 4th: "Details" via `UnitDetailsView` — the details window body is empty in vanilla, so skip.)

Also change `:3646` `using = bg_main_inner_notabs_alt` → keep as is (secondary tabs look fine on it; `maritime` does the same) or switch to `bg_main_inner_alt` if you move the bar above the unit card as `header_main_tabs` (then use `button_main_tab_alt`).

### Step 3 — gate existing content (already done by vanilla)
`:3697` and `:4016` already carry `visible = "[SingleUnitWindow.Vars.NotExistOrHasValue( 'tab', 'actions' )]"`. Nothing to change. (The `vbox` at `:4006` with `bg_secondary_inner_alt` stays visible as the blue frame for both tabs — desired.)

### Step 4 — add the HQ content panel
Insert inside the `vbox { using = layoutpolicy_expanding using = bg_secondary_inner_alt` (opened at `:4006`), **as a sibling after the `### ACTIONS CONTENT` vbox** (i.e. right before the commented `# ### FORMATION CONTENT` at `:5058`):
```
				### CW HEADQUARTERS CONTENT
				vbox = {
					using = layoutpolicy_expanding
					margin = {5 5}
					spacing = 5
					visible = "[SingleUnitWindow.Vars.HasValue( 'tab', 'headquarters' )]"
					datacontext = "[SingleUnitWindow.GetSelectedUnit]"

					# (a) status card: timed/unit modifiers on this army (vanilla widget, shows cw_no_hq penalty)
					hbox = {
						layoutpolicy_horizontal = expanding
						minimumsize = { -1 45 }
						using = bg_paper_card
						using = bg_cabinet_card_frame
						icon_text_2rows = {
							blockoverride "icon_obj" { icon = { size = { 32 32 } texture = "gfx/interface/icons/unit_actions/commander.dds" } }
							blockoverride "top_text_setup" { text = "CW_HQ_STATUS" }
							blockoverride "bottom_setup" {}
						}
						widget = {
							size = { 50 40 }
							datacontext = "[SingleUnitWindow.GetSelectedUnit.GetTimedModifierOwner]"
							visible = "[GreaterThan_int32(GetDataModelSize(TimedModifierOwner.GetModifiers), '(int32)0')]"
							OneOrSeveralTimedModifiers = {}
						}
					}
```
```
					# (b) regiments list filtered to HQ regiments
					scroll_list = {
						using = layoutpolicy_expanding
						blockoverride "scroll_list_setup" {
							using = layoutpolicy_expanding
							scrollbarpolicy_horizontal = always_off
							scrollbar_vertical = { using = Scrollbar_Vertical_Small }
						}
						blockoverride "scroll_list_is_empty" { visible = "[IsDataModelEmpty(SingleUnitWindow.GetSubUnits)]" }
						blockoverride "scroll_list_content" {
							addcolumn = 100%
							addrow = 75
							datamodel = "[SingleUnitWindow.GetSubUnits]"
							item = {
								widget = {
									size = { 100% 70 }
									visible = "[SubUnit.GetDefinition.HasStat('cw_hq')]"   # UNVERIFIED filter, see §12
									scroll_sub_unit_banner = { parentanchor = center blockoverride "size" { size = { 92% 70 } } }
								}
							}
						}
					}
				}
```
Verified parts: `scroll_list` + `scroll_list_setup`/`scroll_list_is_empty`/`scroll_list_content` blocks, `addcolumn/addrow`, `datamodel = "[SubUnitArray.GetSubUnits]"`, `scroll_sub_unit_banner { blockoverride "size" {...} }` (`single_unit_formation_window.gui:272-306`); `datamodel = "[SingleUnitWindow.GetSubUnits]"` (`single_unit_window.gui:4742`); `OneOrSeveralTimedModifiers` on `GetTimedModifierOwner` (`:3723-3728`); `icon_text_2rows` blocks `icon_obj`/`top_text_setup`/`bottom_setup` (`G/in_game/gui/shared/standard_types.gui:881-940`); `SubUnitType.HasStat('artillery_barrage')` (`single_unit_window.gui:5233`). **UNVERIFIED**: whether a custom stat key is accepted by `HasStat`, and whether a hidden `item` keeps its row height (vanilla lists usually use `filtered_sorted_list` with a code-side filter instead; alternative is `ignoreinvisible = yes` in a `flowcontainer`/`vbox` list — `multi_unit_window.gui:229-241` uses `flowcontainer { wrap_count = 10 ignoreinvisible = yes ... datamodel = ... item = { unit_action_item = {} } }`).

### Step 5 — scripted actions on the tab (buttons)
Button skeleton (pattern verified in `economy_lateralview.gui:1710` and SC `simple_cheats_ui.gui:71-77`; country root):
```
					button_regular = {
						size = { 220 30 }
						raw_text = "[Localize('CW_HQ_REQUEST')]"
						enabled = "[GetScriptedGui('cw_request_hq').IsValid(GuiScope.SetRoot(GetPlayer.MakeScope).AddScope('loc', SingleUnitWindow.GetSelectedUnit.GetLocation.MakeScope).End)]"
						onclick = "[GetScriptedGui('cw_request_hq').Execute(GuiScope.SetRoot(GetPlayer.MakeScope).AddScope('loc', SingleUnitWindow.GetSelectedUnit.GetLocation.MakeScope).End)]"
						tooltipwidget = { LeftClickButtonTooltip = { blockoverride "onclick_text" { text = "CW_HQ_REQUEST_TT" } } }
					}
```
`Location.MakeScope` verified (`location_window.gui` uses `Location.MakeScope`, `Siege.MakeScope` at `:1058`); `.AddScope('estate_type', X.MakeScope)` verified (`economy_lateralview.gui:1710`); `LeftClickButtonTooltip` + `onclick_text` verified (SC `:29-31`, type at `main_menu_cooltip_types.gui:1548`). The script then finds the unit from `scope:loc` (`every_unit = { limit = { unit_location = scope:loc } }` — `unit_location` token seen 44× in `G/in_game/common`, exact trigger form **INFERRED**). Passing the unit itself (`SingleUnitWindow.GetSelectedUnit.MakeScope`) is **UNVERIFIED** — test first; if it works, use `scope = unit` scripted GUIs (also UNVERIFIED).

### Step 6 — localization
`<mod>/main_menu/localization/english/cw_gui_l_english.yml` (UTF-8 **with BOM**, header `l_english:`, one leading space per key — format verified at `G/main_menu/localization/english/interfaces_l_english.yml:1-5`), plus `russian/cw_gui_l_russian.yml` (`l_russian:`; the user's game runs in Russian — error.log shows Russian loc strings; folder `G/main_menu/localization/russian` exists):
```
l_english:
 CW_UNIT_TAB_ACTIONS: "Actions"
 CW_UNIT_TAB_HQ: "Headquarters"
 CW_HQ_STATUS: "Headquarters status"
```
Vanilla keys reused: `OPEN_TAB: "Open tab"` (`:950`), `MILITARY_TAB: "Military"` (`:2807`), `FORMATION_TAB: "Formation"` (`:2816`), `OPEN_FORMATION_TAB: "Open $FORMATION_TAB$"` (`:2817`), `ARMY_OVERVIEW: "Armies"` (`:2906`).

### Step 7 — verify
Launch, open an army, watch `Documents/Paradox Interactive/Europa Universalis V/logs/gui.log` for lines mentioning `gui/single_unit_window.gui:<line>`; console `GUI.CreateWidget`/`GUI.ClearWidgets` exist for scripted-widget windows (SC). Hot-reload: not verified for this build (vanilla has `reload gui`-style console commands in other Jomini games — **UNVERIFIED** here).

---

## 5. Data functions on the unit contexts (as used in the unit GUI files) — all VERIFIED by grep

**Window object `SingleUnitWindow`**: `GetSelectedUnit`, `AccessSelectedUnit` (datacontext form), `GetPlayer`, `Vars.*`, `GetSubUnits`, `GetSubUnitsSortSearch`, `GetAllActionItems`, `CategoryActionsAmount('cat')`, `GetBalanceAction`, `GetDetachAction`, `GetMercenariesAction`, `GetMercenaries`, `GetCreateUnitAction`, `GetMaintenanceCost`, `GetRetreatTooltip`, `IsSubUnitUpgradable(SubUnit.Self)`, `CanRenameUnit`, `RenameUnit`, `OnUnitNameEdited`, `ToggleCompactView`, `IsCompactViewEnabled`, `ToggleSingleUnitSelectUnit(widget)`, `IsSingleUnitSelectUnitOpened(widget)`, `AddSubunitToNewUnit/AddSubunitTypeToNewUnit/AddSubunitCategoryToNewUnit`, `CanAddToCreatingUnit`, `IsAddToCreatingUnitVisible`, `HideCreateNewUnit`, `OnMouseEnter/LeaveAttackerBox/DefenderBox`. Sibling objects: `SingleUnitFormationWindow.*`, `MultiUnitWindow.*`, `UnitOverview.*` (`GetArmyUnits`, `GetArmyUnitsSortSearch`, `GetArmyTradition`, `RaiseAllLevies`, `CanBuild`, …), `UnitDetailsView.GetUnit/OnClose`.

**`Unit` (chained after `GetSelectedUnit.` or as datacontext)**:
* identity/owner: `Self`, `GetName`, `GetNameWithNoTooltip`, `GetCountry`, `GetLocation`, `IsArmy`, `IsNavy`, `GetVisualSubunit`, `GetStatusTexture`, `IsAutomated`, `GetObjectiveGroup.GetObjective.GetName`, `GetLoadedOn`.
* leader: `GetCommander` (→ `Character`), `HasLeader`, `CanReplaceLeader`, `CanReplaceLeaderInfo`, `RemoveCommander`, `GetCommander.CanGiveUnitBonus`; `Character.IsValid`, `Character.GetAbilityTooltipAsGeneral/AsAdmiral`; select commander: `SetupSelectCommanderLeft(Unit.Self)` (`unit_overview.gui:1981`).
* strength/morale/experience: `GetVisualStrength`, `GetMoraleFloat`, `GetMaxMoraleFloat`, `GetExperience`, `GetExperienceTooltip`, `IsGainingExperience`, `HasMaximumMaintenance`, `GetAccumulatedUnitStat('blockade_capacity')`, `GetCombinedArmsBonus/Info`, `GetArtilleryBonus/…Tooltip`, `GetTotalAttritionWeight`, `GetAttritionTooltip`.
* supply/money: `GetMaintenanceCost`, `GetFoodPercentage`, `GetDailyFoodBalance`, `IsGainingFood`, `GetReinforcementRateTooltip`, `GetUnitReinforceDetails`, `ShowReinforceDetails`, `GetReinforceSpeedInfo`, `GetTransportCost`, `GetMax/UsedTransportCapacity(Short|Percentage)`, `CanEmbark/CanDisembark(+Tooltip)`, `Disembark`.
* state: `InCombat`, `GetCombat`, `InSiege`, `GetSiege` (→ `Siege.GetLocation`, `GetSiegeDefender`, `GetNameWithNoTooltip`), `IsRetreating`, `IsExiled`, `GetExileTooltip`, `IsInTransport`, `IsVisibleToAi`, `GetIsVisibleToAiTooltip`, `HasPrisoners`, `ContainsPlayerMercenaries`.
* modifiers: `GetTimedModifierOwner` → `TimedModifierOwner.GetModifiers` (datamodel of `TimedModifier`), `.GetDisplayedCategoryTexture/Key`, `.GetDisplayedConceptLink`; `TimedModifier.GetModifier.GetName`, `.GetIcon`, `.GetTooltip`, `.GetModifierEffect`, `.GetDuration`, `.GetDesc`, `.GetProgress/GetInverseProgress`, `.IsPermanent`, `.IsUntilEndGame`.
* formation: `GetUnitBox('left'|'center'|'right'|'reserves'|'captured')` → `SubUnitArray` (`GetSubUnits`, `GetSize`, `GetStrength`, `GetStrengthPercent/Tooltip`, `GetMoralePercent/Tooltip`, `GetExperience/Tooltip`, `GetUsedFrontagePercentage`, `GetFrontageUsage`, `GetBoxName`, `GetFlankIcon`, `IsShip`, `IsLeft`, `IsReserves`, `GetUnit`), `GetUnitFormationPreference.GetName`, `IsAutobalanced`, `ToggleAutobalance`, `GetBalanceAction`, `GetQuickUnitActions`.
* sub units: `Unit.GetSubUnits` (`GetDataModelSize(Unit.GetSubUnits)`, `unit_overview.gui:2998`).

**`SubUnit`** (`sub_unit_banner.gui`, regiments list): `Self`, `GetDefinition` (→ `SubUnitType`), `GetUnit`, `GetOwner`, `GetNameWithNoTooltip`, `GetStrength`, `GetMaxStrength`, `GetStrengthDescription`, `GetMoralePercent`, `GetExperience`, `GetStat('combat_power'|'cannons'|'hull_size')`, `GetStatTooltip('x')`, `GetTypeDescription`, `GetSourceTooltip`, `IsRegiment`, `IsShip`, `IsLevy`, `IsMercenary`, `IsEstatePrivate`, `IsPrisoner`, `GetMercenary`, `GetUnitBox`, `GetSubunitFlankIcon`. **`SubUnitType`**: `Self`, `GetName`, `GetNameWithNoTooltip`, `GetCategory.IsArmy`, `HasStat('artillery_barrage')`, `GetStat('x')` (16× in `regiments_overview.gui`).

**Globals**: `GetUnitIcon(SubUnit.GetDefinition)`, `GetSubunitIllustration(SubUnit.Self)`, `GetSubunitIllustrationMask(...)`, `GetCountryUnitPrimary/Secondary/TertiaryColor(country, SubUnitType)`, `GetConceptTexture('morale'|'frontage'|'regulars'|'mercenary'|'private_regiment')`, `IsUnitSelected(Unit.Self)`, `AccessPlayerUnits`, `UpgradeSubUnit(SubUnit.Self)`, `CanUpgradeSubUnitTooltip(SubUnit.Self)`, `ShowUnitCombat(Combat.Self, Unit.Self)`, `SelectLocation(Siege.GetLocation)`, `ChangeUnitFormationPreference(Unit.Self)`, `GetUnitFormationPreferenceIcon(...)`, `OpenLateralView('x')`, `OpenLateralViewWithFilter('automation','automation_filter_military')`, `IsLateralViewOpened('x')`, `GetAutomatedSystemItem('armybuilder')`, `GetPlayer`, `Player`, `Pin('unit_actions')`, `IsDataModelEmpty(x)`, `DataModelHasItems(x)`, `GetDataModelSize(x)`, `GreaterThan_int32(a,'(int32)0')`, `FixedPointToFloat(x)`, `Subtract_float('(float)100.0', x)`, `StringToStringPairList(x)`, `Select_CString(cond, a, b)`, `SelectLocalization(cond, a, b)`, `Localize('KEY')`, `Localize(Concatenate(key, '_desc'))`, `AddTextIf(cond, text)`, `MakeItFailIf(cond, tooltip)`, `StringIsEmpty(x)`, `PdxGuiWidget.FindParent('name').Self`, `PdxGuiWidget.GetRemainingHeightInParent('lateralview_container','(float)10.0')`, `ToVector2f(...)`, `ExecuteConsoleCommand('...')`.

**Unit actions**: `UnitActionItem.{GetName, GetKey, GetTexture, GetNotTexture, GetShortcut, IsCategory('main_actions'), IsEnabled, IsActive, IsSecondaryActive, IsToggleAction, IsPinnedByDefault, HasSingleLeftAction, CanSingleLeftClick, SingleLeftClick, GetLeftClickDescription, HasSingleRightAction, CanSingleRightClick, SingleRightClick, GetRightClickDescription, HasHoldLeftAction, CanHoldLeftClick, HoldLeftClick, HasHoldRightAction, CanHoldRightClick, HoldRightClick, HasShiftLeftClick, GetShiftLeftName, GetSecondaryName, GetTooltip}`; `type unit_action_item = widget` at `unit_overview.gui:3373`.

**Strength / morale bars** (`unit_overview.gui:3044-3066`):
```
							progressbar = {
								visible = "[Unit.HasMaximumMaintenance]"
								tooltipwidget = { using = UnitMorale_tooltip }
								layoutpolicy_horizontal = expanding
								size = { -1 5 }
								using = progress_bar_green_alt
								min = 0
								max = "[Unit.GetMaxMoraleFloat]"
								value = "[Unit.GetMoraleFloat]"
```
Per-regiment bars (`sub_unit_banner.gui:218-250`): vertical `progressbar { size = { 5 40 } using = progress_bar_green_alt value = "[FixedPointToFloat(SubUnit.GetExperience)]" min = 0 max = 100 direction = vertical }` and the same with `SubUnit.GetMoralePercent`. Strength text: `text = "[Unit.GetVisualStrength]"` + `icon { using = army_strength_texture }` (`unit_overview.gui:2979-2988`); `raw_text = "[SubUnit.GetStrength]@army_strength!"` (icon-in-text syntax, `sub_unit_banner.gui`). Location: `datacontext = "[Unit.GetLocation]"` → `Location.GetNameWithNoTooltip`, `Location.IsLand`.

---

## 6. Calling scripted GUIs and reading script variables from .gui

### 6.1 Verified call patterns
| Pattern | Where |
|---|---|
| `on_finish = "[GetScriptedGui('taxing_setup').Execute(GuiScope.SetRoot(GetPlayer.MakeScope).End)]"` | `G/in_game/gui/economy_lateralview.gui:444` |
| `on_action = "[GetScriptedGui('subtract_one_percent').Execute(GuiScope.SetRoot(TaxRateSetting.GetEstate.GetCountry.MakeScope).AddScope('estate_type', TaxRateSetting.GetEstate.GetType.MakeScope).End)]"` → script reads `scope:estate_type` via `saved_scopes = { country estate_type }` | `economy_lateralview.gui:1710`; `G/in_game/common/scripted_guis/economy_satisfaction_target.txt:29-33` |
| `enabled = "[GetScriptedGui('sakuya_check_country_marked').IsValid(GuiScope.SetRoot(GetPlayer.MakeScope).End)]"` + `onclick = "[GetScriptedGui('...').Execute(...)]"` | `CMP/in_game/gui/sakuya_ai_personality.gui:74` |
| `visible = "[GetScriptedGui('sakuya_check_character_marked').IsValid(GuiScope.SetRoot(GetPlayer.MakeScope).End)]"` | CMP (line 50 of a sakuya gui) |
| `.IsShown(GuiScope.SetRoot(GetPlayer.MakeScope).End)` (2 158 uses) | CMP |
| Roots used: `GetPlayer.MakeScope`, `Player.MakeScope`, `Province.MakeScope`, `Location.MakeScope` (CMP); `TaxRateSetting.GetEstate.GetCountry.MakeScope` (vanilla) | — |
| `onclick = "[GetScriptedGui('pcs_global_population_capacity_add').Execute(GuiScope.SetRoot(GetPlayer.MakeScope).End)]"` with script `scope = country effect = { add_country_modifier = { modifier = X years = 999 mode = add } }` | `SC/in_game/gui/simple_cheats_ui.gui:91-93`; `SC/in_game/common/scripted_guis/sc_scripts.txt:2-5` |
| Button event names: `onclick = "[...]"` (plain button) or `action_tooltip = { click_type = left click_mode = single|confirm title = "KEY" on_action = "[...]" enabled = "[...]" description = "[...]" }` (vanilla style; `click_mode = confirm` asks confirmation) | `unit_overview.gui:1976-1985`; `single_unit_window.gui:3959-3966` |

Objects with `.MakeScope` seen in vanilla GUI (counts): `GetSituation`(104) `GetOwner`(66) `GetInternationalOrganization`(20) `Country`(16) `GetCountry`(10) `GetType`(9) `GetLeaderCountry`(9) `GetReligionByKey('orthodox')`(7) `Location`(3) `GetLocationByKey('constantinople')`(3) `Player`(2) `Market`(2) `TownRights` `Siege` `Omen` `God`. **`Unit.MakeScope` / `SubUnit.MakeScope`: 0 hits → UNVERIFIED.**

### 6.2 Reading script variables (VERIFIED)
```
datacontext = "[DisasterView.GetDisaster.GetOwner.MakeScope.GetVariable('GUI_pretender_rebel_character').GetCharacter]"
visible = "[InternationalOrganizationsView.GetInternationalOrganization.MakeScope.GetVariable('iberian_union_active').IsSet]"
text = "[SituationView.GetActiveSituation.GetSituation.MakeScope.GetVariable('heretics_converted_variable').GetValue|0]"
text = "[Multiply_CFixedPoint(DisasterView.GetDisaster.GetOwner.MakeScope.GetVariable('sunni_pop_count').GetValue, '(CFixedPoint)1000')|K-0]"
datacontext = "[GetReligionByKey('orthodox').MakeScope.GetVariableFromVariableMap('pentarchy', GetLocationByKey('constantinople').MakeScope).GetCharacter]"
```
(`panels/disaster/*.gui`, `panels/situation/*.gui`, `panels/organization/*.gui`). Accessors after `GetVariable('x')`: `.IsSet`, `.GetValue`, `.GetCountry`, `.GetCharacter`, `.GetLocation`, `.GetReligion`, `.GetReligionGroup`, `.GetPolicy`, `.GetRebel`, `.GetDiseaseOutbreak`. CMP: `MakeScope.GetVariable('X').GetCountry` (65×), `.IsSet` (2×). For a **country-level** HQ counter the mod can therefore display `[GetPlayer.MakeScope.GetVariable('cw_hq_count').GetValue|0]` (INFERRED from the `Country.MakeScope.GetVariable(...).GetValue` form at `panels/...:79`). There is **no `.Var(` syntax** anywhere (0 hits in vanilla and CMP).

### 6.3 Modifier text helpers (VERIFIED)
* `textcontext = "[GetModifier('western_schism_modifier').GetDesc]"` inside `TooltipRowList` (`panels/situation/western_schism.gui:222-226`) — renders a static modifier's effect list by key. Also `GetModifier('dlh_situation_modifier').GetDesc`, etc.
* `raw_text = "[ShowModifierEffect('sc_global_population_growth_add')]"` (SC `:91`), vanilla `textcontext = "[ShowModifierEffect('is_bankrupt')]"` (`credit.gui:517`), `cooltip.gui:216`.
* Country modifier values: `GetModifierValue('discipline')`, `GetModifierValueFixed('x')`, `GetModifierRawValue('x')`, `GetModifierValueNoFormat('x')`, `GetModifierTooltipContext('x')` (called on a country/`Player` context; grep counts in §0 research). `GetStaticModifier(...)`: **0 hits → UNVERIFIED** (use `GetModifier('key')`).
* `Localize('KEY')`, `Localize(Concatenate(X.GetNameKey, '_desc'))`, `Localize(TimedModifierOwner.GetDisplayedConceptLink)`; `Select_CString(cond, Localize('A'), Localize('B'))` (`single_unit_window.gui:4625`).

### 6.4 Script side relevant to the HQ feature (VERIFIED in `G/in_game/common`)
* Unit-scope list from country: `ordered_army = { limit = { NOT = { has_unit_modifier = extensive_training_modifier} } order_by = num_subunits max = 1 check_range_bounds = no save_scope_as = target_army add_unit_modifier = { modifier = extensive_training_modifier years = modifier_duration_years_short } }` (`generic_actions/parliament.txt:1262-1272`); `every_unit = { limit = { any_sub_unit = { sub_unit_type = unit_type:a_farfanes } } destroy_every_sub_unit_of_type = { sub_unit_type = unit_type:a_farfanes } }` (`government_reforms/country_specific.txt:1977-1982`); `any_army = { NOT = { exists = leader } }` (`generic_actions/unlockable_io_actions.txt:209`).
* Unit triggers index (`trigger_localization/unit_triggers.txt`): `is_army is_movement_locked morale_percentage strength_percentage experience_percentage is_unit_locked is_exiled food_percentage is_carrying_troops ... has_prisoners has_only_prisoners can_upgrade_unit has_unit_modifier has_commander in_combat in_retreat in_siege sub_unit_fraction sub_unit_count sub_unit_strength num_subunits has_levies has_regulars has_mercenaries`. Sub-unit triggers: `is_ship sub_unit_type sub_unit_category_this_equal subunit_morale_percentage subunit_strength_percentage is_levy definition_is_for_levy is_mercenary can_upgrade_subunit subunit_morale subunit_strength subunit_number`.
* Unit effects index (`effect_localization/unit_effects.txt`): `remove_unit_modifier add_unit_modifier add_unit_modifier_duration add_unit_modifier_forever add_morale add_subunit lock_unit unlock_unit add_food add_food_percentage destroy_unit set_unit_size change_unit_owner damage_unit_percent damage_unit_morale_percent set_as_commander make_unit_available_for_hire move_to_assist_on_adjacent_combat lend_unit_to_country`; sub-unit: `add_subunit_morale destroy_subunit add_subunit_strength add_subunit_strength_percentage add_subunit_experience change_subunit_type`.
* Unit static modifiers (`G/main_menu/common/static_modifiers/unit.txt:11-16`) — the vanilla "penalty for lacking X" precedent:
```
army_leaderless = {
	game_data = {
		category = unit
	}
	land_morale_modifier = -0.20
}
```
  and `siege_ability={ percent=yes game_data={ category=unit } }` (`G/main_menu/common/modifier_type_definitions/00_modifier_types.txt:5985-5990`); other unit-category keys used: `discipline`, `experience_decay`, `monthly_experience_gain`, `land_morale_modifier`, `land_unit_attrition`, `naval_morale_modifier`, `navy_repair_efficiency`, `naval_damage_taken`.
* Hooks: `on_siege_won` (`root = country, scope:target = location, scope:character = leading general character`, `on_action/_hardcoded.txt:319-321`), `on_location_occupied` (`:492-494`), `on_battle_won/lost` (`:3203-3209`, float scopes `killed_land_units`, `war_score`…), `on_battle_won_character` (`root = character`), `on_war_declared`, `on_join_war`. No `on_unit_*` on_action exists (grep) → per-unit HQ checks must run from country pulses (`country_monthly.txt` etc.).

---

## 7. Visual building blocks for a polished look (VERIFIED definitions)

| Name | Kind / file:line | What it is |
|---|---|---|
| `text_single`, `text_multi` | `type … = textbox`, `G/main_menu/gui/shared/labels.gui:5-16` | single/multi-line text; color via `default_format = "#yellow_titles" / "#subtle_name" / "#high" / "#overview_text" / "#header_titles" / "#color_white"` |
| `Font_Size_Small/Medium/Big` (15/18/23 px), `Font_Type_Headers` (`font = HeadersFont`), `Font_Type_Standard`, `Font_Type_Flavor` | templates, `G/loading_screen/gui/preload/fonts.gui:16-37, 48-61` | `using = Font_Size_Small` etc. |
| `header_title` | `type … = text_single`, `main_menu_windows.gui:133-138` | centered header text, `#header_titles` |
| `window_header_alt` | `type … = widget`, `main_menu_windows.gui:173+` | 40-px window header; blocks `header_text`, `header_text_object`, `window_header_alt_color_texture` (`color_default_brown_texture`, `color_military_texture` …, `colors.gui:56,71`) |
| `header_main_tabs`, `header_secondary_tabs`, `button_main_tab_alt`, `button_secondary_tab_alt`, `button_panel_tab_alt` | `main_menu_buttons.gui:967, 1280, 1051, 1715, 1739` | §3.2 |
| `subheader` | `type … = widget`, `main_menu_windows.gui:570-592` | 50-px sub header with blocks `subheader_background`, `content`, `subheader_bottom_divider` |
| `divider_solid_gold` | `type … = icon`, `window_components.gui:55-59` | 1-px gold line (`layoutpolicy_horizontal = expanding size = { -1 1 }`) |
| `divider_vertical_template` | template, `window_components.gui:211-222` | `size = { 2 15 }` light-blue vertical bar (army window uses `widget { using = divider_vertical_template layoutpolicy_vertical = expanding size = { 1 -1 } }`) |
| `bg_paper_card` | template, `backgrounds.gui:749-773` | paper card (`paper_card_texture`, `color_paper_texture`, `overlay_paper_03`) — regiments rows |
| `bg_market_card` + `bg_cabinet_card_frame` | `backgrounds.gui:2490-2504`, `:2665-2693` | dark-brown round card + wooden frame — the unit card container |
| `bg_text_mask_container_brown` | `backgrounds.gui:3852-3870` | brown pill behind icon+number stats (block `text_mask_extra { alpha }`) |
| `bg_age_event_frame` | `backgrounds.gui:5868-5900` | gold-rimmed squared frame (`tile_frame_age_squared.dds`) — around the illustration |
| `bg_card_header_01_military` | `backgrounds.gui:2015-2040` | red "military" card header (`color_military_texture` + pattern) — siege card |
| `bg_main_inner_alt / _notabs_alt`, `bg_secondary_inner_alt / _notabs_alt`, `bg_main_inner_image_alt` (block `image { texture = "gfx/interface/illustrations/bg/bg_military.dds" }`) | `backgrounds.gui:4897, 5371, 5017, 5392, 5074` | panel backgrounds |
| `icon_text_2rows` | `type … = widget`, `G/in_game/gui/shared/standard_types.gui:881-940` | 40-px icon + two text rows; blocks `icon_obj`/`icon_texture`, `top_text_setup`, `bottom_setup`, `text_align` |
| `OneOrSeveralTimedModifiers`, `timed_modifier_icon`, `timed_modifier_tooltip` | `shared/modifiers.gui:5-137`, `shared/standard_types.gui:772-829`, `shared/modifier_tooltips.gui:1-41` | banner icon (`regular_banner.dds`, 44×48) listing `TimedModifierOwner.GetModifiers`; 28-px pie-progress icon per modifier |
| `progress_bar_green_alt`, `progress_bar_goldish`, `progress_bar_blue_grey_alt` | templates, `progressbars.gui:189-195` | `progresstexture = "gfx/interface/progressbars/progress_bar_green_alt.dds"`; use `progressbar { size = { -1 5 } min/max/value }` |
| `header_button_left` / `header_button_right` | `main_menu_buttons.gui:2526-2560` (+ `header_button_template :463-520`) | 40-px navigational button with icon + `text_top`/`text_bottom` blocks (army window "Formation" button uses `header_button_right` 175×40 with `blockoverride "icon_overlay" { texture = "[GetConceptTexture('frontage')]" size = { 28 28 } }`) |
| `card_header_button_04` | `type … = button`, `G/in_game/gui/shared/buttons.gui:745-752` | 4-frame card header button (`card_header_button_04.dds`) |
| `button_regular`, `button_regular_red/yellow/green` | `G/loading_screen/gui/shared/defaults.gui:385-420` | plain 30-px text buttons (`fontsize = 13`), SC uses them |
| `button_minimize`, `button_close_alt`, `ui_direction_button_alt`, `filter_button_alt`, `button_icon` | `G/in_game/gui/shared/buttons.gui:426`; `main_menu_buttons.gui:1128, 961, 1675, 1248` | small icon buttons (`blockoverride "button_texture" { texture = ... texture_density = 2 }`) |
| `AutomationCheckbox` (22×22 toggle), `AutomatedSection` | `automation_lateralview.gui:191-213, 33` | `down = "[Unit.IsAutobalanced]"` style toggles |
| `scroll_list`, `filtered_sorted_list`, `Scrollbar_Vertical`, `Scrollbar_Vertical_Small` | `main_menu_lists.gui:92`, `G/in_game/gui/shared/lists.gui:81`, `custom_loading_screen.gui:387-389, 408` | lists; blocks `scroll_list_setup/_is_empty/_is_empty_text/_content/_layout` |
| Tooltips: `BasicFunctionalTooltip`, `ContextualTooltipType` (blocks `title_icon`, `title_text`, `concept_link`, `tooltip_content`), `SimpleContextualTooltipType` (+ `textcontext`/`lowpriotextcontext`), `TooltipTextBlock` (`blockoverride "text"`), `TooltipStringPairList`, `TooltipScrolledStringPairList`, `TooltipRowList`, `TooltipScrolledRowList`, `TooltipFunctionalBlock` + `tooltip_left_click_template`, `LeftClickButtonTooltip` (`onclick_text`), `tooltip_title_icon_size` (42×42) | `main_menu_cooltip_types.gui:1567, 1734, 987, 1931, 1974, 1772, 534, 1548, 6`; `G/in_game/gui/cooltip_types.gui:417, 463` | attach via `tooltipwidget = { X = { ... } }`; `BasicFunctionalTooltip = {}` auto-renders the sibling `action_tooltip` title/description |
| `glow = { name = "drop_shadow" glow_radius = 3 color = {0.0 0.0 0.0 1.0} alpha = 0.3 }` | used on most icons | drop shadow |
| `masked_threecolor_icon` + `GetSubunitIllustration/Mask` + `GetCountryUnit*Color` | `single_unit_window.gui:3700-3706, 5216-5255` | tinted unit illustration (`frame_grid = {3 1}`) |

---

## 8. Icon candidates (all under `G/main_menu/gfx/interface/`; referenced in .gui as `gfx/interface/...`) — VERIFIED paths

HQ / officers / commander: `icons/unit_actions/commander.dds`, `icons/character_roles/general.dds`, `icons/character_interactions/commander_button.dds`, `icons/character_interactions/assume_fort_command.dds`, `icons/diplomatic_status/giving_send_officers.dds`, `icons/diplomatic_status/receiving_send_officers.dds`, `icons/alerts_icons/army_without_leader.dds`, `icons/buildings/war_college.dds`, `icons/buildings/regimental_camp.dds`, `icons/unit_actions/create_supply_depot.dds`, `icons/unit_actions/regiment.dds`, `icons/unit_actions/regulars.dds`.
War / sword / stance: `icons/diplomatic_actions/war.dds`, `icons/diplomatic_status/war.dds`, `icons/map_icon_war.dds`, `icons/military_stances/aggressive_military_stance.dds`, `.../defensive_military_stance.dds`, `.../normal_military_stance.dds`, `.../passive_military_stance.dds`, `.../siege_raider_military_stance.dds`, `.../supportive_military_stance.dds`, `icons/ai_dispositions/planning_war.dds`, `icons/ai_dispositions/wary.dds`, `icons/ai_personalities/ai_defensive.dds`, `icons/flat_icons/attacker.dds`, `icons/flat_icons/defender.dds`, `icons/flat_icons/defense.dds`, `icons/flat_icons/war_enthusiasm.dds`, `icons/flat_icons/war_view/army_strength.dds`, `icons/flat_icons/declare_war/army_battles_won.dds`, `icons/flat_icons/declare_war/war_leader.dds`.
Shield: `icons/flat_icons/unit_selection_shield.dds`, `icons/military_army/fort_defense.dds`, `icons/flat_icons/siege_occupation/fort_defense.dds`.
Siege: `icons/flat_icons/siege_occupation/siege.dds`, `.../siege_accumulation.dds`, `.../occupation.dds`, `.../fortification.dds`, `.../brokenwalls.dds`, `icons/flat_icons/military/assume_siege.dds`, `icons/military_objectives/focus_siege.dds`, `icons/military_objectives/carpet_siege.dds`, `buttons/map_markers/unit_siege_button.dds`.
Harassing / hunting / waiting: `icons/military_objectives/hunt_armies.dds`, `.../hunt_reachable_armies.dds`, `.../chase_target.dds`, `.../defend_home_territory.dds`, `.../independent_operations.dds`, `.../support_armies.dds`, `.../where.dds`, `icons/flat_icons/battle/pause.dds`, `buttons/flats/pause_button.dds`, `icons/expedition_types/expeditions_paused.dds`, `buttons/flats/retreating.dds`.
Unknown / hidden: `icons/unit_view/army_hidden_icon.dds`, `icons/unit_view/army_visible_icon.dds`, `icons/character_roles/unknown_artist.dds`, `icons/icon_warning.dds`, `icons/unit_type/blocked_vision.dds`, `mapitems/hidden_from_land.dds`.
Time / age: `icons/age/age_1_traditions.dds … age_6_revolutions.dds`, `time_control/speed_indicator.dds`, `component_effects/alert_diplomacy_timer_base.dds` (no hourglass/clock icon exists — **VERIFIED absence**; draw one or reuse `age_*`).
Morale / discipline / stats: `icons/military_army/discipline.dds`, `.../army_morale.dds`, `.../military_tactics.dds`, `.../combined_arms.dds`, `icons/unit_view/morale.dds`, `icons/unit_view/experience.dds`, `icons/unit_view/food.dds`, `icons/unit_types/combat_power.dds`, `icons/unit_types/frontage.dds`, `icons/unit_category/army_size.dds`, `icons/flat_icons/military.dds`, `icons/flat_icons/tabicons/military.dds`, `buttons/flats/army.dds`, `buttons/flats/military.dds`.
Continents (colonial HQ): `icons/continents/{africa,asia,europe,north_america,oceania,south_america}.dds`, `icons/flat_icons/overseas.dds`.
Frames/banners for a custom plate: `component_tiles/regular_banner.dds`, `regular_banner_yellow.dds`, `military_banners.dds`, `military_modifiers_container.dds`, `tile_frame_age_squared.dds`, `buttons/round_button_texture_alt.dds` (CMP's round HUD button).

---

## 9. What gui.log / error.log show (and what causes it) — VERIFIED from the user's logs

`Documents/Paradox Interactive/Europa Universalis V/logs/gui.log` (305 lines, mostly from the installed cheat mods):
| Message | Cause / fix |
|---|---|
| `gui/sakuya_test.gui:N - Could not find template 'tooltip_ne'` (87×) | `using = X` where template X does not exist (typo / removed in 1.4). |
| `gui/sakuya_test.gui:N - Could not find template 'layoutpolicy_fixed'` | same; vanilla only has `layoutpolicy_expanding` (+ explicit `layoutpolicy_horizontal = fixed`). |
| `'use_global_input_instance' is not a valid widget/type/property` | property removed from the engine (see comment `single_unit_formation_window.gui:159`). |
| `Widget cannot have a position in a layout` (`cards.gui:4755`, `sakuya_location.gui`) | a child of `vbox`/`hbox` has `position = {}`; wrap it in a `widget` or drop `position`. |
| `Property 'spacing'(N) not handled` / `Error setting properties for '' (uberscrollarea)` | `spacing`/`margin` set on a widget type that is not a layout box (e.g. `scrollarea`, `button`). |
| `Illegal Property Value: 'fontsize_min' should be greater than 0 and less than 15` | `fontsize_min >= fontsize`. |
| `Malformed item desc '', item descriptions can only contain a single child and no properties` | `item = { ... }` of a `datamodel` list has two children or a property; wrap in one `widget`. |
| `Failed parsing localized text: KEY` | loc string contains an invalid `[...]` function or bad `$...$`. |
| `Failed setting property 'alwaystransparent'` on `modify_texture` | property placed on a wrong node. |
| `Reloadable widget [gui/alertmanager.gui]:[discard_stash] still registered when its context is destroyed` (error.log) | engine warning on exit; ignore. |
error.1.log (earlier sessions): `gui/shared/estate_tooltips.gui:N: No context supplied (Use SetDataContext), wanted context of type 'Container' for 'ESTATE.GetNameWithNoTooltip'` (1 529×) — a widget referencing `Estate.*` without a `datacontext`; and `Could not find data system function 'GetAdjective' in 'TARGET_CULTURE.GetAdjective'` — a promoted-function name that does not exist on that type. **These two are the errors you will see when a new tab references `Unit.*` outside a unit `datacontext` or calls a non-existent function such as `Unit.MakeScope`.**

---

## 10. Pitfalls

1. **Full-file override**: the only way to put a tab *inside* the army window; conflicts with any other mod touching `single_unit_window.gui` and must be re-merged after every patch (file has patch-note comments such as `:159` in the formation window). Keep a `.patch` and a vanilla checksum.
2. **No new lateral views**: `OpenLateralView('cw_hq')` cannot be registered from script (§1) → use the Vars tab or a scripted-widget window.
3. **Scripted widget `visible` must be a function** (`_scripted_widgets.info`); `visible = yes` silently never shows.
4. **Wrong relative path = extra file, not override** (SC `panels/left_panel.gui` vs vanilla `panels/left_panel/left_panel.gui`).
5. **`datacontext` scoping**: `Unit.*` only works under `datacontext = "[SingleUnitWindow.GetSelectedUnit]"` (or `AccessSelectedUnit`); otherwise "No context supplied" errors (§9). `Character.*` needs `datacontext = "[...GetCommander]"` and `Character.IsValid` guard (`:3909`).
6. **`item = {}` must contain exactly one child, no properties** (§9).
7. **`position` inside `vbox/hbox` is illegal**; use `parentanchor`/margins or wrap in `widget`.
8. **Tooltips**: `tooltipwidget = { BasicFunctionalTooltip = {} }` must sit next to an `action_tooltip` to have content; text tooltips need `ContextualTooltipType` with `TooltipTextBlock { blockoverride "text" { text = "KEY" } }`.
9. **Fonts/templates live in three folders** (`loading_screen/gui/preload/fonts.gui`, `loading_screen/gui/shared/defaults.gui`, `main_menu/gui/shared/*`); `grep` all of `game/` when a `using =` fails.
10. **Vars default**: use `NotExistOrHasValue('tab','actions')` for the default tab (var is unset until the first click) and `HasValue` for the others — exactly as vanilla does.
11. **Localization**: BOM + `l_english:`; the user plays in Russian → provide `l_russian` too or the tab shows raw keys; vanilla loc for `OPEN_TAB`, `FORMATION_TAB` is reusable.
12. **Hiding list items** does not collapse `scroll_list` rows (`addrow = 75` fixed grid) — prefer a code-side filtered list or `flowcontainer { ignoreinvisible = yes }` (`multi_unit_window.gui:229-241`) / `vbox { ignoreinvisible = yes }` (`sub_unit_banner.gui:38-42`).
13. **`raw_text` vs `text`**: `text = "KEY"` localizes; `raw_text` prints as is (`raw_text = "[SubUnit.GetStrength]@army_strength!"`).
14. **Scripted GUI roots**: `GetPlayer.MakeScope` gives the *player*, not the unit's owner; for AI-owned units use `SingleUnitWindow.GetSelectedUnit.GetCountry.MakeScope` (`GetCountry.MakeScope` form verified).
15. CMP leaves 100+ errors in gui.log; filter by `single_unit_window.gui` when debugging your own file.

---

## 11. Recommendations for the mod

1. Implement the HQ tab as in §4 (secondary tab bar under the unit card; `Vars 'tab'` with values `actions` / `headquarters`). Optional third button = navigation to the vanilla formation lateral view. Keep `bg_main_inner_notabs_alt` (maritime precedent) to minimise the diff.
2. Show HQ state via data that is **already rendered by vanilla widgets**: apply a static unit modifier `cw_no_hq` (`game_data = { category = unit }`, `siege_ability = -0.90`, `discipline = -x`, `land_morale_modifier = -y`) with `add_unit_modifier_forever`/`add_unit_modifier` from country pulses, so `OneOrSeveralTimedModifiers` (`GetTimedModifierOwner`) displays it with icon + tooltip for free — zero new data functions needed. Give it an icon in `main_menu/gfx/interface/icons/modifiers/` (vanilla folder `icons/modifiers` exists; file naming convention there is **UNVERIFIED**).
3. For counters ("HQ 2/3", "colonial HQ 1/2") store country variables (`set_variable` in country scope — vanilla pattern `economy_satisfaction_target.txt:4-5`) and read them in GUI with `[GetPlayer.MakeScope.GetVariable('cw_hq_count').GetValue|0]` (INFERRED from verified `Country.MakeScope.GetVariable('x').GetValue` form). A `text_single` + `icon_text_2rows` row per counter.
4. For buttons ("Request HQ regiment here", "Move HQ"), use country-root scripted GUIs with `AddScope('loc', <unit>.GetLocation.MakeScope)` (verified `AddScope` + `Location.MakeScope`) and resolve the unit in script; test `GetSelectedUnit.MakeScope` early — if it works, switch to `scope = unit` scripted GUIs (both UNVERIFIED).
5. Per-row HQ highlighting: give the HQ regiment a distinct `sub_unit_type`; in the list row use `datacontext = "[SubUnit.GetDefinition]"` + `SubUnitType.GetNameWithNoTooltip`; a boolean filter needs either `HasStat('<custom>')` (UNVERIFIED) or a vanilla `UnitActionItem`/code filter — simplest robust option: show *all* regiments and mark HQ rows with an icon whose `visible` uses the verified `SubUnitType.HasStat` on a stat the HQ type actually defines in its unit-type file (coordinate with the unit-type research doc).
6. War-stance top-bar plate: a `window = { layer = topbar ... visible = "[GetPlayer.IsValid]" }` registered via `<mod>/in_game/gui/scripted_widgets/cw_windows.txt` (CMP pattern), using `icons/military_stances/*.dds` and `GetVariableSystem`/`GetPlayer.MakeScope.GetVariable('cw_stance_<tag>')` for state; no vanilla file override needed.
7. Reuse `bg_paper_card` + `bg_cabinet_card_frame` for cards, `bg_text_mask_container_brown` for icon+number pills, `header_button_left/right` for big actions, `divider_solid_gold` between sections, `icon_text_2rows` for labelled stats, `Font_Type_Headers` for titles — this matches the vanilla look exactly.
8. Add a `docs/gui_lines.md`-style map (the line numbers in §2/§4) and re-derive it after every game update (`grep -n "NotExistOrHasValue( 'tab'" single_unit_window.gui`).

---

## 12. UNVERIFIED assumptions (test in game before relying on them)

1. `SingleUnitWindow.Vars.Set(...)` exists (only `Toggle/Exists/Clear/HasValue/NotExistOrHasValue` seen on this object; `Set` seen on `MaritimeLateralView.Vars`, `UnitOverview.Vars`, `LateralView.Vars`, `GameLobby.Vars`).
2. `Unit.MakeScope` / `SingleUnitWindow.GetSelectedUnit.MakeScope` (no GUI usage anywhere) and `scope = unit` in `scripted_guis` (never used).
3. `IsLateralViewOpened('single_unit_formation')` / `IsLateralViewOpened('single_unit')` keys (only `OpenLateralView('single_unit_formation')` verified).
4. `SubUnitType.HasStat('<custom_stat>')` for a mod-defined stat; whether an invisible `item` in `scroll_list` collapses.
5. Both `in_game/common/scripted_guis` and `main_menu/common/scripted_guis` are loaded (vanilla uses the former, CMP the latter; CMP's SGUIs evidently work for its users but were not executed here).
6. Header tab containers (`header_secondary_tabs`) render correctly on `bg_main_inner_notabs_alt` inside the army window (maritime does it on `bg_main_inner_alt`).
7. Static-modifier icon lookup path/naming for `TimedModifier.GetIcon` with a mod-defined modifier.
8. GUI hot-reload console command for EU5 1.4.7 (`reload gui` style) — not found in logs/console history.
9. `unit_location = scope:loc` as a unit-scope trigger form (token present 44×, exact usage not inspected).
