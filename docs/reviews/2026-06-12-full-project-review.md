# Полное ревью проекта My AI Map — 2026-06-12

## Вердикт

Проект в хорошей форме для середины стека: архитектура iOS-порта (pure-core слои, 69 тестов, parity-дисциплина через docs/UNIVERSE_CONSTANTS.md) и веб-перфоманс (TBT 10.4s → 840ms под бюджетом в CI) — выше среднего, P0-блокеров не найдено, ни одна находка не была опровергнута. Главный риск — **продуктовый, не технический**: iOS живёт на Phase 0-заглушке из 12 инструментов вместо 49, сфера без подписей и без связей не отвечает ни на один из трёх продуктовых столпов (что это / зачем / с чем связано), а на iPad приложение целиком блокируется немодальным sheet'ом — это stop-ship по собственным правилам проекта. Главная сила — дисциплина: чистые тестируемые ядра, документированные инварианты и процесс, в котором почти все найденные пробелы уже самозафиксированы в backlog'е. Иными словами, фундамент отличный, но «полировка» (Phase C) запланирована раньше, чем закрыт долг по данным и базовой навигации — порядок стоит поменять.

## Сильные стороны

- **Pure-core архитектура iOS**: ProximityWatcherCore, UniverseLayout, PocketTransition, SearchCore, CameraController-математика отделены от SwiftUI/RealityKit и покрыты 69 быстрыми детерминированными тестами в 9 сьютах.
- **Parity-дисциплина между портами**: layout.ts ↔ UniverseLayout.swift портирован один-в-один, docs/UNIVERSE_CONSTANTS.md ведёт датированный аудит 33/33 констант с журналом намеренных отклонений; палитра категорий синхронизирована hex-в-hex.
- **Веб-перфоманс реально защищён**: idle-mount StarField/GalaxyDust (10.4s → 840ms TBT), lazy-load 3D-сцены, shared geometry в ToolNode.tsx, bundle-size budget в CI — все строки бюджета CLAUDE.md проходят.
- **Persistent-scene рефакторинг (be86b3f) сделан правильно**: diff-based update closure, Entity.move вместо пересборки, меши строятся один раз — убран 5-9s чёрный экран при смене категории.
- **Информационная архитектура веб-панели попадает в продуктовые столпы**: «What it does» → «Map position» → «Connected because» → relation lens; пятистадийный цикл research→planning→execution→approval→review смоделирован сквозно от seed до UI.
- **Classifier — честная founder-фича**: категория + confidence + сигналы + dedupe; fallback откровенно признаёт низкую уверенность (0.34), все значения доказуемо в [0,1].
- **Токенизированный театр бренда на iOS**: BrandColor/BrandTypography/BrandRadius/BrandMotion/BrandHaptics — дисциплина токенов сейчас сильнее, чем у веб-оригинала; liquid-glass язык на вебе един и последователен.
- **Reduce Motion уважается сквозь весь стек** — от SwiftUI-хрома до длительности полёта камеры RealityKit и спина pocket shell; на вебе полный prefers-reduced-motion блок.
- **HIG-паттерны выбраны верно**: bottom sheet по модели Apple Maps (detents + backgroundInteraction), централизованные хептики с pre-warm, увеличенные hit-сферы 3D-целей (1.6–1.8x).
- **Гигиена релиза и секретов чистая**: ни одного секрета в истории git, release-check.sh = docs = CI, xcodegen project.yml как единственный источник истины, Dependabot-холды осознанны и задокументированы.

## P0/P1 — подтверждённые

P0 не найдено. После верификации в P1 осталось 5 находок (дубликаты объединены):

| # | Находка | Роль | Область | Доказательство | Рекомендация |
|---|---------|------|---------|----------------|--------------|
| 1 | **iPad: постоянный немодальный sheet полностью перекрывает карту.** TARGETED_DEVICE_FAMILY "1,2", detents игнорируются на regular width, interactiveDismissDisabled(true), кнопки закрытия нет — продукт недоступен на поддерживаемом девайсе. Готовый фикс (AdaptiveDetailContainer в AdaptiveLayout.swift) написан, но не подключён (dead code) | Apple platform designer | ios | project.yml:42; UniverseScreen.swift:58-73; RootSheet.swift без dismiss; AdaptiveLayout.swift — ноль call sites | Минимум: убрать iPad из v1 (device family 1). Лучше: подключить уже существующий AdaptiveDetailContainer по horizontalSizeClass |
| 2 | **iOS-сид — заглушка Phase 0: 12 из 49 инструментов, порт Phase 1 так и не выполнен.** Целые категории из одного инструмента; ни один из 50 пунктов backlog'а не планирует порт, Phase C visual parity строится на 24% данных | DATA/CONTENT reviewer | ios | UniverseSeed.swift:3-5, 75-86 vs src/data/ai-tool-universe.seed.json (49); AGENT_STATUS.md: «PHASE 2 COMPLETE» | Бандлить seed.json в iOS-таргет или codegen UniverseSeed.swift из JSON; добавить parity-тест ids/summaries; сделать до Phase C |
| 3 | **iOS-обзор — анонимные сферы: ни подписей, ни линий связей.** Нарушает Pillar 1 («что с чем связано») и Pillar 2 («readable labels»); по собственной рубрике docs/design/README.md обзор набирает ~1-2 при релизном пороге ≥4 | Product reviewer + Visual designer (консенсус двух ролей) | ios | verify-6.png: ~12 безымянных сфер; ноль text/label/line-кода в ios-app/Sources; веб-аналоги ToolNode.tsx/ConnectionLines.tsx существуют | Вытащить вперёд минимальный срез Phase C: billboarded подписи категорий (backlog 23) + линии primary workflow; без этого 3D-сцена — декорация |
| 4 | **iOS detail sheet не отвечает «с чем связано» и не даёт действия.** relationIds есть в данных всех 13 инструментов, но ни один UI не читает их; нет URL/Open — карточка тупиковая. Пробел не отслеживается в backlog'е до релиза | Product reviewer | ios | Tool.swift:32 + UniverseSeed.swift:75-86 (данные есть); ToolDetailSection.swift:24-97 (единственная поверхность — не рендерит); ps-final.png | Добавить в ToolDetailSection ряд «Connected to» (tappable chips → re-select) + Open-действие по url. Самый дешёвый способ доставить Pillar 3 до визуальной полировки |
| 5 | **Веб показывает «No public link» для Figma, Vercel, Docker, VS Code, Claude Code и ещё 26 из 49 инструментов.** Фактически неверно и убивает job «узнал → пошёл попробовал»; домены уже известны в tool-logos.ts | Product reviewer | web | AIToolUniverseMap.tsx:1015-1029; в seed.json url отсутствует у 26 записей; src/lib/tool-logos.ts уже мапит id → домены | Заполнить url для всех реальных продуктов; «No public link» оставить только концепт-нодам или переименовать в «Internal workflow node» |

## P2/P3 — бэклог-кандидаты

*(включая подтверждённые находки, пониженные верификатором с P1 до P2/P3)*

### iOS — UX и навигация
- **ClarityMenu — плацебо** (P2): clarityMode пишется, но рендерер его не читает; сцена pixel-identical. Подключить к UniverseView или спрятать до Phase C.
- **Нет видимого выхода из pocket world** (P2): PocketReadout display-only, чип «Core» последний в rail и за экраном. Сделать readout tappable («× Close») или toggle на активном чипе.
- **Pocket не приглушает чужие ноды** (P2): на вебе dimmed → opacity 0.12 (ToolNode.tsx:107), на iOS все сферы яркие внутри чужого shell. Портировать dim rule — главный orientation-фикс.
- **Нет onboarding/подсказок жестов** (P2): pinch-to-enter недискаверим; портировать двухстрочный hint с веба (AIToolUniverseMap.tsx:881-885).
- **VoiceOver не видит 3D-сцену** (P2): ноль AccessibilityComponent; добавить в makeTappable() (label/trait/value). Смягчение: SwiftUI-контролы доступны.
- **Compact detent 118pt режет rail посередине строки + не дружит с Dynamic Type** (P2, 3 находки слиты): магическое число продублировано (UniverseScreen.swift:6/50/60), при AX-размерах помещается одна строка. Один shared-констант + чистая граница клипа.
- **Фиксированные шрифты/фреймы вопреки «Dynamic Type honored»** (P2): BrandTypography display 28pt, eyebrow 10pt, карточки width:132. @ScaledMetric.
- **ClarityMenu/CategoryRail: ~28pt таргеты, нет .isSelected** (P2).
- **Контраст: .white.opacity(0.55) caption-текст на ultraThinMaterial поверх яркой сцены** (P2); + нет label у кнопки очистки поиска.
- **Dark-only только на уровне SwiftUI** (P2): добавить INFOPLIST_KEY_UIUserInterfaceStyle: Dark, иначе launch screen светлый у light-mode юзеров.
- **Landscape включён, но layout портретный** (P2): залочить iPhone на portrait для v1.
- **«1 tools expanded» для 5 из 8 категорий** (P2): inflect: true на iOS, тернарник на вебе.
- **Header: ASCII «->» и потерянная стадия Approve** (P2, 3 находки слиты): UniverseScreen.swift:92 → «→» и все 5 стадий. Однострочник.
- **Чёрный launch screen без бренда** (P2/P3, 3 находки слиты): фон BrandColor.void + градиент/глиф через INFOPLIST_KEY_UILaunchScreen.
- **Search submit без совпадений молча гасит клавиатуру** (P3); **хептики на no-op ветках** (P3); **инертные капсулы выглядят как кнопки** (P3); **нет .isSearchField** (P3).

### iOS — перфоманс и тесты
- **Нет signposts, first-render не атрибутирован** (P2): выполнить backlog 35 (OSSignposter + Instruments) и 36 (launch screen); дешёвая гипотеза — shared unit-sphere MeshResource.
- **Entity.move на каждый узел при любом update без epsilon-чека и отмены in-flight анимаций** (P2): быстрые тапы = десятки конкурирующих контроллеров.
- **Pocket shell torus пересоздаётся синхронно при каждой смене категории** (P2): кэшировать MeshResources в static let.
- **retarget() — ноль покрытия** (P2): регрессионные тесты #53 охраняют устаревший attach()-путь; клонировать pinch-lifecycle тесты на retarget(), он ещё и анимирует (возможное расхождение поведения).
- **Persistent-scene transition / applyLayout без regression net** (P2): извлечь pure layout-diff функцию + лэндить backlog 33 (XCUITest).
- **applyLayout создаёт новый PhysicallyBasedMaterial на каждый узел при каждом тапе** (P3): кэш по (categoryId, selected, pocketed).
- **handleTap не тестируется** (P3); **focus(on:) — мёртвый код, дублирующий retarget()** (P3); **shell всё ещё destroy/recreate внутри «persistent» сцены — backlog 22 разлочен не полностью** (P3).
- **Detents/SearchDock lifecycle без тестов, magic 118 связывает rail и detent** (P2).

### iOS — данные и релиз
- **8 dangling relationIds в iOS-сиде** (P2, 2 находки слиты): cursor→vscode и др. указывают на несуществующие ids; добавить integrity-тест по образцу validateUniverseData. Решается портом полного сида.
- **Два рукописных сида дрейфуют в обе стороны** (P2): описания, relationIds 6 vs 4, glow rgba vs hex, logoDomain в трёх местах. Объявить JSON каноном + parity-check по образцу UNIVERSE_CONSTANTS.
- **Статичный build number "1"** (P2): сломает второй TestFlight-аплоад; скриптовать bump + строка в TESTFLIGHT_CHECKLIST.md.
- **Нет DEVELOPMENT_TEAM** (P3, внешне-гейтед: ждёт enrollment владельца); **нет ITSAppUsesNonExemptEncryption: NO** (P3); **мёртвое правило в ios-app/.gitignore** (P3); **LiquidGlass «native» ветка не зовёт glassEffect** (P3); **стейл-док хептик-таксономии** (P3).

### Web
- **«Connected because» даёт реальную причину лишь 8 из 49 инструментов** (P2): 7 workflowLinks, остальное — boilerplate; даже 30 рукописных reasons для внутренних орбит трансформируют панель. Дорожная карта это уже планирует.
- **Нет per-tool «why it matters»** (P2): одна и та же stage-фраза для 20+ execution-инструментов; добавить поле bestFor/whyItMatters — самая выгодная контент-инвестиция.
- **Стек фаундера живёт только в localStorage одного браузера** (P2): storage/sync — продуктовый блокер для «my stack», не infra nice-to-have.
- **Classifier: substring-матчинг даёт ложные категории** (P2): 'x.com' матчит netflix.com, 'ui' матчит 'builder'; перейти на word-boundary + тесты.
- **5 summaries в голосе внутренних заметок («candidate», «concept»)** (P2): это незакрытый Task 32 master-роадмапа; переписать или убрать.
- **Сомнительные URL** (P2): chorus.com/skills — продукт ZoomInfo, coderabbit ведёт на /login.
- **Концепт-ноды раздувают счётчик «49 tools»** (P2): добавить kind: tool|workflow-node|candidate и исключить из бейджа.
- **Почти нет цветовых токенов — палитра в ~40 inline-значениях** (P2): зеркалировать BrandColor.swift обратно в @theme.
- **Типографика: h1 меньше h2, рабочий текст 10-11px** (P2): 5-ступенчатая шкала, поднять .universe-label-tool до 11-12px.
- **frameloop="always" — нетрекаемый battery/thermal cost** (P2): минимум — demand при reducedMotion; завести явную roadmap-задачу.
- **Playwright smoke не в CI + fixed sleeps (1800/650ms)** (P2): добавить CI-джобу, заменить sleeps на state-based waits.
- **Scene.tsx 549 строк — извлечь derivation-слой до Phase E** (P3); **labelBudgetIds без useMemo** (P3); **toneMapping: 0 клипует emissive >1 в белый** (P3); **разнобой радиусов** (P3); **eyebrow tracking 0/0.16/0.18em** (P3); **нет Reset на мобиле** (P3); **бейдж «6» при списке из 4** (P3); **relations односторонние у 48 из 49** (P3); **distribution — фактически 2 инструмента** (P3); **bundle-check игнорирует новые чанки вне 4 префиксов** (P3).

### Process / Docs
- **Два конкурирующих 50-задачных роадмапа с коллизией нумерации** (P2): backlog 16 ≠ master Task 16; объявить один канон (backlog), master — ARCHIVED, префиксы B/M.
- **Persistent-scene коммит ушёл без синка доков** (P2): чекбоксы 15/16 в CLAUDE_BACKLOG, deviation #1 в UNIVERSE_CONSTANTS, AGENT_STATUS — обновить в том же PR до merge.
- **Нет iOS CI — iOS-ломающие изменения мержатся с зелёными чеками** (P2, 3 находки слиты): единственный гейт — локальный симулятор с захардкоженным UUID на машине с 1.5 GiB свободного диска. Минимальная macos-джоба = backlog 34.
- **Синк 33 констант — ручная проза, уже дрейфанул за день** (P2): shared universe-constants.json + golden-vector фикстуры для Vitest и Swift Testing.
- **Тестовая асимметрия: порт layout-математики протестирован, канонический layout.ts — нет** (P2): layout.test.ts на тех же golden vectors.
- **UniverseStateComponent несёт reference/closure через ECS** (P2): упадёт на Swift 6 strict concurrency; вынести event sink в MainActor-bridge.
- **npm test не запускается в свежих worktree (нет node_modules)** (P2, 2 находки слиты): документировать npm ci в RUNBOOK или ставить при создании worktree.
- **Нет iOS perf-бюджета, а perf-релевантные PR уже мержатся** (P2): снять baseline до Phase C (IBL/skybox).
- **Стейл-доки** (P3): AGENT_STATUS «65/65 в 8 сьютах» vs 69 в 9; perf.md:30 — выполненный пункт в open-списке; RELEASE_REVIEW отстаёт от Phase 2; доки ссылаются на несуществующую схему «My AI Map» (реальная — MyAIMap); release-check без npm audit --omit=dev.

## Отклонённые находки

Опровергнутых находок нет — все 24 подтверждённые P0/P1-кандидата прошли верификацию как реальные (19 из них верификатор понизил до P2/P3 — учтено выше). Находки без вердикта сохранены как confirmed-unverified (верификатор упал на части прогона).

## Рекомендованный план

Top-10 по соотношению impact/effort:

1. **NEW-1 — iPad-ловушка: убрать device family 2 из project.yml или подключить уже написанный AdaptiveDetailContainer.** Stop-ship по собственным инвариантам, фикс — часы, не дни.
2. **NEW-2 — Порт полного сида на iOS: codegen UniverseSeed.swift из ai-tool-universe.seed.json + integrity-тест (relationIds резолвятся, parity ids/summaries).** Снимает разом «12 из 49», пустые pocket worlds, 8 dangling refs и двунаправленный дрейф. Обязательно ДО Phase C.
3. **NEW-3 — Backfill url для 26 инструментов веб-сида + relabel концепт-нод + правка подозрительных URL (coderabbit, chorus-skills).** Час работы с данными, чинит фактическую ложь «No public link» у Figma.
4. **NEW-4 — «Connected to» + Open-действие в ToolDetailSection (iOS).** Самый дешёвый способ доставить Pillar 3; данные уже лежат в relationIds.
5. **Backlog 23 + 26 (вытащить вперёд из Phase C) — billboarded подписи категорий, затем инструментов, на iOS.** Превращает декорацию в карту; минимальный срез — только категории.
6. **NEW-5 — Канонизация процесса: объявить CLAUDE_BACKLOG единственным execution board, пометить master-роадмап ARCHIVED, в одном PR с feat/ios-persistent-scene закрыть чекбоксы 15/16 и переписать deviation #1 в UNIVERSE_CONSTANTS.** Дешёвая страховка от повторной работы агентов.
7. **Backlog 34 — минимальный iOS CI: macos-джоба, path-filtered на ios-app/**, через существующий scripts/ios-verify.sh.** Убирает single point of failure из локального симулятора и зелёные чеки на сломанном Swift.
8. **NEW-6 — ClarityMenu: подключить clarityMode к рендереру или спрятать контрол до Phase C.** Видимый «сломанный» контрол хуже его отсутствия.
9. **NEW-7 — Ориентация в pocket: dim чужих нод (~0.12-0.2 по образцу веба) + явный выход (tappable PocketReadout «× Close»).** Две правки, закрывающие три P2 разом.
10. **Backlog 35 + 36 — perf baseline: OSSignposter вокруг first-frame/entity-loop, числа в docs/perf-ios.md с правилом «>10% — поднимать в PR», брендированный launch screen.** До того, как Phase C добавит IBL/skybox без точки сравнения.

Быстрые однострочники вне топ-10, которые стоит сделать попутно: «→» вместо «->» + стадия Approve в хедере (NEW-8), inflect для «1 tools expanded» (NEW-9), INFOPLIST_KEY_UIUserInterfaceStyle: Dark + ITSAppUsesNonExemptEncryption: NO в project.yml (NEW-10).