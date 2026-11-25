import 'package:flutter_test/flutter_test.dart';
import 'package:norma_ryadom/domain/models/diary.dart';
import 'package:norma_ryadom/domain/models/meal.dart';
import 'package:norma_ryadom/domain/models/nutrition_norm.dart';
import 'package:norma_ryadom/domain/nutrition/week_summary.dart';

void main() {
  const norm = NutritionNorm(kcal: 2000, protein: 100, fat: 60, carbs: 250);
  final today = DateTime(2026, 11, 26);
  var nextId = 1;

  DiaryEntry entry(int daysAgo, double kcal, {String title = 'Обед', double protein = 50}) => DiaryEntry(
    id: nextId++,
    day: DateTime(today.year, today.month, today.day - daysAgo),
    meal: MealType.lunch,
    title: title,
    intake: Intake(kcal: kcal, protein: protein, fat: 20, carbs: 100),
    createdAt: today,
  );

  test('берёт семь последних дней, заканчивая сегодняшним', () {
    final week = WeekSummary.of([entry(0, 500), entry(7, 900)], today: today, norm: norm);

    expect(week.days, hasLength(7));
    expect(week.days.first.day, DateTime(2026, 11, 20));
    expect(week.days.last.kcal, 500);
    expect(week.recorded, hasLength(1));
  });

  test('считает среднее только по дням с записями', () {
    final week = WeekSummary.of(
      [entry(0, 1800), entry(1, 1200, protein: 70), entry(1, 400, protein: 30)],
      today: today,
      norm: norm,
    );

    expect(week.averageKcal, 1700);
    expect(week.averageProtein, 75);
  });

  test('день в норме — от 85 до 105 процентов калорий, перебор больше 5 процентов выделяется', () {
    final week = WeekSummary.of(
      [entry(0, 1700), entry(1, 2100), entry(2, 2101), entry(3, 1600)],
      today: today,
      norm: norm,
    );

    expect(week.daysInNorm, 2);
    expect(week.isOver(week.days.last), isFalse);
    expect(week.isOver(week.days[4]), isTrue);
  });

  test('называет блюдо, которое ели чаще всего, если оно повторялось', () {
    final repeated = WeekSummary.of(
      [entry(0, 500, title: 'Борщ'), entry(1, 500, title: 'Борщ'), entry(2, 500, title: 'Сырники')],
      today: today,
      norm: norm,
    );
    final single = WeekSummary.of(
      [entry(0, 500, title: 'Борщ')],
      today: today,
      norm: norm,
    );

    expect(repeated.favorite, (title: 'Борщ', times: 2));
    expect(single.favorite, isNull);
  });

  test('без записей неделя пустая', () {
    expect(WeekSummary.of(const [], today: today, norm: norm).isEmpty, isTrue);
  });
}
