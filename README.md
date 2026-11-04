# New Intelligence — сборка модов для Europa Universalis V 1.4.x

Сборка модов, которые делают ИИ EU5 умнее и войны — играбельнее. Каждый мод живёт в своей папке в `mods/`, подключается к игре отдельно и выкладывается в Workshop отдельно; документация и инструменты общие.

| Мод | Папка | Статус |
|---|---|---|
| **New Intelligence: Battle** — штабы армий, концентрация войск, стадии войны, военный счёт | `mods/new_intelligence_battle` | v0.1, готов к первому игровому тесту |
| New Intelligence: Geopolitics — дипломатия и стратегический ИИ | `mods/new_intelligence_geopolitics` | план |

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
2. Новая партия (мод меняет стартовые данные — старые сохранения не подойдут). В правилах игры появятся 5 правил мода: сила штрафа без штаба, концентрация ИИ, переработка военного счёта, штраф туземцам, события о смене стадии войны.
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

## Публикация

GitHub: репозиторий сборки будет добавлен позже; коммиты ведутся от имени владельца. Workshop: каждый мод загружается отдельно из своей папки `mods/<mod>` (превью — `.metadata/thumbnail.png`), текст — `docs/WORKSHOP_DESCRIPTION.md`.
