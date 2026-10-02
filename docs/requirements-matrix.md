# Матрица «ТЗ → код → тест»

Источник требований — документ «Норма рядом: разбор идеи и план реализации» (MVP, раздел 7.1, и разделы 5–13). Пути к коду указаны от корня репозитория; `server/…/` — это `server/src/main/kotlin/ru/normaryadom/`, тесты сервера — `server/src/test/kotlin/ru/normaryadom/`, тесты клиента — `app/test/`, сквозные — `e2e/tests/`.

## Онбординг и норма (7.2.1, 8, 6.3)

| Требование | Код | Тесты |
|---|---|---|
| Параметры тела, активность, цель | `app/lib/ui/onboarding/body_parameters_form.dart` | `ui/onboarding_test.dart` «проходит три шага…», E2E «сценарий защиты» шаг 1 |
| Норма по Миффлину — Сан Жеору, коэффициенты активности и цели | `app/lib/domain/nutrition/norm_calculator.dart` | `domain/norm_calculator_test.dart` по `contract/norm-cases.json`; сервер: `contract/NormCalculationContractTest` |
| Объяснение расчёта | `app/lib/ui/onboarding/norm_card.dart` | `ui/onboarding_test.dart` «считает норму…и объясняет расчёт» |
| Ручная правка нормы | `norm_card.dart`, `OnboardingController.setManualNorm` | `ui/onboarding_test.dart` «не даёт задать ручную норму ниже…» |
| Безопасный минимум 1200/1500 ккал, дефицит ≤ 20% | `NormCalculator.safeMinimumKcal`, `Goal.lose` = 0.85 | `norm_calculator_test.dart` «поднимает норму до безопасного минимума», контрольные примеры |
| Предпочтения как теги исключения | `app/lib/domain/models/diet_preference.dart` | `domain/meal_planner_test.dart` «превращает предпочтения…» |
| Согласие на геолокацию, без него — район | `app/lib/ui/onboarding/location_picker.dart`, `LocationController` | `ui/onboarding_test.dart` «без доступа к геолокации…», `ui/home_test.dart` «при отказе в геолокации…» |
| Дисклеймер «не является медицинской рекомендацией» | `app_ru.arb: disclaimer` | виден на экранах онбординга, главном и профиле (скриншоты E2E) |

## Главный экран «Что взять» (7.2.2)

| Требование | Код | Тесты |
|---|---|---|
| «Осталось на сегодня» | `app/lib/ui/home/home_screen.dart`, `DaySummary.remaining` | `ui/home_test.dart` «показывает остаток…», E2E шаг «главный экран показывает уменьшившийся остаток» |
| Переключатель приёма пищи с предзаполненной целью (обед = 35%) | `MealType.share`, `MealPlanner` | `domain/meal_planner_test.dart`, `ui/home_test.dart` «выбирает приём пищи по времени…» |
| Ручная правка цели | `app/lib/ui/home/target_sheet.dart` | `ui/home_test.dart` «даёт поправить цель вручную…» |
| «Подобрать рядом» → 3–5 вариантов | `NearbySearchController`, `POST /api/v1/combos/search` с `location` | `ui/home_test.dart`, `recommendation/ComboApiIT` «подбирает рядом по сетям…», E2E шаг «подбор рядом» |
| Пустой результат, ошибка сети, повтор | `_SearchResults` | `ui/home_test.dart` «честно говорит…», «показывает ошибку сети…» |
| Опция «подешевле» | `PricePreference.PREFER_CHEAPER` | `optimizer/ComboScorerTest` «учитывает цену только…», `ui/home_test.dart` |

## Карта (7.2.3, 6.1)

| Требование | Код | Тесты |
|---|---|---|
| Только заведения с данными, «показать все» | `GET /api/v1/venues?includeWithoutMenu`, `NearbyVenueRepository` | `geo/NearbyVenueRepositoryIT` «по умолчанию скрывает точки без меню…», `ui/tabs_test.dart` |
| Цвет точки: зелёный / жёлтый / серый | `VenueDirectoryService`, `FitLevel`, `map_screen.dart` | `recommendation/VenueApiIT` «красит точки…», «отмечает серым…», `ui/tabs_test.dart` «карта красит заведения…» |

## Экран заведения (7.2.4)

| Требование | Код | Тесты |
|---|---|---|
| Меню, отсортированное по близости к цели | `DishAssessor.assessMenu`, `GET /api/v1/venues/{id}/menu` | `recommendation/DishAssessorTest` «сортирует меню…», `VenueApiIT` «сортирует меню…» |
| Пометки «подходит / можно, но… / не подходит» с причиной | `DishAssessor`, `ReasonCode` | `DishAssessorTest`, `ui/venue_test.dart` «показывает меню с пометками…» |
| Значок достоверности A/B/C, дата проверки, диапазон для C | `TrustBadge`, `DataSource` | `ui/venue_test.dart`, E2E шаг «экран заведения» |
| «Собрать обед здесь» | `VenueComboController`, `POST /combos/search` с `venueId` | `ui/venue_test.dart`, `ComboApiIT` «подбирает наборы в заведении…», E2E |

## Результат подбора (7.2.5)

| Требование | Код | Тесты |
|---|---|---|
| Блюда, сумма КБЖУ, отклонение по каждому показателю, цена, достоверность набора | `ComboExplanation`, `combo_screen.dart` | `optimizer/MealRulesTest` «объясняет каждый показатель…», `ui/combo_test.dart`, E2E |
| «Заменить блюдо» с фиксацией остальных | `ComboOptimizer.replacements`, `POST /combos/replace` | `ComboOptimizerTest` «заменяет блюдо на той же позиции…», `ComboApiIT` «заменяет напиток…», `ui/combo_test.dart`, E2E |
| «Съел» — запись в дневник одним касанием | `DiaryActions.addCombo` | `ui/combo_test.dart`, E2E шаг «Записать в дневник» |

## Дневник и профиль (7.2.6, 6.2)

| Требование | Код | Тесты |
|---|---|---|
| Приёмы пищи за день, прогресс по каждому макросу | `diary_screen.dart`, `NutrientProgress` | `ui/tabs_test.dart` «дневник показывает прогресс…», `data/local_repositories_test.dart` |
| Избранное и история, «добавить снова» | `LocalDiaryRepository.watchQuickAdd`, `DiaryActions.addAgain` | `local_repositories_test.dart` «быстрое добавление…», `ui/tabs_test.dart` |
| Дневник и профиль только на устройстве | `LocalProfileRepository`, `LocalDiaryRepository` (drift) | `local_repositories_test.dart` |
| Удаление всех данных одной кнопкой | `ProfileController.deleteAllData` | `local_repositories_test.dart` «удаляет все данные…», `ui/tabs_test.dart` «профиль удаляет все данные…» |

## Алгоритм подбора (11)

| Требование | Код | Тесты |
|---|---|---|
| Жёсткие ограничения: калории ± допуск, белок ≥, жиры и углеводы ≤, без исключённых тегов | `MealTarget.isSatisfiedBy`, `MealTarget.allows` | `ComboOptimizerTest` (границы, ограничения, теги), свойства jqwik |
| Одно блюдо не больше двух раз; ≤ 1 основного и ≤ 1 напитка; соус только с блюдом | `MealStructure` | `ComboOptimizerTest`, `MealRulesTest` |
| Целевая функция: отклонение, штраф за уровень доверия (C ниже A и B), цена | `ComboScorer` | `ComboScorerTest`, `ComboOptimizerTest` «ставит блюдо с проверенными данными выше…» |
| Перебор с отсечением, куча limit × 4, диверсификация | `ComboOptimizer`, `ComboDiversifier` | `ComboOptimizerPropertiesTest` «перебор с отсечением даёт тот же ответ, что полный перебор» |
| Результаты отсортированы, ограничения соблюдены (свойства) | — | `ComboOptimizerPropertiesTest` (4 свойства × 200–300 случайных меню) |
| Производительность: 250 позиций, бюджет 100 мс | — | `ComboOptimizerPerformanceTest` (медиана ~7 мс), `docs/reports/optimizer-timing.csv` |
| Кэш лучшего набора по округлённой цели | `MenuComboCache`, `TargetRounding` | `TargetRoundingTest`, `ComboApiIT` «после обновления меню сети отдаёт новый подбор…» |

## Геопоиск (12)

| Требование | Код | Тесты |
|---|---|---|
| Точки в радиусе, ближайшие первыми, `ST_DWithin` + GiST | `NearbyVenueRepository`, `V1__catalog_and_intake.sql` | `NearbyVenueRepositoryIT` (порядок, радиус, лимит) |
| Порядок аргументов долгота/широта | `ST_MakePoint(:lon, :lat)` | `NearbyVenueRepositoryIT` «не путает широту и долготу» |
| План запроса через EXPLAIN ANALYZE на 10 тыс. точек | — | `NearbyVenueRepositoryIT` «геозапрос использует пространственный индекс…», `docs/reports/explain-nearby-venues.txt` |

## Данные, импорт, модерация (5, 10, 7.2.7)

| Требование | Код | Тесты |
|---|---|---|
| Импорт CSV меню сети (уровень A) с источником и датой | `CatalogImportService`, `MenuCsvParser` | `CatalogImportIT`, `MenuCsvParserTest`, E2E админки |
| Блюдо пропало с сайта сети → снимается из подбора | `MenuItemRepository.withdrawChainItemsExcept` | `CatalogImportIT` «при повторном импорте…снимает пропавшие…» |
| Импорт точек сети; точки, пропавшие из файла, закрываются | `VenueCsvParser`, `VenueRepository.upsertForChain`, `deactivateChainVenuesExcept` | `VenueCsvParserTest`, `CatalogImportIT`, E2E админки |
| CSV только в UTF-8 (с BOM или без) | `CsvEncoding` | `CatalogImportIT` |
| Фото меню → хранилище → OCR → очередь модерации | `MenuPhotoService`, `S3PhotoStorage`, `TesseractTextRecognizer`, `MenuOcrProcessor` | `intake/MenuPhotoApiIT` (реальный Tesseract и S3), E2E «модератор видит фото меню с распознанным текстом…» |
| Модерация: перенос строк в меню заведения (уровень B) или отклонение | `ModerationService` | `admin/AdminWebIT`, E2E админки |
| Жалоба «цифры не совпадают»; три жалобы разных людей → перепроверка | `ItemReportService`, `ReporterFingerprint`, `MenuItemService`, `ReviewService` | `intake/ItemReportApiIT` (дубли, параллельные жалобы, кэш), `AdminWebIT` «модератор разбирает жалобы…», E2E |
| Соусы — отдельные позиции | категория `sauce` | `MenuCsvParserTest`, `MealRulesTest` |
| Цена в копейках, `GEOGRAPHY`, массив тегов + GIN, частичные индексы | `V1__catalog_and_intake.sql` | `CatalogImportIT`, `NearbyVenueRepositoryIT` |

## API (13)

| Требование | Код | Тесты |
|---|---|---|
| `GET /api/v1/venues`, `GET /venues/{id}/menu`, `POST /combos/search`, `POST /combos/replace`, `POST /venues/{id}/menu-photos`, `POST /items/{id}/reports`, `/admin/**` под авторизацией | `recommendation/api`, `intake/api`, `admin` | `VenueApiIT`, `ComboApiIT`, `MenuPhotoApiIT`, `ItemReportApiIT`, `AdminWebIT` |
| Описание в Swagger | springdoc, `contract/openapi.json` | `contract/OpenApiContractIT` |
| Валидация: калории 100–2000, радиус до 5 км, ≤ 20 тегов | `MealTargetRequest`, `LocationRequest`, `VenueController` | `VenueApiIT` «проверяет координаты…», `ComboApiIT` «требует ровно одну область…» |
| Фото: до 8 МБ и 24 млн пикселей, проверка типа, без EXIF, лимит запросов на IP | `PhotoSanitizer`, `PhotoFormat`, `RateLimiter`, `ClientKey` | `MenuPhotoApiIT`, `HttpEdgeIT`, `PhotoFormatTest`, `RateLimiterTest`, `ClientKeyTest` |
| Защита входа в админку от перебора | `AdminLoginRateLimitFilter` | `AdminWebIT` |
| Объяснение для каждого показателя: значение, цель, отклонение | `MetricCheckResponse` | `ComboApiIT`, `MealRulesTest` |

## Обратный список: есть в коде, нет в документе

| Что | Зачем |
|---|---|
| `OCR_FAILED` | Без него заявка с нераспознаваемым фото навсегда осталась бы в очереди распознавания. |
| `appliedTarget` в ответе подбора | Клиент показывает и использует ту цель, по которой реально шёл поиск с кэшем. |
| `menu_version`, `under_review`, `resolved_at` | Версионирование кэша и жизненный цикл жалоб (раздел 5.6). |
| Профиль `demo` с вымышленным каталогом | Демонстрация без реальных данных сетей. |
