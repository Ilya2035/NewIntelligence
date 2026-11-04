# 14 — HQ limits at the 1337 start: sanity check of `cw_hq_limit` / `cw_colonial_hq_limit`

Research note for the *Concentrated Warfare* mod (`cw_`), EU5 1.4.7. Game root `G = C:\Program Files (x86)\Steam\steamapps\common\Europa Universalis V\game` (paths below are relative to it). Everything was read from the installed files on 2026-11-04 with perl/awk; nothing was run in game.

Legend: **VERIFIED** = read in the files (path:line quoted). **INFERRED** = follows from verified data, composition/units not stated anywhere. **UNVERIFIED** = plausible, needs an in-game test.

Formula under test (SPEC §3): home HQ limit = `1 + min(age slots, floor(num_locations / 100))`, age slots 0/0/1/2/3/4 (Traditions, Renaissance, Discovery, Reformation, Absolutism, Revolutions). Colonial HQs: +1 per overseas continent with >= 5 owned locations (or an army of >= 3 regiments), +1 at >= 25 (age >= 4), +1 at >= 60 (age >= 5), cap 4.

## 0. Summary (read this first)

1. **Ownership at start lives in `main_menu/setup/1337/10_countries.txt`**, not in `in_game/setup/countries` (that folder only holds colours/culture) — §1.
2. Only **13 landed regular countries own >= 100 locations** in 1337 (China 1668, Delhi 369, Japan 339, Castile 244, Hungary 189, Novgorod 171, France 163, Egypt/Mamluks 143, England 138, Sweden 131, Goryeo 126, Norway 119, Lithuania 103) plus two hordes (Golden Horde 740, Chagatai 127). Only **China** is >= 400. With 100 locations per slot the "5 HQs in the last age" club is China/Horde-tier; France would need 400 locations — §3, §4.
3. **Critical: steppe hordes are `type = army` countries** (Golden Horde, Chagatai, Jalayirids, Gurgan, Hüleguids, Choros … 28 landed hordes, 1,341 locations, all `government = steppe_horde`). The SPEC's `cw_is_real_country = { is_real_country = yes NOT = { country_type = army } }` would exempt every horde from HQ limits and penalties. Exempt conquistador hosts by subject type instead — §5 F1.
4. Location count is a poor proxy for strength on the steppe/taiga: Novgorod (171 loc, 0.47 M pop), Sweden (131, 0.62 M), Norway (119, 0.37 M), Golden Horde (740, 3.3 M) outrank Naples (65, 2.3 M), Hoysala (47, 3.2 M), Khmer (82, 2.5 M), Bohemia (45, 1.7 M), Venice (14) and Milan (29) — §5 F2–F4.
5. All triggers needed for alternatives exist (`num_locations_owned_or_owned_by_subjects`, `num_location_rank:<rank>`, `num_of_non_rural`, `country_tax_base`, `total_population`, `regular_army_size`, `expected_army_size`, `army_size`, …); `total_tax_base` does **not** exist (`country_tax_base` is the key) — §6.
6. Recommended change: keep locations as the base but at **75 per slot**, and add an **army route** `max(floor(num_locations/75), floor(regular_army_size/20))`; do not count subject land for the home limit; the colonial tiers must count colonial-subject land, because the AI never holds overseas land directly — §7.
7. Nobody has overseas holdings at start (America: 5,772 of 6,265 land locations unowned), so `cw_colonial_hq_limit = 0` everywhere in 1337 — consistent with the spec.

## 1. Where ownership is defined (VERIFIED)

| What | Where | Evidence |
|---|---|---|
| Bookmark → setup folder | `main_menu/common/bookmarks/00_bookmarks.txt:1-5` | `bookmark_1337 = { start_date = 1337.4.1 … setup_folder = "setup/1337" }` |
| Country definitions (colour, culture, religion only) | `in_game/setup/countries/*.txt` (46 files) | `in_game/setup/countries/00_readme.info`: `TAG = { color … culture_definition … }`; `france.txt:10-22` (`FRA = { color = map_FRA … culture_definition = french … difficulty = 3 }`). **No ownership keys at all** (grep `own`/`control` → 0 hits). |
| **Ownership, capital, rank, government** | `main_menu/setup/1337/10_countries.txt` (63,445 lines) | line 1 `current_age = age_1_traditions`; lines 3-13 list the keys `own_control_core, own_control_integrated, own_control_conquered, own_control_colony, own_core, own_conquered, own_integrated, own_colony, control_core, control, our_cores_conquered_by_others`; structure `countries = { countries = { TAG = { own_control_core = { stockholm norrtalje … } … capital = stockholm } } }` (`:15-16`, SWE `:18-160`). |
| Map hierarchy (location → province → area → region → sub-continent → continent) | `in_game/map_data/definitions.txt` (10,563 lines) | depth-0 blocks: `europe` (`:1`), `asia` (`:1943`), `africa` (`:4785`), `america` (`:5880`), `oceania` (`:9125`) + 4 ocean "continents" (`:10287-10550`). |
| Population per location | `main_menu/setup/1337/06_pops.txt` | `stockholm = { define_pop = { type = peasants size = 18.908 culture = swedish religion = catholic } … }`; 51,530 `define_pop` lines in 20,794 locations. Sizes are in **thousands** (INFERRED: Cairo 529.2, Paris 254.4, world total 393,828 ≈ 394 M people). |
| Location ranks | `main_menu/setup/1337/07_cities_and_buildings.txt` | `stockholm = { rank = town town_setup = … }`; 749 towns, 260 cities, 4 megalopolises (Cairo, Constantinople, Dadu, + 1), 7 explicit rural_settlement; everything else rural. |
| Subjects | `main_menu/setup/1337/12_diplomacy.txt` | 649 `dependency = { first = ENG second = WLS subject_type = dominion }` (vassal 402, tusi 126, tributary 68, samanta 22, fiefdom 12, appanage 10, dominion 4, hanseatic_member 3, familial_governor 2). |
| Starting armies | `main_menu/setup/1337/27_armies.txt` (193 lines) | Only the two scripted wars have units: `army = { country = VEN … a_footmen ×2 }`, VER 3 regiments, MOR 1, plus levies (VER/VEN/PAD/MLO/MAN/FER/MOR/TLE). **Every other starting army is generated by the engine** — regiment counts at start cannot be read from files. |
| Ages | `in_game/common/age/00_default.txt` | `age_2_renaissance year = 1342` (`:54`), `age_3_discovery 1437` (`:114`), `age_4_reformation 1537` (`:175`), `age_5_absolutism 1637` (`:242`), `age_6_revolutions 1737` (`:322`). |

Key-usage counts in `10_countries.txt`: `own_control_core` 1,594 blocks, `own_control_integrated` 115, `own_control_conquered` 30, `own_control_colony` 1 (SWE `asele`), `own_core` 4, `control` 3 (TEU occupations in the Lithuanian crusade), `control_core` 0, `our_cores_conquered_by_others` 241 (claims, not ownership). 2,351 tag blocks; 15,452 owned-location entries; **no location is listed under two owners**; 2,016 tags own at least one location (1,538 of them "regular" countries, the rest hordes, pops, building-countries).

Country **types** inside tag blocks (`type = …`, `:3996` for GLH): `army` 33 (all steppe hordes + 5 landless: CHB, MGE, OIR, **TIM**, ZAZ), `building` 150 (145 Japanese clans + Hansa etc.), `pop` 453, `location` 3, default (real settled country) 1,712.

What `num_locations` counts: loc `NUM_LOCATIONS_TRIGGER: "Has $COMPARATOR$ $NUM|V0$ [locations|E]"` (`in_game/common/trigger_localization/country_triggers.txt:1558`); used as a value in `in_game/common/auto_modifiers/country.txt:331-337` (`num_locations_impact = { scales_with = { value = num_locations divide = 10 } fort_limit = 1 }`). INFERRED: it counts all owned locations regardless of core/integrated/conquered/colony status; whether it excludes locations controlled by others is UNVERIFIED (irrelevant at start — only 3 `control` entries).

Method (reproducible, scripts in the session scratchpad `C:\Users\fyrno\AppData\Local\Temp\claude\ee4f8276f1e5680c\dda03347-7e50-4df6-8aec-a460d1d85c95\scratchpad\`): `parse_countries.pl` (brace-depth tokenizer of `10_countries.txt` → per-tag counts, capital, type, includes), `parse_defs.pl` (`definitions.txt` → location geography), `parse_pops.pl`, `agg.pl` (joins → `tag_stats.tsv`), `table.awk` / `variants.awk`.

## 2. Land per continent at start (VERIFIED counts)

| Continent | Land locations | Unowned in 1337 | Note |
|---|---|---|---|
| europe | 6,323 | 1,250 | includes the steppe, Iceland/Greenland (`north_atlantic_islands_region` is `europe/western_europe`) |
| asia | 10,317 | 3,393 | |
| africa | 3,240 | 2,123 | |
| america | 6,265 | 5,772 | largest native country owns 23 |
| oceania | 2,152 | ~2,140 | largest owner 3 locations |

## 3. Countries at the 1337 start

Loc = owned locations (all `own_*` keys). +subj = Loc + locations of **direct** subjects (what `num_locations_owned_or_owned_by_subjects` measures). Pop = sum of `define_pop` sizes (millions, INFERRED units). Urban = town + city + megalopolis. Prov = distinct provinces owned. "Other cont." = owned locations outside the capital's continent (none is "overseas" in the game sense — see F6). HQ columns = `1 + min(age slots, floor(Loc/100))` if the size never changes.

| Tag | Name | Type | Loc | +subj | Pop M | Urban | Prov | Capital cont./sub-cont. | Other cont. | ⌊Loc/100⌋ | Trad/Ren | Disc | Ref | Abs | Rev |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| CHI | China (Yuan) | regular | 1668 | 2268 | 82.8 | 261 | 353 | asia/east_asia | - | 16 | 1 | 2 | 3 | 4 | 5 |
| GLH | Jochi (Golden Horde) | **army** | 740 | 960 | 3.3 | 9 | 138 | europe/eastern_europe | asia 242 | 7 | 1 | 2 | 3 | 4 | 5 |
| DLH | Delhi | regular | 369 | 448 | 39.7 | 29 | 64 | asia/south_asia | - | 3 | 1 | 2 | 3 | 4 | 4 |
| JAP | Japan | regular | 339 | 339 | 9.8 | 7 | 65 | asia/east_asia | - | 3 | 1 | 2 | 3 | 4 | 4 |
| CAS | Castile | regular | 244 | 262 | 5.0 | 22 | 45 | europe/western_europe | - | 2 | 1 | 2 | 3 | 3 | 3 |
| HUN | Hungary | regular | 189 | 210 | 3.5 | 14 | 38 | europe/eastern_europe | - | 1 | 1 | 2 | 2 | 2 | 2 |
| NOV | Velikiy Novgorod | regular | 171 | 188 | 0.5 | 4 | 33 | europe/eastern_europe | - | 1 | 1 | 2 | 2 | 2 | 2 |
| FRA | France | regular | 163 | 333 | 5.4 | 29 | 48 | europe/western_europe | - | 1 | 1 | 2 | 2 | 2 | 2 |
| MAM | Egypt (Mamluks) | regular | 143 | 265 | 6.5 | 11 | 30 | africa/north_africa | asia 75 | 1 | 1 | 2 | 2 | 2 | 2 |
| ENG | England | regular | 138 | 197 | 3.0 | 13 | 39 | europe/western_europe | - | 1 | 1 | 2 | 2 | 2 | 2 |
| SWE | Sweden | regular | 131 | 142 | 0.6 | 8 | 23 | europe/western_europe | - | 1 | 1 | 2 | 2 | 2 | 2 |
| CHG | Chagatai | **army** | 127 | 317 | 1.4 | 3 | 21 | asia/central_asia | - | 1 | 1 | 2 | 2 | 2 | 2 |
| KOR | Goryeo | regular | 126 | 126 | 2.4 | 8 | 24 | asia/east_asia | - | 1 | 1 | 2 | 2 | 2 | 2 |
| NOR | Norway | regular | 119 | 154 | 0.4 | 6 | 20 | europe/western_europe | - | 1 | 1 | 2 | 2 | 2 | 2 |
| LIT | Lithuania | regular | 103 | 170 | 0.9 | 5 | 23 | europe/eastern_europe | - | 1 | 1 | 2 | 2 | 2 | 2 |
| MOR | Morocco | regular | 90 | 111 | 1.9 | 9 | 17 | africa/north_africa | europe 4 | 0 | 1 | 1 | 1 | 1 | 1 |
| BYZ | Byzantium | regular | 87 | 97 | 1.2 | 7 | 25 | europe/eastern_europe | asia 5 | 0 | 1 | 1 | 1 | 1 | 1 |
| ARA | Aragon | regular | 85 | 94 | 1.3 | 18 | 19 | europe/western_europe | - | 0 | 1 | 1 | 1 | 1 | 1 |
| KHM | Khmer | regular | 82 | 82 | 2.5 | 4 | 18 | asia/south_east_asia | - | 0 | 1 | 1 | 1 | 1 | 1 |
| KIE | Kyiv | regular | 79 | 79 | 0.7 | 2 | 17 | europe/eastern_europe | - | 0 | 1 | 1 | 1 | 1 | 1 |
| POL | Poland | regular | 75 | 117 | 1.0 | 2 | 19 | europe/eastern_europe | - | 0 | 1 | 1 | 1 | 1 | 1 |
| YEM | Yemen | regular | 69 | 69 | 2.6 | 2 | 13 | asia/middle_east | - | 0 | 1 | 1 | 1 | 1 | 1 |
| HAB | Austria | regular | 68 | 68 | 1.4 | 5 | 24 | europe/western_europe | - | 0 | 1 | 1 | 1 | 1 | 1 |
| POR | Portugal | regular | 67 | 67 | 1.2 | 7 | 10 | europe/western_europe | - | 0 | 1 | 1 | 1 | 1 | 1 |
| NAP | Naples | regular | 65 | 80 | 2.3 | 17 | 12 | europe/western_europe | - | 0 | 1 | 1 | 1 | 1 | 1 |
| BUL | Bulgaria | regular | 63 | 63 | 0.9 | 10 | 10 | europe/eastern_europe | - | 0 | 1 | 1 | 1 | 1 | 1 |
| SER | Serbia | regular | 63 | 63 | 0.9 | 4 | 16 | europe/eastern_europe | - | 0 | 1 | 1 | 1 | 1 | 1 |
| JAL | Jalayirids | **army** | 59 | 177 | 0.7 | 3 | 16 | asia/middle_east | europe 16 | 0 | 1 | 1 | 1 | 1 | 1 |
| TIB | Tibet | regular | 59 | 164 | 0.3 | 1 | 14 | asia/east_asia | - | 0 | 1 | 1 | 1 | 1 | 1 |
| DAI | Đại Việt | regular | 53 | 53 | 1.7 | 1 | 13 | asia/south_east_asia | - | 0 | 1 | 1 | 1 | 1 | 1 |
| HSL | Hoysala | regular | 47 | 47 | 3.2 | 4 | 8 | asia/south_asia | - | 0 | 1 | 1 | 1 | 1 | 1 |
| TLE | Tlemcen | regular | 46 | 46 | 1.0 | 5 | 10 | africa/north_africa | - | 0 | 1 | 1 | 1 | 1 | 1 |
| BOH | Bohemia | regular | 45 | 106 | 1.7 | 4 | 11 | europe/western_europe | - | 0 | 1 | 1 | 1 | 1 | 1 |
| ETH | Ethiopia | regular | 45 | 96 | 0.7 | 2 | 16 | africa/east_africa | - | 0 | 1 | 1 | 1 | 1 | 1 |
| GEO | Georgia | regular | 44 | 73 | 0.5 | 1 | 11 | europe/eastern_europe | - | 0 | 1 | 1 | 1 | 1 | 1 |
| TEU | Teutonic Order | regular | 43 | 80 | 0.5 | 3 | 10 | europe/eastern_europe | - | 0 | 1 | 1 | 1 | 1 | 1 |
| DAN | Denmark | regular | 40 | 46 | 0.6 | 7 | 10 | europe/western_europe | - | 0 | 1 | 1 | 1 | 1 | 1 |
| TUN | Tunis | regular | 37 | 116 | 0.8 | 3 | 8 | africa/north_africa | - | 0 | 1 | 1 | 1 | 1 | 1 |
| VIJ | Vijayanagar | regular | 36 | 36 | 2.4 | 3 | 7 | asia/south_asia | - | 0 | 1 | 1 | 1 | 1 | 1 |
| MAJ | Majapahit | regular | 32 | 112 | 2.6 | 4 | 5 | asia/south_east_asia | - | 0 | 1 | 1 | 1 | 1 | 1 |
| KBO | Kanem | regular | 32 | 91 | 0.5 | 2 | 7 | africa/west_africa | - | 0 | 1 | 1 | 1 | 1 | 1 |
| MLO | Milan | regular | 29 | 29 | 0.9 | 8 | 8 | europe/western_europe | - | 0 | 1 | 1 | 1 | 1 | 1 |
| SCO | Scotland | regular | 28 | 37 | 0.2 | 1 | 11 | europe/western_europe | - | 0 | 1 | 1 | 1 | 1 | 1 |
| BRA | Brandenburg | regular | 27 | 33 | 0.4 | 2 | 8 | europe/western_europe | - | 0 | 1 | 1 | 1 | 1 | 1 |
| MOS | Muscovy | regular | 26 | 26 | 0.3 | 1 | 5 | europe/eastern_europe | - | 0 | 1 | 1 | 1 | 1 | 1 |
| TUR | Ottomans | regular | 23 | 23 | 0.6 | 3 | 7 | asia/middle_east | - | 0 | 1 | 1 | 1 | 1 | 1 |
| MAL | Mali | regular | 21 | 168 | 0.4 | 3 | 5 | africa/west_africa | - | 0 | 1 | 1 | 1 | 1 | 1 |
| PAP | Papal State (Rome) | regular | 20 | 21 | 0.9 | 9 | 6 | europe/western_europe | - | 0 | 1 | 1 | 1 | 1 | 1 |
| GEN | Genoa | regular | 19 | 22 | 0.5 | 2 | 7 | europe/western_europe | asia 2 | 0 | 1 | 1 | 1 | 1 | 1 |
| UBV | Upper Bavaria (Emperor) | regular | 17 | 17 | 0.3 | 1 | 7 | europe/western_europe | - | 0 | 1 | 1 | 1 | 1 | 1 |
| LBV | Lower Bavaria | regular | 17 | 17 | 0.4 | 0 | 7 | europe/western_europe | - | 0 | 1 | 1 | 1 | 1 | 1 |
| VEN | Venice | regular | 14 | 25 | 0.2 | 2 | 9 | europe/western_europe | - | 0 | 1 | 1 | 1 | 1 | 1 |
| PAL | Palatinate (Rhine) | regular | 11 | 13 | 0.2 | 1 | 6 | europe/western_europe | - | 0 | 1 | 1 | 1 | 1 | 1 |
| LUX | Luxembourg | regular | 10 | 10 | 0.1 | 1 | 5 | europe/western_europe | - | 0 | 1 | 1 | 1 | 1 | 1 |
| WUR | Württemberg | regular | 10 | 11 | 0.2 | 1 | 5 | europe/western_europe | - | 0 | 1 | 1 | 1 | 1 | 1 |
| MAG | Magdeburg | regular | 8 | 8 | 0.2 | 2 | 4 | europe/western_europe | - | 0 | 1 | 1 | 1 | 1 | 1 |
| KOL | Cologne | regular | 8 | 8 | 0.2 | 2 | 5 | europe/western_europe | - | 0 | 1 | 1 | 1 | 1 | 1 |
| FLO | Florence | regular | 5 | 5 | 0.3 | 2 | 2 | europe/western_europe | - | 0 | 1 | 1 | 1 | 1 | 1 |
| AAC | Aachen (free city) | regular | 1 | 1 | 0.0 | 1 | 1 | europe/western_europe | - | 0 | 1 | 1 | 1 | 1 | 1 |
| CHK | Cahokia | regular | 23 | 23 | 0.1 | 1 | 9 | america/north_america | - | 0 | 1 | 1 | 1 | 1 | 1 |
| TAR | Purépecha | regular | 19 | 19 | 0.5 | 2 | 5 | america/north_america | - | 0 | 1 | 1 | 1 | 1 | 1 |
| COC | Cocom (Mayapan) | regular | 12 | 21 | 0.9 | 1 | 4 | america/north_america | - | 0 | 1 | 1 | 1 | 1 | 1 |
| KKA | Kanien'kehaka | regular | 11 | 11 | 0.0 | 1 | 2 | america/north_america | - | 0 | 1 | 1 | 1 | 1 | 1 |
| CYA | Sacha-p-qulla (Andes) | regular | 10 | 10 | 0.1 | 0 | 3 | america/south_america | - | 0 | 1 | 1 | 1 | 1 | 1 |
| PCJ | Paka Jaqis (Andes) | regular | 7 | 7 | 0.2 | 0 | 2 | america/south_america | - | 0 | 1 | 1 | 1 | 1 | 1 |
| CHM | Chimu | regular | 4 | 4 | 0.2 | 1 | 2 | america/south_america | - | 0 | 1 | 1 | 1 | 1 | 1 |

Tags asked for that do **not** exist as landed countries in 1337 (VERIFIED, no block or 0 locations): Aztecs `AZT`, Inca `INC`, Ming `MNG` (block, 0 locations), Timurids `TIM` (landless `type = army` block — Chagatai `CHG` is the 1337 stand-in), `OTT` (the Ottomans are `TUR`, 23 locations, duchy), Mughals, Russia, Prussia, Netherlands, Spain. Egypt = `MAM`; the Golden Horde = `GLH` ("Jochi"); Yuan China = `CHI`.

Other groups:
- **Japan**: `JAP` owns all 339 Japanese locations (`10_countries.txt:24882-…`); the 145 daimyo clans (`include = "japanese_clan"`) are `type = building` countries with **0 locations** (e.g. `AHT`, `:30007-30011`). They only become land countries through the shogunate situation (`in_game/common/scripted_triggers/situation_triggers.txt:243-245`: `is_valid_landable_daimyo = { country_type = building is_subject = no …}`). At start Japan is one 339-location country → 3 size slots; after the daimyo landing it shrinks and the formula follows.
- **HRE** (`15_international_organizations.txt:12-22`, 313 members, leader `UBV`): 254 members own 1-4 locations, 30 own 5-9, 21 own 10-24, 4 own 25+ (HAB 68, BOH 45, MLO 29, BRA 27). All HRE minors sit at 1 HQ for the whole game under any size rule.
- **America**: largest owners Cahokia 23, Purépecha 19, Cocom 12 (richest: 0.9 M pop), Kanien'kehaka 11, Sacha-p-qulla 10, Chimu 4 (0.2 M). None reaches 25 locations; no American country can earn a size slot before conquering ~4× its start.
- **Hordes (`type = army`, all `government = steppe_horde`)** with land: GLH 740, CHG 127, JAL 59, GRG 48, CRS 37, HLG 31, QUN 26, OTC 23, HCN 21, YSU 21, DGH 20, OGE 19, QAS 19, BAT 18, BGT 17, SLD 17, KHD 16, JKR 15, NGD 15, BRL 13, JLY 9, APD 6, TRH 6, BSD 4, JUR 4, KTT 4, ART 3, UGH 3 (28 countries, 1,341 locations).

## 4. Size distribution of the 1,538 landed regular countries (VERIFIED)

| Threshold (owned locations) | Countries | Who |
|---|---|---|
| >= 400 | 1 | CHI |
| >= 300 | 3 | + DLH, JAP |
| >= 200 | 4 | + CAS |
| >= 100 | 13 | + HUN NOV FRA MAM ENG SWE KOR NOR LIT (plus hordes GLH, CHG) |
| >= 75 | 19 | + MOR BYZ ARA KHM KIE POL |
| >= 60 | 26 | + YEM HAB POR NAP BUL SER |
| >= 50 | 29 | + DAI PRM (Perm) … |
| >= 25 | 73 | |
| < 5 | 1,074 | |

Consequences of the current 100-per-slot rule: in 1337-1437 every country has exactly 1 HQ (age slots 0) — good, the age gate neutralises size at start. In 1437 (Discovery) 15 countries jump to 2 HQs at once; a 3rd HQ in 1537 needs >= 200 locations (CHI, GLH, DLH, JAP, CAS only); 5 HQs in 1737 needs >= 400 (China only at start). Provinces do not change the picture: the locations-per-province ratio is similar everywhere (GLH 740/138 = 5.4, CHI 4.7, FRA 3.4, NOV 5.2).

## 5. Findings — where the formula feels wrong

**F1 (critical, VERIFIED): hordes are `country_type = army`.** `10_countries.txt:3995-3996` `GLH = { type = army own_control_core = { … 740 locations } }`; the same for all 28 landed hordes listed in §3. Vanilla treats army-type countries as a first-class type: advances `in_game/common/advances/ctype_army.txt:1-12` (`country_type = army` → `movement_speed_if_no_road = 0.10`), `cabinet_actions/settle_the_frontier.txt:4-9` (`num_locations > 0` + `country_type = location/army`), `advances/country_ILK.txt:41-43` (Ilkhanate reform `allow = { NOT = { country_type = army } }` = "settled"). Conquistador hosts are *also* army countries (`in_game/events/colonization/conquistador.txt:45-53`: `create_army_country_in_location = { reforms = { conquistador_country } … subject_type = subject_type:conquistador }`). `is_real_country` excludes only "Rebels, Pirates and Mercenaries" (`in_game/common/auto_modifiers/country.txt:11` comment `requires_real = no # Non-"real" countries are Rebels, Pirates and Mercenaries`), so hordes are real. **SPEC §5 `cw_is_real_country = { is_real_country = yes NOT = { country_type = army } }` would exempt the Golden Horde, Chagatai, Jalayirids, Gurgan, … from HQ limits, penalties and AI HQ assignment** — they would siege at full speed while everyone else is penalised. Fix (INFERRED composition, every part verified): `cw_is_real_country = { is_real_country = yes NOT = { is_subject_type = conquistador } }` (`is_subject_type = <key>` pattern VERIFIED 70× as `is_subject_type = colonial_nation`; subject type key `conquistador` from `conquistador.txt:52` and `in_game/common/subject_types/conquistador.txt`). Alternative: keep the army exemption but add back `government_type = government_type:steppe_horde` (VERIFIED syntax `scripted_triggers/disaster_triggers.txt:288`). Also note `TIM` (Timurids) exists in 1337 as a landless army-type block — a Timur that spawns later is a horde, not a conquistador host.

**F2 (VERIFIED data): locations ≠ strength on the steppe/taiga.** Novgorod (171 loc, 0.47 M pop, 4 urban), Sweden (131, 0.62 M), Norway (119, 0.37 M), Perm (64, 0.3 M), Golden Horde (740, 3.3 M, 9 urban) all score higher than Naples (65 loc, 2.3 M, 17 urban), Hoysala (47, 3.2 M), Khmer (82, 2.5 M), Yemen (69, 2.6 M), Majapahit (32, 2.6 M + 80 subject locations), Bohemia (45, 1.7 M), Đại Việt (53, 1.7 M), Vijayanagar (36, 2.4 M), Bengal sultanates (Saptagram 19 loc / 2.9 M, Sonargaon 19 / 2.7 M). Under the formula Novgorod/Sweden/Norway get a 2nd HQ in 1437 while Naples/Hoysala/Bohemia stay at 1 all game unless they pass 100 locations. France (163 loc, 5.4 M + 38 appanages/vassals with 170 locations) and England (138, 3.0 M + 59) get the same single size slot as Novgorod.

**F3 (VERIFIED thresholds): 100 per slot is steep for the design goal "big powers reach 5 in the last age".** Vanilla itself treats `num_locations > 120` as "strongest beylik" (`generic_actions/rise_of_the_ottomans.txt:111`, `situations/rise_of_the_ottomans.txt:412`), `>= 125` as too big for a reform (`government_reforms/country_specific.txt:889`), `>= 150` as a great ally (`events/DHE/flavor_pol.txt:3621`) and `> 500` as a huge empire (`situations/rise_of_the_ottomans.txt:29`). France needs +237 locations for 5 HQs; Castile +156 (its American land will sit in colonial subjects, not in `num_locations`). With 75 per slot: 19 countries have >= 1 slot at start (CAS 3, HUN/NOV/FRA 2), 5 HQs at 375. With 60: 26 countries, 5 HQs at 300.

**F4: rich compact states never leave 1 HQ.** Venice 14 loc (0.2 M), Milan 29 (0.9 M), Genoa 19, Florence 5, Papal State 20, Ottomans 23 (0.6 M), Muscovy 26 (0.3 M), Brandenburg 27, Denmark 40, Scotland 28. This matches the author's "small country = one army" rule, but late-game Venice/Milan/Netherlands/Prussia-type states field 30-60 regiments: with one HQ they are forced into a single doomstack, which contradicts "main army + auxiliaries". An army-size route (R3) fixes this without touching the location rule.

**F5 (VERIFIED trigger): subject land.** `num_locations_owned_or_owned_by_subjects` counts **direct** subjects only (loc `"Has or has direct subjects own $COMPARATOR$ $NUM|V0$ [locations|E]"`; used in `situations/italian_wars.txt:177` and `subject_types/hanseatic_member.txt:69`); `num_locations_owned_or_owned_by_subjects_or_below` exists for the whole tree (name in `trigger_localization/country_triggers.txt`, no vanilla usage found — UNVERIFIED). Start values: FRA 163 → 333, CHI 1668 → 2268, MAL 21 → 168 (13 vassals), MAJ 32 → 112, TUN 37 → 116, BOH 45 → 106, LIT 103 → 170, ENG 138 → 197, TIB 59 → 164, CHG 127 → 317, JAL 59 → 177, GRG 48 → 154. Counting subjects gives France 3 slots (feudal host feel) but double-counts: every subject is a real country with its own HQ and AI subjects already follow the overlord's war; it also inflates mandala/tusi empires (Mali, Majapahit, China, Tibet).

**F6 (INFERRED): no overseas holdings in 1337, and the colonial tiers will rarely fire for AI.** Cross-continent holdings at start: Egypt 75 of 143 locations in Asia (Levant/Hejaz; capital Africa), Golden Horde 242 in Asia, Jalayirids 16 in Europe (Caucasus), Byzantium 5 in Asia, Morocco 4 in Europe, Genoa 2 in Asia. By the game's definition (`game_concept_overseas_desc`: another continent whose sub-continent does not border the capital's continent by land or sea — research 10 §1.3) none of these is overseas, so `cw_colonial_hq_limit = 0` for everyone at start (and age < 3 anyway) — consistent with the spec. Later: the vanilla AI never keeps overseas charter land directly (research 10 §2.2) → `any_owned_location = { count >= 25 continent = continent:C is_overseas_for_owner = yes }` will be true mostly for human players; AI colonial empires reach the +1/+2 tiers only via their colonial subjects. Count subject land per continent for the tiers (INFERRED composition from verified parts: `any_subject = { is_colonial_subject = yes any_owned_location = { count >= 25 continent = continent:C } }`), or make the tiers depend on the "army of >= 3 regiments present" clause only.

**F7: native reform threshold.** SPEC §9 allows `cw_reform_war_host` at "owns >= 60 locations". The largest American country owns 23 (Cahokia), the richest 12 (Cocom, 0.9 M pop); 60 is unreachable without ~4× growth. Use 30 (or `num_of_non_rural >= 2`, VERIFIED trigger, comparisons `>= 2/3/5/10` are common in vanilla).

**F8: the giants.** China (1668 loc, 82.8 M pop, 95 subjects incl. Goryeo 126 and Tibet 59) and Delhi (369 loc, 39.7 M) max out any size rule; only the age cap (max 4 extra) limits them, which is fine — both are scripted to fragment (`situations/fall_of_delhi.txt`, Red Turban content). Golden Horde: 740 locations but 536 of them are `own_control_integrated` (low control), 3.3 M pop, 9 urban locations; it gets the same ceiling as China.

## 6. Triggers / values that exist for alternative formulas (all names VERIFIED in `in_game/common/trigger_localization/country_triggers.txt`; loc strings from `main_menu/localization/english/*.yml`)

| Key | Meaning (loc string) | Vanilla usage (file:line) |
|---|---|---|
| `num_locations` | "Has N locations" | value: `auto_modifiers/country.txt:333`; `> 120` `generic_actions/rise_of_the_ottomans.txt:111`; `> 500` `situations/rise_of_the_ottomans.txt:29` |
| `num_locations_owned_or_owned_by_subjects` | "Has or has direct subjects own N locations" | `situations/italian_wars.txt:177`, `subject_types/hanseatic_member.txt:69` |
| `num_locations_owned_or_owned_by_subjects_or_below` | whole subject tree | name only (`country_triggers.txt`), no vanilla usage — UNVERIFIED |
| `num_provinces` | "Has N provinces" | `disasters/succession_crisis.txt:9` (`> 2`) |
| `num_location_rank:<rank>` | "Has N <rank>" | `events/DHE/flavor_ENG.txt:14583` (`num_location_rank:city > 5`), `events/random_event.txt:1305` (`:town > 1`) |
| `num_of_non_rural` | non-rural locations | `advances/0_age_of_discovery.txt:587` (`multiply = num_of_non_rural`), `auto_modifiers/country.txt:473` (`scales_with`) |
| `country_tax_base` (not `total_tax_base`) | tax base | value: `ai_scripted_expansion_target/attack_neighbors.txt:41`; `> 500` `events/DHE/flavor_HAB.txt:8084`, `flavor_vij.txt:315`. Also `country_potential_tax_base`, `estate_tax_base` (names). |
| `total_population`, `total_control_scaled_population` | "Has a total population of N" | `auto_modifiers/country.txt:1011` (`scales_with = total_population`); `generic_actions/italian_wars.txt:359` |
| `total_development` | "Has N total development" | `events/wokou_events.txt:249` |
| `army_size` | "Has N men in the Army" (regulars + levies) | value: `generic_actions/ilkhanate_actions.txt:83`; `> 0` `country_interactions/lend_unit_to_ally.txt:6` |
| `regular_army_size` | "Has N @army_strength regulars when fully reinforced" (1 = one regiment of `REGIMENT_SIZE = 1000`, `loading_screen/common/defines/00_defines.txt:381`) | value: `cabinet_actions/D008_cabinet_actions.txt:94`; `>= 10` `decisions/flavor_decisions_byz.txt:20` |
| `expected_army_size` | "Has N men expected to be in the Army" (what the estates expect) | `estates/00_default.txt:176`; thresholds `< 10`, `> 10 … < 20`, `> 20` `parliament_issues/03_nobles_estate_parliament_issues.txt:1274-1289` |
| `army_size_percentage` | army / expected | `auto_modifiers/country.txt:1113` (`> 1.0`) |
| `potential_army_size` | field strength + unraised levies | `generic_actions/conquistadors.txt:78` |
| `country_total_army_levy_size` | "Has N levies in the Army" | `situations/fall_of_delhi.txt:143` (`order_by`) |
| `num_regiments`, `total_sub_unit_count`, `total_sub_unit_strength` | regiment counts | `resolutions/nanbokuchou_resolution.txt:19`; `hegemons/1_naval_hegemon.txt:5` |
| `military_strength`, `country_strength`, `great_power_ranking`, `country_rank_level` | composite strength / rank | `country_interactions/hre.txt:1793`; `decisions/generic_age_decisions.txt:494` (`> 20`); `building_types/capital_buildings.txt:162` |

How `expected_army_size` is built (VERIFIED): `auto_modifiers/country.txt:1010-1020` — `country_population = { scales_with = total_population expected_army_size = 0.0001 }` and `country_accepted_culture_population = { scales_with = total_accepted_culture_population expected_army_size = 0.002 }`; each age adds `expected_army_size_modifier` +1.0 / +2.0 / +4.0 / +8.0 / +16.0 (`age/00_default.txt:68,129,190,258,337`), i.e. ×2, ×3, ×5, ×9, ×17 from Renaissance on. Units are INFERRED: with populations in thousands, France ≈ 5,401 × 0.0021 ≈ 11 → consistent with the vanilla 10/20 thresholds → **expected_army_size is in regiment-equivalents (1,000 men), ≈ 2.1 per million pop in the first age**: China ≈ 174, Delhi ≈ 83, Japan ≈ 21, Egypt ≈ 14, France ≈ 11, Castile ≈ 10, Hungary ≈ 7, Golden Horde ≈ 7, England ≈ 6, Novgorod ≈ 1, Venice ≈ 0.4. Any formula using it must divide by the age multiplier or it will explode by Absolutism (×9).

## 7. Candidate size rules on the 1337 data and recommendation

A = ⌊Loc/100⌋ (current), B = ⌊Loc/60⌋, C = ⌊(Loc + direct subject Loc)/100⌋, D = ⌊Urban/10⌋ (`num_location_rank:town + :city + :megalopolis`), E = ⌊Pop M / 2⌋ (≈ ⌊expected regiments / 4⌋, population route), P = ⌊Prov/20⌋, H = max(A, E), G = min(B, ⌊Pop M × 1.5⌋) ("big **and** populous").

| Tag | Name | Loc | Pop M | Urban | Prov | A | B | C | D | E | P | H | G |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| CHI | China | 1668 | 82.8 | 261 | 353 | 16 | 27 | 22 | 26 | 41 | 17 | 41 | 27 |
| GLH | Jochi | 740 | 3.3 | 9 | 138 | 7 | 12 | 9 | 0 | 1 | 6 | 7 | 4 |
| DLH | Delhi | 369 | 39.7 | 29 | 64 | 3 | 6 | 4 | 2 | 19 | 3 | 19 | 6 |
| JAP | Japan | 339 | 9.8 | 7 | 65 | 3 | 5 | 3 | 0 | 4 | 3 | 4 | 5 |
| CAS | Castile | 244 | 5.0 | 22 | 45 | 2 | 4 | 2 | 2 | 2 | 2 | 2 | 4 |
| HUN | Hungary | 189 | 3.5 | 14 | 38 | 1 | 3 | 2 | 1 | 1 | 1 | 1 | 3 |
| NOV | Velikiy Novgorod | 171 | 0.5 | 4 | 33 | 1 | 2 | 1 | 0 | 0 | 1 | 1 | 0 |
| FRA | France | 163 | 5.4 | 29 | 48 | 1 | 2 | 3 | 2 | 2 | 2 | 2 | 2 |
| MAM | Egypt | 143 | 6.5 | 11 | 30 | 1 | 2 | 2 | 1 | 3 | 1 | 3 | 2 |
| ENG | England | 138 | 3.0 | 13 | 39 | 1 | 2 | 1 | 1 | 1 | 1 | 1 | 2 |
| SWE | Sweden | 131 | 0.6 | 8 | 23 | 1 | 2 | 1 | 0 | 0 | 1 | 1 | 0 |
| CHG | Chagatai | 127 | 1.4 | 3 | 21 | 1 | 2 | 3 | 0 | 0 | 1 | 1 | 2 |
| KOR | Goryeo | 126 | 2.4 | 8 | 24 | 1 | 2 | 1 | 0 | 1 | 1 | 1 | 2 |
| NOR | Norway | 119 | 0.4 | 6 | 20 | 1 | 1 | 1 | 0 | 0 | 1 | 1 | 0 |
| LIT | Lithuania | 103 | 0.9 | 5 | 23 | 1 | 1 | 1 | 0 | 0 | 1 | 1 | 1 |
| MOR | Morocco | 90 | 1.9 | 9 | 17 | 0 | 1 | 1 | 0 | 0 | 0 | 0 | 1 |
| BYZ | Byzantium | 87 | 1.2 | 7 | 25 | 0 | 1 | 0 | 0 | 0 | 1 | 0 | 1 |
| ARA | Aragon | 85 | 1.3 | 18 | 19 | 0 | 1 | 0 | 1 | 0 | 0 | 0 | 1 |
| KHM | Khmer | 82 | 2.5 | 4 | 18 | 0 | 1 | 0 | 0 | 1 | 0 | 1 | 1 |
| POL | Poland | 75 | 1.0 | 2 | 19 | 0 | 1 | 1 | 0 | 0 | 0 | 0 | 1 |
| HAB | Austria | 68 | 1.4 | 5 | 24 | 0 | 1 | 0 | 0 | 0 | 1 | 0 | 1 |
| POR | Portugal | 67 | 1.2 | 7 | 10 | 0 | 1 | 0 | 0 | 0 | 0 | 0 | 1 |
| NAP | Naples | 65 | 2.3 | 17 | 12 | 0 | 1 | 0 | 1 | 1 | 0 | 1 | 1 |
| HSL | Hoysala | 47 | 3.2 | 4 | 8 | 0 | 0 | 0 | 0 | 1 | 0 | 1 | 0 |
| BOH | Bohemia | 45 | 1.7 | 4 | 11 | 0 | 0 | 1 | 0 | 0 | 0 | 0 | 0 |
| DAI | Đại Việt | 53 | 1.7 | 1 | 13 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| YEM | Yemen | 69 | 2.6 | 2 | 13 | 0 | 1 | 0 | 0 | 1 | 0 | 1 | 1 |
| MAJ | Majapahit | 32 | 2.6 | 4 | 5 | 0 | 0 | 1 | 0 | 1 | 0 | 1 | 0 |
| TUN | Tunis | 37 | 0.8 | 3 | 8 | 0 | 0 | 1 | 0 | 0 | 0 | 0 | 0 |
| DAN | Denmark | 40 | 0.6 | 7 | 10 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| MLO | Milan | 29 | 0.9 | 8 | 8 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| BRA | Brandenburg | 27 | 0.4 | 2 | 8 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| MOS | Muscovy | 26 | 0.3 | 1 | 5 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| TUR | Ottomans | 23 | 0.6 | 3 | 7 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| VEN | Venice | 14 | 0.2 | 2 | 9 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| GEN | Genoa | 19 | 0.5 | 2 | 7 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |

Reading the table: the location rules (A/B/P) reward the steppe/taiga (GLH, NOV, SWE, NOR, CHG); the population/urban rules (D/E) reward India, Italy and Egypt and starve the north; the subject rule (C) mostly helps France, Chagatai, Majapahit, Mali, Bohemia and Tunis. Only a combination keeps "France ≈ Castile ≈ Egypt > Novgorod ≈ Sweden" while bounding the Horde. Note that in 1337-1437 none of this matters (age slots 0): the rules first bite in 1437.

### Recommendations

- **R1 (must, F1):** replace `NOT = { country_type = army }` in `cw_is_real_country` with `NOT = { is_subject_type = conquistador }` (or re-include `government_type = government_type:steppe_horde`). Add a test: in 1337 the Golden Horde must show `cw_hq_limit = 1` and get `cw_no_hq` on its non-HQ stacks.
- **R2 (tuning, F3):** 100 per slot only if the intended 5-HQ club is China/Russia/Ottomans/Mughal-tier; for "France/Austria/Spain reach 5 by Revolutions" use **75** (`cw_size_hq_slots: value = num_locations divide = 75 floor = yes`; `floor = yes` VERIFIED `script_values/religious_order_values.txt:31`). 60 is the generous variant (26 countries with a slot at start).
- **R3 (recommended, F2/F4):** add an army route so rich compact states and big standing armies earn HQs: `cw_size_hq_slots = max(floor(num_locations / 75), floor(regular_army_size / 20))` — written as `value = num_locations divide = 75 floor = yes` then `max = { value = regular_army_size divide = 20 floor = yes }` (`max =` inside script values is the pattern SPEC §3 already uses). Use `regular_army_size` (fully-reinforced regulars, excludes levies and mercenaries), not `army_size` (levies swing in war) and not `expected_army_size` (×17 by Revolutions). 20 regiments per extra HQ = "an officer corps per 20,000 men". Because regiments die, re-evaluate only on the quarterly peace pulse / `on_new_age` or keep a high-water mark variable, so `cw_cleanup_excess_hqs` does not strip HQs mid-war; the vanilla `limit` itself only blocks new recruitment.
- **R4 (F5):** do not count subject land for the home limit (double counting; subjects get their own HQ). If the feudal-host feel is wanted, half weight: `value = num_locations_owned_or_owned_by_subjects subtract = num_locations multiply = 0.5 add = num_locations` (direct subjects only; France 163 → 248 → 3 slots at 75).
- **R5 (optional, F2):** to stop sparse giants from out-scaling populous states, cap the location slots by population: `min = { value = total_population divide = 1500000 floor = yes }` → the "G" column (GLH 4, NOV/SWE/NOR 0, HUN 3, FRA 2). The population unit (people vs. thousands) is UNVERIFIED — print `total_population` in a custom tooltip in game before fixing the divisor.
- **R6 (F6):** colonial tiers: count locations owned by colonial subjects on the continent (or keep the tiers but expect them to trigger only for human players) and keep the "3-regiment army present" clause as the AI's main source of colonial slots.
- **R7 (F7):** `cw_reform_war_host` threshold 60 → 30 owned locations, or `num_of_non_rural >= 2`.
- **R8:** 15 countries get their 2nd HQ simultaneously on 1437.1.1; `cw_events.1` will fire for every human player that day — acceptable, but the loc text should say "the Age of Discovery opened a slot".

## 8. Test checklist for the in-game pass

1. Debug tooltip on FRA, GLH, VEN, NOV: `num_locations`, `num_locations_owned_or_owned_by_subjects`, `regular_army_size`, `expected_army_size`, `total_population`, `num_of_non_rural` (confirms units; expected: FRA 163 / 333 / ? / ≈11 / ≈5.4 M / 29).
2. Golden Horde has `cw_hq_limit = 1` and is not exempt (F1).
3. Console `age` forward to 1437/1537/1737 and re-read `cw_hq_limit` for CHI, DLH, CAS, FRA, VEN.
4. Spawn a conquistador host (Castile, age 3) and confirm it is exempt.
