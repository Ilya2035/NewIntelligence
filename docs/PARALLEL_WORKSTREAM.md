# Параллельный поток работ (второй чат)

Этот файл — вводная для второго потока работ, который идёт параллельно с основным. Репозиторий — сборка модов «New Intelligence»: `C:\Users\fyrno\PycharmProjects\EU5-NewIntelligence` (ветка `main`). Мод первого потока — **New Intelligence: Battle** в `mods/new_intelligence_battle` (внутренний префикс ключей `cw_`, бывш. Concentrated Warfare), подключён к игре через junction `Documents\Paradox Interactive\Europa Universalis V\mod\new_intelligence_battle`. Второй мод сборки — **New Intelligence: Geopolitics** — будет жить в том же репозитории в папке `mods/new_intelligence_geopolitics` (своя `.metadata/metadata.json`, свой junction `mod\new_intelligence_geopolitics`). Прежняя схема с отдельной папкой-worktree `EU5-ConcentratedWarfare-Colonial` больше не действует.

## Как это устроено
- Один репозиторий, моды — соседние папки в `mods/`. Второй поток работает либо в отдельной ветке этого репозитория (например `geopolitics`), либо в git worktree этого же репозитория в соседней папке (`git worktree add ../EU5-NewIntelligence-geopolitics geopolitics`); в обоих случаях его мод лежит в `mods/new_intelligence_geopolitics`.
- В игре загружается то, на что указывают junction'ы: `mod\new_intelligence_battle` → `mods/new_intelligence_battle` основной папки. Для проверки второго мода в игре — создать junction `mod\new_intelligence_geopolitics` на папку мода в той рабочей копии, где он развивается (или влить ветку в `main`).
- Перед большими правками во второй рабочей копии: `git merge main`, чтобы забрать свежие изменения Battle, инструменты и документацию.
- Валидатор общий: `bash tools/validate.sh` (по умолчанию проверяет `mods/new_intelligence_battle`), для второго мода — `bash tools/validate.sh new_intelligence_geopolitics`.

## Что уже есть (чтобы не делать дважды)
- В Battle: механика штабов, лимиты, раздача штабов ИИ, стадии войны, военный счёт, правила игры, UI (плашка, окно «Штабы», вкладка в окне армии), локализация RU/EN — см. `docs/IMPLEMENTATION_NOTES.md`; балансовые решения применены (настройка баланса 2026-11-04, `docs/SPEC.md` v0.3).
- Колониальные штабы (`cw_hq_colonial`), театры по континентам (пороги учитывают земли подданных), бонус `cw_expeditionary` за морем, «колониальный штаб дома воюет, но не осаждает» (`cw_no_hq_siege_only`).
- Исследования: `docs/research/10_colonial_overseas_balance.md` (колонии, туземцы, история гарнизонов), `14_hq_limits_at_game_start.md` (размеры стран на 1337), `15_balance_review.md` (ревью чисел), `12_unit_3d_models_pipeline.md` (как сделать 3D-офицеров).

## Тема второго потока
New Intelligence: Geopolitics — дипломатия и стратегический ИИ (см. `README.md`). Темы, оставшиеся от прежнего «колониального» плана (наблюдатель 1437–1600 за ИИ-колонизаторами, метрики `tools/log_stats.sh`, баланс штрафа державам Америки `cw_isolated_tradition_auto` / решения `cw_reform_war_host`), относятся к Battle и делаются в `mods/new_intelligence_battle`.

## Правила совместной работы двух чатов
- Второй поток правит **только** свои файлы: всё своё — в `mods/new_intelligence_geopolitics` с собственным префиксом ключей (не `cw_`), чтобы ключи двух модов никогда не пересекались. Файлы Battle (`mods/new_intelligence_battle`, в том числе ядро `cw_effects.txt`, `cw_triggers.txt`, `cw_limit_values.txt`) менять минимально и сообщать об этом в описании коммита.
- Не трогать `mods/new_intelligence_battle/in_game/gui/single_unit_window.gui` и `.../location_ranks/00_default.txt` (цельные копии ванильных файлов — конфликты слияния гарантированы); второй мод не должен заменять те же ванильные файлы целиком.
- Общие инструменты (`tools/`) и документы (`docs/`) — менять согласованно, отдельными коммитами.
- Каждый коммит — после `bash tools/validate.sh` без ошибок (для каждого затронутого мода).
