# 12 — Unit 3D models pipeline: giving `cw_hq` its own officer model (per culture)

EU5 1.4.7 (Caesar/Jomini). Research for mod **Concentrated Warfare** (`cw_`), roadmap item v0.3 (DESIGN.md §9).
Paths are relative to `game/` inside the EU5 install (`G:` = `C:\Program Files (x86)\Steam\steamapps\common\Europa Universalis V\game`) unless stated otherwise. `U:` = `C:\Users\fyrno\Documents\Paradox Interactive\Europa Universalis V`.

Legend:
- **VERIFIED** — seen in vanilla/DLC files on this machine with the quoted syntax (file:line), or fetched from the named web page (**V-WEB**).
- **INFERRED** — composition of verified parts or a reading of comments/usage; not directly observed.
- **UNVERIFIED** — nothing seen; must be tested in game (collected in §9).

---

## 0. TL;DR

| Question | Answer | Status |
|---|---|---|
| Where is a regiment's 3D model chosen | `main_menu/gfx/unit_graphics/units/*.txt`; key = `[<gfx_culture>:][<age>:]<unit_category | unit_type | gfx_tag>` (`00_units.info:4-5`, `01_army.txt`, `01_navy.txt:4`, `D008_army.txt:1`, `D009_navy.txt:3`) | VERIFIED |
| What `cw_hq` shows today | donkey cart: `army_auxiliary = { schematic_name = unit_auxiliary_donkey_schematic … }` (`01_army.txt:168-174`), because `category = army_auxiliary` | VERIFIED |
| Can a **unit type** get its own model without touching vanilla | yes: a new file with a `cw_hq = { … }` entry; unit-type keys beat category keys (`age_4_reformation:a_byz_helepolis_cannon_unit` in `D008_army.txt:1` coexists with `age_4_reformation:army_artillery` in `01_army.txt:251`) | VERIFIED pattern / INFERRED precedence |
| Human (officer) look with zero new binaries | `schematic_name = unit_skeleton_schematic` + `attach = { 100 = <list> }` lists that pick vanilla meshes: `unit_torso_general_shape_mesh`, `unit_hat_general_shape_mesh`, `unit_legs_pants_general_shape_mesh`, `unit_mustaches_general_mesh`, sword/pistol schematics, banner meshes (§3, §4) | VERIFIED parts |
| Per-culture variants | prefix the list or the unit key with a graphical-culture tag: `iberian_gfx:age_1_traditions:torsos_clothes` (`D009_castile_torsos.txt:9`), `north_american_gfx:heads` (`00_heads.txt:15`), `afrasian_gfx:n_canoe` (`D009_navy.txt:3`) | VERIFIED |
| Country colours | automatic: masked cloth regions are repainted with `unit_color0/1/2` from `in_game/setup/countries/*.txt` (`anatolia.txt:215-217`) through `texture_variations` + `materials` | VERIFIED |
| Fixed "officer" colour | (1) unit-type `color = <named colour>` (`readme.txt:29`, used by `a_hunters` `2_unlocked_through_tech.txt:516`) — wiki says "appears to be unused"; (2) own `.asset` alias of a copied vanilla mesh + own `texture_variations` block with fixed-colour groups (`cloth_only_black_group`, `cloth_golden_white_group`) | UNVERIFIED / VERIFIED parts |
| Custom mesh toolchain | Blender 3.6+/4.2+ with **io_pdx_mesh 0.91** (GPL-3; CK3/Vic3 preset, custom shader name) or Maya 2018 + official **Clausewitz Maya Exporter** (settings file points at `main_menu/tools/pdxexporter.settings`). EU5 `.mesh/.anim` are the `@@b@ pdxasset` binaries of the IR/CK3 family (`lodperc`, `boundingsphere` present) | V-WEB + VERIFIED headers / INFERRED compatibility |
| 2D art for the HQ | illustration entry `trigger = { is_unit_type = cw_hq }` priority 900000 (`d009_unit_illustrations.txt:1-7`); texture 1080×440 DXT1 + same-named mask under `masks/`; list icon = category icon 128×128 (`icons/unit_category/army_auxiliary.dds`) | VERIFIED / per-type icon UNVERIFIED |
| Biggest risk | a 100-man regiment may never be drawn on the map: visible soldiers scale with army strength (`NUnitGraphics`, `00_graphics.txt:680-686`), and the unit panel shows the army's "visual subunit" only (`single_unit_window.gui:3704`) | INFERRED / UNVERIFIED |

---

## 1. Files read

- `main_menu/gfx/unit_graphics/units/00_units.info`, `01_army.txt` (279 lines), `01_navy.txt`; DLC: `dlc/D008_fate_of_the_phoenix/main_menu/gfx/unit_graphics/units/D008_army.txt`, `D008_navy.txt`, `dlc/D009_across_the_pillars/main_menu/gfx/unit_graphics/units/D009_navy.txt`
- `main_menu/gfx/unit_graphics/attachments/00_attachment_lists.txt`, `00_unique.txt`, `00_audiotags_units.info`, `heads/00_heads.txt`, `hairstyles/01_attachment_hairstyles.txt`, `torsos/00_european_torsos.txt`, `legs/00_european_legs.txt`, `headgear/00_european_headgear.txt`, `beards/01_attachment_beards.txt`, `weapons/00_european_weapons.txt`, `backpacks/01_attachment_backpacks.txt`, `offhand/01_attachment_offhand.txt`, `cavalry/01_attachment_horses.txt`, `01_attachment_saddles.txt`; DLC `D009_castile_torsos.txt`, `D009_castile_headgear.txt`
- `main_menu/gfx/unit_graphics/materials/00_generic.txt`, `00_cloth.txt`, `01_groups.txt`, `materials/textures/` (45 entries); `texture_variations/cloth_and_leather.txt`, `metals.txt`, `skin_and_hair.txt`, `weapons.txt`, `assets_without_texture_variations.txt`; `colors/00_colors.txt`; `main_menu/common/named_colors/02_units.txt`
- `in_game/gfx/models/units/unit_skeleton.asset` + `.mesh`, `unit_cavalry_skeleton.asset`, `base_entities.asset`, `debug/debug_unit_entities.asset`, `auxiliary/unit_auxliary_donkey/unit_auxiliary_donkey.asset`, `torso/unit_torso_general_shape/*.asset`, `headgear/unit_hat_general_shape/*.asset`, `weapons/unit_weapon_flag_pole/*.asset`, `weapons/unit_accessories_banner/*.asset`, `torso/unit_torso_armor_chainmail_tabard/unit_torso_armor_chainmail_long_tabard_coa_side.asset`
- `in_game/gfx/models/schematics/unit_skeleton_schematic.schematic`, `unit_auxiliary_donkey_schematic.schematic`, `unit_weapon_flag_pole_schematic.schematic`, `army_schematic.schematic`
- `main_menu/gfx/animation_state_machines/unit_skeleton_state_machine_one_handed_axe.animsm`, `unit_auxiliary_donkey_machine.animsm`, `unit_skeleton_state_machine_two_handed_flag.animsm`
- `main_menu/tools/pdxexporter.settings`; `loading_screen/common/defines/graphic/00_graphics.txt` (`NUnitGraphics`)
- `in_game/gfx/graphical_culture_types/*.txt` (153 keys), `in_game/common/cultures/00_cultures.info`, `baltic.txt`, `in_game/common/government_reforms/theocracy.txt`, `republic.txt`, `in_game/common/trigger_localization/culture_triggers.txt`, `in_game/common/scripted_triggers/00_clothing_triggers.txt`
- `in_game/common/unit_types/readme.txt`, `2_unlocked_through_tech.txt`, `1_uniques_for_age_4_reformation.txt`, `navy_galley.txt`, `dlc/D009…/in_game/common/unit_types/d009_uniques_for_age_1_traditions.txt`; `in_game/common/unit_categories/05_army_auxiliary.txt` + readme
- `in_game/gfx/unit_illustrations/readme.txt`, `00_unit_illustrations.txt`, `dlc/D009…/in_game/gfx/unit_illustrations/d009_unit_illustrations.txt`, `main_menu/gfx/interface/illustrations/units/00_naming_convention.info`; icon folders `main_menu/gfx/interface/icons/unit_category|unit_type|unit_types`
- GUI: `in_game/gui/single_unit_window.gui:3704-3708`, `army_builder.gui:1229,1326`; setup: `in_game/setup/countries/anatolia.txt:211-217`
- Logs: `U:/logs/debug.log` (enumeration of `gfx/unit_graphics/{units,attachments,materials,texture_variations,colors}` `(.txt)`), `U:/logs/error.log` (no unit-graphics diagnostics in current or rotated logs)
- Mod: `C:\Users\fyrno\PycharmProjects\EU5-ConcentratedWarfare\in_game\common\unit_types\cw_headquarters.txt` (`gfx_tags = { medium_tag }`, written by another agent), `.metadata/metadata.json`
- Web (§7): EU5 wiki Unit_modding / Modding / Mod_structure / Art_modding; Vic3 wiki Model_modding; CK3 wiki Exporters, 3D_models; GitHub ross-g/io_pdx_mesh (readme, releases, `pdx_blender/blender_ui.py`, `pdx_data.py`, `clausewitz.json`, wiki FAQ); Steam Workshop "Battle Graphics" (3599514412)

Asset inventory (counts by `find`): `.mesh` 3 709 (in_game/gfx 3 198, main_menu/gfx 33, dlc 443), `.asset` 3 362, `.anim` 770 (684 in `in_game/gfx`, mostly `models/units/animations/<weapon family>/`, 30 families), `.dds` 28 284. Unit parts live in `in_game/gfx/models/units/{accessories,artillery,auxiliary,beard,camelry,cavalry,elephantry,hair,head,headgear,legs,shared,torso,weapons}` (1 427 `.asset`, 905 of them with LODs); schematics in `in_game/gfx/models/schematics/` (374 files = `.schematic` + `.editordata` pairs); state machines in `main_menu/gfx/animation_state_machines/` (307 files, 31 `unit_skeleton_state_machine_*.animsm`).

Example paths — auxiliary cart: `in_game/gfx/models/units/auxiliary/unit_auxliary_donkey/unit_auxiliary_donkey.{asset,mesh}`, `unit_auxiliary_donkey_{idle,moving}.anim`, `unit_donkey_auxiliary_armor_{diffuse,normal,properties,mask}.dds`; `…/auxiliary/unit_auxiliary_carriage_open/` (unused "old carriage", `01_army.txt:193-219`). Infantry: shared rig `in_game/gfx/models/units/unit_skeleton.{asset,mesh}` + parts such as `torso/unit_torso_general_shape/unit_torso_general_shape.{asset,mesh}` + `_diffuse/_normal/_mask.dds`.

---

## 2. How EU5 resolves a regiment's 3D look (data flow)

```
unit type (common/unit_types)  --category / key / gfx_tags / force_culture_gfx / color-->
units/*.txt entry  [gfx_culture:][age:]<key> = { schematic_name  attach = { w = list … }  animation_state_machine_name  size  width }
   |-> schematic (.schematic, text graph): skeleton mesh + animation state machine + audio/particles
   |-> each attach list (attachments/**.txt): weighted entries -> add_entity { node  mesh_name|schematic_name  add_tags  required_tags  animation_state_machine_override }
         list name is itself prefixed by [gfx_culture:][age:][gfx_tag:][IDEAL_UNIFORM:] -> culture/age/tag variants
   |-> mesh (.asset -> .mesh + dds) with shader unit_material_repaint; mask.dds colours -> texture_variations -> material groups -> materials (textures + repaint with unit_color0/1/2, skin/hair/eye colours)
   |-> animation state machine (.animsm): UnitState 0 idle / 1 attack / 2 move / 3 retreat / 4 charge -> timelines = animation ids from the skeleton .asset
```

### 2.1 `units/*.txt` — the model entry (VERIFIED)

- Key forms seen: plain category `army_heavy_infantry` (`01_army.txt:4`), gfx tag `elephant_tag` (`:37`), `camel_auxiliary_tag` (`:106`), age-prefixed category `age_2_renaissance:army_artillery` (`:231`), unit type `n_canoe` (`01_navy.txt:4`, type defined in `in_game/common/unit_types/navy_galley.txt:1`), age+unit type `age_4_reformation:a_byz_helepolis_cannon_unit` (`D008_army.txt:1`), culture+unit type `afrasian_gfx:n_canoe` (`D009_navy.txt:3`), culture+age+category `afrasian_gfx:age_2_renaissance:navy_galley` (`D009_navy.txt`). `00_units.info:4-5`: "unit_category or unit_type / can also add some gfx_tag".
- Fields: `schematic_name` (`01_army.txt:5`), `attach = { <weight> = <list> [use_uniformity = no] }` (`:7-16`, `00_units.info:18-22`), `animation_state_machine_name` (`:18`), `size`/`width` (spacing in formations, `:40-41`, `:172-173`), `render_under_water` + `size` for ships (`01_navy.txt:6-7`), `dlc = "<id>"` gate (`D008_army.txt:3`). `00_units.info:8-11` documents `entity = "…"` as the base; no vanilla entry uses it and `test_unit_shader_entity` does not exist in any `.asset` → treat the `.info` as stale and use `schematic_name`.
- Attachments "are evaluated in the order they are scripted, so add_tags/require_tags should take that into account" (`00_units.info:16`); vanilla order: heads, torsos, legs, headgear, hairstyles, beards, weapons, shields, back, offhand (`01_army.txt:7-16`).
- Precedence: the helepolis unit (`1_uniques_for_age_4_reformation.txt:286-300`, `copy_from = a_age_4_reformation_artillery`, `gfx_tags = { helepolis_tag }`) is given a model by **unit-type** key although its category has an `age_4_reformation:army_artillery` entry → unit-type key > category key (INFERRED; the DLC entry would be dead otherwise). Order between a gfx-tag key and a unit-type key is UNVERIFIED (vanilla never defines both for one unit).
- Mismatch to know about: `army_auxiliary` sets `animation_state_machine_name = unit_auxiliary_donkey_mesh` (`01_army.txt:174`) — a mesh name, not a state machine — while the donkey schematic hard-codes `state_machine_name="unit_auxiliary_donkey_machine"` (`unit_auxiliary_donkey_schematic.schematic:49`). The infantry schematic instead reads the name through a schematic parameter `CustomAnimationMachineName` (`unit_skeleton_schematic.schematic:343-355`) → the field only matters for schematics that expose that parameter (INFERRED).

### 2.2 Attachment lists (`attachments/**/*.txt`) (VERIFIED)

- List = `<prefixes:>name = { <weight> = <sub-list | { add_entity … } | {}> … }`. Empty block `{ }` = "nothing" (`00_attachment_lists.txt:61`, `:361`, hairstyles `:23`). `default = {}` fallback entry (105 uses; `offhand:11`, `backpacks:12`). `skip_initial_check = yes` (33 uses; `01_attachment_horses.txt:10`). Weights are relative integers.
- Entry: `add_entity = { node = <joint|shared_pose_entity> mesh_name = "<pdxmesh name>" | schematic_name = "<schematic>" add_tags = "x" (repeatable) required_tags = "x" | "not(x)" animation_state_machine_override = "<animsm>" }` — e.g. torso `torsos/00_european_torsos.txt:7`, weapon `weapons/00_european_weapons.txt:18`, sheath on `Unit_Base_Rig_Hips` (`backpacks:5`), banner on `Unit_Base_Rig_Spine2` (`backpacks:114-115`), hairstyle with covered fallback (`hairstyles:7-10`). Key counts across all files: `add_tags` 2 766, `entity` 2 453, `node` 2 290, `mesh_name` 1 844, `required_tags` 612, `animation_state_machine_override` 482, `schematic_name` 444 (one weapon entry may be a sub-schematic with its own parts), `material` 1. `required_tags = "no(thick_armor)"` also occurs (`headgear:55`).
- Conditionals: `if/else_if/else = { fast_limit = { … } <entries> }` with `religion_graphical_culture = muslim_gfx` (`00_attachment_lists.txt:82-93`), `raw_material = lumber`, `raw_material_method = mining|hunting` (`:196-206`), `uniformity > 0.20` (`materials/01_groups.txt:157-160`, `>= 0.95` `:214`), `graphical_culture = iroquois_gfx` (`:265`).
- Key prefixes actually used (count of prefixed list names): ages `age_1_traditions`…`age_6_revolutions` (≈460), graphical cultures `middle_east_gfx` 95, `east_asian_gfx` 80, `iberian_gfx` 63, `east_mediterranean_gfx` 62, `indian_gfx` 61, `south_american_gfx` 45, `african_gfx` 42, `maghrebi_gfx` 39, `north_american_gfx` 33, `european_gfx` 14, `andalusi_gfx` 9, `north_german_gfx` 6, `irish_gfx`, `greek_gfx`, `east_slavic_gfx`, `austronesian_gfx`, `iroquois_gfx`, `aztec_gfx`; gfx tags `medium_tag` 25, `heavy_tag` 24, `musket_tag` 11, `tuareg_tag`, `legionary_tag`, `tercio_tag`, `polearm_tag`, `pavise_tag`, `light_tag`, `archer_tag`, `alabardero_tag`, `guardia_ornato_tag`, `rifle_tag`, `conquistador_tag`, `black_guard_tag`, `gallowglass_tag`, `cataphract_tag` …; `IDEAL_UNIFORM` 12; ethnicity `american_ethnicity` (`:142`); `basic` (`:348`); `REB` (rebels). Multi-prefix chains are fine: `IDEAL_UNIFORM:age_3_discovery:soldier_weapons` (`:230`), `south_american_gfx:age_1_traditions:heavy_tag:backpacks` (`backpacks:111`), `iberian_gfx:tercio_tag:torsos` (`D009_castile_torsos.txt:54`). Which prefix wins when several match is UNVERIFIED (vanilla writes the most specific key and expects it to win).
- Tags: a unit type's `gfx_tags` (`readme.txt:28`; vanilla uses 44 distinct tags, free-form strings) select `<tag>:<list>` variants; `add_tags` from earlier parts gate later parts (`hair_covered`, `beard_covered`, `crotch_covered`, `shield`, `torso_has_backpack`, `cavalry`, `one_handed`, `thick_armor`). Audio switches read tags of the form `UnitArmor_*`, `UnitDetail_*`, `UnitLegs_*`, `UnitShield_*`, `UnitWeapon_*`, `UnitCavalryArmor_*` (`00_audiotags_units.info:23-93`; the skeleton schematic turns them into audio switch states via `GeneratedUnitTags`, `unit_skeleton_schematic.schematic:356-363`). Always add them to new entries.
- `IDEAL_UNIFORM:` lists (e.g. `IDEAL_UNIFORM:torsos = { 10 = soldier_torsos_clothes }` `:13-15`) and `use_uniformity = no` on an `attach` (`00_units.info:19`, heads) tie to the uniformity value computed as `UNIFORMITY_BASE 0.25 + levy/merc bonus + discipline + experience + tradition …` (`00_graphics.txt:758-768`): high-uniformity regulars draw the "ideal uniform" set; exact threshold UNVERIFIED.
- Files from DLC mounts in subfolders are read (`D009_castile_torsos.txt` under `attachments/torsos/`), so a mod file anywhere under `main_menu/gfx/unit_graphics/attachments/` is loaded (`debug.log`: `Starting pre-enumerating 'gfx/unit_graphics/attachments'(.txt, , -1)`). DLC files start with `@dlc = "d009_across_the_pillars"` (`D009_castile_torsos.txt:1`); not needed for a mod.

### 2.3 Materials, masks and country colours (VERIFIED)

- `.asset` meshsettings use `shader = "unit_material_repaint"`, `shader_file = "gfx/FX/units.shader"`, diffuse + normal (+ optional `texture_specular` = `_properties.dds`, usually commented out) and `texture = { index = 3 srgb = no file = "<name>_mask.dds" }` (`unit_torso_general_shape.asset:10-19`, donkey `:8-17`).
- The mask's flat colours are matched by `texture_variations/*.txt`: a variation block lists material groups with `mask = { color = { r g b } tolerance hardness }` and optional `repaint = { <weight> = { primary_color = unit_color0 secondary_color = unit_color1 } … }`, then `assets = { <mesh names> }` (`cloth_and_leather.txt:1-110`, `metals.txt:1-12`, `skin_and_hair.txt:1-27`). Example mapping in `general_clothing_group`: red = skin (`skin_color`), `{0 1 0}` = country cloth (95 % `unit_color0`), `{0.5 0 1}` = second country cloth (`unit_color1`), `{0.75 0.75 1}` = leather in country colour, yellow / `{0.5 0.25 0}` = plain cloth, `{0.25 1 0.5}` = peasant greys with fixed hex colours (`:62-72`), `{0.25 0.5 1}` chainmail, `{0 0 1}` leather brown, `{1 0.5 1}` rough cloth, `{0 1 1}` iron, `{1 0.5 0}` wood, `{0.5 0 0.5}` gold, `{1 0.5 0.25}` bronze. `unit_torso_general_shape_mesh` is in that group's assets (`:184`), the hat (`:1927`), the legs (`:2235`), the banners (`:3167-3169`) and the donkey (`:318`).
- Material groups (`materials/01_groups.txt`) are weighted picks of materials (`group:cloth_country_solid_group_two = { 70 = cloth_country_one 30 = cloth_country_two 10 = cloth_pure_white }` `:80-84`; fixed-colour groups `cloth_only_black_group` `:56`, `cloth_golden_white_group` `:65`, `cloth_country_coa_knights` `:133`); materials (`00_cloth.txt`, `00_metals.txt`, …) name textures under `materials/textures/` and optional `mask_texture` + `repaint = { input_name = primary_color mask = {…} }` (`00_cloth.txt:85-90`, `00_generic.txt:2-11`); `parent =` inheritance (`00_cloth.txt:7-10`).
- `unit_color0/1/2` come from the country setup (`in_game/setup/countries/anatolia.txt:215-217`: `unit_color0 = rgb { 175 40 40 } …`); the GUI tints 2D art with `GetCountryUnitPrimaryColor(<country>, <unit definition>)` (`single_unit_window.gui:3706-3708`). Named colours for unit types live in `main_menu/common/named_colors/02_units.txt:2-3` (`unit_rifle_green`, `unit_cacadore_brown`), referenced by `color = unit_rifle_green` (`2_unlocked_through_tech.txt:516`); readme: "`color = color # override primary color in visuals`" (`readme.txt:29`). The EU5 wiki claims `color` "appears to be unused" (V-WEB) → UNVERIFIED in game.
- Meshes without a mask must be listed in `assets_without_texture_variation = { … }` (`assets_without_texture_variations.txt:1-17`, artillery/horses) — INFERRED purpose: silence a validation error.
- `colors/00_colors.txt` holds only three hex colours (`color_leather_whitened`, `color_leather_blackened`, `gold`) used by materials.

### 2.4 Binary assets and their text wrappers (VERIFIED)

| Thing | Where / format | Notes |
|---|---|---|
| `.mesh`, `.anim` | binary, header `@@b@` + `!\x08pdxasset` + `i` [2 ints] (first 32 bytes of `unit_skeleton.mesh` and `animations/unit_drowning.anim`) | same "pdxasset" container io_pdx_mesh reads/writes (V-WEB `pdx_data.py`); unit meshes contain `lodperc`, `boundingsphere`, `skeleton`, `bones`, `locator`, `material`, `shaders` records (strings in `unit_torso_general_shape.mesh`) = the Imperator/CK3 ("Jomini") variant of the format |
| `.asset` | text, **no BOM**, CRLF in vanilla (`unit_skeleton.asset`: 897 CR) | `pdxmesh = { name file [lod_percentages = { lod = { index percent } }] animation = { id type } meshsettings = { name index texture_diffuse texture_normal [texture_specular] texture = { index = 3 srgb = no file } shader shader_file } }` (`unit_torso_general_shape.asset:1-42`, `unit_skeleton.asset:1-32`, 207 animation lines); `entity = { name pdxmesh default_state state = { name animation } }` (`unit_auxiliary_donkey.asset:20-34`), inline `meshsettings` + `scale = @var` (`debug_unit_entities.asset:1-16`), `clone`, `locator`, `attach` (`base_entities.asset:19-23`, `:67-72`). The Vic3 wiki's "`.asset` must be LF" (V-WEB) is contradicted by EU5 vanilla; CRLF is safe |
| textures | DDS: part diffuse/normal/mask 256² DXT5 (torso general shape), donkey diffuse 512² DXT5, donkey mask 256² DXT1, with mipmaps | naming `<mesh>_diffuse/_normal/_properties/_mask.dds`; the mesh name in `.asset` must be globally unique (`name = "unit_torso_general_shape_mesh"`) |
| `.schematic` (+ `.editordata`) | text with UTF-8 BOM, node graph `pdxns:ecs:*` | donkey: `MeshType{mesh_name}` `:37-45`, `animation_state_machine{state_machine_name}` `:46-53`, `assemble_entity` `:54-95`, particle child `wheel_dust_vfx` on `JNT|root` `:96-128`, `create_local_transform` (translation `{3 0 0}`, scale 1) `:129-145`, `create_particle_component "wagon_dust"` `:163-168`, `create_skeleton_component "unit_auxiliary_donkey_mesh"` `:176-180`, audio compound `snd_cmp_omo_fauna_donkey` `:4-36`. Infantry: `unit_skeleton_schematic` with audio emitter `units_infantry_spawn` `:123-127`, six audio switches, parameters `CustomAnimationMachineName`/`GeneratedUnitTags` `:343-363`. Flag pole: `unit_weapon_flag_pole_schematic.schematic:7` `unit_weapon_flag_pole_mesh` + `:16` `ship_flag_mesh` (a cloth flag child) |
| `.animsm` | text with BOM | `local_variables = { "UnitState" = int }`, `behavioral_states` Attack/Idle/Move/Retreat/Charge/Idle Loop, each `timeline_layer = { timeline = "<animation id from .asset>" }` (`unit_skeleton_state_machine_one_handed_axe.animsm:1-70`), transitions on `"UnitState" = "1"` → Attack, `"2"` → Move, `"3"` → Retreat, `"4"` → Charge, `"0"` → Idle Loop (`:72-160`). Same 0-4 mapping as the wiki's `animation_gfx_override` (V-WEB). Donkey machine (`unit_auxiliary_donkey_machine.animsm:1-46`) only maps `idle_animation`/`moving_animation` |
| skeleton | `unit_skeleton.mesh` (6.4 KB): 50 joints `Unit_Base_Rig_{Hips,Spine,Spine1,Spine2,Neck,Head,Left/Right Shoulder/Arm/ForeArm/Hand/HandIndex1-4/HandRing1-4/HandThumb1-4/LeafForeArmRoll1/UpLeg/Leg/Foot/ToeBase}` + weapon joints `Unit_Wea_Right_Hand01`, `Unit_Wea_Right_Hand02` | attachment nodes used by script: `shared_pose_entity` (skinned parts), `Unit_Wea_Right_Hand01/02`, `Unit_Base_Rig_Spine2`, `Unit_Base_Rig_Hips`, `Unit_Base_Rig_LeftHand`; cavalry uses `unit_cavalry_skeleton.mesh` + rider parts on `shared_pose_entity` (`01_attachment_horses.txt:5-7`) |
| exporter settings | `main_menu/tools/pdxexporter.settings` | `animations = { "none" "idle" "idle_l_turn" "idle_r_turn" "moving" "attack" "charge" "unfold" "fold" "attack_l" "attack_r" }` (`:1`), 100+ shader presets `{ shader = "standard" shader_file = "in_game/gfx/FX/pdxmesh.shader" }` … `{ shader = "unit_material_repaint" shader_file = "in_game/gfx/FX/units.shader" }` (`:6`, `:108`), `version = 1`, `uniform_bone_scaling = no` (`:110-112`) |

### 2.5 Which culture/nation variant is picked (VERIFIED unless noted)

- Every culture carries graphical tags: `tags = { baltic_gfx eastern_european_gfx european_gfx }` (`in_game/common/cultures/baltic.txt:6`; `00_cultures.info:6` "# gfx tags"). Graphical cultures are declared in `in_game/gfx/graphical_culture_types/*.txt` (153 keys) with `priority` (continental 100 → subcontinental 200-250 → regional 300-400 → area 500-600) and `ethnicities` for heads (`00_graphical_culture_types.txt:3-9`, `:78-84`; comments in `01_graphical_culture_types_british.txt:2,7,30`). "fallbacks are just tags used during asset lookup" (`00_graphical_culture_types.txt:1`).
- Religion tags (`muslim_gfx`, `western_christian_gfx`, `shinto_gfx` … `01_graphical_religion_types.txt`) feed `religion_graphical_culture` conditions; government reforms can add tags: `graphical_cultures = { military_order_gfx }` (`theocracy.txt:5`), `{ pirate_gfx }` (`republic.txt:87`), orders `03_graphical_order_types.txt:1-14`.
- 3D lookup uses the regiment's culture tags against the prefixed list names (most specific first — INFERRED from priorities). 2D uses `scope:culture ?= { gfx_culture_applicable = <tag> }` (`00_unit_illustrations.txt:10`, readme `:23`). Triggers: `gfx_culture_applicable` (`00_clothing_triggers.txt:3`), `has_graphical_culture` (`culture_triggers.txt:71-74`).
- Per **nation**: there is no country-tag prefix in gfx scripts (only `REB` for rebels); nation looks are expressed through culture tags (`french_gfx`, `english_gfx`, `castilian_gfx` …) plus the country's `unit_color0/1/2`. Unit types can pin the culture: `force_culture = andalusi` + `force_culture_gfx = yes` (`d009_uniques_for_age_1_traditions.txt:8-9`; readme `:25-27`: forces "the 3D model (and 2D) to use this regiment culture graphical identity, ignoring the country/language uniformity look").
- Which culture a script-spawned regiment (`add_subunit = unit_type:cw_hq`) gets is UNVERIFIED (expected: location/primary culture) — it decides both the 2D illustration (`scope:culture`) and the 3D variant; test in §9.

---

## 3. (a) Exact keys to attach a model to `cw_hq` (and per-culture variants)

All paths are inside the mod (new files only; nothing vanilla is overridden). `.txt` files: UTF-8 **with BOM**, CRLF (SPEC §0).

**File A — `main_menu/gfx/unit_graphics/units/cw_army.txt`** (unit-type key; pattern `01_navy.txt:4`, `D008_army.txt:1`)

```
# Concentrated Warfare: HQ regiments use a human officer instead of the army_auxiliary donkey cart.
cw_hq = {
	schematic_name = unit_skeleton_schematic                 # 01_army.txt:5
	attach = { 100 = heads use_uniformity = no }             # vanilla culture-keyed heads (00_heads.txt)
	attach = { 100 = cw_hq_torsos }
	attach = { 100 = cw_hq_legs }
	attach = { 100 = cw_hq_headgear }
	attach = { 100 = hairstyles }                            # vanilla, respects hair_covered
	attach = { 100 = cw_hq_beards }
	attach = { 100 = cw_hq_weapons }
	attach = { 100 = cw_hq_back }
	animation_state_machine_name = unit_skeleton_state_machine_one_handed_sword   # overridden per weapon anyway
}
cw_hq_colonial = { … identical block, or point its lists at cw_hq_* …}
```
Per-culture at the unit level (optional): `iberian_gfx:cw_hq = { … }`, `age_5_absolutism:cw_hq = { … }` (patterns `afrasian_gfx:n_canoe`, `age_2_renaissance:navy_galley`). Mounted variant: `schematic_name = unit_cavalry_skeleton_schematic_new` + `attach = { 100 = cavalry }` + `cavalry_weapons` + `horse_accessories` (`01_army.txt:131-148`).

**File B — `main_menu/gfx/unit_graphics/attachments/cw_hq/cw_hq_attachments.txt`** (lists; subfolder is fine)

```
cw_hq_torsos = {   # age 1-2 default: noble mail + country-coloured tabard with CoA side panel
	1 = { add_entity = { node = shared_pose_entity  mesh_name = "unit_torso_armor_chainmail_long_tabard_coa_side_mesh"  add_tags = "UnitArmor_chainmail" add_tags = "crotch_covered" } }   # 00_european_torsos.txt:29
}
age_3_discovery:cw_hq_torsos = {
	1 = { add_entity = { node = shared_pose_entity  mesh_name = "unit_torso_armor_fabric_tunic_fur_mesh"  add_tags = "UnitArmor_cloth" add_tags = "UnitDetail_plate" } }   # :85
}
age_4_reformation:cw_hq_torsos = {
	1 = { add_entity = { node = shared_pose_entity  mesh_name = "unit_torso_armor_cuirassier_mesh"  add_tags = "UnitArmor_plate_full" add_tags = "UnitDetail_leather" } }   # :105
}
age_5_absolutism:cw_hq_torsos = {
	1 = { add_entity = { node = shared_pose_entity  mesh_name = "unit_armor_torso_gold_trimmings_coat_mesh"  add_tags = "UnitArmor_cloth" add_tags = "UnitDetail_plate" } }   # :128
	1 = { add_entity = { node = shared_pose_entity  mesh_name = "unit_armor_torso_breastplate_sash_mesh"     add_tags = "UnitArmor_cloth" add_tags = "UnitDetail_plate" } }   # :130
}
age_6_revolutions:cw_hq_torsos = {
	1 = { add_entity = { node = shared_pose_entity  mesh_name = "unit_torso_general_shape_mesh"        add_tags = "UnitArmor_cloth" } }   # :150 (the vanilla "general" coat)
	1 = { add_entity = { node = shared_pose_entity  mesh_name = "unit_torso_jacket_gold_details_mesh"  add_tags = "UnitArmor_cloth" } }   # :149
}
cw_hq_legs = { 1 = { add_entity = { node = shared_pose_entity mesh_name = "unit_legs_pants_high_chainmail_kneepads_mesh" add_tags = "UnitLegs_medium" } } }   # 00_european_legs.txt:25
age_5_absolutism:cw_hq_legs = { 1 = { add_entity = { node = shared_pose_entity mesh_name = "unit_legs_pants_high_leather_riding_boots_mesh" add_tags = "UnitLegs_medium" } } }   # :119
age_6_revolutions:cw_hq_legs = { 1 = { add_entity = { node = shared_pose_entity mesh_name = "unit_legs_pants_general_shape_mesh" add_tags = "UnitLegs_medium" } } }   # :143
cw_hq_headgear = { 1 = { add_entity = { node = shared_pose_entity mesh_name = "unit_hat_helm_chainmail_hood_fabric_mesh" add_tags = "hair_covered" add_tags = "beard_covered" } } }   # 00_european_headgear.txt:30
age_5_absolutism:cw_hq_headgear = {
	1 = { add_entity = { node = shared_pose_entity mesh_name = "unit_hat_bicorne_noble_feathers_a_mesh"   add_tags = "hair_covered" } }
	1 = { add_entity = { node = shared_pose_entity mesh_name = "unit_hat_tricorn_gold_trim_feathers_mesh" add_tags = "hair_covered" } }
}
age_6_revolutions:cw_hq_headgear = { 1 = { add_entity = { node = shared_pose_entity mesh_name = "unit_hat_general_shape_mesh" add_tags = "hair_covered" } } }   # :199
cw_hq_beards = {
	1 = {
		add_entity = { required_tags = "not(beard_covered)"  node = shared_pose_entity  mesh_name = "unit_mustaches_general_mesh" }   # 01_attachment_beards.txt:317
		add_entity = { required_tags = "beard_covered" }
	}
}
cw_hq_weapons = {   # officer's sword; the override picks the matching animation set
	1 = { add_entity = { node = Unit_Wea_Right_Hand01  schematic_name = "unit_weapon_sword_leather_hilt_schematic"  add_tags = "UnitWeapon_sword" add_tags = "one_handed"  animation_state_machine_override = "unit_skeleton_state_machine_one_handed_sword" } }   # 00_european_weapons.txt:241
}
age_5_absolutism:cw_hq_weapons = {
	1 = { add_entity = { node = Unit_Wea_Right_Hand01  schematic_name = "unit_weapon_pistol_ball_detail_schematic"  add_tags = "UnitWeapon_pistol"  animation_state_machine_override = "unit_skeleton_state_machine_pistol" } }   # :312
}
cw_hq_back = {
	10 = { add_entity = { node = Unit_Base_Rig_Hips    mesh_name = "unit_weapon_sword_leather_hilt_sheath_mesh" required_tags = "UnitWeapon_sword" } }   # backpacks:5
	10 = { add_entity = { node = Unit_Base_Rig_Spine2  mesh_name = "unit_accessories_banner_mesh" required_tags = "not(torso_has_backpack)" } }         # backpacks:115 (country-coloured banner on the back)
	default = {}
}
# culture variants: prefix any list (pattern D009_castile_torsos.txt:9 / 00_heads.txt:15)
east_asian_gfx:cw_hq_headgear = { 1 = { add_entity = { node = shared_pose_entity mesh_name = "unit_hat_flag_plume_lamellar_mesh" add_tags = "hair_covered" } } }
```
Every mesh above is base-game (no DLC); for DLC meshes (e.g. `unit_torso_armor_bevor_tercios_a_mesh`, D009) add `dlc = "d009_across_the_pillars"` to the entry (pattern `D008_army.txt:3`; 27 `dlc =` uses in attachment files) or avoid them.

**Unit type side** (`in_game/common/unit_types/cw_headquarters.txt`, owned by hq_core): keep `category = army_auxiliary`; `gfx_tags = { cw_hq_tag medium_tag }` — `cw_hq_tag` is only needed if you prefer tag-keyed lists (`cw_hq_tag:torsos`, pattern `gallowglass_tag:torsos` `00_unique.txt:1`) or as an IDENTITY tag for illustrations; the unit-type key in File A works without it. Optional `color = cw_officer_color` with `main_menu/common/named_colors/cw_colors.txt` → `colors = { cw_officer_color = hsv360 { 220 60 45 } }` (format `02_units.txt:1-5`; effect UNVERIFIED, see §2.3).

**Standard-bearer option** (no new assets, INFERRED composition): `cw_hq_weapons = { 1 = { add_entity = { node = Unit_Wea_Right_Hand01 schematic_name = "unit_weapon_flag_pole_schematic" add_tags = "UnitWeapon_spear_two_handed" animation_state_machine_override = "unit_skeleton_state_machine_two_handed_flag" } } }`. The pole schematic (pole + `ship_flag_mesh` flag child, `:7,16`) and the `two_handed_flag` state machine (reuses `*_two_handed_spear_animation` timelines) exist but no vanilla list references them → may be unfinished; the "Battle Graphics" mod shipped exactly such a flag-bearer with a dynamic CoA (V-WEB), so the engine can do it.

---

## 4. (b) Cheapest viable path for v0.3

| Option | What | Cost | Risk |
|---|---|---|---|
| **B0** keep the donkey cart | nothing (already country-coloured via mask, `cloth_and_leather.txt:318`) | 0 | none |
| **B1 (recommended)** "officer on foot" | File A + File B from §3 (vanilla general coat/hat/legs/mustache + sword + banner), per-age lists, 3-6 culture variants via prefixes | ~1 day scripting + 0.5 day in-game checks; no art tools | 100-man regiment may not be drawn (§8.1); list/prefix precedence untested |
| **B2** standard bearer | B1 + flag pole entry | +0.5 day | unused vanilla assets, may look broken (flag cloth material) |
| **B3** mounted officer | `unit_cavalry_skeleton_schematic_new` + `cavalry` + `cavalry_weapons` (`01_army.txt:131-148`) | +0.5 day | cavalry lists are heavier; formation size 3 |
| **B4** fixed officer colour / own texture | copy `unit_torso_general_shape.{mesh,dds}` into the mod under a new `.asset` name (`cw_officer_coat_mesh`; `file =` is relative to the asset's folder — no cross-folder `file =` exists in vanilla, 7 902 lines checked), repaint the diffuse or give it its own `texture_variations` block (`cw_officer_coat_mesh` in `assets = {}` with `cloth_only_black_group` / `cloth_golden_white_group`) | 1 day + a texture edit | duplicate-mesh memory; variation precedence if the same mesh name appears in two blocks (so use a new name) |

Recolour summary: country colours come for free (masks + `unit_color0/1/2`); a *fixed* colour needs either `color =` on the unit type (UNVERIFIED, test with `a_hunters`'s rifle green first) or B4.

---

## 5. (c) Full custom-model path (new mesh/texture/animation)

Tooling (V-WEB unless noted):
- **Blender** 3.6+ / 4.2+ (extension) + **io_pdx_mesh 0.91** (ross-g, GPL-3; release "0.91 — 23 Sep", Blender 4.2 support, Vic3 material presets; 0.9 added Maya 2022 and CK3/IR LOD support; 0.8 prunes >4 skin influences per vertex and exports only the first 4 UV sets). Engine presets in its `clausewitz.json`: `europa_universalis_4`, `stellaris`, `hearts_of_iron_4`, `imperator_rome`, `crusader_kings_3`, `victoria_3` — **no EU5 key**; pick `crusader_kings_3` or `victoria_3` (both list `standard`, `standard_usercolor_coa`/`standard_flag_basic` …) and create materials with `Custom type` = `unit_material_repaint` (the material `mat_type`/`custom_type` fields exist in `blender_ui.py`). Import options: mesh / join materials / skeleton / locators; export: meshes (+as blendshape), skeleton, locators, selected only, split vertices, sort vertices, plain-text copy; animation export: frame range, "Uniform scale only" (newer games support non-uniform scale). EU5 files carry `lodperc` and `boundingsphere` and the same `@@b@ pdxasset` header (§2.4) → the IR/CK3 code path should read them; **not tested here** (UNVERIFIED until `unit_skeleton.mesh` imports cleanly).
- **Maya 2018** (not LT) + official **Clausewitz Maya Exporter** (free, Paradox account download; CK3 wiki Exporters): settings `Documents\Paradox Interactive\PdxExporter\settings\clausewitz.settings` → `projects` entry with `path` = `<EU5>/game/main_menu/tools` (holds `pdxexporter.settings`: shader list incl. `unit_material_repaint`, clip names `idle/moving/attack/charge/unfold/fold/attack_l/attack_r/idle_l_turn/idle_r_turn`, `uniform_bone_scaling = no`), `export_path` = mod `gfx/models` folder, `target_exe` = `binaries/eu5.exe`; Photoshop TextureExporter packs DDS. EU5 wiki "Modding" lists it as "A tool to create and export 3D models to use in EU5 and other Clausewitz games".

Steps for a new officer part (coat/hat) on the vanilla rig:
1. Import `in_game/gfx/models/units/unit_skeleton.mesh` (skeleton on) and one vanilla part (`torso/unit_torso_general_shape/unit_torso_general_shape.mesh`) and one `.anim` (`animations/one_handed_sword/unit_one_hand_sword_idle01.anim`) to validate scale/orientation (io_pdx_mesh FAQ: "pick an example of a THING that already exists in GAME … import its .mesh and .anim").
2. Model the part at that scale; skin it to the 50 named joints (§2.4; ≤ 4 influences/vertex; keep joint names exactly; attach via `shared_pose_entity` needs no locators). Optional LODs: vanilla parts ship `lod0/lod1/lod2` shapes with `lod_percentages = { lod = { index = 1 percent = 1.5 } lod = { index = 2 percent = 1.0 } }` (`unit_torso_general_shape.asset:5-8`); 522 of 1 427 unit assets have no LODs, so one LOD is acceptable.
3. Textures: `<name>_diffuse.dds` (DXT5/BC3, sRGB), `<name>_normal.dds` (DXT5), optional `<name>_properties.dds`, and `<name>_mask.dds` (DXT1/DXT5, linear) painted with the flat key colours of §2.3 (green = country colour cloth, `{0.25 1 0.5}` grey cloth, `{0.25 0.5 1}` mail, `{0 1 1}` iron, `{0.5 0 0.5}` gold …), 256-512 px with mipmaps.
4. `.asset` (text, CRLF ok, no BOM): copy `unit_torso_general_shape.asset`, rename `name = "cw_officer_coat_mesh"`, `file`, shape names (`<mesh>_lod0Shape` must match the object names exported), textures; keep `shader = "unit_material_repaint"`, `shader_file = "gfx/FX/units.shader"`, mask at `index = 3 srgb = no`. Put it under `in_game/gfx/models/units/cw_hq/<part>/` (DLC D008 adds parts under `dlc/D008…/in_game/gfx/models/units/torso/…` — same mechanism).
5. Register: `main_menu/gfx/unit_graphics/texture_variations/cw_hq.txt` with a block copied from `general_clothing_group` (or a reduced one) and `assets = { cw_officer_coat_mesh }`; if the part has no mask, list it in a mod file as `assets_without_texture_variation = { cw_officer_coat_mesh }`.
6. Reference from File B lists via `mesh_name = "cw_officer_coat_mesh"`; add audio tags.
7. New **animations**: the ids live in vanilla `unit_skeleton.asset` (207 `animation = { id type }` lines) and the state machines reference ids — adding an id means shipping a full copy of `in_game/gfx/models/units/unit_skeleton.asset` (same-path override, wiki Mod_structure: "entirely overridden by a file in the same directory and of the same name") plus a new `.animsm` and `animation_state_machine_override = "<yours>"` in the weapon entry. Rigged `.anim` export must target the same 50 joints. Skip for v0.3.
8. Non-humanoid prop (tent, map table, wagon): copy the donkey pattern — `.mesh` + `.asset` with `entity = { default_state state = { name animation } }`, copy `unit_auxiliary_donkey_schematic.schematic` to a new file (edit `name=` GUID/name, `mesh_name`, `state_machine_name`, `create_skeleton_component value`), copy `unit_auxiliary_donkey_machine.animsm`, then `cw_hq = { schematic_name = cw_hq_tent_schematic size = 3 width = 2 }`. DLC D008 adds schematics/animsm the same way (`unit_artillery_helepolis_schematic.schematic`, `unit_artillery_helepolis_state_machine.animsm`), so a mod can too. The `.editordata` twin is editor-only (INFERRED; ship it if copied).
9. Test with `-debug_mode`; read `U:/logs/error.log` (missing mesh/asset/texture names are the expected messages; none exist for vanilla today, so any `unit_graphics`/`pdxmesh` line is ours); view at max zoom; check `ARMY_ENTITY_SCALE = 0.2` / `SINGLE_UNIT_ENTITY_SCALE = 3` (`00_graphics.txt:771-784`) if the part looks mis-scaled.

Effort: one new part family (coat or hat) with textures and 1 LOD: 2-4 days for a modeller who has done CK3/Vic3 parts; a full officer set (coat, hat, legs) × 3 ages × 5 culture variants with LODs: 3-5 weeks; custom animations: +1-2 weeks and a vanilla-file override. Mod-size budget: each part ≈ 150 KB mesh + 3×88 KB textures.

---

## 6. (d) Icon / 2D illustration requirements

- **Illustration** (unit panel, recruitment lists, lobby): add `in_game/gfx/unit_illustrations/cw_unit_illustrations.txt`:
  ```
  cw_hq_illustration = {
  	texture = "gfx/interface/illustrations/units/cw_hq.dds"     # file goes to main_menu/gfx/interface/illustrations/units/
  	priority = 900000                                           # is_unit_type tier (readme.txt:30)
  	trigger = { is_unit_type = cw_hq }
  }
  cw_hq_illustration_east_asian = {
  	texture = "gfx/interface/illustrations/units/cw_hq_east_asian_gfx.dds"
  	priority = 900001
  	trigger = { is_unit_type = cw_hq  scope:culture ?= { gfx_culture_applicable = east_asian_gfx } }
  }
  ```
  Rules (`readme.txt:4-9,13-15,25-46`): highest priority whose trigger passes wins, ties alphabetical; root = unit type, `scope:culture` = subunit culture (player's primary culture in recruitment lists); mask = same file name under `masks/` (never scripted; falls through to the next matching entry's mask, then `masks/_default.dds`); error.log reports missing textures, unreachable entries and orphan masks. Vanilla fallback for us today: `army_auxiliary_1` (priority 110000, `00_unit_illustrations.txt:1691-1697`) → `army_auxiliary` (100000, `:1731-1737`).
- **Texture spec** (from vanilla): `army_auxiliary.dds` 1080×440, DXT1, 11 mips; masks 1080×440 DXT1 (`masks/army_auxiliary_elephant_tag.dds`); `masks/_default.dds` 32×32 BC7/DX10. The mask drives the three-colour tint applied by `GetCountryUnitPrimaryColor/Secondary/Tertiary(<country>, <definition>)` (`single_unit_window.gui:3704-3708`) — paint the mask only where the uniform should take country colours. Masks are optional (falls through).
- **List icon**: the army builder uses `GetUnitIcon(SubUnitType.Self)` / `GetUnitIcon(SubUnit.GetDefinition)` (`army_builder.gui:1229`); no unit type has its own icon file in vanilla (`icons/unit_category/<category>.dds` 128×128 DXT5 8 mips; `icons/unit_type/` = 11 generic kind icons; `icons/unit_types/` = stat icons such as `combat_power.dds`). The HQ therefore shows the auxiliary icon; whether a `gfx/interface/icons/unit_types/cw_hq.dds` (or `unit_category/cw_hq.dds`) would be picked up by key is UNVERIFIED (cheap test: drop the file and look). Age icon via `GetAgeIcon(SubUnitType.GetAge)` (`:1326`) comes from `age = "age_1_traditions"`.
- No 3D viewer exists in the unit window: the only `GetVisualSubunit` use feeds the 2D illustration (`single_unit_window.gui:3704`); `in_game/gfx/models/scenes/scenes_unit_view/` planes are not referenced by any `.gui`.

---

## 7. Web sources (V-WEB) and what they add

| Source | Useful content |
|---|---|
| https://eu5.paradoxwikis.com/Unit_modding | `gfx_tags` "used when determining the icon for the subunit and its look ingame"; `animation_gfx_override` 0 idle/1 attack/2 move/3 retreat/4 charge; `color` "accepts a script color, but appears to be unused"; link "Unit graphics modding" is a red link |
| https://eu5.paradoxwikis.com/Modding , https://eu5.paradoxwikis.com/Mod_structure | folder layout; same-path file override; `INJECT/REPLACE` database modes; `metadata.json`; "Clausewitz Maya Exporter — A tool to create and export 3D models to use in EU5 and other Clausewitz games"; "3D Models" page does not exist |
| https://github.com/ross-g/io_pdx_mesh (readme, releases, wiki FAQ, `pdx_blender/blender_ui.py`, `pdx_data.py`, `clausewitz.json`) | Maya 2018+/Blender 3.6+ (4.2 extension), GPL-3, release 0.91; format: `@@b@` binary, `lodperc`/`boundingsphere` for IR/CK3, locator 4×4 `tx`, non-uniform bone scale (CK3); engine presets list (no EU5 key); import/export option names |
| https://vic3.paradoxwikis.com/Model_modding | workflow (copy vanilla folder, edit `.mesh` in Blender, never edit game files); claims `.asset` needs LF — EU5 vanilla uses CRLF |
| https://ck3.paradoxwikis.com/Exporters , https://ck3.paradoxwikis.com/3D_models | exporter download (Paradox account), Maya 2018, `clausewitz.settings` fields (`path`, `export_path`, `target_exe`), Photoshop TextureExporter, texture channel packing, "Error! Mesh contains broken normals" fix |
| Steam Workshop 3599514412 "Battle Graphics" (page currently flagged removed) | EU5 mod replacing the auxiliary donkey with "an animated flag-bearer and donkey unit that carries a dynamically changing coat of arms", custom BYZ/KNI models, "Compatible with EUV v1.2 and v1.3 Beta", known issue "purple or black units instead of coat of arms" after playset changes |
| Searches (`EU5 unit model modding`, `Jomini pdxmesh Blender exporter`, `Clausewitz Maya exporter Victoria 3`, `Europa Universalis V gfx unit_graphics`) | no EU5-specific documentation of `unit_graphics`/attachments anywhere; eu5db.com advertises "Unit Models / Unit Attachments / Unit Materials" browsers (site unreachable during this run) |

---

## 8. (e) Pitfalls

1. **Visibility**: visible soldiers per army scale with total strength (`ARMY_VISIBLE_SOLDIERS_REFERENCE = 15` for 10 000 men, max 40, `00_graphics.txt:680-686`); how they are split among subunits is code. A 100-man HQ in a 10 000-man army is 1 % → likely zero officer figures (INFERRED). Mitigations: accept it (lone/small HQ armies will show it), or test whether a subunit always gets ≥ 1 figure (§9). The 2D illustration also shows only the "visual subunit".
2. **Key precedence** between `cw_hq` (unit type), `cw_hq_tag:` and `army_auxiliary` entries, and between multi-prefix lists, is undocumented — write only unit-type-keyed entries + custom list names (`cw_hq_*`) so nothing collides.
3. **Culture of script-spawned HQs** decides the variant (§2.5) — verify; `force_culture_gfx` only helps with a fixed `force_culture`.
4. **Encoding**: gfx `.txt`, `.schematic`, `.animsm` have a UTF-8 BOM; `.asset` has none; CRLF everywhere in vanilla.
5. **Names are global**: `pdxmesh name`, schematic `name`, animsm file names must be unique; reusing a vanilla name silently shadows or conflicts (UNVERIFIED which).
6. **Attachment order** (`00_units.info:16`): headgear must precede hairstyles/beards or `hair_covered`/`beard_covered` gating fails; weapons before `back` (sheath requires `UnitWeapon_sword`).
7. **Audio tags**: parts without `UnitArmor_*/UnitLegs_*/UnitWeapon_*` tags leave audio switches unset (silent or default sounds).
8. **DLC meshes** (D008 Byzantine, D009 Castile/Morocco) disappear for players without the DLC → gate with `dlc =` or avoid.
9. **`assets_without_texture_variation`** / unmasked meshes and masks with off-key colours → wrong materials or validation noise.
10. **Overriding vanilla files** (`unit_skeleton.asset`, `01_army.txt`) breaks on every patch; prefer new files. Same-name file override is the only way to add animation ids (§5 step 7).
11. **Performance**: each attached part is a draw call per figure; keep the officer at ≤ 6 parts like vanilla soldiers.
12. **Exporter compatibility is unproven for EU5**: no public confirmation that io_pdx_mesh or the official exporter handles EU5 1.4 files; the Battle Graphics team did ship custom models (V-WEB), so it is possible, but budget a day for a round-trip test before planning art.
13. **CoA on cloth** uses `_coa_` meshes and `cloth_country_coa_knights`-style groups; the "purple/black units" symptom reported by Battle Graphics users is a CoA texture cache issue, not script.
14. **`.info` files are documentation only** (`00_naming_convention.info:1-2`, `00_audiotags_units.info:5`); the `entity =` example in `00_units.info` is stale.

---

## 9. Test checklist (in-game, `-debug_mode`)

1. Load with File A + File B; `error.log` must show no `cw_` / `unit_graphics` / mesh-not-found lines.
2. Spawn an army of 1 infantry + 1 `cw_hq` (console or script); zoom to max: is an officer figure drawn? Then 10 regiments + 1 HQ: is it still drawn (pitfall 1)?
3. Recruit `cw_hq` as Castile (iberian_gfx), Ming (east_asian_gfx), Iroquois (north_american_gfx): do culture-prefixed lists and vanilla heads switch?
4. Script-added HQ (`add_subunit`): which culture/illustration does it get?
5. Age change (console `age` / save in age 5): per-age lists switch; hats/coat appear.
6. `color = cw_officer_color` on the unit type: does the coat / illustration tint change? Compare with `a_hunters`.
7. Illustration entry: unit panel shows `cw_hq.dds`; mask falls back to `_default`.
8. Drop `icons/unit_types/cw_hq.dds` and `icons/unit_category/cw_hq.dds`: does `GetUnitIcon` pick either?
9. Blender round-trip: import `unit_skeleton.mesh` + `unit_torso_general_shape.mesh` + an `.anim` with io_pdx_mesh 0.91 (CK3 preset); re-export the torso unchanged under a new name and load it through a `.asset` + File B entry.
