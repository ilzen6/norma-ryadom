import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:norma_ryadom/domain/models/catalog.dart';
import 'package:norma_ryadom/domain/models/diary.dart';
import 'package:norma_ryadom/domain/models/district.dart';
import 'package:norma_ryadom/domain/models/meal.dart';
import 'package:norma_ryadom/domain/models/nutrition_norm.dart';
import 'package:norma_ryadom/ui/core/theme.dart';
import 'package:norma_ryadom/ui/map/map_view_model.dart';
import 'package:norma_ryadom/ui/venue/venue_screen.dart';
import 'package:norma_ryadom/utils/result.dart';

import '../support/fakes.dart';
import '../support/pump_app.dart';

void main() {
  NearbyVenue venue(int id, String name, FitLevel? fit, {bool hasMenu = true}) => NearbyVenue(
    venue: TestData.venue.copyWith(id: id, name: name, chainName: null, lon: TestData.venue.lon + (id - 2) * 0.004),
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
    await tester.tap(find.byKey(const Key('map-sheet-expand')));
    await tester.pumpAndSettle();

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

    await Scrollable.ensureVisible(tester.element(find.byKey(const Key('map-show-all'))), alignment: 0.3);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('map-show-all')));
    await tester.pumpAndSettle();
    expect(harness.venues.includeWithoutMenuRequests.first, isFalse);
    expect(harness.venues.includeWithoutMenuRequests.last, isTrue);

    await Scrollable.ensureVisible(
      tester.element(find.textContaining('есть набор под цель · Пресненская наб., 2 · ')),
      alignment: 0.5,
    );
    await tester.pumpAndSettle();
    expect(
      find.textContaining(RegExp(r'^есть набор под цель · Пресненская наб\., 2 · \d+ м · \d+ мин$')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('map-sheet-map')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('map-sheet-expand')), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Зелёный бар, есть набор под цель'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('map-selected-venue')), findsOneWidget);
    await tester.tap(find.byKey(const Key('map-open-venue')));
    await tester.pumpAndSettle();
    expect(find.byType(VenueScreen), findsOneWidget);
    expect(tester.widget<VenueScreen>(find.byType(VenueScreen)).venueId, 1);
  });

  testWidgets('карта в режиме «По данным» красит заведения по достоверности КБЖУ', (tester) async {
    final harness = TestHarness(profile: TestData.profile)
      ..venues.nearbyResult = Ok([
        venue(1, 'Сеть', FitLevel.none).copyWith(dataQuality: SourceKind.verified),
        venue(2, 'Столовая', FitLevel.good).copyWith(dataQuality: SourceKind.fromMenu),
        venue(3, 'Шаурма', FitLevel.good).copyWith(dataQuality: SourceKind.estimate),
        venue(4, 'Кафе без меню', null, hasMenu: false),
      ]);
    await harness.pump(tester);

    await openTab(tester, 'Карта');
    await tester.tap(find.byKey(const Key('map-sheet-expand')));
    await tester.pumpAndSettle();
    await Scrollable.ensureVisible(tester.element(find.byKey(const Key('map-coloring'))), alignment: 0.3);
    await tester.pumpAndSettle();
    await tester.tap(find.text('По данным'));
    await tester.pumpAndSettle();

    Color colorOf(String name) => tester
        .widget<Text>(find.descendant(of: find.widgetWithText(ListTile, name), matching: find.text(name[0])))
        .style!
        .color!;

    expect(find.textContaining(RegExp(r'^\W*КБЖУ — оценка$'), findRichText: true), findsOneWidget);
    expect(find.textContaining(RegExp(r'^\W*есть набор под цель$'), findRichText: true), findsNothing);
    expect(colorOf('Сеть'), Palette.light.good);
    expect(colorOf('Столовая'), Palette.light.warn);
    expect(colorOf('Шаурма'), Palette.light.bad);
    expect(find.textContaining(RegExp(r'^КБЖУ из меню заведения · ')), findsOneWidget);

    await tester.tap(find.text('По норме'));
    await tester.pumpAndSettle();
    expect(colorOf('Сеть'), Palette.light.neutral);
  });

  testWidgets('карта объединяет соседние заведения в кружок с числом и приближает по нажатию', (tester) async {
    final harness = TestHarness(profile: TestData.profile)
      ..venues.nearbyResult = Ok([
        for (var id = 1; id <= 4; id++)
          NearbyVenue(
            venue: TestData.venue.copyWith(id: id, name: 'Точка $id', lon: TestData.venue.lon + id * 0.0002),
            distanceMeters: 100 * id,
            hasMenu: true,
            fit: FitLevel.good,
          ),
      ]);
    await harness.pump(tester);
    await openTab(tester, 'Карта');
    expect(find.bySemanticsLabel('4 заведения рядом, приблизить'), findsOneWidget);
    expect(find.bySemanticsLabel('Точка 1, есть набор под цель'), findsNothing);

    await tester.tap(find.bySemanticsLabel('4 заведения рядом, приблизить'));
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('4 заведения рядом, приблизить'), findsNothing);
    expect(find.bySemanticsLabel('Точка 1, есть набор под цель'), findsOneWidget);
  });

  testWidgets('карта подгружает заведения вокруг видимой области после перемещения', (tester) async {
    final harness = TestHarness(profile: TestData.profile)
      ..venues.nearbyResult = Ok([venue(1, 'Зелёный бар', FitLevel.good)]);
    await harness.pump(tester);
    await openTab(tester, 'Карта');
    expect(harness.venues.requestedRadii.last, inInclusiveRange(500, 30000));
    final before = harness.venues.requestedCenters.last;

    await tester.drag(find.byType(FlutterMap), const Offset(-200, 150));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();

    expect(harness.venues.requestedCenters.last, isNot(before));
  });

  testWidgets('карта переносит в выбранный город и ищет заведения уже там', (tester) async {
    final harness = TestHarness(profile: TestData.profile)
      ..venues.nearbyResult = Ok([venue(1, 'Зелёный бар', FitLevel.good)]);
    await harness.pump(tester);
    await openTab(tester, 'Карта');
    await tester.tap(find.byKey(const Key('map-cities')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('city-spb')));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();

    final center = harness.venues.requestedCenters.last;
    expect(center.lat, closeTo(59.93, 0.05));
    expect(center.lon, closeTo(30.34, 0.05));
    expect(find.text('Санкт-Петербург'), findsOneWidget);
  });

  testWidgets('карта показывает всю Россию с подписями крупных городов', (tester) async {
    final harness = TestHarness(profile: TestData.profile);
    await harness.pump(tester);
    await openTab(tester, 'Карта');
    await tester.tap(find.byKey(const Key('map-cities')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('city-russia')));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();

    expect(find.text('Вся Россия'), findsOneWidget);
    expect(find.text('Москва'), findsOneWidget);
    expect(find.text('Невский проспект'), findsNothing);
  });

  testWidgets('карта просит приблизиться, когда в области больше заведений, чем показано', (tester) async {
    final harness = TestHarness(profile: TestData.profile)
      ..venues.nearbyResult = Ok([for (var id = 1; id <= mapVenueLimit; id++) venue(id, 'Точка $id', FitLevel.good)]);
    await harness.pump(tester);
    await openTab(tester, 'Карта');

    expect(find.byKey(const Key('map-truncated')), findsOneWidget);
  });

  testWidgets('карта честно показывает пустую выдачу, а ошибку подгрузки — плашкой, не теряя карту', (tester) async {
    final harness = TestHarness(profile: TestData.profile);
    await harness.pump(tester);

    await openTab(tester, 'Карта');
    expect(find.text('Рядом нет заведений с меню'), findsOneWidget);

    harness.venues.nearbyResult = const Err(AppFailure.serviceUnavailable);
    await tester.tap(find.byKey(const Key('map-show-all')));
    await tester.pumpAndSettle();
    expect(find.text('Сервис временно недоступен. Попробуйте позже.'), findsOneWidget);
    expect(find.byType(FlutterMap), findsOneWidget);
    expect(find.byKey(const Key('map-reload-failed')), findsOneWidget);
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

  testWidgets('список заведений разворачивается на весь экран, а «Назад» сворачивает его к карте', (tester) async {
    final harness = TestHarness(profile: TestData.profile)
      ..venues.nearbyResult = Ok([venue(1, 'Зелёный бар', FitLevel.good)]);
    await harness.pump(tester);
    await openTab(tester, 'Карта');
    expect(find.text('1 на карте'), findsOneWidget);

    await tester.tap(find.byKey(const Key('map-sheet-expand')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('map-sheet-collapse')), findsOneWidget);
    expect(find.byKey(const Key('map-sheet-expand')), findsNothing);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('map-sheet-expand')), findsOneWidget);
    expect(find.byType(FlutterMap), findsOneWidget);
  });

  testWidgets('район выбирается поиском из списка, сгруппированного по Москве, области и Петербургу', (tester) async {
    final harness = TestHarness(profile: TestData.profile);
    await harness.pump(tester);
    await openTab(tester, 'Профиль');
    await tester.scrollUntilVisible(find.byKey(const Key('district-field')), 120);
    await tester.tap(find.byKey(const Key('district-field')));
    await tester.pumpAndSettle();

    expect(find.text('МОСКВА'), findsOneWidget);
    expect(find.text('МОСКОВСКАЯ ОБЛАСТЬ'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('district-search')), 'хим');
    await tester.pumpAndSettle();
    expect(find.text('МОСКВА'), findsNothing);
    expect(find.byKey(const Key('district-arbat')), findsNothing);

    await tester.tap(find.byKey(const Key('district-khimki')));
    await tester.pumpAndSettle();
    expect(harness.profiles.profile?.district, District.khimki);
    expect(find.text('Химки'), findsOneWidget);
  });

  testWidgets('поиск района без совпадений честно сообщает об этом', (tester) async {
    final harness = TestHarness(profile: TestData.profile);
    await harness.pump(tester);
    await openTab(tester, 'Профиль');
    await tester.scrollUntilVisible(find.byKey(const Key('district-field')), 120);
    await tester.tap(find.byKey(const Key('district-field')));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('district-search')), 'Владивосток');
    await tester.pumpAndSettle();
    expect(find.text('Ничего не нашлось — попробуйте другое название'), findsOneWidget);
  });

  testWidgets('поиск района не различает «е» и «ё»', (tester) async {
    final harness = TestHarness(profile: TestData.profile);
    await harness.pump(tester);
    await openTab(tester, 'Профиль');
    await tester.scrollUntilVisible(find.byKey(const Key('district-field')), 120);
    await tester.tap(find.byKey(const Key('district-field')));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('district-search')), 'королев');
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('district-korolev')), findsOneWidget);
    await tester.enterText(find.byKey(const Key('district-search')), 'Щелково');
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('district-shchyolkovo')), findsOneWidget);
  });

  testWidgets('карта без единой удачной загрузки показывает ошибку на весь экран с повтором', (tester) async {
    final harness = TestHarness(profile: TestData.profile)
      ..venues.nearbyResult = const Err(AppFailure.serviceUnavailable);
    await harness.pump(tester);
    await openTab(tester, 'Карта');
    expect(find.byType(FlutterMap), findsNothing);
    expect(find.text('Сервис временно недоступен. Попробуйте позже.'), findsOneWidget);

    harness.venues.nearbyResult = Ok([venue(1, 'Зелёный бар', FitLevel.good)]);
    await tester.tap(find.text('Повторить'));
    await tester.pumpAndSettle();
    expect(find.byType(FlutterMap), findsOneWidget);
  });
}
