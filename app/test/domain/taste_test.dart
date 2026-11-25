import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:norma_ryadom/domain/models/diary.dart';
import 'package:norma_ryadom/domain/models/meal.dart';
import 'package:norma_ryadom/domain/models/nutrition_norm.dart';
import 'package:norma_ryadom/domain/models/taste.dart';

void main() {
  final contract = jsonDecode(File('../contract/taste-cases.json').readAsStringSync()) as Map<String, dynamic>;

  DiaryEntry entry(String title, {int id = 1}) => DiaryEntry(
    id: id,
    day: DateTime(2026, 11, 20),
    meal: MealType.lunch,
    title: title,
    intake: Intake.zero,
    createdAt: DateTime(2026, 11, 20, 13),
  );

  test('вкусы блюд совпадают с сервером на всём демо-каталоге', () {
    final dishes = (contract['dishes'] as List<dynamic>).cast<Map<String, dynamic>>();

    expect(dishes, hasLength(greaterThan(1000)));
    for (final dish in dishes) {
      expect(
        [
          for (final taste in TasteTag.ofDish(
            dish['name'] as String,
            category: dish['category'] as String,
            tags: (dish['tags'] as List<dynamic>).cast<String>(),
          ))
            taste.code,
        ],
        dish['tastes'],
        reason: dish['name'] as String,
      );
    }
  });

  test('вкусы по виду заведения совпадают с сервером', () {
    final kinds = (contract['venueKinds'] as Map<String, dynamic>).cast<String, List<dynamic>>();

    for (final MapEntry(key: kind, value: tastes) in kinds.entries) {
      expect([for (final taste in TasteTag.ofVenueKind(kind)) taste.code], tastes, reason: kind);
    }
  });

  test('короткие слова узнаёт только целиком', () {
    expect(TasteTag.ofDish('Уха по-фински'), {TasteTag.soup});
    expect(TasteTag.ofDish('Фокачча'), isEmpty);
  });

  test('в записи дневника считает вкус один раз, даже если он у нескольких блюд', () {
    final counts = TasteLearning.countByTaste([entry('Борщ + Солянка')]);

    expect(counts, {TasteTag.soup: 1});
  });

  test('сортирует выученные вкусы по частоте', () {
    final counts = TasteLearning.countByTaste([
      entry('Хачапури по-аджарски', id: 1),
      entry('Борщ + Хинкали', id: 2),
      entry('Борщ', id: 3),
      entry('Суп-лапша', id: 4),
    ]);

    expect(counts.keys.first, TasteTag.soup);
    expect(counts[TasteTag.soup], 3);
    expect(counts[TasteTag.georgian], 2);
  });

  test('учитывает вкус, только если он встретился не меньше трёх раз', () {
    expect(TasteLearning.learned({TasteTag.soup: 3, TasteTag.georgian: 2}), {TasteTag.soup});
  });
}
