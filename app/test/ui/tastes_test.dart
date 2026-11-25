import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:norma_ryadom/domain/models/combo.dart';
import 'package:norma_ryadom/domain/models/diary.dart';
import 'package:norma_ryadom/domain/models/meal.dart';
import 'package:norma_ryadom/domain/models/nutrition_norm.dart';
import 'package:norma_ryadom/domain/models/taste.dart';
import 'package:norma_ryadom/utils/result.dart';

import '../support/fakes.dart';
import '../support/pump_app.dart';

void main() {
  Future<void> openTab(WidgetTester tester, String label) async {
    await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text(label)));
    await tester.pumpAndSettle();
  }

  Future<void> eat(TestHarness harness, String title, int daysAgo) => harness.diary.add(
    NewDiaryEntry(meal: MealType.lunch, title: title, intake: const Intake(kcal: 400, protein: 20, fat: 15, carbs: 40)),
    harness.now.subtract(Duration(days: daysAgo)),
  );

  testWidgets('из профиля открывает «Ваши вкусы» и сохраняет любимую еду', (tester) async {
    final harness = TestHarness(profile: TestData.profile);
    await harness.pump(tester);
    await openTab(tester, 'Профиль');

    await tapVisible(tester, find.byKey(const Key('open-tastes')));
    await tester.tap(find.byKey(const Key('taste-SOUP')));
    await tester.pumpAndSettle();

    expect(find.text('Что вы любите'.toUpperCase()), findsOneWidget);
    expect(harness.profiles.profile?.likedTastes, {TasteTag.soup});
  });

  testWidgets('показывает, что подбор заметил по дневнику', (tester) async {
    final harness = TestHarness(profile: TestData.profile);
    await eat(harness, 'Борщ со сметаной', 1);
    await eat(harness, 'Крем-суп грибной + Морс', 3);
    await eat(harness, 'Солянка', 5);
    await eat(harness, 'Хачапури по-аджарски', 20);
    await harness.pump(tester);
    await openTab(tester, 'Профиль');

    await tapVisible(tester, find.byKey(const Key('open-tastes')));

    expect(find.byKey(const Key('learned-SOUP')), findsOneWidget);
    expect(find.text('3 раза за 2 недели'), findsOneWidget);
    expect(find.byKey(const Key('learned-GEORGIAN')), findsNothing);
  });

  testWidgets('без записей подсказывает вести дневник', (tester) async {
    final harness = TestHarness(profile: TestData.profile);
    await harness.pump(tester);
    await openTab(tester, 'Профиль');

    await tapVisible(tester, find.byKey(const Key('open-tastes')));

    expect(find.text('Записывайте приёмы пищи — подбор начнёт узнавать ваши вкусы'), findsOneWidget);
  });

  testWidgets('выученные вкусы уходят в подбор, пока включено «Учитывать дневник»', (tester) async {
    final harness = TestHarness(profile: TestData.profile.copyWith(likedTastes: {TasteTag.fish}));
    for (final daysAgo in [1, 2, 3]) {
      await eat(harness, 'Борщ', daysAgo);
    }
    await harness.pump(tester);

    await tapVisible(tester, find.byKey(const Key('find-nearby')));
    expect(harness.combos.requestedTastes.single, {TasteTag.fish, TasteTag.soup});

    await openTab(tester, 'Профиль');
    await tapVisible(tester, find.byKey(const Key('open-tastes')));
    await tapVisible(tester, find.byKey(const Key('learn-tastes')));
    expect(harness.profiles.profile?.learnTastes, isFalse);
    await openTab(tester, 'Что взять');
    await tapVisible(tester, find.byKey(const Key('find-nearby')));

    expect(harness.combos.requestedTastes.last, {TasteTag.fish});
  });

  testWidgets('плашка над выдачей показывает учтённые вкусы и ведёт к их настройке', (tester) async {
    final harness = TestHarness(profile: TestData.profile.copyWith(likedTastes: {TasteTag.georgian, TasteTag.soup}))
      ..combos.nearbyResult = Ok(
        ComboSearchResult(
          appliedTarget: TestData.lunchTarget,
          options: [
            TestData.option([TestData.dish(1, 'Хачапури', 520)]),
          ],
        ),
      );
    await harness.pump(tester);

    await tapVisible(tester, find.byKey(const Key('find-nearby')));
    await scrollTo(tester, find.byKey(const Key('tastes-banner')));

    expect(find.text('Учитываем ваши вкусы: супы, грузинская кухня'), findsOneWidget);
    await tapVisible(tester, find.byKey(const Key('tastes-edit')));
    expect(find.text('Ваши вкусы'), findsOneWidget);
  });

  testWidgets('без вкусов плашку над выдачей не показывает', (tester) async {
    final harness = TestHarness(profile: TestData.profile)
      ..combos.nearbyResult = Ok(
        ComboSearchResult(
          appliedTarget: TestData.lunchTarget,
          options: [
            TestData.option([TestData.dish(1, 'Хачапури', 520)]),
          ],
        ),
      );
    await harness.pump(tester);

    await tapVisible(tester, find.byKey(const Key('find-nearby')));
    await scrollTo(tester, find.byKey(const Key('search-results')));

    expect(find.byKey(const Key('tastes-banner')), findsNothing);
  });

  testWidgets('неделя в дневнике показывает столбики и итоги', (tester) async {
    final harness = TestHarness(profile: TestData.profile);
    await eat(harness, 'Борщ', 0);
    await eat(harness, 'Борщ', 1);
    await eat(harness, 'Сырники', 2);
    await harness.pump(tester);
    await openTab(tester, 'Дневник');

    await tester.tap(find.byKey(const Key('diary-mode-week')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('week-chart')), findsOneWidget);
    expect(find.text('В среднем 400 ккал в день'), findsOneWidget);
    expect(find.text('Дней в норме: 0 из 3'), findsOneWidget);
    expect(find.text('Чаще всего: Борщ (2 раза)'), findsOneWidget);
    expect(find.byKey(const Key('diary-add-manual')), findsNothing);
  });

  testWidgets('пустая неделя подсказывает вести дневник и возвращается к дню', (tester) async {
    final harness = TestHarness(profile: TestData.profile);
    await harness.pump(tester);
    await openTab(tester, 'Дневник');

    await tester.tap(find.byKey(const Key('diary-mode-week')));
    await tester.pumpAndSettle();
    expect(find.text('Записывайте приёмы пищи — здесь появится неделя'), findsOneWidget);

    await tester.tap(find.byKey(const Key('diary-mode-day')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('diary-add-manual')), findsOneWidget);
  });
}
