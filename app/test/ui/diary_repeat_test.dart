import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:norma_ryadom/domain/models/diary.dart';
import 'package:norma_ryadom/domain/models/meal.dart';
import 'package:norma_ryadom/domain/models/nutrition_norm.dart';
import 'package:norma_ryadom/data/repositories/diary_repository.dart';

import '../support/fakes.dart';
import '../support/pump_app.dart';

void main() {
  Future<void> openDiary(WidgetTester tester) async {
    await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text('Дневник')));
    await tester.pumpAndSettle();
  }

  Future<void> eat(TestHarness harness, MealType meal, String title, double kcal, {int daysAgo = 1}) =>
      harness.diary.add(
        NewDiaryEntry(
          meal: meal,
          title: title,
          intake: Intake(kcal: kcal, protein: 10, fat: 10, carbs: 30),
        ),
        harness.now.subtract(Duration(days: daysAgo)),
      );

  List<DiaryEntry> today(TestHarness harness) => [
    for (final entry in harness.diary.entries)
      if (LocalDiaryRepository.dayKey(entry.day) == LocalDiaryRepository.dayKey(harness.now)) entry,
  ];

  testWidgets('у пустого приёма предлагает повторить вчерашний и записывает копии одним касанием', (tester) async {
    final harness = TestHarness(profile: TestData.profile);
    await eat(harness, MealType.lunch, 'Борщ со сметаной', 330);
    await eat(harness, MealType.lunch, 'Хлеб бородинский', 182);
    await harness.pump(tester);
    await openDiary(tester);

    expect(find.text('Повторить вчерашний обед · 512 ккал'), findsOneWidget);
    await tapVisible(tester, find.byKey(const Key('repeat-lunch')));

    expect(today(harness).map((entry) => (entry.meal, entry.title)), [
      (MealType.lunch, 'Борщ со сметаной'),
      (MealType.lunch, 'Хлеб бородинский'),
    ]);
    expect(find.text('Записано'), findsOneWidget);
    expect(find.byKey(const Key('repeat-lunch')), findsNothing);
  });

  testWidgets('«Отменить» убирает повторённые записи', (tester) async {
    final harness = TestHarness(profile: TestData.profile);
    await eat(harness, MealType.dinner, 'Гречка с котлетой', 540);
    await harness.pump(tester);
    await openDiary(tester);

    await tapVisible(tester, find.byKey(const Key('repeat-dinner')));
    expect(today(harness), hasLength(1));
    await tester.tap(find.text('Отменить'));
    await tester.pumpAndSettle();

    expect(today(harness), isEmpty);
    await scrollTo(tester, find.byKey(const Key('repeat-dinner')));
    expect(find.byKey(const Key('repeat-dinner')), findsOneWidget);
  });

  testWidgets('не предлагает повторить, если вчера этого приёма не было', (tester) async {
    final harness = TestHarness(profile: TestData.profile);
    await eat(harness, MealType.breakfast, 'Сырники', 420);
    await eat(harness, MealType.lunch, 'Плов', 650, daysAgo: 2);
    await harness.pump(tester);
    await openDiary(tester);

    expect(find.byKey(const Key('repeat-lunch')), findsNothing);
    await scrollTo(tester, find.byKey(const Key('repeat-breakfast')));
    expect(find.byKey(const Key('repeat-breakfast')), findsOneWidget);
  });

  testWidgets('не предлагает повторить приём, который сегодня уже записан', (tester) async {
    final harness = TestHarness(profile: TestData.profile);
    await eat(harness, MealType.lunch, 'Борщ', 330);
    await eat(harness, MealType.lunch, 'Салат', 150, daysAgo: 0);
    await harness.pump(tester);
    await openDiary(tester);

    expect(find.byKey(const Key('repeat-lunch')), findsNothing);
  });

  testWidgets('если записать не получилось, сообщает об ошибке и ничего не оставляет', (tester) async {
    final harness = TestHarness(profile: TestData.profile);
    await eat(harness, MealType.lunch, 'Борщ', 330);
    await harness.pump(tester);
    await openDiary(tester);
    harness.diary.writeError = Exception('нет места');

    await tapVisible(tester, find.byKey(const Key('repeat-lunch')));

    expect(today(harness), isEmpty);
    expect(find.text('Записано'), findsNothing);
  });
}
