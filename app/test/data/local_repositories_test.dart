import 'dart:convert';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:norma_ryadom/data/local/app_database.dart';
import 'package:norma_ryadom/data/repositories/diary_repository.dart';
import 'package:norma_ryadom/data/repositories/profile_repository.dart';
import 'package:norma_ryadom/data/repositories/settings_repository.dart';
import 'package:norma_ryadom/domain/models/diary.dart';
import 'package:norma_ryadom/domain/models/diet_preference.dart';
import 'package:norma_ryadom/domain/models/district.dart';
import 'package:norma_ryadom/domain/models/meal.dart';
import 'package:norma_ryadom/domain/models/nutrition_norm.dart';

import '../support/fakes.dart';

void main() {
  late AppDatabase database;

  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  setUp(() => database = AppDatabase(NativeDatabase.memory()));

  tearDown(() => database.close());

  test('сохраняет и читает профиль с предпочтениями, районом и ручной нормой', () async {
    final repository = LocalProfileRepository(database);
    final profile = TestData.profile.copyWith(
      preferences: {DietPreference.noPork, DietPreference.noNuts},
      district: District.arbat,
      manualNorm: const NutritionNorm(kcal: 1900, protein: 100, fat: 60, carbs: 230),
    );

    expect(await repository.load(), isNull);
    await repository.save(profile);
    await repository.save(profile.copyWith(age: 26));

    expect(await repository.load(), profile.copyWith(age: 26));
  });

  test('удаляет все данные пользователя одной операцией', () async {
    final profiles = LocalProfileRepository(database);
    final diary = LocalDiaryRepository(database);
    await profiles.save(TestData.profile);
    await diary.add(_entry('Обед'), DateTime(2026, 10, 2, 13));

    await profiles.deleteAllData();

    expect(await profiles.load(), isNull);
    expect(await diary.watchDay(DateTime(2026, 10, 2)).first, isEmpty);
  });

  test('дневник показывает записи только выбранного дня', () async {
    final diary = LocalDiaryRepository(database);
    await diary.add(_entry('Вчерашний ужин', meal: MealType.dinner), DateTime(2026, 10, 1, 20));
    await diary.add(_entry('Обед'), DateTime(2026, 10, 2, 13));

    final today = await diary.watchDay(DateTime(2026, 10, 2, 23, 59)).first;

    expect(today.map((entry) => entry.title), ['Обед']);
    expect(today.single.meal, MealType.lunch);
    expect(today.single.intake.kcal, 600);
    expect(today.single.venueName, 'Гриль');
  });

  test('быстрое добавление - сначала избранное, без повторов названий', () async {
    final diary = LocalDiaryRepository(database);
    await diary.add(_entry('Боул'), DateTime(2026, 10, 1, 13));
    await diary.add(_entry('Сырники'), DateTime(2026, 10, 2, 9));
    await diary.add(_entry('Боул'), DateTime(2026, 10, 2, 13));
    final syrniki = (await diary.watchDay(DateTime(2026, 10, 2)).first).firstWhere((entry) => entry.title == 'Сырники');
    await diary.setFavorite(syrniki.id, favorite: true);

    final quick = await diary.watchQuickAdd(limit: 5).first;

    expect(quick.map((entry) => entry.title), ['Сырники', 'Боул']);
    expect(quick.first.favorite, isTrue);
  });

  test('удаляет запись дневника', () async {
    final diary = LocalDiaryRepository(database);
    await diary.add(_entry('Обед'), DateTime(2026, 10, 2, 13));
    final entry = (await diary.watchDay(DateTime(2026, 10, 2)).first).single;

    await diary.remove(entry.id);

    expect(await diary.watchDay(DateTime(2026, 10, 2)).first, isEmpty);
  });

  test('формирует ключ дня с ведущими нулями', () {
    expect(LocalDiaryRepository.dayKey(DateTime(2026, 3, 7, 23, 59)), '2026-03-07');
  });

  test('сохраняет адрес сервера и перезаписывает его', () async {
    final repository = LocalSettingsRepository(database);

    expect(await repository.serverAddress(), isNull);
    await repository.saveServerAddress('http://192.168.1.5:8080');
    await repository.saveServerAddress('https://norma.example.ru');

    expect(await repository.serverAddress(), 'https://norma.example.ru');
  });

  test('обновляет базу первой версии, не теряя профиль', () async {
    final legacy = AppDatabase(
      NativeDatabase.memory(
        setup: (raw) {
          raw
            ..execute('CREATE TABLE profile_records (id INTEGER NOT NULL PRIMARY KEY, json TEXT NOT NULL)')
            ..execute(
              'CREATE TABLE diary_records (id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT, day TEXT NOT NULL, '
              'meal TEXT NOT NULL, title TEXT NOT NULL, venue_name TEXT NULL, kcal REAL NOT NULL, '
              'protein REAL NOT NULL, fat REAL NOT NULL, carbs REAL NOT NULL, created_at INTEGER NOT NULL, '
              'favorite INTEGER NOT NULL DEFAULT 0 CHECK (favorite IN (0, 1)))',
            )
            ..execute('INSERT INTO profile_records (id, json) VALUES (1, ?)', [jsonEncode(TestData.profile.toJson())])
            ..userVersion = 1;
        },
      ),
    );
    addTearDown(legacy.close);

    expect(await LocalProfileRepository(legacy).load(), TestData.profile);
    await LocalSettingsRepository(legacy).saveServerAddress('https://norma.example.ru');
    expect(await LocalSettingsRepository(legacy).serverAddress(), 'https://norma.example.ru');
  });
}

NewDiaryEntry _entry(String title, {MealType meal = MealType.lunch}) => NewDiaryEntry(
  meal: meal,
  title: title,
  venueName: 'Гриль',
  intake: const Intake(kcal: 600, protein: 40, fat: 20, carbs: 60),
);
