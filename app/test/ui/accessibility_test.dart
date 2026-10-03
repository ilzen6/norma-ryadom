import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:norma_ryadom/domain/models/catalog.dart';
import 'package:norma_ryadom/domain/models/combo.dart';
import 'package:norma_ryadom/utils/result.dart';

import '../support/fakes.dart';
import '../support/pump_app.dart';

void main() {
  Future<void> expectAccessible(WidgetTester tester) async {
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(textContrastGuideline));
  }

  testWidgets('онбординг доступен: размер целей, подписи, контраст', (tester) async {
    final handle = tester.ensureSemantics();
    await TestHarness().pump(tester);

    await expectAccessible(tester);
    handle.dispose();
  });

  testWidgets('главный экран с результатами доступен', (tester) async {
    final handle = tester.ensureSemantics();
    final harness = TestHarness(profile: TestData.profile)
      ..combos.nearbyResult = Ok(
        ComboSearchResult(
          appliedTarget: TestData.lunchTarget,
          options: [
            TestData.option([TestData.dish(1, 'Куриная грудка гриль', 374)]),
          ],
        ),
      );
    await harness.pump(tester);
    await tester.tap(find.byKey(const Key('find-nearby')));
    await tester.pumpAndSettle();

    await expectAccessible(tester);
    handle.dispose();
  });

  testWidgets('экран набора доступен', (tester) async {
    final handle = tester.ensureSemantics();
    final harness = TestHarness(profile: TestData.profile)
      ..combos.nearbyResult = Ok(
        ComboSearchResult(
          appliedTarget: TestData.lunchTarget,
          options: [
            TestData.option([TestData.dish(1, 'Куриная грудка гриль', 374)]),
          ],
        ),
      );
    await harness.pump(tester);
    await tester.tap(find.byKey(const Key('find-nearby')));
    await tester.pumpAndSettle();
    await tapVisible(tester, find.text('Куриная грудка гриль'));

    await expectAccessible(tester);
    handle.dispose();
  });

  testWidgets('карта доступна: переключатель подписан, уровень соответствия назван словами', (tester) async {
    final handle = tester.ensureSemantics();
    final harness = TestHarness(profile: TestData.profile)
      ..venues.nearbyResult = Ok([
        const NearbyVenue(venue: TestData.venue, distanceMeters: 120, hasMenu: true, fit: FitLevel.good),
        NearbyVenue(venue: TestData.venue.copyWith(id: 8, name: 'Кафе без меню'), distanceMeters: 300, hasMenu: false),
      ]);
    await harness.pump(tester);
    await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text('Карта')));
    await tester.pumpAndSettle();

    await expectAccessible(tester);
    expect(
      tester.getSemantics(find.byKey(const Key('map-show-all'))),
      matchesSemantics(
        label: 'Показать все\nВключая заведения, у которых пока нет данных о меню',
        hasToggledState: true,
        hasEnabledState: true,
        isEnabled: true,
        isFocusable: true,
        hasTapAction: true,
        hasFocusAction: true,
      ),
    );
    expect(find.semantics.byLabel(RegExp('нет данных о меню ·')), findsOne);
    handle.dispose();
  });

  testWidgets('экран заведения доступен и озвучивает КБЖУ словами', (tester) async {
    final handle = tester.ensureSemantics();
    final harness = TestHarness(profile: TestData.profile)
      ..venues.menuResult = const Ok(
        VenueMenu(
          venue: TestData.venue,
          items: [
            MenuItem(
              id: 11,
              name: 'Куриная грудка гриль',
              category: DishCategory.main,
              nutrients: Nutrients(kcal: 374, protein: 38, fat: 6, carbs: 2),
              source: DataSource(kind: SourceKind.verified),
              assessment: Assessment(verdict: Verdict.fits),
            ),
          ],
        ),
      );
    await harness.pump(tester);
    unawaited(GoRouter.of(tester.element(find.byType(Scaffold).first)).push('/venue/7'));
    await tester.pumpAndSettle();

    await expectAccessible(tester);
    expect(find.bySemanticsLabel(RegExp('374 килокалорий, белки 38 г, жиры 6 г, углеводы 2 г')), findsOneWidget);
    handle.dispose();
  });

  testWidgets('экраны не ломаются при двукратном увеличении шрифта', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final harness = TestHarness(profile: TestData.profile)
      ..combos.nearbyResult = Ok(
        ComboSearchResult(
          appliedTarget: TestData.lunchTarget,
          options: [
            TestData.option([TestData.dish(1, 'Куриная грудка гриль', 374), TestData.dish(2, 'Рис с овощами', 207)]),
          ],
        ),
      );
    await harness.pump(tester);
    await tapVisible(tester, find.byKey(const Key('find-nearby')));
    await tapVisible(tester, find.bySemanticsLabel(RegExp(r'Куриная грудка гриль \+ Рис с овощами')));
    await scrollTo(tester, find.text('Попадание в цель'));
    expect(find.text('Попадание в цель'), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    for (final tab in ['Карта', 'Дневник', 'Профиль']) {
      await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text(tab)));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('дневник и профиль доступны', (tester) async {
    final handle = tester.ensureSemantics();
    await TestHarness(profile: TestData.profile).pump(tester);

    for (final tab in ['Дневник', 'Профиль']) {
      await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text(tab)));
      await tester.pumpAndSettle();
      await expectAccessible(tester);
    }
    handle.dispose();
  });
}
