import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:norma_ryadom/domain/models/catalog.dart';
import 'package:norma_ryadom/domain/models/combo.dart';
import 'package:norma_ryadom/utils/result.dart';

import '../support/fakes.dart';
import '../support/layout_audit.dart';
import '../support/pump_app.dart';

void main() {
  final longVenue = TestData.venue.copyWith(
    name: 'Столовая Ложка, Большая Серпуховская',
    address: 'ул. Большая Серпуховская, 12/11 с2',
  );
  final options = [
    TestData.option(
      [
        TestData.dish(1, 'Сэндвич с курицей и песто на чиабатте', 374),
        TestData.dish(2, 'Рис с овощами', 207, category: DishCategory.side),
        TestData.dish(2, 'Рис с овощами', 207, category: DishCategory.side),
      ],
      venue: longVenue,
      distance: 1480,
    ),
    TestData.option([TestData.dish(3, 'Боул с курицей', 446), TestData.dish(4, 'Морс', 96)], distance: 167),
  ];
  final menu = VenueMenu(
    venue: longVenue,
    items: [
      MenuItem(
        id: 11,
        name: 'Салат с курицей и печёной тыквой',
        category: DishCategory.salad,
        nutrients: const Nutrients(kcal: 388, protein: 22, fat: 12, carbs: 18),
        priceMinor: 38900,
        source: DataSource(kind: SourceKind.verified, verifiedAt: DateTime.utc(2026, 9, 30)),
        assessment: const Assessment(verdict: Verdict.fits),
      ),
      const MenuItem(
        id: 13,
        name: 'Тефтели в томатном соусе',
        category: DishCategory.main,
        nutrients: Nutrients(kcal: 259, protein: 17, fat: 15, carbs: 14),
        source: DataSource(kind: SourceKind.estimate, kcalLow: 180, kcalHigh: 340),
        assessment: Assessment(
          verdict: Verdict.notFits,
          reasons: [
            AssessmentReason(code: ReasonCode.excludedTag, tag: 'pork'),
            AssessmentReason(code: ReasonCode.fatAbove, amount: 4.5),
          ],
        ),
      ),
    ],
  );
  final nearby = [
    for (final (index, fit) in [FitLevel.good, FitLevel.compromise, FitLevel.none].indexed)
      NearbyVenue(
        venue: longVenue.copyWith(id: 20 + index, lon: longVenue.lon + index * 0.004),
        distanceMeters: 300 + index * 400,
        hasMenu: true,
        fit: fit,
      ),
  ];

  Future<void> openTab(WidgetTester tester, String label) async {
    await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text(label)));
    await tester.pumpAndSettle();
  }

  for (final (width, scale) in [(320.0, 1.0), (375.0, 1.0), (412.0, 1.0), (412.0, 1.3)]) {
    final label = '${width.toInt()} dp, шрифт ×$scale';

    testWidgets('онбординг без наложений и с отступами от края: $label', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final harness = TestHarness()..screen = Size(width, 780);
      await harness.pump(tester);
      final issues = <String>[...await LayoutAudit.inspectScrolling(tester, 'шаг 1')];
      await tester.enterText(find.byKey(const Key('age-field')), '25');
      await tester.enterText(find.byKey(const Key('height-field')), '165');
      await tester.enterText(find.byKey(const Key('weight-field')), '62');
      await tester.pumpAndSettle();
      issues.addAll(await LayoutAudit.inspectScrolling(tester, 'шаг 1 с нормой'));
      await tester.tap(find.byKey(const Key('onboarding-next')));
      await tester.pumpAndSettle();
      issues.addAll(await LayoutAudit.inspectScrolling(tester, 'шаг 2'));
      await tester.tap(find.byKey(const Key('onboarding-next')));
      await tester.pumpAndSettle();
      issues.addAll(await LayoutAudit.inspectScrolling(tester, 'шаг 3'));

      expect(issues, isEmpty, reason: issues.join('\n'));
    });

    testWidgets('рабочие экраны без наложений и с отступами от края: $label', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final harness = TestHarness(profile: TestData.profile)
        ..screen = Size(width, 780)
        ..combos.nearbyResult = Ok(ComboSearchResult(appliedTarget: TestData.lunchTarget, options: options))
        ..combos.replaceResult = Ok(ComboSearchResult(appliedTarget: TestData.lunchTarget, options: options))
        ..venues.nearbyResult = Ok(nearby)
        ..venues.menuResult = Ok(menu);
      await harness.pump(tester);
      final issues = <String>[...await LayoutAudit.inspectScrolling(tester, 'главный')];

      await tester.tap(find.byKey(const Key('edit-target')));
      await tester.pumpAndSettle();
      issues.addAll(await LayoutAudit.inspectScrolling(tester, 'цель приёма пищи'));
      Navigator.of(tester.element(find.byKey(const Key('target-save')))).pop();
      await tester.pumpAndSettle();
      await tapVisible(tester, find.byKey(const Key('find-nearby')));
      issues.addAll(await LayoutAudit.inspectScrolling(tester, 'варианты рядом'));
      await tapVisible(tester, find.text('Сэндвич с курицей и песто на чиабатте'));
      issues.addAll(await LayoutAudit.inspectScrolling(tester, 'набор'));
      await tapVisible(tester, find.byKey(const Key('replace-1')));
      issues.addAll(await LayoutAudit.inspectScrolling(tester, 'замены'));
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      await openTab(tester, 'Карта');
      issues.addAll(await LayoutAudit.inspectScrolling(tester, 'карта'));
      await openTab(tester, 'Дневник');
      issues.addAll(await LayoutAudit.inspectScrolling(tester, 'дневник'));
      await openTab(tester, 'Профиль');
      issues.addAll(await LayoutAudit.inspectScrolling(tester, 'профиль'));

      unawaited(GoRouter.of(tester.element(find.byType(Scaffold).first)).push('/venue/7'));
      await tester.pumpAndSettle();
      issues.addAll(await LayoutAudit.inspectScrolling(tester, 'заведение'));
      await tester.tap(find.byKey(const Key('build-here')));
      await tester.pumpAndSettle();
      issues.addAll(await LayoutAudit.inspectScrolling(tester, 'наборы в заведении'));

      expect(issues, isEmpty, reason: issues.join('\n'));
    });
  }
}
