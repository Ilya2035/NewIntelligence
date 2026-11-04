# Steam Workshop description — New Intelligence: Battle v0.1

Workshop title: **New Intelligence: Battle** (part of the "New Intelligence" collection; formerly "Concentrated Warfare" — the internal key prefix `cw_` is kept). Mod folder `mods/new_intelligence_battle`, `metadata.json` `id = new_intelligence_battle`.

Draft for the Workshop page. Russian first, then English. Steam Workshop uses BBCode, not Markdown: when pasting, convert `##` headings to `[h1]…[/h1]`/`[h2]…[/h2]`, `**bold**` to `[b]…[/b]`, bullet lists to `[list][*]…[/list]`, and code to `[code]…[/code]`. Fill in the `[ник автора]` / `[author]` placeholders before publishing. Everything below describes v0.1.0 as built on 2026-11-04 for game 1.4.7; it has not been through a full in-game test yet — the "известные ограничения / known limitations" sections say so on purpose, keep them.

---

## Русский

### New Intelligence: Battle — Штабы и стратегия

Часть сборки «New Intelligence» (прежнее название мода — Concentrated Warfare).

Войны без беготни за десятками мелких стеков: у страны мало настоящих армий, и только армия со **штабом** может осаждать и занимать территорию.
ИИ собирает силы в кулак, держит штаб в главной армии и меняет **стадию войны** — наступление, оборона, выжидание, изматывание — а игрок видит её на верхней панели.
Очки войны дают города и столица, а не оккупация сотни деревень.

**Версия мода 0.1.0 · Игра: 1.4.\* (собрано и проверено по файлам 1.4.7) · Русский + English**

#### Что добавляет мод
- **Штаб армии** (`Штаб армии`, 100 человек, вспомогательный полк): бесплатный, но число ограничено. 1 главный штаб у любой страны; дополнительные = минимум из слотов по эпохе (Открытия 1 → Революции 4) и по размеру (1 за каждые 75 локаций), плюс имперский слот при 300 и более локаций; всего не больше 5. Малые страны всю игру воюют одной армией, великие державы к концу игры доходят до 5.
- **Только штрафы, никаких бонусов.** Штаб ничего не даёт; армия **без штаба** получает модификатор «Армия без штаба»: осада −90 %, штурм −50 %, дисциплина −20 %, мораль −25 % (правило игры: мягкий −10/−10, жёсткий −30/−30). Штаб организует армию только вместе с двумя другими полками: одинокий штаб или «штаб + один полк» ничего не оккупирует. Повстанцы получают только боевую часть штрафа («Беспорядок в войске повстанцев») и осаждают как обычно; пираты, экспедиции конкистадоров, армии в изгнании и отряды из одних пленных не штрафуются; степные орды под правила подпадают наравне со всеми.
- **Колониальные (экспедиционные) штабы** — отдельный лимит по заморским театрам (континент, где у вас ≥ 5 локаций или стоит армия от 3 полков; больше слотов при 25 и 60 локациях в поздние эпохи, максимум 4; пороги считают и земли колониальных подданных). За морем заменяют обычный штаб и дают небольшой бонус: −15 % потерь от истощения, +10 % скорость, +10 % восстановление морали; дома такая армия воюет как обычно, но не осаждает («Армия без штаба (только осады)»), пока ей не разместят обычный штаб.
- **Вкладка «Штаб» в окне армии**: статус, действующие штрафы, счётчик слотов, кнопки «Разместить штаб» / «Колониальный штаб» / «Расформировать». Окно **«Штабы»** со списком всех армий и переключателем «Доверить размещение штабов Генштабу» (автоматика как у ИИ). На старте каждая страна получает штаб в самой крупной армии.
- **Концентрация ИИ**: переопределены дефайны военного ИИ — меньше дробления стеков, слияние армий, ожидание союзников перед боем, более ранний переход к асимметричной войне при численном превосходстве врага, более широкий радиус присоединения союзных войск. Штабы ИИ ежемесячно получают его самые крупные армии (дома и на каждом заморском континенте).
- **Стадии войны ИИ**: раз в месяц для каждой воюющей страны-ИИ вычисляется стадия — Наступление / Оборона / Выжидание / Изматывание — по соотношению сил, чертам правителя и командующего, ходу войны; меняется не чаще раза в 2 месяца. Модификаторы стадий действуют только на ИИ.
- **Плашка на верхней панели**: во время войны показывает стадию главного противника (или «Неизвестно» в течение месяца после смены — разведка ещё не донесла) с объяснением в подсказке; клик открывает окно «Штабы».
- **Военная стойка подданных «Эскорт»**: подданный держится рядом с армиями сюзерена и поддерживает его осады (назначается игроком в окне подданных).
- **Переработка военного счёта**: базовая ценность локации 2 → 0.5, столица 5 → 15, столицы провинций и порты ×2, потолки вклада построек и населения подняты; крупные города и мегаполисы дороже в мирном договоре (деревни — по ванильной цене). Без городов и столицы 100 % очков не набрать. Задел под разовый бонус за взятие столицы (проверяется).
- **Державы Америки** (любой формы правления; колониальные подданные держав Старого Света не затронуты): мягкий штраф «изолированная военная традиция» (−5 % дисциплины, без дополнительных слотов штабов), снимается решением «Реформировать войско» (эпоха Реформации, институт или ≥ 60 локаций); отключается правилом.
- **Правила игры** (5): сила штрафа «без штаба» (мягкий / стандарт / жёсткий), концентрация ИИ вкл/выкл, переработка военного счёта вкл/выкл, штраф державам Америки вкл/выкл, события о смене стадии противника.
- Оповещения: открылся новый слот штаба; армия потеряла штаб. Игровые концепции с подсказками. Локализация: русский и английский.

#### Совместимость
- Мод **целиком заменяет два файла игры**: `in_game/gui/single_unit_window.gui` (окно армии — добавлена вкладка «Штаб») и `in_game/common/location_ranks/00_default.txt` (цена локаций в мире). Любой мод, который тоже заменяет эти файлы, несовместим без ручного слияния.
- Частично переопределяет дефайны `NAI` (поведение армий ИИ) и `NWar` (ценность локаций); другие моды с теми же ключами перекрывают друг друга по порядку загрузки.
- Всё остальное — новые объекты с префиксом `cw_`; ванильные on_action только дополняются. Своих `replace`-локализаций нет.
- Ставьте мод **ниже всех UI-модов** в плейсете. Проверено по файлам с Cheat Menu Pro и Simple Cheats на 1.4.7: конфликтов файлов и ключей нет (читы, разумеется, перекрывают штрафы осады).
- Нужна **новая партия** (штабы выдаются при старте). Ironman/достижения — не проверено, считайте, что отключены.

#### Известные ограничения (честно)
- **v0.1 — первая сборка, нужен игровой тест.** Числа баланса — первая прикидка, они вынесены в настраиваемые значения и будут меняться.
- **ИИ армий зашит в код игры.** Мод не может запретить ИИ двигать армию без штаба — он делает такую армию бесполезной для осад и слабой в бою и раздаёт штабы в главные стеки ИИ. Тактика (обход, выбор момента) остаётся за движком, мод только крутит её параметры.
- Стойку «Эскорт» подданным ИИ-сюзеренов скриптом назначить нельзя — только игрок в окне подданных.
- Несколько механизмов движка ещё не подтверждены в игре (частичное переопределение дефайнов из мода, бонус очков войны за столицу, переключение вкладок окна армии). Если что-то из этого не сработает — напишите в обсуждении с `error.log`.
- Нет своих 3D-моделей и иконок офицеров — используется ванильная графика вспомогательных полков (план на v0.3). Мультиплеер не тестировался.

#### Авторы
- Идея, дизайн и правила: [ник автора].
- Скрипты, интерфейс, документация и разбор файлов игры 1.4.7: собраны автором с помощью ИИ-ассистента Claude (Anthropic).
- Спасибо: EU5 Wiki (modding), проекту Community Mod Framework за описание переопределений GUI, Cheat Menu Pro (Xier) — рабочий пример реестра scripted widgets, по которому выверена структура мода. Paradox Interactive — за Europa Universalis V.

Исходники, документация и список тестов: см. папку `docs/` мода (DESIGN.md, SPEC.md, TESTING.md, COMPATIBILITY.md).

---

## English

### New Intelligence: Battle — Headquarters & Strategy

Part of the "New Intelligence" collection (formerly released as Concentrated Warfare).

Wars without chasing dozens of tiny stacks: a country fields few real armies, and only an army with a **Headquarters** can besiege and occupy.
The AI concentrates its forces, keeps the HQ in its main army and shifts its **war stance** — offensive, defensive, waiting, harassing — which the player sees on the top bar.
War score comes from cities and the capital, not from occupying a hundred villages.

**Mod version 0.1.0 · Game: 1.4.\* (built and file-checked against 1.4.7) · English + Russian**

#### Features
- **Army Headquarters** (100 men, auxiliary regiment): free, but limited. 1 main HQ for every country; extra HQs = min(age slots: Discovery 1 → Revolutions 4, size slots: 1 per 75 owned locations) plus an imperial slot at 300+ locations; 5 at most. Small countries fight with one army all game; great powers reach 5 HQs late.
- **Penalties only, no bonuses.** An HQ grants nothing; an army **without** one gets the "Army without Headquarters" modifier: siege ability −90 %, assault −50 %, discipline −20 %, morale −25 % (game rule: mild −10/−10, harsh −30/−30). An HQ organizes an army only together with two other regiments: a lone HQ or "HQ + one regiment" occupies nothing. Rebels get only the combat half ("Rebel Disorder") and besiege normally; pirates, conquistador hosts, exiled and prisoner-only units are exempt; steppe hordes play by the same rules as everyone else.
- **Colonial (expeditionary) HQs** with their own limit per overseas theater (a continent where you own ≥ 5 locations or keep an army of ≥ 3 regiments; more slots at 25 / 60 locations in later ages, max 4; the tiers also count colonial subjects' land). Overseas they replace a regular HQ and add a small bonus: −15 % attrition, +10 % movement, +10 % morale recovery; at home such an army fights normally but cannot besiege ("Army without Headquarters (sieges only)") until it receives a regular HQ.
- **"Headquarters" tab in the army window**: status, active penalties, slot counter, buttons Place HQ / Colonial HQ / Disband. A **Headquarters overview window** listing every army, with a toggle to let the General Staff place HQs automatically (same rules as the AI). Every country starts with an HQ in its largest army.
- **AI concentration**: military AI defines retuned — less stack splitting, army merging, waiting for allies before battle, earlier switch to asymmetric warfare when outnumbered, allied units attach from further away. AI HQs go to its largest armies every month (at home and on each overseas continent).
- **AI war stances**: each warring AI country picks a stance monthly — Offensive / Defensive / Waiting / Harassing — from strength ratio, ruler and commander traits and how the war is going; it changes at most every 2 months. Stance modifiers apply to the AI only.
- **Top-bar plate**: while at war it shows your main enemy's stance (or "Unknown" for a month after a change — intelligence has not reported yet) with an explanation tooltip; click to open the overview window.
- **Subject military stance "Escort"**: the subject stays close to the overlord's armies and supports its sieges (assigned by the player in the subjects screen).
- **Warscore rework**: base war worth per location 2 → 0.5, capital 5 → 15, province capitals and ports ×2, the building and population caps are raised; cities and megalopolises are dearer in peace deals (villages stay at the vanilla price). Without cities and the capital you cannot reach 100 %. A one-off bonus for taking the capital is prepared (pending verification).
- **Countries of the Americas** (any government type; colonial subjects of Old World powers are not affected): a mild "isolated military tradition" penalty (−5 % discipline, no extra HQ slots), removed by the "Reform the war host" decision (Age of Reformation, the institution, or ≥ 60 locations); can be switched off by rule.
- **Game rules** (5): no-HQ penalty strength (mild / standard / harsh), AI concentration on/off, warscore rework on/off, native penalty on/off, enemy-stance-change events.
- Notifications: new HQ slot available; an army lost its HQ. Game concepts with tooltips. Localization: English and Russian.

#### Compatibility
- The mod **replaces two vanilla files wholesale**: `in_game/gui/single_unit_window.gui` (army window — adds the Headquarters tab) and `in_game/common/location_ranks/00_default.txt` (peace price per location rank). Any other mod replacing these files is incompatible without a manual merge.
- Partially overrides the `NAI` (AI army behaviour) and `NWar` (war worth) defines; other mods touching the same keys override each other by load order.
- Everything else is new `cw_`-prefixed content; vanilla on_actions are only appended to. No `replace` localization.
- Load the mod **below all UI mods** in your playset. File-checked against Cheat Menu Pro and Simple Cheats on 1.4.7: no file or key conflicts (cheats will of course mask the siege penalties).
- Needs a **new game** (HQs are granted at game start). Ironman/achievements: not verified, assume disabled.

#### Known limitations (honest)
- **v0.1 — first build, needs play-testing.** Balance numbers are a first pass; they live in tunable script values and will change.
- **Army AI is hard-coded.** The mod cannot forbid the AI from moving an army without an HQ — it makes such an army useless for sieges and weak in battle and hands HQs to the AI's main stacks. Tactics (flanking, timing) stay with the engine; the mod only turns its knobs.
- The "Escort" stance cannot be assigned to AI overlords' subjects by script — only by the player in the subjects screen.
- Several engine mechanisms are not yet confirmed in-game (partial defines override from a mod, the capital war-score bonus, army-window tab switching). If one of them fails for you, post in the discussions with your `error.log`.
- No custom 3D officer models or icons yet — vanilla auxiliary art is reused (planned for v0.3). Multiplayer untested.

#### Credits
- Concept, design and rules: [author].
- Scripts, UI, documentation and the 1.4.7 game-file research: assembled by the author with the AI assistant Claude (Anthropic).
- Thanks: the EU5 Wiki modding pages; the Community Mod Framework project for its GUI-override notes; Cheat Menu Pro (Xier) as the working example of the scripted-widgets registry that the mod's layout follows. Paradox Interactive for Europa Universalis V.

Sources, documentation and the test checklist: see the mod's `docs/` folder (DESIGN.md, SPEC.md, TESTING.md, COMPATIBILITY.md).
