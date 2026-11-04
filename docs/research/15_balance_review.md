# 15 — Balance review before the first play-test (adversarial design pass)

Scope: the numbers and rules in `docs/DESIGN.md` / `docs/SPEC.md` as implemented in the mod files on 2026-11-04, judged against the
EU5 1.4.7 defines, localisation and 1337 setup data, and against research docs 01/03/04/05/06/10. No mod file was edited.

Legend: **VERIFIED** = read in a file (file:line). **INFERRED** = follows from verified pieces, engine formula not visible.
**UNVERIFIED** = needs an in-game test (T-ids in §9). **ASSUMED** = a placeholder number of mine, to be replaced by a measurement.

Paths: `DEF` = `game/loading_screen/common/defines/00_defines.txt`, `LOC` = `game/main_menu/localization/english`,
`SM` = `game/main_menu/common/static_modifiers`, `SETUP` = `game/main_menu/setup/1337`, `MOD` = mod root.

---

## 0. Verdict (ranked)

| # | Finding | Severity | Fix (details below) |
|---|---|---|---|
| 1 | The siege half of `cw_no_hq` is **undetermined**: `siege_ability -0.9` is either ×1.9 slower (additive phase formula) or ×10 (divisive). The whole "only HQ armies occupy" concept depends on which. | blocker for tuning | T1.3 first; fallback values for the additive case in §1.4 |
| 2 | The combat half is harsher than the author's "≈50 %": three multiplicative terms give **≈38 %** (standard) and **≈26 %** (harsh — a coin flip vs 250 organised men, violating the author's own requirement). | high | standard −20 % discipline / −25 % morale (=50 %), harsh −30/−30, mild −10/−10 |
| 3 | Rebels are exempt but the owner's HQ-less stacks fight them at 38 % → big empires (Yuan 1668 locations, Horde 740, Delhi 369 — one HQ each until 1437) lose rebel wars they win in vanilla. | high | apply the penalty only while `at_war = yes` (or at least the softer combat tier) |
| 4 | Home HQ limit `/100`: at 1337 only **15 of 2351** countries own ≥100 locations; France (163) caps at 2 HQs all game, 5 HQs needs ≥400 locations (Yuan, Horde only). | high | divisor 60 + an "imperial" slot (≥300 locations) in ages 1–2 |
| 5 | Warscore: `WAR_WORTH_COUNTRY_CAPITAL 30` + `+10` bonus + scale 1.5 ⇒ **one siege ≈ 95–100 %** against any state ≤ ~30 locations (HRE, Italy); rank efficiency `+1.0` makes villages **~6× cheaper** in peace than vanilla ⇒ faster blobbing, the opposite of the brief. | high | capital 15, `OCCUPATION_VALUE_SCALE` 1.3, rural efficiency 0, base 0.5, `WAR_WORTH_DEVELOPMENT_MIN -0.25` |
| 6 | Colonial HQs count as HQs at home ⇒ a coloniser gets up to **+4 organised home armies** (they are recruited overseas and shipped back). Merc-only stacks are exempt ⇒ unlimited organised siege armies for gold. | high (exploit) | colonial HQ organises only overseas; drop the mercenary exemption |
| 7 | War stance reads `relative_military_strength` = **potential** strength (manpower + army + levies) ⇒ the plate keeps saying "Offensive" after the AI's field army is destroyed; no hysteresis band ⇒ "Unknown" flicker every 2–3 months near 0.55. | medium | fielded-strength term, ±0.03 bands, intel delay 1 month, conditional "Waiting" |
| 8 | AI defines: `HEAVILY_OUTNUMBERED_RATIO = 0.5` means "parity" if StrengthBalance is a fraction (like `relative_military_strength`) — every slightly weaker AI would stop contesting the field; the passivity group (`SUPPORT 0.5`, `NO_SUPPORT 3`, `RECOVER_MORALE 75`) + HQ-gated sieges ⇒ white-peace risk (`YEARS_SINCE_LAST_WAR_ACTION_BEFORE_WHITE_PEACE = 3`). The OFF game rule restores only 13 of the 27 overridden keys. | medium | hedge 0.45, revert the passivity trio to vanilla, complete the OFF rule |
| 9 | Native penalty keys on `government_type = tribe`: of the 20 largest American polities only CHK (Cahokia, 23 loc.) is a tribe; Tenochtitlan, Tarascans, Mayapan are monarchies. The HQ half is moot (largest American state = 23 locations). | low | drop the tribe clause or drop the feature |
| 10 | `cw_min_subunits_organized = 2` ⇒ "HQ + 1 regiment" siege detachments; the 15-day ticker leaves freshly split fragments penalty-free for ≤15 days (one unfortified occupation phase) if split units do not inherit modifiers. | low | organised ≥ 3; verify modifier inheritance (T2.4) |

---

## 1. The `cw_no_hq` penalty (siege −90 %, assault −50 %, discipline −30 %, morale −30 %)

Source: `MOD/main_menu/common/static_modifiers/cw_unit_modifiers.txt:8-16` (standard), `:30-38` (mild −75/−25/−15/−15), `:40-48` (harsh −95/−75/−40/−40).

### 1.1 Engine facts used (VERIFIED)

| Fact | Source |
|---|---|
| Combat tick: d10 (`COMBAT_DICE_SIDE`), `COMBAT_BASE 5`, cap `COMBAT_MAX 15`, `COMBAT_DAMAGE_MULT 0.12` per daily tick, `COMBAT_DAILY_MORALE_TICK 0.03` | `DEF:461-465` |
| Strength damage ×`LAND_STRENGTH_DAMAGE_MODIFIER 0.04`, morale damage ×`LAND_MORALE_DAMAGE_MODIFIER 0.25`, `BASE_MORALE_DAMAGE 1.0` | `DEF:488,490,507` |
| Morale damage scales with regiment-size ratio, capped ×4 (`MORALE_SIZE_RATIO_MAX`) | `DEF:476` |
| Overrun at 10:1 on the first tick, 2:1 once morale has collapsed | `DEF:495-496` |
| Base max morale `LAND_MORALE = 3.0`; `land_morale_modifier` scales max morale by a percentage | `DEF:391`; `LOC/modifier_types_l_english.yml:73` |
| Discipline "impacts both the damage that a regiment does and the damage taken" — two separate rows in the combat tooltip: `+X% discipline` and `+X% discipline of Target` | `LOC/game_concepts_l_english.yml:2281`; `LOC/units_l_english.yml:1718,1723` |
| Morale is per regiment; the side retreats at 0 | `LOC/game_concepts_l_english.yml:487` |
| Frontage: 10 per location base, 1 per regiment, `AVERAGE_FRONTAGE 12`, min 2 after terrain | `SM/location.txt:4-30`; `unit_categories/00_army_light_infantry.txt`; `DEF:901,1937` |
| Levies carry `discipline = -0.20` as a sub-unit modifier; exiled `-0.75` morale, leaderless `-0.20` morale are **unit** modifiers (so unit-level morale/discipline maluses are vanilla practice) | `SM/subunit.txt:7-14`; `SM/unit.txt:4-16,85-99` |
| `siege_ability -1.0` exists in vanilla (`army_maintenance_reverse_mod`, scaled by 1−maintenance) | `SM/country.txt:388-394` |
| `siege_ability` on a *unit* static modifier: category fits, no vanilla example → INFERRED-plausible | research 03 §5.1 |

### 1.2 Combat model (INFERRED) and the effectiveness factor

Per engaged regiment per tick: `dmg ∝ (5 + d10 + mods, ≤15) × 0.12 × combat_power × strength × (1 + disc_own) × f(disc_target)`;
morale pool = `3.0 × (1 + land_morale_modifier)`. The tooltip rows show both discipline terms as separate percentage rows, so
`f` is either `(1 − disc_target)` (additive, Paradox norm) or `1/(1 + disc_target)` (divisive); both are tabulated.

Effective fighting value per man of an HQ-less regiment relative to an organised one:
`E = (1 + d) × (1 + m) / (1 + |d|)` (additive f) — "how long I last × how much I deal" in a 1-v-1 duel.

| Tier | d / m | E (additive f) | E (divisive f) | Regiment-equivalents consumed to break ONE organised regiment (= ceil(1/E)) |
|---|---|---|---|---|
| mild (current) | −15/−15 | 0.63 | 0.61 | 2 |
| **standard (current)** | −30/−30 | **0.38** | 0.34 | 3 |
| harsh (current) | −40/−40 | **0.26** | 0.22 | 4 |
| mild (proposed) | −10/−10 | 0.74 | 0.74 | 2 |
| **standard (proposed)** | −20/−25 | **0.50** | 0.48 | 2 |
| harsh (proposed) | −30/−30 | 0.38 | 0.34 | 3 |

The author's "≈50 %" (DESIGN §2.2) is only reached by −20 % discipline / −25 % morale; the current standard is 38 %, harsh 26 %.

### 1.3 Does the author's requirement hold? (1000 unorganised beat 250 organised, lose to 1000 organised)

* Open field, frontage ≥ 4 (the normal case: base frontage 10): 4 regiment-equivalents all engage, the lone organised regiment
  takes 4×E damage units per tick while it can only hit one target → every tier wins "comfortably" (current harsh: 4 × 0.26 = 1.03 :
  1 — still wins because its damage is spread over four morale pools). Size-scaled morale damage (`DEF:476`) only helps the big side.
* Worst case, sequential duels (narrowest frontage, 2 after terrain): the big side needs `ceil(1/E)` regiment-equivalents.
  Current harsh needs all 4 → any bad dice loses → **fails the "comfortably" requirement**. Current standard uses 3 of 4 → wins
  without reserve. Proposed standard uses 2 of 4 → comfortable. Proposed mild uses 2.
* Equal numbers (1000 vs 1000): the HQ-less side loses whenever E < 1; at E = 0.74 (proposed mild) the organised side ends the
  duel with ~26 % morale left — a narrow but clear loss, acceptable for a *mild* setting. At 0.50 it is decisive.
* Casualties: discipline also scales **strength** damage taken → HQ-less armies lose ≈1.3× more men per battle (current) — an
  AI manpower drain over a campaign (metric in T1.5).

Levy stacking (VERIFIED input, INFERRED effect): levies already carry −20 % discipline; an HQ-less levy host in ages 1–2 sits at
−50 % discipline, i.e. ≈0.6× an organised levy host and ≈0.3× organised regulars. Most 1337 AI armies are levies (`SETUP/27_armies.txt`
has standing armies for only four tags), so the early game is where the penalty bites hardest.

Rebels (DESIGN §2.2: "rebels are not penalised"): correct via `is_real_country` (`MOD/.../cw_triggers.txt:17-20`), but the *owner's*
secondary stacks are penalised, so rebel suppression by anything but the HQ army happens at E ≈ 0.38. Rebel-held locations also have
to be **re-sieged** at −90 % siege ability. Yuan (1668 locations, 1 HQ until 1437), the Golden Horde (740) and Delhi (369) are the
countries vanilla already stresses with revolts. → P1 proposal: do not apply the penalty while `at_war = no` (wars are the design
target; peace-time policing is not), and keep it on at war. Side benefit: the quarterly peace pass becomes a pure HQ-placement pass.

### 1.4 Siege and assault — the undetermined half

The siege window shows `"Siege phases are [Siege.GetPhaseSize] ([Siege.GetSiegeFortDefenseDifference]) days long due to:"` with rows
"Fort defense … a positive value makes a siege last longer" and "Siege Ability: $VAL|-=2%$" (`LOC/units_l_english.yml:1879,1903,1908`);
unfortified: `"This occupation takes [GetPhaseSize] day due to:"` (`:1878`). Base `DAYS_PER_SIEGE_PHASE 30`, min 7, without fort 15
(`DEF:528-530`). The combination rule is not in any file (UNVERIFIED):

| Hypothesis | phase at −75 % / −90 % / −95 % (fort def 0) | unfortified occupation (15 d) at −90 % | Reading |
|---|---|---|---|
| additive: `30 × (1 + def − ability)` | 52 / **57** / 58 days | 28 days | "2× slower", nowhere near "cannot occupy" |
| divisive: `30 / (1 + ability)` | 120 / **300** / 600 days | 150 days | the author's "≈10× slower" |
| clamp at −100 % = no progress (what `army_maintenance_reverse_mod` at 0 % maintenance suggests) | — | — | −100 % = "cannot siege" exists as a vanilla state |

**T1.3 decides everything.** If additive: standard `siege_ability = -4.0` (×5), harsh `-9.0` (×10), mild `-2.0` (×3) — plain numbers,
but check the clamp at −100 % first (if ≤ −100 % means "no progress", then standard = −1.0 is literally "cannot siege" and the AI's
HQ-less fragments can never occupy even villages; then keep −0.9 and accept ×1.9). Note the stacking: a player at 50 % maintenance
without HQ is at −140 % (`SM/country.txt:392` + mod) — document the floor once measured.

Lone HQ (SPEC §15 "cannot occupy alone"): false as written — 100 men meet the "at least 100 men" unfortified gate
(`LOC/game_concepts_l_english.yml:375`) and only suffer the siege malus. If "cannot" is wanted, make the HQ 99 men
(`max_strength = 0.099`, `MOD/in_game/common/unit_types/cw_headquarters.txt:25`; T2.5).

Assault −50 % / −75 %: `assault_ability` "impacts how well an army can perform an assault" (`LOC/modifier_types_l_english.yml:505`);
AI assaults only at 3:1 / 1.5:1 with breach (`DEF:1446-1447`); nothing to change.

### 1.5 Proposed triplet

| key (file `cw_unit_modifiers.txt`) | mild | standard | harsh | rationale |
|---|---|---|---|---|
| `discipline` | −0.10 | **−0.20** | −0.30 | E = 0.74 / 0.50 / 0.38; standard = the author's 50 % |
| `land_morale_modifier` | −0.10 | **−0.25** | −0.30 | morale is the cheaper lever (recovers), discipline costs men |
| `siege_ability` | −0.75 | −0.90 | −0.95 | unchanged pending T1.3; additive fallback −2.0 / −4.0 / −9.0 |
| `assault_ability` | −0.25 | −0.50 | −0.75 | unchanged |
| gating (`cw_update_unit_organization`, `cw_effects.txt:100-130`) | — | apply only if `owner = { at_war = yes }` | — | rebels / peace-time policing (§1.3) |

Tests: T1.1 (duel), T1.2 (4:1 and 1:1 battles), T1.3 (siege phase length), T1.4 (lone HQ occupation), T1.5 (AI manpower and
rebel outcomes in a 1337–1450 observer run).

---

## 2. HQ limit formula and colonial theatres

### 2.1 What the 1337 map actually looks like (VERIFIED, counted from `SETUP/10_countries.txt` own_* lists and `SETUP/07_cities_and_buildings.txt`)

2351 countries own 13 579 land locations; ranks: 12 566 rural, 749 towns, 260 cities, 4 megalopolises (7.5 % urban).

| owned locations | 1–4 | 5–19 | 20–49 | 50–99 | 100–199 | 200–399 | ≥400 |
|---|---|---|---|---|---|---|---|
| countries | 1864 | 374 | 81 | 17 | 10 | 3 | 2 |

| tag | locations | rural / town / city | capital rank | tag | locations | rural / town / city | capital rank |
|---|---|---|---|---|---|---|---|
| CHI (Yuan) | 1668 | 1407 / 225 / 34 (+2 mega) | megalopolis | POL | 75 | 73 / 1 / 1 | city |
| GLH (Golden Horde) | 740 | 731 / 6 / 3 | town | HAB (Austria) | 68 | 63 / 4 / 1 | city |
| DLH (Delhi) | 369 | 340 / 11 / 18 | town | POR | 67 | 60 / 6 / 1 | city |
| JAP | 339 | 332 / 5 / 2 | city | NAP | 65 | 48 / 15 / 2 | city |
| CAS (Castile) | 244 | 222 / 18 / 4 | city | BOH | 45 | 41 / 3 / 1 | city |
| HUN | 189 | 175 / 13 / 1 | city | DAN | 40 | 33 / 7 / 0 | town |
| NOV | 171 | 167 / 3 / 1 | city | MLO (Milan) | 29 | 21 / 6 / 2 | city |
| FRA | 163 | 134 / 25 / 4 | city | SCO | 28 | 27 / 1 / 0 | rural |
| MAM | 143 | 132 / 0 / 10 (+1) | megalopolis | GEN | 19 | 17 / 1 / 1 | city |
| ENG | 138 | 125 / 12 / 1 | city | VEN | 14 | 12 / 1 / 1 | city |
| SWE | 131 | 123 / 8 / 0 | town | BUR | 14 | 12 / 2 / 0 | town |
| LIT | 103 | 98 / 5 / 0 | town | HRE minors (LUX/HOL/KOL) | 8–10 | 5–9 / 1–3 / 0–1 | town |
| ARA | 85 | 67 / 16 / 2 | city | TNC (Tenochtitlan) / TAR / CHK | 1 / 19 / 23 | — | city / town / town |

(Research 06 §4 states `setup/countries/26_ai_personalities.txt` does not exist; it does, at `SETUP/26_ai_personalities.txt` —
historical AI personalities are assigned, so `ai_personality = …` is a usable stance input.)

### 2.2 What the formula yields (`cw_hq_limit = 1 + min(age_slots, floor(num_locations/100))`, `MOD/main_menu/common/script_values/cw_limit_values.txt:25-74`)

Ages begin 1337 / 1342 / 1437 / 1537 / 1637 / 1737 (`game/in_game/common/age/00_default.txt`).

| 1337 size (no conquests) | current (÷100): T / R / D / Ref / Abs / Rev | proposed (÷60, +imperial slot) |
|---|---|---|---|
| < 60 (Venice, Genoa, Milan, Scotland, Denmark, Bohemia, Teutons, Brandenburg, every HRE minor) | 1/1/1/1/1/1 | 1/1/1/1/1/1 |
| 60–99 (Austria, Portugal, Naples, Poland, Aragon, Byzantium, Morocco) | 1/1/1/1/1/1 | 1/1/2/2/2/2 |
| 100–119 (Norway, Lithuania) | 1/1/2/2/2/2 | 1/1/2/2/2/2 |
| 120–179 (France, England, Novgorod, Mamluks, Sweden, Korea) | 1/1/2/2/2/2 | 1/1/2/3/3/3 |
| 180–239 (Hungary) | 1/1/2/2/2/2 | 1/1/2/3/4/4 |
| 240–299 (Castile) | 1/1/2/3/3/3 | 1/1/2/3/4/5 |
| ≥ 300 (Delhi, Japan, Horde, Yuan) | 1/1/2/3/4/4–5 | **2**/2/2/3/4/5 |

The brief ("great powers reach 5 in the last age") is met by the current formula only above 400 locations. With ÷100, Austria,
Portugal, Poland, Aragon and Byzantium never get a second staff without conquering ≥32–35 locations; France is capped at 2 for
the whole game. Proposal: `cw_size_hq_slots: divide = 60`; `cw_age_hq_slots`: add `else_if = { limit = { num_locations >= 300 } value = 1 }`
before the age branches so continental empires get a second staff in ages 1–2 (rebel policing, §1.3). Keep the floor of 1 and
the "small countries live with one army" rule (everything under 60 locations — 2323 of 2351 countries).

### 2.3 Degenerate cases

| Case | What happens | Verdict / fix |
|---|---|---|
| Golden Horde (740 loc., 6 towns, `steppe_horde`) | 1 HQ until 1437; levy hosts at −50 % discipline; occupation-based war worth is 77 % rural (§4.2) so its wars yield little; if horde unity needs looting through occupation (`DEF:1940`, mechanism UNVERIFIED), fewer occupations = faster horde decay | imperial slot (§2.2); watch GLH horde unity and war results in T2.6 |
| Yuan / Ming (1668 loc.) | 1 HQ in ages 1–2 while fighting the Red Turban-style revolts with HQ-less stacks | imperial slot + at-war gating (§1.3) |
| Venice / Genoa (14 / 19 loc.) | 1 HQ for ever; Dalmatia, Crete, Caffa are on `continent:europe` or on sub-continents bordering Europe by sea → never "overseas" (`LOC/game_concepts_l_english.yml:92`) → no colonial slot either | intended ("one army"); mention in the game concept text |
| HRE minors (1–10 loc.) | 1 HQ, armies of 2–4 regiments: organised as soon as the HQ sits in a 2-regiment stack | fine; the emperor's attached allied stacks keep their own HQ |
| Colonial nations (AI subjects) | real countries, 1 HQ, carpet-siege native villages with ≤4 fragments of which 1 can occupy | fine if the siege formula is additive; under the divisive formula America stays native much longer (T2.6 metric) |
| Byzantium, Mamluks, Ottomans, Japan↔Korea, Ming↔SE Asia | other continents that border by land/sea are not overseas → no colonial HQs, correct per the game concept | fine; adjacency table UNVERIFIED (T2.3) |
| Rebels, pirates, conquistador hosts | exempt (`is_real_country`, `country_type = army`) | correct |
| Natives (America) | `cw_age_hq_slots = 0` while isolated — moot, the largest American polity owns 23 locations | see §6 |

### 2.4 Player exploits

| Exploit | Why it works | Fix |
|---|---|---|
| **Colonial HQ at home** | `cw_unit_is_organized` accepts either HQ type anywhere (`cw_triggers.txt:107-111`); colonial HQs are recruitable overseas (`cw_headquarters.txt:64-66`) and the limit reaches 4 → a coloniser fields up to 6 organised armies in Europe | organised = home HQ, **or** colonial HQ while `unit_location = { would_be_overseas_for = owner }`; AI cleanup strips colonial HQs that have been at home for 2 passes |
| **Mercenary-only stacks exempt** | `cw_unit_is_exempt` (`cw_triggers.txt:92-103`) exempts "mercenaries only"; a hired company sieges at full ability with no HQ | drop the mercenary branch; if the engine refuses to merge an HQ into a company (T2.7), give merc-only stacks a siege-only malus (`cw_no_hq_merc`: `siege_ability = -0.6`) |
| **HQ + 1 regiment siege detachment** | `cw_min_subunits_organized = 2` (`cw_values.txt:20`) | 3 (consistent with `cw_min_subunits_for_ai_hq = 3`) |
| Split-and-occupy inside the ticker window | a freshly split unit has no modifier until the next 15-day tick / monthly pulse / `on_command_gained`; an unfortified occupation phase is 15 days | T2.4: if split units inherit unit modifiers nothing to do; otherwise ticker 15 → 10 days (`cw_events.txt:111-118`) — the warscore rework makes the prize (villages) worthless anyway |
| Lone HQ occupying villages | 100 men meet the ≥100-men gate | 99-man HQ (§1.4) |
| HQ hopping (disband here, recruit free HQ there in 30 days) | HQ is free and builds in 30 days (category time) | acceptable; optionally `build_time_modifier = 0.5` (sign INFERRED positive = slower, research 01 §5) |
| Merging two HQs into one army | wastes a slot, no gain | harmless |

### 2.5 AI failure modes

| Mode | Mechanism | Fix |
|---|---|---|
| HQ ends up in a small carpet-siege fragment | the engine splits sub-units without knowing the HQ (research 06 §9.7); the script only *adds* HQs when a slot is free, never moves them | monthly `cw_ai_relocate_hqs`: if an HQ army has `num_subunits < cw_min_subunits_for_ai_hq` and a larger eligible HQ-less army exists, strip the HQ (`cw_strip_hq_from_unit`) — the same pass refills the largest (`cw_ai_assign_hqs`) |
| HQ lost in a stack-wipe overseas | overrun at 10:1 / 2:1 (`DEF:495-496`) destroys the whole stack; re-grant needs an eligible army of ≥3 regiments on that continent | fine (≤15 days); accept |
| AI disbands the HQ regiment | `ai.log` shows `disband_subunit` commands (research 01 §9) | the pass re-adds it; measure churn (T2.6) |
| Theatre flapping | army sails home → theatre inactive → cleanup strips the colonial HQ → army returns → re-grant | require the excess to persist for 2 passes before cleanup |
| Naval invasion lands HQ-less | no landing on_action; ≤15 days at war | accept |
| 4 carpet-siege fragments, 1 HQ | only the HQ fragment occupies; `AI_STICK_TO_SIEGE_TIME_FACTOR` keeps the others on sieges they cannot finish | relocation rule above + the warscore rework (fragment targets are worthless) |

### 2.6 15-day ticker vs the 15-day unfortified window

`cw_tick.1` re-fires every 15 days and is guarded by a 14-day variable (`cw_events.txt:92-120`); plus the monthly pulse, the two
battle hooks and `on_command_gained`. Worst-case penalty-free window for a new unit = 15 days = exactly one unfortified occupation
phase (`DEF:530`). Whether a modifier applied mid-siege changes the running phase is UNVERIFIED. Cost of a 10-day ticker is
negligible (one `every_army` loop per country at war). Decision: T2.4 first, then 10 days only if modifiers are not inherited.

Script cost to watch: `cw_colonial_hq_limit` runs up to five `any_owned_location` scans + five `any_army` scans
(`cw_limit_values.txt:92-371`) and is evaluated by `cw_cache_limits`, by `cw_has_free_colonial_hq_slot` (per AI pass and per
continent) **and** by the engine as the unit type's `limit` whenever recruitment is evaluated. Cache it once per pass into
`cw_colonial_hq_limit_v` and compare the script triggers against the variable (T5.3).

---

## 3. War stance thresholds (0.55 / 0.33, 2-month lock, intel delay)

Sources: `MOD/in_game/common/script_values/cw_stance_values.txt:20-58`, `scripted_triggers/cw_stance_triggers.txt:113-157`,
`scripted_effects/cw_stance_effects.txt:124-142` (lock), `:277-292` (player mirror).

### 3.1 What the trigger measures

`relative_military_strength` is read as the fraction ours / (ours + theirs), 0.5 = parity (INFERRED: research 04 §4.3 from the
`relative_strength` loc text "Has X % of the total combined strength of them and TARGET"; `RELATIVE_MILITARY_STRENGTH_TRIGGER` itself,
`LOC/triggers_l_english.yml:3044`, only prints the number), and "Military Strength … is calculated from its maximum manpower, army size,
and levy power" (`LOC/game_concepts_l_english.yml:1597`, VERIFIED). So it is **potential** strength: an AI whose field army was just destroyed but keeps its manpower pool stays "Offensive"
until `war_score ≤ −25` or `war_exhaustion ≥ 8` catches it. It is also measured against the enemy **war leader alone**, not the
coalition, and the AI's stance is per country, not per war: in a coalition war the player's plate shows the AI's posture towards
its biggest enemy, which may be someone else.

| fraction f | ratio f/(1−f) | current meaning |
|---|---|---|
| 0.33 | 1 : 2.0 | harassing (cautious: 0.40 = 1 : 1.5) |
| 0.45 | 1 : 1.2 | — |
| 0.50 | 1 : 1 | offensive floor for bold temperaments |
| 0.55 | 1.22 : 1 | offensive (cautious: 0.60 = 1.5 : 1) |
| 0.70 | 2.3 : 1 | hard cap |

### 3.2 Flicker and lies

* No hysteresis band: at f ≈ 0.55 the desired stance alternates monthly; the lock only slows it to one switch per 2–3 months. The
  player's mirror writes 0 ("Unknown") whenever the enemy carries `cw_stance_lock` (`cw_stance_effects.txt:277-292`), i.e. for the
  2 months after **every** change → an AI hovering near a threshold shows "Unknown" two months out of three.
* "Waiting" = not offensive/harassing and the war is younger than 1 year (`cw_stance_triggers.txt:151-157`): every mid-strength AI
  shows "Waiting" for the first 12 months and flips to "Defensive" at month 12–13 regardless of what its armies do. The modifiers
  behind the label are strategic `ai=yes` types plus +10 % reinforcement and +10 % supply (`cw_country_modifiers.txt:40-49`); the
  army AI does not read them (research 06 §3.2). The label is therefore an estimate, not an observation.
* A human enemy always shows 0 — fine; say so in the tooltip.

### 3.3 Proposals

| knob | now | proposed | why |
|---|---|---|---|
| `cw_stance_offensive_base` | 0.55 enter/exit | enter ≥ 0.57, exit < 0.53 (`cw_stance_is_offensive` picks the band) | kills the flicker without touching the lock |
| `cw_stance_harassing_base` | 0.33 | enter ≤ 0.33, exit > 0.38 | same |
| fielded-strength term | — | harassing also when own `army_size` ≤ 0.5 × enemy `army_size` (store the enemy value in a variable as `cw_find_main_enemy` already does for `military_strength`); offensive additionally requires `war_score_of_country ≥ −10` | plate stops lying after a lost field army; `army_size` is a VERIFIED country value ("men in the Army", `LOC/triggers_l_english.yml:3791`) |
| "Waiting" condition | war < 1 year | war < 1 year **and** `army_size_percentage < 0.8` (value exists: `auto_modifiers/country.txt:1113`, semantics INFERRED "current vs expected") | the label matches reinforcing armies |
| intel delay | = lock (2 months → Unknown) | separate `cw_stance_intel` variable, 1 month; keep `cw_enemy_stance_last_known` and show it greyed instead of "Unknown" | the plate keeps information while signalling a change |
| temperament input | ruler/general traits | also `ai_personality = ai_personality:ai_aggressive` → bold, `ai_cautious` → cautious | historical personalities exist (`SETUP/26_ai_personalities.txt`) |

Tests: T3.1 (hover test at f ≈ 0.55 in an observer game: count plate changes per year), T3.2 (destroy an AI field army, read the
plate for 3 months), T3.3 (coalition war: compare the plate with the AI's actual targets in `ai_targets_viewer`).

---

## 4. Warscore defines and rank peace-cost efficiencies

Sources: `MOD/loading_screen/common/defines/cw_war_defines.txt:5-15`; `MOD/in_game/common/location_ranks/00_default.txt:5,81,148,197`
(megalopolis −0.4, city −0.25, town +0.25, rural +1.0); capital bonus `cw_warscore_effects.txt:52-55` (+10, bucket cap 50 `DEF:2434`).
Vanilla: `DEF:2669` (`OCCUPATION_VALUE_SCALE 2.0`), `DEF:2685-2701` (war worth terms), `DEF:2427` (`MONTHS_BEFORE_TOTAL_OCCUPATION 60`),
`DEF:2717` (white peace after 3 years without war action), `DEF:2297-2298` (call for peace 60 months / 67 %), complete-victory rule
(`LOC/interfaces_l_english.yml:1459`: 100 % only when the loser controls none of its locations and no towns or cities), peace cost
= worth × `conquer_cost` / (1 + efficiencies) (research 05 §5.2, INFERRED chain of VERIFIED links; `conquer_province` 0.75,
`wargoals/00_default.txt:26-35`).

### 4.1 Worth worksheet (per-rank non-base terms are ASSUMED; replace with T4.1 readings of "War Score of <location>")

Assumed extras: rural tax 0.3 + pop 0.1 (mod 0.15), no buildings; town tax 1.5, pop 0.5 (0.75), buildings 2 (mod 4), province
capital 1 (2); city tax 4, pop 2 (3), buildings 6 (mod 12), province capital 1 (2), port 1 (2).

| rank | vanilla | mod (base 0.3, cap 30) | proposed (base 0.5, cap 15, building scale back to 0.025) |
|---|---|---|---|
| village | 2.4 | 0.75 | 0.95 |
| town | 7.0 | 8.55 | 6.75 |
| city | 16.0 | 23.3 | 17.5 |
| capital (city / town) | 21 / 12 | 53.3 / 38.55 | 32.5 / 21.75 |

### 4.2 Shares and "can wars reach 100 %?"

| country (1337 counts) | version | rural / towns / cities / capital share | occupation score needed for 100 % | reachable without… |
|---|---|---|---|---|
| France 134/25/3+cap | vanilla | 57 / 31 / 8.5 / 3.7 % | 50 % of worth (scale 2.0) | villages alone give 100 % (the design complaint, confirmed) |
| | mod | 23 / 49 / 16 / 12 % | 66.7 % (scale 1.5) | villages + cities + capital = 51 % → **towns are required**; but towns + villages = 72 % → 100 % **without** the capital and cities |
| | proposed | 33 / 44 / 14 / 8.5 % | 77 % (scale 1.3) | towns + every village = 77.7 % (theoretically still enough); in practice capital + cities + most towns + villages |
| Sweden 123/7/0, capital town | mod | 48 / 31 / 0 / 20 % | 66.7 % | rural-heavy states stay village-decided |
| Golden Horde 731/6/3, capital town | mod | 77 / 7 / 10 / 5 % | 66.7 % | all urban = 23 % × 1.5 = **34 %**: wars vs the Horde are won by battles (≤50 %, age-scaled) + wargoal ticking (≤25) + villages |
| 20-location minor 17/2, capital town | vanilla | 61 / 21 / — / 18 % | 50 % | capital = 36 % |
| | mod | 19 / 25 / — / **56 %** | 66.7 % | capital alone = 85 % **+10 bonus = 95 %**: one siege |
| | proposed | 31 / 26 / — / 42 % | 77 % | capital = 55 % + 10 = 65 %; two more sieges for ~95 |
| 8-location HRE minor 7/0, capital town | vanilla / mod / proposed | capital 42 / 88 / 77 % | — | 83 / 100 / 100 % — minors are capital-decided in every version |

Conclusions: (a) "no 100 % without cities and the capital" is unachievable for big countries by construction — a single location
would have to hold > 1 − 1/scale of the worth; what the rework *does* achieve is "villages alone cannot win", which holds for
every urbanised country; (b) against rural giants (Horde, Lithuania, Sweden, Novgorod) the rework turns wars into battle/ticking
wars — defensible, but AI-vs-AI wars in the East will end at 20–40 % (metric T4.4); (c) the current capital term makes every
≤30-location state a one-siege kill — faster, not slower, blobbing in the HRE/Italy.

### 4.3 Peace cost worksheet (`conquer_province` 0.75; other efficiency terms ignored)

| item | vanilla | mod (rural +1.0, town +0.25, city −0.25) | proposed (rural 0, town 0, city −0.15, megalopolis −0.25) |
|---|---|---|---|
| one village | 1.80 | **0.28** (6.4× cheaper) | 0.71 |
| one town | 5.25 | 5.13 | 5.06 |
| one city | 12.0 | 23.3 | 15.4 |
| province = town + 5 villages | 14.3 | 6.5 | 8.6 |
| province = city + 5 villages | 21.0 | 24.7 | 19.0 |

"Can the AI still take land?" — yes, more of it: the AI prices treaties by war score (`AI_CONQUER_LOCATION_TREATY_WAR_WORTH_FACTOR 0.5`,
`DEF:1492`) and a 50 % peace now buys ~2× the town-provinces and ~6× the villages. Because the *same* quantity feeds occupation score
and peace cost (research 05 §1.2), a near-zero village worth necessarily makes villages near-free in peace — the rank efficiency
is the only decoupling lever, and the mod currently uses it in the wrong direction (+1.0 halves the price again). Also
`WAR_WORTH_DEVELOPMENT_SCALE` adds `clamp(0.05×(dev − taker's average), −1, +5)` (`DEF:2699-2701`): with base 0.3 a village can reach
≤ 0 worth for a developed taker (Venice) — engine behaviour at ≤ 0 is unknown; raise the floor instead of the base alone.

### 4.4 Stalls and white peaces

HQ-gated sieges + fewer carpet fragments + `AI_RECOVER_MORALE_THRESHOLD 75` + `HEAVILY_OUTNUMBERED` behaviour mean long stretches
without a completed siege. Vanilla ends such wars by itself: white peace after 3 years without war action (`DEF:2717`), call for
peace at 60 months (`DEF:2297`), AI "stalled war" peace logic (`PEACE_STALLED_WAR_THRESHOLD 3`, `PEACE_OFFER_WAR_ENTHUSIASM_STALE_WAR 0.5`,
`DEF:576,1104`), AI peace offers from 50 % (`DEF:1100`). Expect more wars ending at 20–40 % and more white peaces; that is tolerable
("wars end when the field army is beaten and the cities fall") as long as T4.4's white-peace share stays under ~25 % of AI wars.
`MONTHS_BEFORE_TOTAL_OCCUPATION 60` caps one-siege kills at 99 % for 5 years, but 99 % is enough to annex a minor.

### 4.5 Proposals

| key | now | proposed | rationale |
|---|---|---|---|
| `NWar.WAR_WORTH_COUNTRY_CAPITAL` | 30 | **15** | capital ≈ 8–12 % of a kingdom, ~40–55 % of a minor instead of 56–88 %; the +10 bonus stays as the "capital has fallen" shock |
| `NWar.OCCUPATION_VALUE_SCALE` | 1.5 | **1.3** | 100 % needs 77 % of worth: capital + cities + most towns |
| `NWar.WAR_WORTH_BASE` | 0.3 | **0.5** | keeps villages ~0 for warscore but not free in peace; absorbs the development term |
| `NWar.WAR_WORTH_DEVELOPMENT_MIN` | −1 (vanilla) | **−0.25** | no zero/negative worth for developed takers |
| `NWar.WAR_WORTH_BUILDING_SCALE` | 0.05 | **0.025** (vanilla) | the cap (15) is the city lever; the scale inflates every village with a building (unit of "building value" UNVERIFIED — T4.1 decides) |
| `rural_settlement.local_war_score_efficiency` | +1.0 | **0** | village price = worth; +1.0 compounds the base drop into 6× cheaper land |
| `town … local_war_score_efficiency` | +0.25 | 0 | towns are already cheaper than vanilla via the worth |
| `city … local_war_score_efficiency` | −0.25 | −0.15 | stacking with stronghold −0.25, unoccupied fort −0.15/−0.18, non-target −0.5 (`DEF:2377-2388`); vanilla already reaches −1.08 so the engine clamps somewhere — keep the mod's share small |
| `megalopolis … local_war_score_efficiency` | −0.4 | −0.25 | same |
| `add_bonus_warscore amount` | 10 | 10 | keep |

Tests: T4.1 (read 10 locations' worth), T4.2 (capital siege vs a 20-location minor: score before/after), T4.3 (peace screen: cost of a
village / town / city province vs vanilla), T4.4 (observer 1337–1450: distribution of final war scores, white-peace share, locations
ceded per war vs vanilla).

---

## 5. AI define overrides (`MOD/loading_screen/common/defines/cw_ai_defines.txt:14-53`)

| key | vanilla → mod | risk | recommendation |
|---|---|---|---|
| `HEAVILY_OUTNUMBERED_RATIO` | 0.40 → 0.50 | **semantics UNVERIFIED**: if StrengthBalance is a fraction (like `relative_military_strength`), 0.5 = parity and every slightly weaker AI switches to "only chase stacks ≤ 50 % of mine" — field stalemates; if a ratio, 0.5 = 1:2 and matches the stance design | hedge **0.45** until T5.1; the mod's own harassing stance (0.33) covers the flavour |
| `AI_SUPPORT_ARMIES_DESIRED_STRENGTH_FACTOR` | 0.33 → 0.5 | half the army idles as covering force; with only the HQ army able to siege, throughput falls further | **0.33** (vanilla); concentration comes from split/merge keys, not from idling |
| `AI_ENEMY_STRENGTH_NO_SUPPORT_ARMIES_FACTOR` | 2 → 3 | covering force kept even at 2–3× superiority → slower sieges when the war is already won | **2** (vanilla) |
| `AI_RECOVER_MORALE_THRESHOLD` | 66 → 75 | more resting; HQ-less armies have lower max morale but the threshold is a percentage, so no interaction | **70** |
| `AI_ENEMY_LAND_SUPREMACY_THRESHOLD` | 3 → 2 | defensive-war turtling from 2× enemy land strength | keep 2, measure war length |
| `RATIO_OVER_SUPPLY_TARGET_TO_SPLIT` | 1.3 → 1.8 | stacks up to 180 % of the supply target before splitting: attrition (`max_attrition 10`, `supply_limit 15`, `SM/location.txt`) in mountains/deserts, more so with `AI_LAND_ARMY_MERGE_THRESHOLD 0.95` and the waiting stance's +10 % supply | **1.5** |
| `CARPET_SIEGE_MAX_ARMIES` 10 → 4, `AI_CARPET_SIEGE_MAX_ARMIES_FACTOR` 0.1 → 0.05 | — | fewer fragments = the HQ fragment does more of the sieging; good fit | keep |
| `HUNT_ARMIES_WIN_CHANCE_SPLIT` 1.0, `HUNT_ARMIES_MAX_SPLINTERS` 2, `HUNT_ARMIES_AI_MAX_NUM_OBJECTIVES` 3 | — | core concentration group | keep |
| `AI_REASSIGN_UNIT_THRESHOLD` 1.33 → 1.6 | — | slower reactions to new threats; acceptable | keep |
| `AI_AWAIT_REINFORCING_ARMY_DISTANCE_MAX/MIN` 35/20 → 60/30, `AI_WAIT_FOR_JOINING_UNIT_STRENGTH_THRESHOLD` 0.33 → 0.2 | — | waiting = time without sieges; combined with the above it feeds the white-peace risk | keep, but it is the first group to revert if T4.4 shows > 25 % white peaces |
| `AI_PERFORMANCE_ATTACH_UNIT_MAX_DISTANCE` 200 → 350, `AI_REINFORCE_ONGOING_BATTLE_DISTANCE` 2 → 4, `AI_REINFORCE_BATTLE_DISTANCE_LIMIT` 3 → 5 | — | explicit pathfinding cost (define comment, research 06 §2.12) | enable in two steps (attach first) and read `performance_degradation.log` (TESTING §6) |
| `AI_REINFORCE_BATTLE_STRENGTH_TRESHOLD` 0.55 → 0.7 | — | AI keeps feeding battles until it holds 70 % → bigger decisive battles (goal) but also marches into lost ones | keep |
| `AI_CALL_ALLY_STRENGTH_BALANCE_THRESHOLD` 0.75 → 0.85, `MAX_RECRUIT_DISTANCE` 10 → 6, `AI_TRANSPORT_STRENGTH_THRESHOLD_PER_DISTANCE` 0.0004 → 0.0003, `OUTNUMBERED_BATTLE_ADVANTAGE` 0.6 → 0.5, `AI_ATTACH_MIN_FRONTAGE_ROOM` 0.5, `AI_FRONTAGE_FILL_TARGET` 1.0 | — | low risk | keep |

Consistency bug (VERIFIED by diffing the key lists): the OFF setting of `cw_rule_ai_concentration` (`cw_game_rules.txt:45-66`) restores
only 13 of the 27 overridden keys and restores `AI_SUPPLY_LIMIT_TARGET`, which the define file does not touch. Missing (14):
`AI_ATTACH_MIN_FRONTAGE_ROOM, AI_AWAIT_REINFORCING_ARMY_DISTANCE_MIN, AI_CALL_ALLY_STRENGTH_BALANCE_THRESHOLD, AI_ENEMY_STRENGTH_NO_SUPPORT_ARMIES_FACTOR,
AI_REASSIGN_UNIT_THRESHOLD, AI_RECOVER_MORALE_THRESHOLD, AI_REINFORCE_BATTLE_DISTANCE_LIMIT, AI_REINFORCE_BATTLE_STRENGTH_TRESHOLD,
AI_REINFORCE_ONGOING_BATTLE_DISTANCE, AI_TRANSPORT_STRENGTH_THRESHOLD_PER_DISTANCE, CARPET_SIEGE_CONFRONT_FACTOR, HUNT_ARMIES_AI_MAX_NUM_OBJECTIVES,
MAX_RECRUIT_DISTANCE, OUTNUMBERED_BATTLE_ADVANTAGE`. Whether `defines = {}` in a game rule works at all is UNVERIFIED (research 06 §2.13).

Stalemate summary: the mod stacks four independent "slower war" effects (HQ-gated sieges, fewer fragments, more waiting/resting, harder
warscore). Vanilla's own stall handling then ends wars white. Ship the concentration group, hold the passivity trio at vanilla, and
let T4.4 decide whether to add it back.

---

## 6. The native penalty (`cw_isolated_tradition_auto`, `cw_auto_modifiers.txt:10-26`; trigger `cw_warscore_triggers.txt:15-21`)

* Coverage (VERIFIED from `SETUP/10_countries.txt` and `SETUP/templates/amerindian_*.txt`): 291 tags have their capital in America;
  the big ones are `monarchy` (Tenochtitlan via `amerindian_advanced_monarchy`, Tarascans 19, Mayapan 12); `type = tribe` appears on
  about a quarter of them (58 inline declarations plus the `amerindian_tribe*` templates), all tiny — the largest tribe is Cahokia (23).
* Effect: −5 % discipline on small tribes until pike-and-shot, Age 4 (1537), `professional_armies`/`new_world` or 60 locations
  (`cw_can_reform_war_host`) — i.e. on the polities vanilla already handicaps structurally (research 10 §5), and nothing on the
  states that actually face conquistadors. The HQ half (no extra slots) never triggers (no American state reaches 60–100 locations
  in 1337). The static modifier `cw_isolated_tradition` (`cw_country_modifiers.txt:64-70`) is defined and localised but never applied —
  dead key.
* Options: (a) make it mean something: drop `government_type = tribe` (keep `capital ?= { continent = continent:america }` + no
  pike-and-shot + not reformed) so Mesoamerican/Andean monarchies get the −5 % too; (b) drop the feature and keep only the decision as
  flavour; either way delete the dead static modifier. Do **not** add `siege_ability` to it (natives rarely siege Europeans; it would
  only slow native-vs-native wars).

---

## 7. Prioritised change list (exact keys)

| P | key / rule | now → proposed | one-line rationale | test |
|---|---|---|---|---|
| 1 | `cw_no_hq.siege_ability` (keep −0.9) — **measure first**; additive fallback mild/std/harsh = −2.0 / −4.0 / −9.0 | — | the concept's core number is undetermined | T1.3 |
| 1 | `cw_no_hq.discipline` / `land_morale_modifier` | −0.3/−0.3 → **−0.2/−0.25**; `cw_no_hq_harsh` −0.4/−0.4 → −0.3/−0.3; `cw_no_hq_mild` −0.15/−0.15 → −0.1/−0.1 | E = 0.50 (author's target) / 0.38 / 0.74; current harsh is a coin flip vs 250 | T1.1, T1.2 |
| 1 | `cw_update_unit_organization`: apply the penalty only when `owner ?= { at_war = yes }` | new | rebels are exempt, your policing stacks are not | T1.5 |
| 1 | `cw_size_hq_slots.divide` 100 → **60**; `cw_age_hq_slots`: `num_locations >= 300` → at least 1 in ages 1–2 | — | France 3 / Castile 5 / Austria 2; giants police revolts | T2.1 |
| 1 | `cw_unit_is_organized`: colonial HQ counts only while `unit_location = { would_be_overseas_for = owner }` | new | +4 home armies for colonisers otherwise | T2.2 |
| 1 | `cw_unit_is_exempt`: remove the mercenaries-only branch (fallback `cw_no_hq_merc` siege-only −0.6 if T2.7 fails) | — | gold buys unlimited organised siege armies otherwise | T2.7 |
| 1 | `NWar.WAR_WORTH_COUNTRY_CAPITAL` 30 → **15**; `OCCUPATION_VALUE_SCALE` 1.5 → **1.3** | — | one siege = 95 % vs minors; 100 % needs capital + cities + towns | T4.2, T4.4 |
| 1 | `rural_settlement.local_war_score_efficiency` 1.0 → **0**; town 0.25 → 0; city −0.25 → −0.15; megalopolis −0.4 → −0.25 | — | villages 6× cheaper than vanilla otherwise | T4.3 |
| 2 | `NWar.WAR_WORTH_BASE` 0.3 → 0.5; `WAR_WORTH_DEVELOPMENT_MIN` → −0.25; `WAR_WORTH_BUILDING_SCALE` 0.05 → 0.025 | — | no ≤0 worth; caps not scales for the urban premium | T4.1 |
| 2 | `NAI.HEAVILY_OUTNUMBERED_RATIO` 0.5 → **0.45**; `AI_SUPPORT_ARMIES_DESIRED_STRENGTH_FACTOR` 0.5 → 0.33; `AI_ENEMY_STRENGTH_NO_SUPPORT_ARMIES_FACTOR` 3 → 2; `AI_RECOVER_MORALE_THRESHOLD` 75 → 70; `RATIO_OVER_SUPPLY_TARGET_TO_SPLIT` 1.8 → 1.5 | — | passivity/attrition hedges until the observer run | T5.1, T4.4 |
| 2 | `cw_rule_ai_concentration.cw_ai_concentration_off.defines`: add the 14 missing keys, drop `AI_SUPPLY_LIMIT_TARGET` | — | OFF must restore vanilla | T5.2 |
| 2 | stance bands: offensive enter 0.57 / exit 0.53, harassing enter 0.33 / exit 0.38; harassing also if `army_size` ≤ 0.5× enemy; offensive requires `war_score ≥ −10`; intel delay 1 month separate from the 2-month lock; "Waiting" also requires `army_size_percentage < 0.8` | — | no flicker, no lying plate | T3.1–T3.3 |
| 2 | `cw_min_subunits_organized` 2 → **3** | — | kills HQ+1 siege detachments | T2.5 |
| 2 | AI `cw_ai_relocate_hqs` (strip HQ from AI armies < 3 regiments when a larger HQ-less army exists) | new | HQ stuck in a 2-regiment fragment for a month | T2.6 |
| 2 | cache `cw_colonial_hq_limit` once per pass; cleanup only after 2 consecutive excess passes | — | 10 list scans per evaluation; theatre flapping | T5.3 |
| 3 | native penalty: drop `government_type = tribe` or drop the feature; delete the unused `cw_isolated_tradition` static modifier | — | hits 1 of the 20 largest American polities | — |
| 3 | `cw_hq.max_strength` 0.1 → 0.099 | — | lone HQ cannot meet the 100-men gate | T1.4 |
| 3 | ticker 15 → 10 days only if T2.4 shows split units lose their modifiers | — | one unfortified phase of free occupation | T2.4 |

## 8. What I would NOT change

* The HQ as a free, limited, bonus-less 100-man auxiliary regiment (`army_auxiliary`, reserves, no combined-arms effect) — correct and cheap.
* The home floor of 1 HQ for everyone and "small countries fight with one army" (2323 of 2351 countries are under 60 locations).
* The expeditionary free slot (an army of ≥3 regiments activates a theatre) — the single most important AI-colonial protection (research 10 R1).
* America as one theatre, the 5/25/60 thresholds and the cap of 4 — matches the historical regular counts in research 10 §9.
* The `cw_expeditionary` bonus (−15 % attrition, +10 % speed, +10 % morale recovery): small, overseas-only, flavourful.
* `assault_ability` −50 %, the hysteresis lock of 2 months, the trait-based temperament shifts (just add bands and the fielded term).
* The concentration group of NAI keys (`HUNT_ARMIES_*`, `CARPET_SIEGE_MAX_ARMIES 4`, `AI_LAND_ARMY_MERGE_THRESHOLD 0.95`, `AI_REASSIGN_UNIT_THRESHOLD 1.6`, the reinforce-battle group, `AI_CALL_ALLY 0.85`).
* The `+10` capital bonus (one-shot, capped at 50 with the other bonuses) — it is the right place for "the capital has fallen".
* `WAR_WORTH_PROVINCE_CAPITAL 2`, `WAR_WORTH_PORT 2`, the population cap 6 and the building cap 15 (caps raise cities, not villages).
* The subject stance "Escort" — player-only tool, zero risk.
* Exemptions for `is_exiled`, prisoners, `country_type = army`, non-real countries.

## 9. Test plan (pass criteria)

| id | how | pass if |
|---|---|---|
| T1.1 | console/observer: one organised vs one HQ-less regiment of the same type, flat terrain, 5 repeats | HQ-less breaks first in ≥ 4/5; organised ends with ≥ 40 % morale (standard) |
| T1.2 | 2 HQ-less infantry regiments (1000) vs 1 organised 250-man cavalry/half regiment; then 2 vs 2 | 4:1 case won ≥ 4/5; equal case lost ≥ 4/5 |
| T1.3 | same fort (level 1), two identical armies, one HQ-less; read "Siege phases are N days" | N ≈ 57 → additive (apply fallback values); N ≈ 300 → divisive (keep); also set `siege_ability = -1.0` once to see the −100 % behaviour |
| T1.4 | lone HQ on an unfortified enemy village | occupies (→ 99-man fix) or not |
| T1.5 | observer 1337–1450, mod vs vanilla: count successful revolts (rebels enforcing demands) for CHI, GLH, DLH; AI manpower at 1400/1450 | revolt successes ≤ 1.3× vanilla; manpower ≥ 0.8× vanilla |
| T2.1 | limit tooltip for France/Austria/Castile at 1337, 1437, 1537 | matches the proposed table |
| T2.2 | ship a colonial HQ home and check the army tab | penalised at home (after fix) |
| T2.3 | debug tooltip: `would_be_overseas_for` for Oran (Castile), Crete (Venice), Goa (Portugal), Nova Scotia (England) | no / no / yes / yes |
| T2.4 | split an HQ-less army at war; inspect the new unit's modifiers immediately | modifier present → no ticker change |
| T2.5 | HQ + 1 regiment on a village and on a level-1 fort | cannot occupy (after the ≥3 rule) |
| T2.6 | observer 1437–1500: per AI war, share of occupations made by HQ armies; HQ churn (`cw_hq` created/destroyed per year via `on_action` counters); colonial-nation gains vs natives vs vanilla | HQ armies ≥ 80 % of occupations; churn < 2 per country-year |
| T2.7 | try `add_subunit = unit_type:cw_hq` on a hired company | works → drop exemption; fails → `cw_no_hq_merc` |
| T3.1–T3.3 | see §3.3 | ≤ 3 plate changes per war-year; plate reads Harassing within 2 months of a lost field army |
| T4.1 | location panel "War Score of <loc>" for 5 villages (with/without buildings), 3 towns, 1 city, capital; mod vs vanilla | village ≤ 1.0, town 5–9, city 15–25, capital 30–40 |
| T4.2 | siege the capital of a 20-location minor; read occupation score + bonus | ≤ 70 % (after fix) |
| T4.3 | peace screen cost of a village / town-province / city-province vs vanilla | village ≥ 0.6, town-province ≥ 8 |
| T4.4 | observer 1337–1450: final war-score distribution, white-peace share, locations ceded per war, mean war length vs vanilla | white peaces ≤ 25 %; locations ceded per war ≤ 1.5× vanilla; mean length ≤ 1.5× vanilla |
| T5.1 | two AIs at `relative_military_strength` ≈ 0.45–0.5: does the weaker one still accept field battles? | yes → ratio semantics, 0.5 acceptable; no → keep 0.45 or vanilla 0.40 |
| T5.2 | start with `cw_ai_concentration_off`: hunting armies split into > 2 stacks again | yes → rule works; complete the key list either way |
| T5.3 | `performance_degradation.log` at 1500 with attach 200 vs 350 | ≤ 10 % slower than vanilla |

## Appendix — source index

DESIGN.md §2.2–2.4, §3.3, §4; SPEC.md §3, §6–§10, §15; research 01 §3/§8/§9, 03 §5.1, 04 §4.3, 05 §1–§5/§7, 06 §2/§3/§5/§11/§12, 10 §1–§3/§6–§9.
Game: `DEF` NCombat 448-563, NUnit 364-447, NAI 565-1608 (lines cited inline), NDiplomacy 2297-2439, NWar 2665-2727; `SM/unit.txt`,
`SM/subunit.txt`, `SM/country.txt:388-394,7558-7564`, `SM/location.txt:4-30`; `LOC/game_concepts_l_english.yml:375,487,1597,2281`,
`LOC/modifier_types_l_english.yml:73,503,505,511`, `LOC/units_l_english.yml:1718,1723,1868-1908`, `LOC/triggers_l_english.yml:3044,3791`;
`SETUP/10_countries.txt`, `SETUP/07_cities_and_buildings.txt`, `SETUP/27_armies.txt`, `SETUP/26_ai_personalities.txt`, `main_menu/setup/templates/*.txt`;
`game/in_game/common/wargoals/00_default.txt:26-35,105-115`, `location_ranks/00_default.txt`, `government_types/00_default.txt:97,130`.
Mod: `cw_unit_modifiers.txt`, `cw_country_modifiers.txt`, `cw_ai_defines.txt`, `cw_war_defines.txt`, `cw_limit_values.txt`, `cw_values.txt`,
`cw_stance_values.txt`, `cw_stance_triggers.txt`, `cw_stance_effects.txt`, `cw_triggers.txt`, `cw_effects.txt`, `cw_events.txt`,
`cw_game_rules.txt`, `cw_auto_modifiers.txt`, `cw_warscore_triggers.txt`, `cw_warscore_effects.txt`, `location_ranks/00_default.txt` (mod copy).
