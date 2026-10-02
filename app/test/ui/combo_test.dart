import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:norma_ryadom/domain/models/catalog.dart';
import 'package:norma_ryadom/domain/models/combo.dart';
import 'package:norma_ryadom/domain/models/meal.dart';
import 'package:norma_ryadom/utils/result.dart';

import '../support/fakes.dart';
import '../support/pump_app.dart';

void main() {
  final chicken = TestData.dish(1, 'Куриная грудка гриль', 374);
  final mors = TestData.dish(2, 'Морс', 96, category: DishCategory.drink);
  final tea = TestData.dish(3, 'Чай', 0, category: DishCategory.drink);
  final juice = TestData.dish(4, 'Сок яблочный', 110, category: DishCategory.drink);

  Future<TestHarness> openCombo(WidgetTester tester) async {
    final harness = TestHarness(profile: TestData.profile)
      ..combos.nearbyResult = Ok(
        ComboSearchResult(
          appliedTarget: TestData.lunchTarget.copyWith(kcal: 650),
          options: [
            TestData.option([chicken, mors]),
          ],
        ),
      );
    await harness.pump(tester);
    await tester.tap(find.byKey(const Key('find-nearby')));
    await tester.pumpAndSettle();
    await tapVisible(tester, find.text('Куриная грудка гриль + Морс'));
    return harness;
  }

  testWidgets('объясняет попадание в цель по каждому показателю', (tester) async {
    await openCombo(tester);

    expect(find.text('Калории 470 из 630'), findsOneWidget);
    expect(find.text('Белок 40 г, нужно от 28 г'), findsOneWidget);
    expect(find.text('Жиры 26 г, цель до 24 г'), findsOneWidget);
    expect(find.text('больше на 2'), findsOneWidget);
    expect(find.text('537 ₽'), findsOneWidget);
    expect(find.text('данные сети'), findsWidgets);
  });

  testWidgets('заменяет блюдо, оставляя остальные, по той же цели поиска', (tester) async {
    final harness = await openCombo(tester);
    harness.combos.replaceResult = Ok(
      ComboSearchResult(
        appliedTarget: TestData.lunchTarget,
        options: [
          TestData.option([chicken, tea]),
          TestData.option([chicken, juice]),
        ],
      ),
    );

    await tester.tap(find.byKey(const Key('replace-1')));
    await tester.pumpAndSettle();
    expect(find.text('Чем заменить'), findsOneWidget);
    expect(harness.combos.replaceRequests.single.$1, [1, 2]);
    expect(harness.combos.replaceRequests.single.$2, 1);
    expect(harness.combos.replaceTargets.single, TestData.lunchTarget.copyWith(kcal: 650));
    expect(harness.combos.requestedVenues.single, TestData.venue.id);
    await tester.tap(find.text('Сок яблочный'));
    await tester.pumpAndSettle();

    expect(find.text('Чем заменить'), findsNothing);
    expect(find.text('Сок яблочный'), findsOneWidget);
    expect(find.text('Морс'), findsNothing);
    expect(find.text('Куриная грудка гриль'), findsOneWidget);
  });

  testWidgets('сообщает, если замены нет, и показывает ошибку замены', (tester) async {
    final harness = await openCombo(tester);

    await tester.tap(find.byKey(const Key('replace-0')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Подходящей замены нет'), findsOneWidget);

    harness.combos.replaceResult = const Err(AppFailure.rateLimited);
    await tester.tap(find.byKey(const Key('replace-0')));
    await tester.pumpAndSettle();
    expect(find.text('Слишком много запросов. Попробуйте чуть позже.'), findsOneWidget);
  });

  testWidgets('«Записать в дневник» сохраняет набор и открывает дневник', (tester) async {
    final harness = await openCombo(tester);

    await tester.tap(find.byKey(const Key('eat-combo')));
    await tester.pumpAndSettle();

    final entry = harness.diary.entries.single;
    expect(entry.title, 'Куриная грудка гриль + Морс');
    expect(entry.meal, MealType.lunch);
    expect(entry.venueName, 'Гриль Хаус, Москва-Сити');
    expect(entry.intake.kcal, 470);
    expect(find.text('Съедено'), findsOneWidget);
  });

  testWidgets('двойное нажатие «Записать в дневник» сохраняет набор один раз', (tester) async {
    final harness = await openCombo(tester);
    final gate = Completer<void>();
    harness.diary.gate = gate;

    await tester.tap(find.byKey(const Key('eat-combo')));
    await tester.pump();
    expect(tester.widget<ButtonStyleButton>(find.byKey(const Key('eat-combo'))).onPressed, isNull);
    await tester.tap(find.byKey(const Key('eat-combo')), warnIfMissed: false);
    gate.complete();
    await tester.pumpAndSettle();

    expect(harness.diary.entries, hasLength(1));
  });

  testWidgets('сообщает об ошибке записи и остаётся на экране набора', (tester) async {
    final harness = await openCombo(tester);
    harness.diary.writeError = Exception('disk full');

    await tester.tap(find.byKey(const Key('eat-combo')));
    await tester.pumpAndSettle();

    expect(harness.diary.entries, isEmpty);
    expect(find.text('Что-то пошло не так. Повторите попытку.'), findsOneWidget);
    expect(find.text('Попадание в цель'), findsOneWidget);
  });
}
