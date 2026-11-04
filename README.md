# New Intelligence — сборка модов для Europa Universalis V 1.4.x

Сборка модов, которые делают ИИ EU5 умнее и войны — играбельнее. Каждый мод живёт в своей папке в `mods/`, подключается к игре отдельно и выкладывается в Workshop отдельно; документация и инструменты общие.

| Мод | Папка | Статус |
|---|---|---|
| **New Intelligence: Battle** — штабы армий, концентрация войск, стадии войны, военный счёт | `mods/new_intelligence_battle` | v0.1, готов к первому игровому тесту |
| **New Intelligence: Geopolicy** — геополитический ИИ: зоны интересов, роли, угроза региону, культура и вера, красивые границы, 11 новых формируемых стран | `mods/new_intelligence_geopolicy` | v0.1, готов к первому игровому тесту |

## New Intelligence: Battle

Войны становятся концентрированными: у страны мало настоящих армий, захватывать провинции может только армия со **штабом**, ИИ собирает силы вместо беготни мелкими стеками, игрок видит **стадию войны** противника, а военный счёт дают прежде всего города и столица. Внутренний префикс ключей в коде — `cw_` (рабочее название Concentrated Warfare).

### Документация

| Файл | Что внутри |
|---|---|
| [docs/DESIGN.md](docs/DESIGN.md) | Концепция и принятые решения (русский) |
| [docs/SPEC.md](docs/SPEC.md) | Техническая спецификация: ключи, файлы, формулы, подтверждённый синтаксис |
| [docs/IMPLEMENTATION_NOTES.md](docs/IMPLEMENTATION_NOTES.md) | Как всё устроено «из конца в конец», реестр «CW TODO verify» с тестом для каждого пункта |
| [docs/TESTING.md](docs/TESTING.md) | Чек-листы и эксперименты для первого игрового теста |
| [docs/COMPATIBILITY.md](docs/COMPATIBILITY.md) | Совместимость с установленными модами и порядок переноса на новый патч |
| [docs/WORKSHOP_DESCRIPTION.md](docs/WORKSHOP_DESCRIPTION.md) | Черновик описания для Steam Workshop (RU/EN) |
| [docs/PARALLEL_WORKSTREAM.md](docs/PARALLEL_WORKSTREAM.md) | Как вести второй мод параллельно (второй чат) и правила совместной работы |
| `docs/research/01…16_*.md` | Исследование файлов игры: юниты, скрипты армий, модификаторы, on_action, очки войны, рычаги ИИ, GUI, упаковка мода, колонии, эпохи/события/локализация, 3D-модели, метрики логов, лимиты на 1337 год, ревью баланса, QA локализации |

### Установка / запуск

Папка мода подключена к игре через junction:
`C:\Users\fyrno\Documents\Paradox Interactive\Europa Universalis V\mod\new_intelligence_battle` → `mods\new_intelligence_battle`.

1. Лаунчер EU5 → Плейсеты → добавить мод «New Intelligence: Battle» (лучше в отдельный плейсет без читов для первого теста).
2. Новая партия (мод меняет стартовые данные — старые сохранения не подойдут). В правилах игры появятся 4 правила мода: сила штрафа без штаба, бонус военного счёта за столицу, штраф туземцам, события о смене стадии войны.
3. После загрузки проверить `Documents\Paradox Interactive\Europa Universalis V\logs\error.log` на строки с `cw_` — это ошибки мода. Дальше — по `docs/TESTING.md`.

### Инструменты (Git Bash, из корня репозитория)

```bash
bash tools/validate.sh
```
Статическая проверка мода (по умолчанию `new_intelligence_battle`; имя другого мода — первым аргументом): кодировка (BOM), баланс скобок, заголовки локализации, существование текстур, сверка каждого ключа скрипта со словарём ванильных файлов (кэш в `tools/cache/`, удалить после патча игры). Не заменяет запуск игры, но ловит опечатки и несуществующие эффекты.

```bash
bash tools/check_vanilla_overrides.sh
```
Показывает, изменились ли после патча два ванильных файла, которые мод переопределяет целиком (`in_game/gui/single_unit_window.gui`, `in_game/common/location_ranks/00_default.txt`). Порядок переноса — в `docs/COMPATIBILITY.md`.

```bash
bash tools/log_stats.sh
```
Метрики из игровых логов (войны, битвы, осады, предупреждения ИИ) для сравнения «ваниль vs мод»; базовая линия — `docs/research/13_ai_log_baseline.md`.

### Структура мода (`mods/new_intelligence_battle`)

```
.metadata/                        metadata.json, thumbnail.png
in_game/common/unit_types/        cw_hq, cw_hq_colonial (штаб и колониальный штаб)
in_game/common/prices, goods_demand   почти нулевая стоимость штабов
in_game/common/script_values/     значения стадий войны, настройки
main_menu/common/script_values/   лимиты штабов (как у ванильных лимитов юнитов)
in_game/common/scripted_effects/  cw_effects (организация армий, раздача штабов ИИ), cw_stance_effects, cw_warscore_effects
in_game/common/scripted_triggers/ cw_triggers, cw_stance_triggers, cw_warscore_triggers
in_game/common/on_action/         хуки в месячный пульс, старт войны, бои, осады, смену эпохи, восстания
in_game/common/scripted_guis/     действия и проверки для интерфейса
in_game/common/decisions/         «Доверить размещение штабов», «Реформа войска» (туземцы)
in_game/common/subject_military_stances/  стойка «Эскорт» для подданных
in_game/common/location_ranks/    копия ванильного файла + цена городов в мирном договоре
in_game/common/auto_modifiers/    мягкий штраф изолированной военной традиции
in_game/events/                   оповещения игроку, скрытый 15-дневный таймер войны, смена стадии противника
in_game/gui/                      плашка стадии войны, окно «Штабы», окно армии с вкладкой «Штаб»
main_menu/common/static_modifiers модификаторы армий (штрафы) и стран (стадии войны)
main_menu/common/game_rules, game_concepts
main_menu/localization/{russian,english}/
loading_screen/common/defines/    cw_ai_defines (концентрация ИИ), cw_war_defines (военный счёт)
```

### Статус

v0.1 (2026-11-04) — первая автономная сборка по голосовому ТЗ: 5 модулей, локализация RU/EN, 10 адверсарных ревью, правка баланса по итогам `docs/research/15_balance_review.md`, статический валидатор без ошибок. **В игре ещё не запускался** — первый запуск и `error.log` решают, какие из допущений («CW TODO verify» в `docs/IMPLEMENTATION_NOTES.md`) верны.

## New Intelligence: Geopolicy

ИИ играет роль своей страны, а не пожирает всё вокруг: сначала собирает свою **область и регион**, потом «сферу» (земли, на которые исторически претендовал), и только как региональный гегемон смотрит вдаль. Раз в год каждая страна определяет **угрозу своему региону** и реагирует на неё (мнение, общий фронт единоверцев, повод для войны «Сдержать региональную угрозу»), отторгает **иноземных пришельцев**, уважает культуру и веру соседей и ведёт границы по целым областям. Отдельные **темпераменты** для Европы, степи, Китая, Японии/Кореи, Индии и исламского Ближнего Востока. Плюс 11 новых формируемых стран с исторической зацепкой (Альба, Арморика, Анжуйская империя, Королевство вендов, Королевство Бургундия, Иллирия, Дакия, Королевство Руси, Новгородская Русь, Иерусалимское королевство, Хорасан). Внутренний префикс ключей — `gp_`.

### Документация

| Файл | Что внутри |
|---|---|
| [docs/GEOPOLICY_DESIGN.md](docs/GEOPOLICY_DESIGN.md) | Концепция: зоны интересов и этапы, роли, угроза региону, пришельцы, культура и вера, темпераменты, формируемые страны, правила игры (русский) |
| [docs/GEOPOLICY_IMPLEMENTATION.md](docs/GEOPOLICY_IMPLEMENTATION.md) | Как всё устроено: файлы, годовой проход, реестр «GP TODO verify» с тестом для каждого допущения, производительность, совместимость |
| [docs/GEOPOLICY_TESTING.md](docs/GEOPOLICY_TESTING.md) | Чек-листы первого запуска и наблюдателя 1337→1450, какие ручки крутить |
| [docs/GEOPOLICY_V2_PROPOSAL.md](docs/GEOPOLICY_V2_PROPOSAL.md) | Предложение v0.2+: 10 состояний государства, сила власти и правитель, сословия, детские обиды и привязанности правителей, единокровные и коалиции по логике, связка с Battle и будущим модом «Двор» (не реализовано) |

### Установка / запуск

Папка мода подключается к игре через junction:
`C:\Users\fyrno\Documents\Paradox Interactive\Europa Universalis V\mod\new_intelligence_geopolicy` → `mods\new_intelligence_geopolicy` (создать из cmd: `mklink /J "<Documents>\mod\new_intelligence_geopolicy" "<репозиторий>\mods\new_intelligence_geopolicy"`).

1. Лаунчер EU5 → Плейсеты → добавить мод «New Intelligence: Geopolicy» (для первого теста — отдельный плейсет без других модов; с Battle совместим, ключи не пересекаются).
2. Новая партия. В правилах игры появится правило мода «Геополитика ИИ» (стандартная / усиленная / выключена); переопределения defines действуют всегда (блок `defines = {}` в правилах игры парсер 1.4.7 отвергает — урок первого запуска Battle).
3. После загрузки проверить `logs\error.log` на строки с `gp_`. Дальше — по `docs/GEOPOLICY_TESTING.md`. У игрока есть решение «Геополитический обзор» (доля домашнего региона, найдена ли угроза региону, профиль зон).

### Инструменты

```bash
bash tools/validate.sh new_intelligence_geopolicy
```
Статический валидатор ключей (общий с Battle). Ожидаемые предупреждения: `map_*` (цвета объявлены внутри блока `colors`) и `influence_nation` (ключ взаимодействия, в кэше отсутствует из-за BOM в ванильном файле).

```bash
bash tools/check_geopolicy_refs.sh
```
Сверка всех ссылок мода с игрой: области и регионы зон (`gp_zones.txt`, формируемые страны) с `map_data/definitions.txt`, локации, культуры, культурные и религиозные группы, теги профилей зон, покрытие локализацией, гербы, цвета и текстуры гербов.

### Структура мода (`mods/new_intelligence_geopolicy`)

```
.metadata/                                metadata.json, thumbnail.png
in_game/common/area_preferences/          gp_zones (~70 профилей: ядро / сфера / дальняя, общий профиль, групповые сферы)
in_game/common/scripted_effects/          gp_effects (годовой проход: доля региона, угроза, пришельцы, общий фронт, темперамент, стадии, роли), gp_zone_effects (профили по тегу)
in_game/common/scripted_triggers/         gp_triggers (настоящая страна, правила, темпераменты, кандидат в угрозы, пришелец)
in_game/common/script_values/             gp_values (пороги)
in_game/common/on_action/                 старт партии, годовой пульс, новая / освобождённая страна
in_game/common/ai_scripted_expansion_score/   9 правок оценки целей войны
in_game/common/ai_scripted_expansion_target/  3 списка целей (сдержать угрозу, выгнать пришельца, домашний регион)
in_game/common/scripted_diplomatic_objectives/ 4 дипломатические цели (общий фронт, защитник, сфера влияния, антагонизм пришельцу)
in_game/common/biases/                    3 модификатора мнения
in_game/common/casus_belli/               «Сдержать региональную угрозу»
in_game/common/formable_countries/        11 новых формируемых стран
in_game/common/decisions/                 «Геополитический обзор»
main_menu/common/static_modifiers/        6 ролей + усиленный темп + 6 темпераментов
main_menu/common/game_rules, game_concepts, named_colors, coat_of_arms/
main_menu/localization/{russian,english}/
loading_screen/common/defines/            gp_defines (красивые границы, культура и вера, дальность, коалиции)
```

### Статус

v0.1 (2026-11-04) — первая сборка по голосовому ТЗ: зоны интересов для ~70 стран Европы, Ближнего Востока и Магриба, роли, угроза региону, пришельцы, темпераменты, 11 формируемых стран, defines, правила игры, локализация RU/EN, оба статических валидатора без ошибок. **В игре ещё не запускался** — реестр допущений «GP TODO verify» в `docs/GEOPOLICY_IMPLEMENTATION.md`.

## Публикация

GitHub: репозиторий сборки будет добавлен позже; коммиты ведутся от имени владельца. Workshop: каждый мод загружается отдельно из своей папки `mods/<mod>` (превью — `.metadata/thumbnail.png`), текст — `docs/WORKSHOP_DESCRIPTION.md`.
