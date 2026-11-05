# New Intelligence: Geopolicy — как это устроено (v0.1, 2026-11-04)

Технические заметки к `mods/new_intelligence_geopolicy` (префикс `gp_`). Дизайн — в `docs/GEOPOLICY_DESIGN.md`. Мод **в игре ещё не запускался**: первый запуск и `error.log` решают, какие из допущений ниже верны.

## 1. Файлы

| Файл | Что делает |
|---|---|
| `in_game/common/on_action/gp_on_actions.txt` | хуки: `on_game_started_after_lobby` (разовая настройка всех стран), `yearly_country_pulse` (годовой проход), `on_new_country_formed` / `on_released_country` (новая страна получает профиль) |
| `in_game/common/scripted_effects/gp_effects.txt` | ядро: доля домашнего региона, угроза, пришельцы, общий фронт, темперамент, стадии, роли |
| `in_game/common/scripted_effects/gp_zone_effects.txt` | профили зон по тегу (`switch = { trigger = tag }`), три стадии, групповые сферы |
| `in_game/common/scripted_effects/gp_relations_effects.txt` | v0.2: история до 1337 (давняя вражда и дружба, стартовые намерения), память войн, симпатии и неприязни правителя с 10 лет, чужеземный сюзерен, колониальная зона, страсти региона (годы мира, смутное время) |
| `in_game/common/scripted_effects/gp_region_effects.txt` | v0.3: ведущие державы регионов и покровители (старт), ведущая / безнадёжная страна (год), менталитет ИИ по состоянию, право на остаток региона (90 %), удержание земель (модификаторы локаций) |
| `in_game/common/area_preferences/gp_zones.txt` | сами зоны: ~70 профилей × ядро / сфера / дальняя, общий `gp_generic_home_region`, `gp_anatolia_sphere`, `gp_persia_sphere` |
| `in_game/common/scripted_triggers/gp_triggers.txt` | `gp_is_real_country`, правила игры, темпераменты, кандидат в угрозы, пришелец (`gp_is_intruder_of = { COUNTRY = … }`), общая угроза |
| `in_game/common/script_values/gp_values.txt` | ручки (пороги) и `gp_region_share_value` |
| ~~`main_menu/common/static_modifiers/gp_country_modifiers.txt`~~ | удалён 2026-11-04 по правилу автора «никаких бафов»: роли — переменные `gp_role_*`, темпераменты читаются на лету, их поведение — в `gp_expansion_scores.txt` |
| `in_game/common/biases/gp_opinions.txt` | 3 модификатора мнения (угроза −40, пришелец −30, общий враг +20; `months = 14`) |
| `in_game/common/ai_scripted_expansion_score/gp_expansion_scores.txt` | всё влияние мода на выбор цели войны: дисциплина зон, общий фронт, сдерживание, пришелец, святое сдерживание; роли (собиратель, региональная, пауза гегемона и империи, сдержанность гегемона, статус-кво, осаждённые); темпераменты (степь, Китай/Япония/Корея, Индия, ислам) |
| `in_game/common/ai_scripted_expansion_target/gp_expansion_targets.txt` | 3 списка целей: сдержать угрозу (с CB мода), выгнать пришельца, домашний регион за границей |
| `in_game/common/scripted_diplomatic_objectives/gp_objectives.txt` | 4 цели: общий фронт (союз), поиск защитника, сфера влияния (`influence_nation`), антагонизм к пришельцу |
| `in_game/common/casus_belli/gp_casus_belli.txt` | `gp_cb_contain_threat` (superiority, `cut_down_in_size_cb`) |
| `in_game/common/formable_countries/gp_formables.txt` | 11 новых формируемых стран (теги GAE AMC AGV WND BGD ILY DAC GVO NVR JRS KHO) |
| `main_menu/common/coat_of_arms/coat_of_arms/gp_formable_coa.txt`, `named_colors/gp_colors.txt` | гербы и цвета новых тегов |
| `main_menu/common/game_rules/gp_game_rules.txt` | правило «Геополитика ИИ» (standard / strong / off); правила с блоком `defines = {}` нет — парсер 1.4.7 его отвергает (первый запуск Battle) |
| `loading_screen/common/defines/gp_defines.txt` | 16 ключей `NAI` + 6 ключей `NDiplomacy`, действуют всегда |
| `in_game/common/decisions/gp_decisions.txt`, `main_menu/common/game_concepts/gp_concepts.txt` | решение «Геополитический обзор», понятия «Геополитика» и «Угроза региону» |
| `in_game/gui/gp_disposition_tooltip.gui`, `in_game/common/customizable_localization/gp_brief.txt` | блок «Геополитика» в подсказке «Настрой державы»: состояние, роль, обстановка, угроза, цель подготовки |
| `main_menu/common/static_modifiers/gp_terrain_modifiers.txt` | природные рубежи: модификаторы локаций для гор, холмов, открытой степи (правило игры) |
| `main_menu/localization/{english,russian}/gp_geopolicy_l_*.yml` | все ключи RU/EN |

## 2. Годовой проход (`gp_yearly_update`, страна сохраняется как `scope:gp_c`)

1. `gp_compute_region_share` — обход `capital.region = { every_ownable_location_in_region }`, счёт в двух временных переменных, результат `var:gp_region_share` (0…1).
2. `gp_update_threat` — снять прошлогоднее мнение и переменные; `save_scope_as = gp_self`; `capital.region = { ordered_present_country = { limit = { gp_is_threat_candidate } order_by = country_strength max = 1 } }`, запасной вариант `ordered_neighbor_country`; результат `var:gp_threat`, `var:gp_threat_ratio`, мнение `gp_opinion_regional_threat`; `clear_saved_scope`.
3. `gp_update_intruders` — `every_present_country` региона с `gp_is_intruder` → мнение `gp_opinion_foreign_intruder` (remove + add).
4. `gp_update_common_front` — те же, у кого `var:gp_threat` совпадает с нашим и та же религиозная группа → `gp_opinion_common_enemy`.
5. Если правило не «off»: `gp_update_role` (осаждённая → империя → гегемон → региональная → статус-кво → собиратель; переменная `gp_role_*`), только ИИ — `gp_update_stage_zones` (сфера при доле ≥ 0.25, дальняя при ≥ 0.55; иначе снять). При «off» роли стираются.
6. `gp_debug_report` — временный отчёт `GP_REPORT` в `debug.log` (18 стран).

Модификаторов страны нет. Видимые следы мода у страны — только мнения («Угрожает нашему региону», «Иноземная сила в нашем регионе», «Общая угроза региону»), обычный ванильный механизм отношений. В цикле старта партии `root` — не страна (первый запуск 2026-11-04), поэтому весь проход работает через `scope:gp_c`.

## 3. Реестр «GP TODO verify» (что проверить первым запуском)

| # | Допущение | Где | Тест |
|---|---|---|---|
| 1 | VERIFIED 2026-11-04 (см. п. 16): `switch = { trigger = tag  ENG = { … } }` принимает голые теги | `gp_zone_effects.txt` | — |
| 2 | Семантика `modifier` area_preferences: складывается с ванильными, не ломает порядок ядро > сфера > дальняя | `gp_zones.txt` | наблюдатель 1337→1400: Бранденбург / Венгрия / османы берут сначала области ядра |
| 3 | `ordered_present_country` работает на `capital.region` из эффекта; `save_scope_as` внутри него | `gp_update_threat` | тест 2 |
| 4 | FOUND 2026-11-04 (первый запуск): угроза не нашлась ни у одной страны за 4 года — `relative_strength` это доля 0…1, а не отношение сил (ванильный комментарий «#this is 0..1»); пороги переведены в доли (1.5× = 0.6, 2× = 0.67, 2.5× = 0.71, 3× = 0.75), переменная `gp_threat_share` | `gp_triggers.txt`, оценки, цели | тест 2: в отчёте у Шотландии / Сербии / Новгорода «threat found» |
| 5 | `religion.group = root.religion.group` (сравнение двух стран) | триггеры, оценки, цели | в `error.log` нет ошибок про `religion.group`; мнение «Общая угроза региону» появляется между единоверцами |
| 6 | `var:gp_threat ?= root.var:gp_threat` (сравнение переменных-стран) | `gp_shares_threat_with` | то же |
| 7 | `set_variable = { value = "scope:x.relative_strength(root)" }` — функция в значении переменной | `gp_update_threat` | роль «осаждённая» появляется у малых соседей гигантов (Новгород при сильной Литве / Орде) |
| 8 | Ежегодные мнения не копятся (remove + add одной и той же метки) | `gp_effects.txt` | через 5 лет мнение об угрозе всё ещё −40, а не −200 |
| 9 | `multiplier = { add = -0.4 }` в expansion_score трактуется как ×0.6 | `gp_expansion_scores.txt` | подсказка планирования войны ИИ (`-debug_mode`) показывает множитель |
| 10 | RESOLVED до запуска: `defines = { }` внутри правила игры отвергается парсером 1.4.7 («Unexpected token: defines», первый запуск Battle 2026-11-04) — правило «Defines геополитики» удалено, переопределения действуют всегда | `gp_game_rules.txt`, `gp_defines.txt` | — |
| 11 | `capital.area = area:east_novgorod_area` в `allow` формируемой страны | `gp_novgorod_rus_f` | Новгород видит кнопку формирования со своей столицей |
| 12 | Производительность: годовой обход локаций регионов и `every_present_country` для ~900 стран | `gp_yearly_update` | `performance_degradation.log`: нет скачка в январе каждого года более ~0.2 с |
| 13 | `clear_saved_scope` без существующего scope не пишет в `error.log` | `gp_update_threat` | grep `clear_saved_scope` в `error.log` |
| 14 | `influence_nation` принимается в `country_interactions` цели | `gp_obj_sphere_minor` | нет ошибки загрузки цели |
| 15 | FOUND 2026-11-04: `debug_log` пишет в `debug.log` (318 строк за 4 года), но локализация в нём не видит сохранённых scope (`[SCOPE.sCountry(…)]` → «TOOLTIP:COUNTRY,4294967295») — отчёт переделан на буквальные теги и интервалы; `[ROOT…]` в `debug_log` тоже не работает («Promote ROOT returned nullptr», второй тест), строка проверки убрана | `gp_debug_report` | тест 2 |
| 16 | VERIFIED 2026-11-04: `switch = { trigger = tag … }` работает (у всех 18 стран отчёта «zone profile historical»); доля региона считается (с 1338 г. появляются гегемоны и империи); в `error.log` 0 строк `gp_` | — | — |
| 17 | FOUND 2026-11-04: в цикле `every_country` внутри `on_game_started_after_lobby` `root` — не страна; ядро переписано на `scope:gp_c` | `gp_effects.txt` | тест 2: строки отчёта за старт партии совпадают по смыслу с январскими |
| 18 | Переопределение шаблона `AiDisposition_tooltip` своим файлом подхватывается (шаблоны переопределяются по имени, побеждает последний загруженный); блок `extra_tooltip_content` виден и в режиме карты «Настрой державы» | `in_game/gui/gp_disposition_tooltip.gui` | навести на ИИ-страну в режиме карты: под «Целями» блок «Геополитика» |
| 19 | `[Country.Custom('gp_brief_posture')]` работает в GUI-контексте (в ванили — `[ROOT.GetCountry.Custom(...)]`) | `GP_BRIEF_MAIN`, `customizable_localization/gp_brief.txt` | в блоке текст «Состояние: …», а не ключ |
| 20 | `Country.MakeScope.GetVariable('gp_threat').IsSet` и `.GetCountry.GetNameWithNoTooltip` в GUI | `gp_disposition_tooltip.gui`, `GP_BRIEF_THREAT` | строка «Главная угроза региону: X» с именем страны |
| 21 | Выбор состояния: `set_variable = { value = gp_ps_* }`, сравнение `var:a < var:b` (ванильный приём `compare_and_get_highest_variable_from_4`), `random_list` с равными весами | `gp_choose_posture` | в отчёте строки `posture …` у разных стран разные и меняются со временем |
| 22 | `set_variable = { value = capital.region }` и сравнение `capital.region = var:gp_region_cached` (ваниль: `value = scope:capital.region`, `root.region = var:high_kingship_region`) | `gp_compute_region_share` | доля региона в отчёте та же, что раньше (гегемоны и империи на месте) |
| 23 | `"estate_power(estate_type:crown_estate)"` и другие сословия в значениях | `gp_values.txt` | нет ошибок про `estate_power` в `error.log` |
| 24 | `on_ending_war`: `scope:loser ?= root` для стороны-проигравшего; `on_new_ruler` для пересмотра курса | `gp_on_war_end_effect`, `gp_on_new_ruler_effect` | после проигранной войны в отчёте «lost a war recently» и «posture recovery» |
| 25 | `cb_make_tributary` в списке целей орды | `gp_target_horde_tribute` | Золотая Орда объявляет войны с поводом дани соседям вне степи |
| 26 | `add_location_modifier = { days = -1 }` — бессрочно; `every_location_in_continent` по пяти континентам при старте | `gp_apply_terrain` | у горной локации с крепостью в подсказке «Горная твердыня», оборона крепости +100 % |
| 27 | `spy_network_target` и `antagonise` в цели без `destroy` | `gp_obj_prepare_target` | нет ошибки загрузки цели |
| 28 | `on_ending_war`: `scope:war = { any_attacker / every_attacker / every_defender }` после окончания войны (ваниль `d009_golden_century.txt`), `reverse_add_opinion` с накоплением `gp_opinion_old_enemy` (min −90) | `gp_war_memory` | после войны в отношениях обеих сторон «Старый враг: память о наших войнах», после второй войны — вдвое сильнее |
| 29 | Персонаж: `set_variable = { name = gp_dislike value = scope:… }`, `every_child`, `age_in_years`, `heir ?=`; страна в переменной персонажа читается после смерти/смены страны | `gp_form_character`, `gp_update_ruler_affinity` | в отчёте строки «ruler dislikes a country» / «ruler likes a country»; в подсказке «Правитель недолюбливает X» |
| 30 | `add_opinion = { … scale = gp_age_scale }` (ваниль: `reverse_add_opinion` со `scale`), `current_age = age_N_…` в script value | `gp_update_foreign_overlord` | у вассала чужой культурной группы «Чужеземный сюзерен» −8 в первую эпоху, −16 во вторую |
| 31 | `navy_size > scope:attacker.navy_size` в `multiplier` оценки цели (ваниль `flavor_dan.txt`: `navy_size >= root.navy_size`) | `gp_score_naval_balance_*` | подсказка цели войны Франции против Англии: «За морем: всё решает флот» |
| 32 | `is_great_power`, `country_rank_level` в `target_trigger` | `gp_score_status_quo_peers` | у двух равных королевств без войн — строка «Статус-кво между равными державами» |
| 33 | Повод `gp_cb_establish_dominion` с `war_goal_type = take_capital_subjugation` и `create_visible` только для ИИ; `casus_belli = casus_belli:…` в списке целей | `gp_casus_belli.txt`, `gp_target_outer_dominion` | ИИ-война «Установить господство» заканчивается вассалитетом, а не аннексией |
| 34 | `defensive_support = yes` в дипломатической цели (readme) | `gp_obj_sphere_minor` | гегемон вступается за малого клиента своего региона |
| 35 | `has_area_preference` / `add_area_preference` / `remove_area_preference` для колоний (ваниль `hidden_events_for_ai_conquest.txt`) | `gp_ensure_colonial_profile` | у колониальной нации зона «Освоить свой колониальный регион» |
| 36 | Новые ключи `NAI` (подданные в мире, доля союзникам, крепости на границе, обращение, колонии, города) принимаются парсером | `gp_defines.txt` | нет ошибок про defines в `error.log` |
| 37 | `set_personality = ai_personality:…` из скрипта (ваниль `ai_personalities_setup.txt`) переживает год и не сбрасывается правилом «личности по правителю» | `gp_apply_personality` | в «Менталитете державы» ИИ-стран — Оборона / Экспансионизм / Агрессия по их состоянию, «Разносторонности» почти нет |
| 38 | `country_strength > scope:gp_c.country_strength` внутри `any_present_country` региона | `gp_update_contender` | в отчёте `GP_REPORT … contender of the region` у сильнейших стран регионов без исторических лидеров |
| 39 | `any_neighbor_location = { count >= 3 owner ?= … }`, `has_location_modifier`, `remove_location_modifier`, `sub_continent` локации, `dominant_culture ?= { has_shared_culture_group }`, `dominant_religion ?=` | `gp_control_location` | у анклава модификатор «Отрезанное владение», у земли в другом регионе — «Вдали от сердца державы»; нет ошибок в `error.log` |
| 40 | Производительность: ежегодный обход всех локаций страны с проверкой соседей (около 20 тыс. локаций в мире) | `gp_update_control` | январские рывки в `performance_degradation.log` не больше прежних; иначе — правило «Удержание земель» выключить |
| 41 | Повод `gp_cb_regional_unification`: `speed = 50`, `war_goal_type = superiority`, `casus_belli = casus_belli:…` в списке целей | `gp_casus_belli.txt`, `gp_target_regional_unification` | в регионе в напряжении ведущие державы воюют между собой с этим поводом |
| 42 | `current_date < 1600.1.1` в триггере (ваниль: `current_date > 1346.10.1`) | `gp_is_before_1600`, `gp_control_location` | после 1600 года строки оценки «За пределами нашего региона» исчезают |

## 4. Производительность

- Ни одного ежемесячного цикла по странам. Годовой проход: ~900 настоящих стран; обход локаций региона столицы (крупные регионы ~500 локаций) и список стран, присутствующих в регионе (в раздробленной Германии ~100). Оценка: < 1 с реального времени в год на среднем ПК (проверить п. 12).
- Дипломатические цели: `days_between_checks = 365`, без `recipient_list_builder` (фильтр `recipient_trigger` по всем достижимым странам).
- Оценки целей расширения считаются движком только для `AI_NUM_EXPANSION_TARGETS = 20` кандидатов.

## 5. Совместимость

- Не заменяет ни одного ванильного файла; все вклады — свои файлы с префиксом `gp_`. Под ванильными ключами `on_action` — только `on_actions = { gp_x }` (слияние одноимённых on_action).
- С Battle (`cw_`) ключи не пересекаются; оба мода вешают разные страновые модификаторы с `ai = yes`, они складываются.
- Новые теги не объявлены в `setup/countries` (как ванильные NSE / CEL / HEN): цвет и имя приходят из формируемой страны, герб — по ключу тега.
- При патче: пересверить номера строк и ванильные значения в `gp_defines.txt`; `bash tools/validate.sh new_intelligence_geopolicy` и `bash tools/check_geopolicy_refs.sh`.
- Урок первого запуска Battle, учтённый здесь: на стадии `main_menu` неизвестны внутриигровые триггеры (`current_age_or_later`) — все файлы мода в `main_menu/` (правила, модификаторы, понятия, цвета, гербы) триггеров не содержат.

## 6. Что сознательно не сделано в v0.1

- Нет интерфейса, кроме решения-отчёта и понятий; переменные (доля, угроза) в подсказках не выводятся (синтаксис показа переменных в loc не подтверждён).
- Нет ванильных `rival_criteria` для мажоров (только теги; угроза уже влияет на мнение и цели).
- Личности ИИ (`ai_personalities`) не переопределяются — роли складываются с ними.
- Колониальные зоны оставлены ванильным предпочтениям (`castile_conquer_new_world`, exploration_preferences).
