# Норма рядом — правила проекта

## Обязательно
- Никаких комментариев в коде (Kotlin, Dart, TypeScript, SQL, YAML, Gradle, Dockerfile, HTML, CSS). Пояснения — в `docs/`.
- Язык интерфейса, сообщений об ошибках и имён тестов — русский; идентификаторы — английские.
- Тексты клиента только через `app/lib/l10n/app_ru.arb`; тексты админки — в шаблонах и `messages.properties`.
- Версии зависимостей точные (Gradle, `pubspec.yaml`, `package.json`).

## Команды
- Сервер: `cd server && LANG=C.UTF-8 ./gradlew check` (тесты, ktlint, detekt, Kover). Нужен Docker (Testcontainers) и Tesseract с `rus`.
- Обновить контракт API: `./gradlew test --tests '*OpenApiContractIT' -PupdateContract=true`.
- Клиент: `cd app && dart run build_runner build --delete-conflicting-outputs && flutter analyze --fatal-infos && flutter test --coverage && dart run tool/check_coverage.dart 90`.
- E2E: `./scripts/e2e.sh` (Docker, Flutter, Node 22).

## Структура
- `server/src/main/kotlin/ru/normaryadom/`: `catalog` (данные, импорт), `geo`, `optimizer` (чистый алгоритм без Spring), `recommendation` (сценарии подбора и API), `intake` (фото, OCR, жалобы), `admin` (Thymeleaf), `web` (Problem Details), `common`.
- Границы модулей проверяет `ArchitectureTest`: `optimizer` не зависит от Spring и SQL, циклов между модулями нет, контроллеры не ходят в репозитории.
- `app/lib/`: `domain` (модели, расчёт нормы), `data` (сервисы, репозитории, drift), `ui/<экран>` (View + ViewModel на Riverpod), `routing`.

## Тесты
- Имена — русская фраза в третьем лице («подбирает…», «не даёт…»), одно правило на тест.
- Сервер: интеграционные тесты наследуют `IntegrationTest` (PostGIS + SeaweedFS), данные готовят через `CatalogFixtures`.
- Клиент: виджет-тесты через `TestHarness` с фейками из `test/support/fakes.dart`.
