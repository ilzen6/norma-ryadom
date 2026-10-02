import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:norma_ryadom/data/services/norma_api.dart';
import 'package:norma_ryadom/domain/models/combo.dart';
import 'package:norma_ryadom/domain/models/diary.dart';
import 'package:norma_ryadom/domain/models/district.dart';
import 'package:norma_ryadom/domain/models/geo_location.dart';
import 'package:norma_ryadom/domain/models/meal.dart';
import 'package:norma_ryadom/domain/models/nutrition_norm.dart';
import 'package:norma_ryadom/utils/result.dart';

import '../support/fakes.dart';
import '../support/pump_app.dart';

void main() {
  final options = [
    TestData.option([TestData.dish(1, 'Куриная грудка гриль', 374), TestData.dish(2, 'Рис с овощами', 207)]),
    TestData.option([TestData.dish(3, 'Боул с курицей', 446), TestData.dish(4, 'Морс', 96)], distance: 167),
    TestData.option([TestData.dish(5, 'Сэндвич с индейкой', 362)], distance: 224),
  ];

  testWidgets('показывает остаток на сегодня с учётом дневника', (tester) async {
    final harness = TestHarness(profile: TestData.profile);
    await harness.diary.add(
      const NewDiaryEntry(
        meal: MealType.breakfast,
        title: 'Сырники',
        intake: Intake(kcal: 400, protein: 20, fat: 15, carbs: 45),
      ),
      harness.now,
    );
    await harness.pump(tester);

    expect(find.bySemanticsLabel(RegExp('1400 ккал, белок 79 г')), findsOneWidget);
  });

  testWidgets('выбирает приём пищи по времени и пересчитывает цель при переключении', (tester) async {
    final harness = TestHarness(profile: TestData.profile);
    await harness.pump(tester);

    expect(find.bySemanticsLabel(RegExp('≈ 630 ккал ± 63')), findsOneWidget);
    await tester.tap(find.byKey(const Key('meal-breakfast')));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel(RegExp('≈ 450 ккал ± 50')), findsOneWidget);
  });

  testWidgets('подбирает варианты рядом и открывает набор', (tester) async {
    final harness = TestHarness(profile: TestData.profile)
      ..combos.nearbyResult = Ok(ComboSearchResult(appliedTarget: TestData.lunchTarget, options: options));
    await harness.pump(tester);

    expect(find.byKey(const Key('how-it-works')), findsOneWidget);
    await tester.tap(find.byKey(const Key('prefer-cheaper')));
    await tester.tap(find.byKey(const Key('find-nearby')));
    await tester.pumpAndSettle();

    await scrollTo(tester, find.text('167 м · 3 мин'));
    expect(find.bySemanticsLabel(RegExp('Куриная грудка гриль \\+ Рис с овощами')), findsOneWidget);
    expect(find.text('167 м · 3 мин'), findsOneWidget);
    expect(harness.combos.requestedPrices.single, PricePreference.cheaper);
    expect(harness.combos.requestedTargets.single.excludeTags, isEmpty);
    expect(harness.combos.requestedLocations.single, TestData.deviceLocation);
    await tapVisible(tester, find.text('Боул с курицей'));
    expect(find.text('Попадание в цель'), findsOneWidget);
  });

  testWidgets('честно говорит, когда рядом нет подходящих наборов', (tester) async {
    final harness = TestHarness(profile: TestData.profile);
    await harness.pump(tester);

    await tester.tap(find.byKey(const Key('find-nearby')));
    await tester.pumpAndSettle();

    await scrollTo(tester, find.textContaining('Рядом нет наборов под эту цель'));
    expect(find.textContaining('Рядом нет наборов под эту цель'), findsOneWidget);
  });

  testWidgets('показывает ошибку сети и повторяет запрос по кнопке', (tester) async {
    final harness = TestHarness(profile: TestData.profile)..combos.nearbyResult = const Err(AppFailure.offline);
    await harness.pump(tester);

    await tester.tap(find.byKey(const Key('find-nearby')));
    await tester.pumpAndSettle();
    await scrollTo(tester, find.text('Нет связи с сервером. Проверьте интернет и адрес сервера в профиле.'));
    expect(find.text('Нет связи с сервером. Проверьте интернет и адрес сервера в профиле.'), findsOneWidget);

    harness.combos.nearbyResult = Ok(ComboSearchResult(appliedTarget: TestData.lunchTarget, options: options));
    await tapVisible(tester, find.text('Повторить'));
    await scrollTo(tester, find.byKey(const Key('search-results')));
    expect(find.byKey(const Key('search-results')), findsOneWidget);
  });

  testWidgets('даёт поправить цель вручную с проверкой границ', (tester) async {
    final harness = TestHarness(profile: TestData.profile);
    await harness.pump(tester);

    await tester.tap(find.byKey(const Key('edit-target')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('target-kcal')), '5000');
    await tester.tap(find.byKey(const Key('target-save')));
    await tester.pumpAndSettle();
    expect(find.text('Допустимо от 100 до 2000'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('target-kcal')), '500');
    await tester.tap(find.byKey(const Key('target-save')));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel(RegExp('≈ 500 ккал ± 63')), findsOneWidget);

    await tester.tap(find.byKey(const Key('find-nearby')));
    await tester.pumpAndSettle();
    expect(harness.combos.requestedTargets.single.kcal, 500);
  });

  testWidgets('при отказе в геолокации ищет от выбранного района и предупреждает', (tester) async {
    final harness = TestHarness(profile: TestData.profile.copyWith(district: District.arbat))
      ..location.result = const Err(AppFailure.locationUnavailable);
    await harness.pump(tester);

    expect(find.text('Не удалось определить местоположение — используем выбранный район.'), findsOneWidget);
    await tester.tap(find.byKey(const Key('find-nearby')));
    await tester.pumpAndSettle();
    final location = harness.combos.requestedLocations.single;
    expect(
      (location.lat, location.lon, location.source),
      (District.arbat.lat, District.arbat.lon, LocationSource.district),
    );
  });

  testWidgets('не показывает устаревший результат, если цель сменилась во время поиска', (tester) async {
    final gate = Completer<void>();
    final harness = TestHarness(profile: TestData.profile)
      ..combos.nearbyResult = Ok(ComboSearchResult(appliedTarget: TestData.lunchTarget, options: options))
      ..combos.gate = gate;
    await harness.pump(tester);

    await tester.tap(find.byKey(const Key('find-nearby')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('meal-dinner')));
    await tester.pump();
    gate.complete();
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('search-results')), findsNothing);
    expect(find.byKey(const Key('how-it-works')), findsOneWidget);
  });
}
