import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:norma_ryadom/domain/models/catalog.dart';
import 'package:norma_ryadom/domain/models/diary.dart';
import 'package:norma_ryadom/domain/models/meal.dart';
import 'package:norma_ryadom/domain/models/nutrition_norm.dart';
import 'package:norma_ryadom/ui/core/theme.dart';
import 'package:norma_ryadom/ui/venue/venue_screen.dart';
import 'package:norma_ryadom/utils/result.dart';

import '../support/fakes.dart';
import '../support/pump_app.dart';

void main() {
  NearbyVenue venue(int id, String name, FitLevel? fit, {bool hasMenu = true}) => NearbyVenue(
    venue: TestData.venue.copyWith(id: id, name: name, chainName: null, lon: TestData.venue.lon + (id - 2) * 0.002),
    distanceMeters: 100 * id,
    hasMenu: hasMenu,
    fit: fit,
  );

  Future<void> openTab(WidgetTester tester, String label) async {
    await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text(label)));
    await tester.pumpAndSettle();
  }

  testWidgets('карта красит заведения по лучшему набору и переключает «Показать все»', (tester) async {
    final harness = TestHarness(profile: TestData.profile)
      ..venues.nearbyResult = Ok([
        venue(1, 'Зелёный бар', FitLevel.good),
        venue(2, 'Блинная', FitLevel.compromise),
        venue(3, 'Пицца', FitLevel.none),
        venue(4, 'Кафе без меню', null, hasMenu: false),
      ]);
    await harness.pump(tester);

    await openTab(tester, 'Карта');

    Future<Color> colorOf(String name) async {
      await tester.scrollUntilVisible(
        find.text(name),
        120,
        scrollable: find.descendant(of: find.byKey(const Key('map-venue-list')), matching: find.byType(Scrollable)),
      );
      return tester
          .widget<Text>(find.descendant(of: find.widgetWithText(ListTile, name), matching: find.text(name[0])))
          .style!
          .color!;
    }

    expect(find.textContaining(RegExp(r'^\W*есть набор под цель$'), findRichText: true), findsOneWidget);
    expect(await colorOf('Зелёный бар'), Palette.light.good);
    expect(await colorOf('Блинная'), Palette.light.warn);
    expect(await colorOf('Пицца'), Palette.light.neutral);
    expect(await colorOf('Кафе без меню'), Palette.light.inkSubtle);

    await tester.tap(find.byKey(const Key('map-show-all')));
    await tester.pumpAndSettle();
    expect(harness.venues.includeWithoutMenuRequests, [false, true]);

    await tester.scrollUntilVisible(
      find.text('есть набор под цель · Пресненская наб., 2 · 100 м'),
      -120,
      scrollable: find.descendant(of: find.byKey(const Key('map-venue-list')), matching: find.byType(Scrollable)),
    );
    expect(find.text('есть набор под цель · Пресненская наб., 2 · 100 м'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Зелёный бар, есть набор под цель'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('map-selected-venue')), findsOneWidget);
    await tester.tap(find.byKey(const Key('map-open-venue')));
    await tester.pumpAndSettle();
    expect(find.byType(VenueScreen), findsOneWidget);
    expect(tester.widget<VenueScreen>(find.byType(VenueScreen)).venueId, 1);
  });

  testWidgets('карта честно показывает пустую выдачу и ошибку', (tester) async {
    final harness = TestHarness(profile: TestData.profile);
    await harness.pump(tester);

    await openTab(tester, 'Карта');
    expect(find.text('Рядом нет заведений с меню'), findsOneWidget);

    harness.venues.nearbyResult = const Err(AppFailure.serviceUnavailable);
    await tester.tap(find.byKey(const Key('map-show-all')));
    await tester.pumpAndSettle();
    expect(find.text('Сервис временно недоступен. Попробуйте позже.'), findsOneWidget);
  });

  testWidgets('дневник показывает прогресс по каждому показателю и даёт управлять записями', (tester) async {
    final harness = TestHarness(profile: TestData.profile);
    await harness.diary.add(
      const NewDiaryEntry(
        meal: MealType.lunch,
        title: 'Боул с курицей + Морс',
        venueName: 'Тёплая плошка',
        intake: Intake(kcal: 530, protein: 34, fat: 14, carbs: 67),
      ),
      harness.now,
    );
    await harness.pump(tester);

    await openTab(tester, 'Дневник');
    expect(find.text('530 из 1800'), findsOneWidget);
    expect(find.text('34 из 99'), findsOneWidget);
    expect(find.text('Обед'), findsWidgets);

    await tester.tap(find.byTooltip('В избранное'));
    await tester.pumpAndSettle();
    expect(harness.diary.entries.single.favorite, isTrue);

    await tester.tap(find.byTooltip('Добавить снова «Боул с курицей + Морс»'));
    await tester.pumpAndSettle();
    expect(harness.diary.entries, hasLength(2));
    expect(find.text('1060 из 1800'), findsOneWidget);

    await tester.tap(find.byTooltip('Удалить запись «Боул с курицей + Морс»').first);
    await tester.pumpAndSettle();
    expect(harness.diary.entries, hasLength(1));
  });

  testWidgets('пустой дневник подсказывает, что записей нет', (tester) async {
    final harness = TestHarness(profile: TestData.profile);
    await harness.pump(tester);

    await openTab(tester, 'Дневник');

    expect(find.text('Пока ничего не записано'), findsOneWidget);
    expect(find.text('0 из 1800'), findsOneWidget);
  });

  testWidgets('профиль удаляет все данные одной кнопкой и возвращает в онбординг', (tester) async {
    final harness = TestHarness(profile: TestData.profile);
    await harness.pump(tester);
    await openTab(tester, 'Профиль');

    expect(find.text('25 лет · 165 см · 62 кг'), findsOneWidget);
    await tapVisible(tester, find.byKey(const Key('delete-all')));
    expect(find.text('Удалить все данные?'), findsOneWidget);
    await tester.tap(find.byKey(const Key('delete-confirm')));
    await tester.pumpAndSettle();

    expect(harness.profiles.deleted, isTrue);
    expect(find.text('ШАГ 1 ИЗ 3'), findsOneWidget);
  });

  testWidgets('профиль сохраняет согласие на геолокацию и редактирует параметры', (tester) async {
    final harness = TestHarness(profile: TestData.profile);
    await harness.pump(tester);
    await openTab(tester, 'Профиль');

    await tester.tap(find.byKey(const Key('location-consent')));
    await tester.pumpAndSettle();
    expect(harness.profiles.profile?.locationConsent, isFalse);

    await tester.tap(find.text('25 лет · 165 см · 62 кг'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('weight-field')), '60,5');
    await tester.tap(find.byKey(const Key('profile-save')));
    await tester.pumpAndSettle();
    expect(harness.profiles.profile?.weightKg, 60.5);
    expect(find.text('25 лет · 165 см · 60,5 кг'), findsOneWidget);
  });

  testWidgets('профиль включает геолокацию только после разрешения системы', (tester) async {
    final harness = TestHarness(profile: TestData.profile.copyWith(locationConsent: false))
      ..location.result = const Err(AppFailure.locationDenied);
    await harness.pump(tester);
    await openTab(tester, 'Профиль');
    final callsBefore = harness.location.calls;

    await tester.tap(find.byKey(const Key('location-consent')));
    await tester.pumpAndSettle();
    expect(harness.location.calls, callsBefore + 1);
    expect(harness.profiles.profile?.locationConsent, isFalse);
    expect(find.textContaining('Нет доступа к геолокации'), findsOneWidget);

    harness.location.result = const Ok(TestData.deviceLocation);
    await tester.tap(find.byKey(const Key('location-consent')));
    await tester.pumpAndSettle();
    expect(harness.profiles.profile?.locationConsent, isTrue);
  });
}
