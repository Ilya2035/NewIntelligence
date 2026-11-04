# 16 — Localization QA report (RU primary, EN secondary), 2026-11-04

Report-only review of `main_menu/localization/russian/cw_concentrated_warfare_l_russian.yml` (212 lines) and `.../english/cw_concentrated_warfare_l_english.yml` (211 lines). Line numbers are file lines at review time; EN line = RU line − 1 for every key. Applied by the localization fix pass after the balance tuning (see IMPLEMENTATION_NOTES).

Vanilla facts used: war score = `game_concept_war_score: "Военный счёт"` («очки войны» never appears in vanilla); `ARMY_BUILDER: "Конструктор армии"`; AI countries = «державы под управлением компьютера»; institutions take «внедрить»; ages in running text = «эпохи Открытий / Реформации / Абсолютизма / Революций»; subject concept = «Ленник»; vanilla English uses American spelling (organize, theater, behavior) and Title Case for rule/modifier names; `warscore` as one word in English concept text.

## 1. Russian terminology, grammar, naturalness
- 110: «Переработка очков войны» → `rule_cw_rule_warscore: "Переработка военного счёта"`
- 112: → `"Военный счёт за оккупацию и стоимость требований в мирном договоре складываются в основном за счёт городов и столицы; деревни почти ничего не стоят. За взятие вражеской столицы начисляется разовый бонус к военному счёту."`
- 63, 165, 167: «в конструкторе армий» → «в конструкторе армии»
- 79: «по тем же правилам, что и у держав под управлением ИИ» → «по тем же правилам, что и для держав под управлением компьютера»
- 135: «державы под управлением ИИ» → «державы под управлением компьютера»
- 172: → `"Когда автоматическое размещение включено, наши штабы каждый месяц распределяются по самым крупным армиям по тем же правилам, что и у компьютера: дома — обычные, за морем — колониальные (по одному на театр). Лишние штабы при этом не расформировываются. То же самое переключает решение «$cw_toggle_auto_hq.title$»."`
- 59: «когда мы примем [институт]… Это пройдёт» → «Традиция исчезнет, когда мы внедрим [Concept('institution', 'институт')|e] «$pike_and_shot$»»
- 117: «пока не примут институт» → «…получают небольшой штраф к дисциплине и лишены дополнительных слотов штабов, пока не внедрят институт «$pike_and_shot$» или не реформируют войско»
- 109: «ванильные параметры» → `"Восстанавливаются исходные параметры поведения армий ИИ."`
- 114: → «Восстанавливаются исходные параметры ценности районов в войне, бонус за столицу отключён (цены в мирном договоре по рангу района сохраняются)»
- 28, 29, 132 (×3), 169 (×3): «с Эпохи Реформации / Абсолютизма / Открытий» → «с эпохи Реформации», «с эпохи Абсолютизма», «с эпохи Открытий»
- 129: «(Открытия — 1, Реформация — 2, Абсолютизм — 3, Революции — 4)» → «(эпоха Открытий — 1, Реформации — 2, Абсолютизма — 3, Революций — 4)»
- 167: → «по [Concept('age', 'эпохе')|e]: Открытий — 1, Реформации — 2, Абсолютизма — 3, Революций — 4;»
- 107: «ИИ держит меньше, но крупнее стеков» → `"ИИ держит меньше армий, но более крупных, ждёт союзников перед боем и раньше переходит к асимметричной войне (изменённые параметры армейского ИИ)."`
- 21, 129, 167: «владеемых районов» → «собственных районов» (21: «не более одного за каждые 75 собственных районов» — NOTE the divisor is now 75 after tuning)
- 129: «один всегда, плюс по эпохе» → «всегда один, плюс по эпохе»
- 135: «пока она только что сменилась, разведка сообщает» → «сразу после смены разведка сообщает «$CW_STANCE_0$»»; sentence with too many «и» → «Стадия пересчитывается раз в месяц с учётом соотношения сил с главным противником, черт правителя и командующего, а также хода войны; меняется она не чаще раза в два месяца.»; «вашего главного противника» → «нашего главного противника»; wrap stance names: ««$CW_STANCE_1$», «$CW_STANCE_2$», «$CW_STANCE_3$», «$CW_STANCE_4$» или «$CW_STANCE_0$»»
- 122: → `"Событие о смене стадии войны противника не показывается (плашка под панелью уведомлений всё равно её отображает)."`
- 155: → `"#T $CW_STANCE_0$#!\n[Concept('cw_war_stance', 'Стадия войны')|e] противника неизвестна: она недавно сменилась, и донесения разведки ещё не поступили (сведения обновляются в течение пары месяцев), либо противник находится под управлением игрока."`
- 53: «…осаждает его тыл» → «…совершает набеги и осаждает крепости в его тылу»; 159: → «…бьёт мелкие отряды и осаждает крепости в нашем тылу»
- 42: «быстрее марш и восстановление боевого духа» → «меньше потерь от истощения, выше скорость передвижения и восстановления боевого духа»
- 87: «переняв уроки чужеземных армий» → «переняв опыт чужеземных армий»
- 79: «Лишние штабы игрока никогда не расформировываются» → «Лишние штабы при этом не расформировываются.»; «Автоматику можно…» → «Автоматическое размещение можно в любой момент отключить этим же решением.»
- 132: «…даёт только пока армия стоит за морем» → «…даёт, только пока армия находится за морем»
- 186: → «Здесь стоит армия со штабом: армия организована»
- 188: «Колониальный штаб на месте» → «Есть колониальный штаб»
- 190, 207: «одинокий штаб» → «…штаб без других полков ничего не оккупирует»; 202: → «Штаб без войск: армия не организована, штраф действует»
- 208/209: → «Счётчик обновляется при ежемесячной проверке организации, при нажатии кнопок этой вкладки, а также в начале и по окончании войны…»
- 211: → «поэтому, если счётчик выше ещё не обновился, нажатие может не сработать»
- 14: → «…а армия без штаба получает штраф «$STATIC_MODIFIER_NAME_cw_no_hq$»»
- 100: «стандартный штраф» → «обычный штраф»
- 38, 40: → «(правило игры «$rule_cw_rule_hq_penalty$», вариант «$setting_cw_hq_penalty_mild$»)» and the harsh counterpart
- 137 (comment): «Военная стойка подданных» → «Военная позиция ленников»; 138: «Эскорт» acceptable («Сопровождение» optional)
- Kept as the author's term: «Стадия войны» (vanilla «Военная позиция» is taken by subject stances).

## 2. Formatting
- BOM, headers, leading spaces, no version numbers, no duplicates, balanced `#…#!` — all fine.
- RU 63 / EN 62: `#V [ROOT.ScriptValue('cw_hq_limit')|V0]#!` double-formats → `Всего доступно штабов: [ROOT.ScriptValue('cw_hq_limit')|V0].`

## 3. Key parity
- Key sets identical. Dead keys (harmless, may be removed from both files): `CW_HQ_PENALTY_TEXT`, `game_concept_cw_hq`.

## 4. Meaning parity
- RU 49 → «Силы примерно равны силам главного противника: держава держится…»
- EN 157 → "…and reinforces its regiments faster before acting."
- EN 134 → "shows the stance of our main enemy"
- EN 171 → "by the same rules the AI uses"
- EN-wide: American spelling (organized, theater, behavior, recognizes); Title Case for rule/modifier names (EN 97 "Headquarters Penalty", 104 "AI Army Concentration", 109 "Warscore Rework", 114 "Isolated Military Tradition (Native Penalty)", 119 "Enemy War Stance Events", 45/47/49/51 "War Stance: Offensive / Defensive / Waiting / Harassing"); EN 109/111 "war score" → "warscore"; EN 108/113 "vanilla" → "default"; unify "Army without Headquarters" (EN 91 vs 34/36/38); EN 185 → "An army with a headquarters is here (organized)".

## 5. Data functions and nested keys
- All `$key$` references resolve (`$pike_and_shot$` is vanilla). `[cw_army.GetName]`, `[cw_enemy.GetName]`, `[ROOT.ScriptValue('cw_hq_limit')|V0]` and all `[Concept(...)|e]` links are plausible/vanilla patterns. Every CW_*/cw_* key referenced from .gui/.txt files is defined.

## Top 10
1. RU 110/112 «очки войны» → «военный счёт». 2. RU 107 grammar. 3. RU 63/165/167 «конструкторе армии». 4. Age names lower-case «эпохи» + genitive. 5. RU 79/135/172 «под управлением компьютера», case fix. 6. RU 135 «сразу после смены», «нашего». 7. RU 155 intel wording. 8. RU 59/117 «внедрим/внедрят институт». 9. RU 109/114, EN 108/113 drop «ванильные»/"vanilla". 10. EN: American spelling, Title Case, "warscore".
