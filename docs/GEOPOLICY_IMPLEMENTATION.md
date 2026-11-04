# New Intelligence: Geopolicy — как это устроено (v0.1, 2026-11-04)

Технические заметки к `mods/new_intelligence_geopolicy` (префикс `gp_`). Дизайн — в `docs/GEOPOLICY_DESIGN.md`. Мод **в игре ещё не запускался**: первый запуск и `error.log` решают, какие из допущений ниже верны.

## 1. Файлы

| Файл | Что делает |
|---|---|
| `in_game/common/on_action/gp_on_actions.txt` | хуки: `on_game_started_after_lobby` (разовая настройка всех стран), `yearly_country_pulse` (годовой проход), `on_new_country_formed` / `on_released_country` (новая страна получает профиль) |
| `in_game/common/scripted_effects/gp_effects.txt` | ядро: доля домашнего региона, угроза, пришельцы, общий фронт, темперамент, стадии, роли |
| `in_game/common/scripted_effects/gp_zone_effects.txt` | профили зон по тегу (`switch = { trigger = tag }`), три стадии, групповые сферы |
| `in_game/common/area_preferences/gp_zones.txt` | сами зоны: ~70 профилей × ядро / сфера / дальняя, общий `gp_generic_home_region`, `gp_anatolia_sphere`, `gp_persia_sphere` |
| `in_game/common/scripted_triggers/gp_triggers.txt` | `gp_is_real_country`, правила игры, темпераменты, кандидат в угрозы, пришелец (`gp_is_intruder_of = { COUNTRY = … }`), общая угроза |
| `in_game/common/script_values/gp_values.txt` | ручки (пороги) и `gp_region_share_value` |
| `main_menu/common/static_modifiers/gp_country_modifiers.txt` | 6 ролей + `gp_strong_tempo` + 6 темпераментов (только `ai = yes` типы) |
| `in_game/common/biases/gp_opinions.txt` | 3 модификатора мнения (угроза −40, пришелец −30, общий враг +20; `months = 14`) |
| `in_game/common/ai_scripted_expansion_score/gp_expansion_scores.txt` | 9 правок оценки целей войны (дисциплина зон, общий фронт, сдерживание, пришелец, святое сдерживание, гегемон, изоляционисты, статус-кво, осаждённые) |
| `in_game/common/ai_scripted_expansion_target/gp_expansion_targets.txt` | 3 списка целей: сдержать угрозу (с CB мода), выгнать пришельца, домашний регион за границей |
| `in_game/common/scripted_diplomatic_objectives/gp_objectives.txt` | 4 цели: общий фронт (союз), поиск защитника, сфера влияния (`influence_nation`), антагонизм к пришельцу |
| `in_game/common/casus_belli/gp_casus_belli.txt` | `gp_cb_contain_threat` (superiority, `cut_down_in_size_cb`) |
| `in_game/common/formable_countries/gp_formables.txt` | 11 новых формируемых стран (теги GAE AMC AGV WND BGD ILY DAC GVO NVR JRS KHO) |
| `main_menu/common/coat_of_arms/coat_of_arms/gp_formable_coa.txt`, `named_colors/gp_colors.txt` | гербы и цвета новых тегов |
| `main_menu/common/game_rules/gp_game_rules.txt` | правила «Геополитика ИИ» (standard / strong / off) и «Defines геополитики» (on / vanilla) |
| `loading_screen/common/defines/gp_defines.txt` | 16 ключей `NAI` + 6 ключей `NDiplomacy` |
| `in_game/common/decisions/gp_decisions.txt`, `main_menu/common/game_concepts/gp_concepts.txt` | решение «Геополитический обзор», понятия «Геополитика» и «Угроза региону» |
| `main_menu/localization/{english,russian}/gp_geopolicy_l_*.yml` | все ключи RU/EN |

## 2. Годовой проход (`gp_yearly_update`, root = страна)

1. `gp_compute_region_share` — обход `capital.region = { every_ownable_location_in_region }`, счёт в двух временных переменных, результат `var:gp_region_share` (0…1).
2. `gp_update_threat` — снять прошлогоднее мнение и переменные; `save_scope_as = gp_self`; `capital.region = { ordered_present_country = { limit = { gp_is_threat_candidate } order_by = country_strength max = 1 } }`, запасной вариант `ordered_neighbor_country`; результат `var:gp_threat`, `var:gp_threat_ratio`, мнение `gp_opinion_regional_threat`; `clear_saved_scope`.
3. `gp_update_intruders` — `every_present_country` региона с `gp_is_intruder` → мнение `gp_opinion_foreign_intruder` (remove + add).
4. `gp_update_common_front` — те же, у кого `var:gp_threat` совпадает с нашим и та же религиозная группа → `gp_opinion_common_enemy`.
5. Только ИИ и правило не «off»: `gp_apply_temperament`, `gp_update_stage_zones` (сфера при доле ≥ 0.25, дальняя при ≥ 0.55; иначе снять), `gp_update_role` (осаждённая → империя → гегемон → региональная → статус-кво → собиратель; в «strong» плюс `gp_strong_tempo`). Игрок: `gp_clear_ai_modifiers`.

Все модификаторы ставятся с `months = 14, mode = replace` — истекают сами, если мод снять или правило выключить.

## 3. Реестр «GP TODO verify» (что проверить первым запуском)

| # | Допущение | Где | Тест |
|---|---|---|---|
| 1 | `switch = { trigger = tag  ENG = { … } }` принимает голые теги как ключи ветвей | `gp_zone_effects.txt` | в `error.log` нет строк про `gp_zone_effects`; у Англии на старте в подсказке желания завоевания видна зона «The English kingdom» |
| 2 | Семантика `modifier` area_preferences: складывается с ванильными, не ломает порядок ядро > сфера > дальняя | `gp_zones.txt` | наблюдатель 1337→1400: Бранденбург / Венгрия / османы берут сначала области ядра |
| 3 | `ordered_present_country` работает на `capital.region` из эффекта; `save_scope_as` внутри него | `gp_update_threat` | решение «Геополитический обзор» у игрока (например, за Болгарию при сильной Венгрии / Византии) показывает «угроза определена», повод `gp_cb_contain_threat` виден в дипломатии |
| 4 | `relative_strength = { target = X value >= gp_threat_ratio_min }` — именованное значение справа | `gp_is_threat_candidate` | если угрозы никогда не находятся — заменить на литерал 1.5 |
| 5 | `religion.group = root.religion.group` (сравнение двух стран) | триггеры, оценки, цели | в `error.log` нет ошибок про `religion.group`; мнение «Общая угроза региону» появляется между единоверцами |
| 6 | `var:gp_threat ?= root.var:gp_threat` (сравнение переменных-стран) | `gp_shares_threat_with` | то же |
| 7 | `set_variable = { value = "scope:x.relative_strength(root)" }` — функция в значении переменной | `gp_update_threat` | роль «осаждённая» появляется у малых соседей гигантов (Новгород при сильной Литве / Орде) |
| 8 | Ежегодные мнения не копятся (remove + add одной и той же метки) | `gp_effects.txt` | через 5 лет мнение об угрозе всё ещё −40, а не −200 |
| 9 | `multiplier = { add = -0.4 }` в expansion_score трактуется как ×0.6 | `gp_expansion_scores.txt` | подсказка планирования войны ИИ (`-debug_mode`) показывает множитель |
| 10 | `defines = { }` внутри правила игры (как в Battle) | `gp_game_rules.txt` | тот же тест, что у Battle; при провале значения мода просто остаются |
| 11 | `capital.area = area:east_novgorod_area` в `allow` формируемой страны | `gp_novgorod_rus_f` | Новгород видит кнопку формирования со своей столицей |
| 12 | Производительность: годовой обход локаций регионов и `every_present_country` для ~900 стран | `gp_yearly_update` | `performance_degradation.log`: нет скачка в январе каждого года более ~0.2 с |
| 13 | `clear_saved_scope` без существующего scope не пишет в `error.log` | `gp_update_threat` | grep `clear_saved_scope` в `error.log` |
| 14 | `influence_nation` принимается в `country_interactions` цели | `gp_obj_sphere_minor` | нет ошибки загрузки цели |

## 4. Производительность

- Ни одного ежемесячного цикла по странам. Годовой проход: ~900 настоящих стран; обход локаций региона столицы (крупные регионы ~500 локаций) и список стран, присутствующих в регионе (в раздробленной Германии ~100). Оценка: < 1 с реального времени в год на среднем ПК (проверить п. 12).
- Дипломатические цели: `days_between_checks = 365`, без `recipient_list_builder` (фильтр `recipient_trigger` по всем достижимым странам).
- Оценки целей расширения считаются движком только для `AI_NUM_EXPANSION_TARGETS = 20` кандидатов.

## 5. Совместимость

- Не заменяет ни одного ванильного файла; все вклады — свои файлы с префиксом `gp_`. Под ванильными ключами `on_action` — только `on_actions = { gp_x }` (слияние одноимённых on_action).
- С Battle (`cw_`) ключи не пересекаются; оба мода вешают разные страновые модификаторы с `ai = yes`, они складываются.
- Новые теги не объявлены в `setup/countries` (как ванильные NSE / CEL / HEN): цвет и имя приходят из формируемой страны, герб — по ключу тега.
- При патче: пересверить номера строк в `gp_defines.txt` и ванильные значения в `gp_game_rules.txt`; `bash tools/validate.sh new_intelligence_geopolicy` и `bash tools/check_geopolicy_refs.sh`.

## 6. Что сознательно не сделано в v0.1

- Нет интерфейса, кроме решения-отчёта и понятий; переменные (доля, угроза) в подсказках не выводятся (синтаксис показа переменных в loc не подтверждён).
- Нет ванильных `rival_criteria` для мажоров (только теги; угроза уже влияет на мнение и цели).
- Личности ИИ (`ai_personalities`) не переопределяются — роли складываются с ними.
- Колониальные зоны оставлены ванильным предпочтениям (`castile_conquer_new_world`, exploration_preferences).
