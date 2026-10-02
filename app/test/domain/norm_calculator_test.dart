import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:norma_ryadom/domain/models/nutrition_norm.dart';
import 'package:norma_ryadom/domain/models/profile.dart';
import 'package:norma_ryadom/domain/nutrition/norm_calculator.dart';

void main() {
  const calculator = NormCalculator();

  group('расчёт нормы совпадает с общими контрольными примерами сервера', () {
    final cases =
        (jsonDecode(File('../contract/norm-cases.json').readAsStringSync()) as Map<String, dynamic>)['cases']
            as List<dynamic>;

    test('контрольных примеров не меньше восьми', () => expect(cases.length, greaterThanOrEqualTo(8)));

    for (final raw in cases) {
      final input = (raw as Map<String, dynamic>)['input'] as Map<String, dynamic>;
      final expected = raw['expected'] as Map<String, dynamic>;
      test('$input', () {
        final profile = UserProfile(
          sex: Sex.values.byName(input['sex'] as String),
          age: input['age'] as int,
          heightCm: input['heightCm'] as int,
          weightKg: (input['weightKg'] as num).toDouble(),
          activity: switch (input['activity'] as String) {
            'very_high' => ActivityLevel.veryHigh,
            final name => ActivityLevel.values.byName(name),
          },
          goal: Goal.values.byName(input['goal'] as String),
        );

        final result = calculator.calculate(profile);

        expect(result.bmr, closeTo((expected['bmr'] as num).toDouble(), 0.01));
        expect(result.tdee, closeTo((expected['tdee'] as num).toDouble(), 0.01));
        expect(
          result.norm,
          NutritionNorm(
            kcal: expected['kcal'] as int,
            protein: expected['protein'] as int,
            fat: expected['fat'] as int,
            carbs: expected['carbs'] as int,
          ),
        );
      });
    }
  });

  test('поднимает норму до безопасного минимума и сообщает об этом', () {
    const profile = UserProfile(
      sex: Sex.male,
      age: 70,
      heightCm: 160,
      weightKg: 50,
      activity: ActivityLevel.sedentary,
      goal: Goal.lose,
    );

    final result = calculator.calculate(profile);

    expect(result.norm.kcal, 1500);
    expect(result.limitedBySafeMinimum, isTrue);
  });

  test('ручная норма заменяет расчётную, но не ниже безопасного минимума', () {
    const manual = NutritionNorm(kcal: 2000, protein: 120, fat: 60, carbs: 230);
    const profile = UserProfile(
      sex: Sex.female,
      age: 25,
      heightCm: 165,
      weightKg: 62,
      activity: ActivityLevel.moderate,
      goal: Goal.lose,
      manualNorm: manual,
    );

    expect(calculator.effectiveNorm(profile), manual);
    expect(calculator.isSafeManualNorm(Sex.female, manual), isTrue);
    expect(calculator.isSafeManualNorm(Sex.female, manual.copyWith(kcal: 1199)), isFalse);
    expect(calculator.isSafeManualNorm(Sex.male, manual.copyWith(kcal: 1499)), isFalse);
    expect(calculator.isSafeManualNorm(Sex.male, manual.copyWith(protein: -1)), isFalse);
  });

  test('остаток нормы считается как норма минус съеденное', () {
    const norm = NutritionNorm(kcal: 1800, protein: 99, fat: 56, carbs: 225);
    const eaten = Intake(kcal: 661, protein: 40.4, fat: 21.2, carbs: 78.6);

    expect(norm.minus(eaten + Intake.zero), const NutritionNorm(kcal: 1139, protein: 59, fat: 35, carbs: 146));
  });
}
