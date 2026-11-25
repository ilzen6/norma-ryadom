# Релизная сборка и публикация

## Ключ подписи

Ключ создаётся один раз и хранится вне репозитория (`*.jks` и `app/android/key.properties` в `.gitignore`):

```bash
keytool -genkeypair -v -keystore ~/norma-ryadom-upload.jks -alias upload -keyalg RSA -keysize 2048 -validity 10000
```

Для локальной сборки рядом с `app/android/build.gradle.kts` кладётся `app/android/key.properties`:

```
storeFile=/Users/.../norma-ryadom-upload.jks
storePassword=...
keyAlias=upload
keyPassword=...
```

Без этого файла релизная сборка подписывается отладочным ключом — так работают CI и демо-APK.

## Сборка

```bash
cd app && flutter build appbundle --release --flavor store --dart-define=DEMO_SERVER=true --dart-define=TILE_URL_TEMPLATE=
```

Сборка для RuStore работает на встроенном демо-каталоге (публичного сервера у курсового проекта нет). Версия — `version` в `app/pubspec.yaml` (`1.0.0+10`: имя версии и номер сборки, номер растёт с каждой загрузкой).

## Иконка и заставка

Исходники — `app/assets/brand/` (генерирует `tool/brand/make_icons.py`, нужен Pillow). Платформенные файлы обновляются командами:

```bash
cd app && dart run flutter_launcher_icons && dart run flutter_native_splash:create
```

После `flutter_launcher_icons` надо откатить его правку `ios/Runner.xcodeproj/project.pbxproj` (он ошибочно меняет `ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS`).

## Политика конфиденциальности

Текст — `docs/privacy.md`. Перед публикацией в нём и на странице `/privacy` нужно заменить «[ДАТА ПУБЛИКАЦИИ]» и «[ПОЧТА ДЛЯ СВЯЗИ]».
