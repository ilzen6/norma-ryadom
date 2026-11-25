import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:norma_ryadom/domain/models/catalog.dart';
import 'package:norma_ryadom/domain/models/combo.dart';
import 'package:norma_ryadom/utils/result.dart';
import 'package:norma_ryadom/domain/models/diary.dart';
import 'package:norma_ryadom/domain/models/meal.dart';
import 'package:norma_ryadom/domain/models/nutrition_norm.dart';
import 'package:norma_ryadom/domain/models/taste.dart';

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

  testWidgets('поле района озвучивается как кнопка с текущим районом', (tester) async {
    final handle = tester.ensureSemantics();
    await TestHarness(profile: TestData.profile).pump(tester);
    await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text('Профиль')));
    await tester.pumpAndSettle();

    expect(
      tester.getSemantics(find.byKey(const Key('district-field'))),
      isSemantics(isButton: true, hasTapAction: true, label: 'Или выберите район: Москва-Сити. Изменить'),
    );
    handle.dispose();
  });

  testWidgets('шторка фильтров доступна', (tester) async {
    final handle = tester.ensureSemantics();
    await TestHarness(profile: TestData.profile).pump(tester);

    await tapVisible(tester, find.byKey(const Key('open-filters')));

    await expectAccessible(tester);
    handle.dispose();
  });

  testWidgets('экран «Ваши вкусы» доступен', (tester) async {
    final handle = tester.ensureSemantics();
    await TestHarness(profile: TestData.profile.copyWith(likedTastes: {TasteTag.soup})).pump(tester);
    unawaited(GoRouter.of(tester.element(find.byType(Scaffold).first)).push('/profile/tastes'));
    await tester.pumpAndSettle();

    await expectAccessible(tester);
    handle.dispose();
  });

  testWidgets('неделя в дневнике доступна и подписывает каждый день для диктора', (tester) async {
    final handle = tester.ensureSemantics();
    final harness = TestHarness(profile: TestData.profile);
    await harness.diary.add(
      const NewDiaryEntry(
        meal: MealType.lunch,
        title: 'Борщ',
        intake: Intake(kcal: 520, protein: 20, fat: 15, carbs: 60),
      ),
      harness.now,
    );
    await harness.pump(tester);
    await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text('Дневник')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('diary-mode-week')));
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel(RegExp(r'^пт: 520 ккал$')), findsOneWidget);
    await expectAccessible(tester);
    handle.dispose();
  });

  testWidgets('плашка «нет связи» доступна', (tester) async {
    final handle = tester.ensureSemantics();
    final harness = TestHarness(profile: TestData.profile)..combos.nearbyResult = const Err(AppFailure.offline);
    harness.settings.savedSearch = SavedSearch(
      result: ComboSearchResult(
        appliedTarget: TestData.lunchTarget,
        options: [
          TestData.option([TestData.dish(1, 'Куриная грудка гриль', 374)]),
        ],
      ),
      meal: MealType.lunch,
      savedAt: DateTime(2026, 10, 2, 12),
    );
    await harness.pump(tester);
    await tapVisible(tester, find.byKey(const Key('find-nearby')));
    await scrollTo(tester, find.byKey(const Key('offline-banner')));

    await expectAccessible(tester);
    handle.dispose();
  });

  testWidgets('экран «О приложении» доступен', (tester) async {
    PackageInfo.setMockInitialValues(
      appName: 'Норма рядом',
      packageName: 'ru.normaryadom.norma_ryadom',
      version: '1.0.0',
      buildNumber: '10',
      buildSignature: '',
    );
    final handle = tester.ensureSemantics();
    await TestHarness(profile: TestData.profile).pump(tester);
    unawaited(GoRouter.of(tester.element(find.byType(Scaffold).first)).push('/profile/about'));
    await tester.pumpAndSettle();

    await expectAccessible(tester);
    handle.dispose();
  });
}
