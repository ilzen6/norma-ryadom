import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:norma_ryadom/data/demo/demo_server.dart';
import 'package:norma_ryadom/data/services/norma_api.dart';
import 'package:norma_ryadom/domain/models/catalog.dart';
import 'package:norma_ryadom/domain/models/combo.dart';
import 'package:norma_ryadom/domain/models/geo_location.dart';
import 'package:norma_ryadom/domain/models/search_filters.dart';
import 'package:norma_ryadom/domain/models/taste.dart';
import 'package:norma_ryadom/utils/result.dart';

import '../../support/fakes.dart';

void main() {
  final api = NormaApi(
    NormaApi.createDio('http://demo')
      ..httpClientAdapter = DemoServerAdapter(() async => File('assets/demo/catalog.json').readAsStringSync()),
  );
  const center = GeoLocation(lat: 55.7495, lon: 37.5374, source: LocationSource.device);

  T valueOf<T>(Result<T> result) => switch (result) {
    Ok(:final value) => value,
    Err(:final failure) => throw StateError('$failure'),
  };
  final catalog = DemoCatalog.fromJson(File('assets/demo/catalog.json').readAsStringSync());
  String? kindOf(ComboOption option) => catalog.venue(option.venue.id)?.kind;
  bool exact(ComboOption option) => option.combo.checks.every((check) => check.status == MetricStatus.ok);
  Future<List<ComboOption>> nearby(SearchFilters filters, {int radiusMeters = 1500}) async => valueOf(
    await api.searchNearby(
      location: center,
      radiusMeters: radiusMeters,
      target: TestData.lunchTarget,
      price: filters.prefersCheaper ? PricePreference.cheaper : PricePreference.any,
      filters: filters,
    ),
  ).options;

  test('показывает заведения рядом с цветом соответствия цели', () async {
    final venues = valueOf(
      await api.nearbyVenues(
        location: center,
        radiusMeters: 1500,
        includeWithoutMenu: false,
        target: TestData.lunchTarget,
      ),
    );

    expect(venues, isNotEmpty);
    expect(
      venues.map((venue) => venue.distanceMeters),
      orderedEquals([...venues.map((v) => v.distanceMeters)]..sort()),
    );
    expect(venues.map((venue) => venue.fit), everyElement(isIn([FitLevel.good, FitLevel.compromise, FitLevel.none])));
    expect(venues.first.distanceMeters, lessThan(300));
  });

  test('отдаёт для карты не больше запрошенного числа ближайших заведений', () async {
    final venues = valueOf(
      await api.nearbyVenues(location: center, radiusMeters: 30000, includeWithoutMenu: false, limit: 7),
    );

    expect(venues, hasLength(7));
    expect(venues.first.distanceMeters, lessThanOrEqualTo(venues.last.distanceMeters));
  });

  test('подбирает рядом без исключённых продуктов и возвращает округлённую цель', () async {
    final result = valueOf(
      await api.searchNearby(
        location: center,
        radiusMeters: 1500,
        target: TestData.lunchTarget,
        price: PricePreference.any,
      ),
    );

    expect(result.appliedTarget.kcal, 630);
    expect(result.appliedTarget.kcalTolerance, 60);
    expect(result.options, isNotEmpty);
    expect(result.options.length, lessThanOrEqualTo(NormaApi.nearbyLimit));
    for (final option in result.options) {
      expect(option.combo.dishes.expand((dish) => dish.tags), isNot(contains('pork')));
      expect(option.combo.checks.map((check) => check.metric), [Metric.kcal, Metric.protein, Metric.fat, Metric.carbs]);
      expect(option.distanceMeters, isNotNull);
    }
  });

  test('меню заведения отсортировано по близости к цели и с пометками', () async {
    final menu = valueOf(await api.venueMenu(1, TestData.lunchTarget));

    expect(menu.venue.name, 'Cofix');
    expect(menu.items.first.assessment?.verdict, Verdict.fits);
    final sausage = menu.items.firstWhere((item) => item.name == 'Марсельская сосиска в тесте');
    expect(sausage.assessment?.verdict, Verdict.notFits);
    expect(sausage.assessment?.reasons.first.code, ReasonCode.excludedTag);
    expect(sausage.source.kind, SourceKind.verified);
  });

  test('подбирает в заведении и заменяет блюдо, оставляя остальные', () async {
    final atVenue = valueOf(
      await api.searchAtVenue(venueId: 1, target: TestData.lunchTarget, price: PricePreference.cheaper),
    );
    final first = atVenue.options.first.combo;
    final replaced = valueOf(
      await api.replaceDish(
        venueId: 1,
        target: atVenue.appliedTarget,
        dishIds: [for (final dish in first.dishes) dish.id],
        replaceIndex: 0,
        price: PricePreference.cheaper,
      ),
    );

    expect(atVenue.options.first.distanceMeters, isNull);
    for (final option in replaced.options) {
      expect(option.combo.dishes.map((dish) => dish.id), containsAll(first.dishes.skip(1).map((dish) => dish.id)));
    }
  });

  test('принимает фото и жалобы, а на неизвестное заведение отвечает «не найдено»', () async {
    final photo = await api.uploadMenuPhoto(venueId: 1, bytes: [1, 2, 3], fileName: 'menu.png');

    expect(valueOf(photo).submissionId, 1);
    expect(await api.reportItem(3, 'Другие цифры'), isA<Ok<void>>());
    expect(await api.health(), isA<Ok<void>>());
    expect((await api.venueMenu(999999, null) as Err<VenueMenu>).failure, AppFailure.notFound);
    expect(
      (await api.replaceDish(
        venueId: 1,
        target: TestData.lunchTarget,
        dishIds: [1],
        replaceIndex: 3,
        price: PricePreference.any,
      ) as Err<ComboSearchResult>).failure,
      AppFailure.invalidRequest,
    );
  });

  test('принимает сообщение о закрытой точке и не находит неизвестную', () async {
    expect(await api.reportVenue(1, VenueReportReason.closed), isA<Ok<void>>());
    expect((await api.reportVenue(999999, VenueReportReason.moved) as Err<void>).failure, AppFailure.notFound);
  });

  test('подбирает в заведениях без своего меню по типичному меню, у каждого отдельно и с оценкой калорий', () async {
    final typical = NormaApi(
      NormaApi.createDio('http://demo')
        ..httpClientAdapter = DemoServerAdapter(
          () async =>
              '{"verifiedAt": "2026-09-30T00:00:00Z", "templates": [{"code": "cafe", "name": "Типичное меню кафе",'
              ' "sourceUrl": "https://example.org/typical", "items": ['
              '{"name": "Куриная грудка", "category": "main", "portionGrams": 150, "kcal": 220, "protein": 36,'
              ' "fat": 7, "carbs": 2, "priceMinor": 29000, "tags": ["chicken", "meat"], "kcalLow": 187, "kcalHigh": 253},'
              '{"name": "Рис отварной", "category": "side", "portionGrams": 150, "kcal": 190, "protein": 4, "fat": 2,'
              ' "carbs": 40, "priceMinor": 12000, "tags": [], "kcalLow": 160, "kcalHigh": 230}]}],'
              ' "chains": [], "places": ['
              '{"name": "Кафе у моста", "address": "наб. Пресненская, 6", "lat": 55.7490, "lon": 37.5380, "template": "cafe"},'
              '{"name": "Кафе на углу", "address": "наб. Пресненская, 8", "lat": 55.7488, "lon": 37.5385, "template": "cafe"},'
              '{"name": "Буфет без вида", "address": "наб. Пресненская, 12", "lat": 55.7492, "lon": 37.5370}]}',
        ),
    );

    final venues = valueOf(
      await typical.nearbyVenues(location: center, radiusMeters: 1000, includeWithoutMenu: false),
    );
    final result = valueOf(
      await typical.searchNearby(
        location: center,
        radiusMeters: 1000,
        target: TestData.lunchTarget,
        price: PricePreference.any,
      ),
    );
    final menu = valueOf(await typical.venueMenu(1, TestData.lunchTarget));

    expect(venues.map((venue) => venue.venue.name), ['Кафе у моста', 'Кафе на углу']);
    expect(venues.map((venue) => venue.dataQuality), everyElement(SourceKind.estimate));
    expect(result.options.map((option) => option.venue.name), unorderedEquals(['Кафе у моста', 'Кафе на углу']));
    expect(result.options.map((option) => option.combo.sourceKind), everyElement(SourceKind.estimate));
    expect(menu.items.map((item) => item.source.kind), everyElement(SourceKind.estimate));
    expect(menu.items.firstWhere((item) => item.name == 'Рис отварной').source.kcalLow, 160);
    expect(
      menu.items.expand((item) => item.assessment?.reasons ?? const <AssessmentReason>[]).map((reason) => reason.code),
      contains(ReasonCode.estimatedData),
    );
  });

  test('если точного набора нет, предлагает ближайший к цели и показывает, что не сходится', () async {
    final soups = NormaApi(
      NormaApi.createDio('http://demo')
        ..httpClientAdapter = DemoServerAdapter(
          () async =>
              '{"verifiedAt": "2026-09-30T00:00:00Z", "chains": [{"name": "Супы", "sourceUrl": "https://example.org",'
              ' "items": [{"name": "Суп с фасолью", "category": "main", "portionGrams": 350, "kcal": 500,'
              ' "protein": 31, "fat": 15, "carbs": 45, "priceMinor": 32000, "tags": []}],'
              ' "venues": [{"name": "Супы, у моста", "address": "наб. Пресненская, 6", "lat": 55.7490, "lon": 37.5380}]}]}',
        ),
    );

    final atVenue = valueOf(
      await soups.searchAtVenue(venueId: 1, target: TestData.lunchTarget, price: PricePreference.any),
    );
    final nearby = valueOf(
      await soups.searchNearby(
        location: center,
        radiusMeters: 1000,
        target: TestData.lunchTarget,
        price: PricePreference.any,
      ),
    );

    expect(atVenue.options.single.combo.dishes.single.name, 'Суп с фасолью');
    expect(atVenue.options.single.combo.checks.first.status, MetricStatus.below);
    expect(nearby.options.map((option) => option.venue.name), ['Супы, у моста']);
  });

  test('заведения без меню видны только по запросу «показать все» и без цвета соответствия', () async {
    final places = NormaApi(
      NormaApi.createDio('http://demo')
        ..httpClientAdapter = DemoServerAdapter(
          () async =>
              '{"verifiedAt": "2026-09-30T00:00:00Z", "chains": [{"name": "Якитория", "sourceUrl": "https://example.org",'
              ' "venues": [{"name": "Якитория", "address": "ул. Тверская, 1", "lat": 55.7575, "lon": 37.6135}]}],'
              ' "places": [{"name": "Кафе Ромашка", "address": "ул. Тверская, 3", "lat": 55.7578, "lon": 37.6129,'
              ' "confirmedOn": "2026-03-14"}]}',
        ),
    );
    const location = GeoLocation(lat: 55.7576, lon: 37.6132, source: LocationSource.device);

    final withMenu = valueOf(
      await places.nearbyVenues(location: location, radiusMeters: 1000, includeWithoutMenu: false),
    );
    final all = valueOf(await places.nearbyVenues(location: location, radiusMeters: 1000, includeWithoutMenu: true));

    expect(withMenu, isEmpty);
    expect(all.map((venue) => venue.venue.name), containsAll(['Якитория', 'Кафе Ромашка']));
    expect(all.every((venue) => !venue.hasMenu && venue.fit == null), isTrue);
    expect(all.firstWhere((venue) => venue.venue.chainName == null).venue.confirmedOn, DateTime(2026, 3, 14));
  });

  test('в режиме «Рекомендуем» не начинает с фастфуда и показывает местное кафе в первой тройке', () async {
    final options = await nearby(const SearchFilters());

    expect(options, hasLength(greaterThan(3)));
    expect(options.take(5).map(kindOf), everyElement(isNot(isIn(['pizza', 'burger', 'shawarma']))));
    expect(options.take(3).map((option) => option.venue.chainName), contains(isNull));
  });

  test('подбирает только в заведениях выбранных видов', () async {
    final options = await nearby(
      const SearchFilters(kinds: {VenueKind.georgian, VenueKind.coffee}),
      radiusMeters: 3000,
    );

    expect(options, isNotEmpty);
    expect(options.map(kindOf), everyElement(isIn(['georgian', 'coffee'])));
  });

  test('«Скрыть фастфуд» убирает бургерные, шаурму и пиццерии', () async {
    final options = await nearby(const SearchFilters(hideFastFood: true), radiusMeters: 3000);

    expect(options, isNotEmpty);
    expect(options.map(kindOf), everyElement(isNot(isIn(['pizza', 'burger', 'shawarma']))));
  });

  test('в режиме «Ближе» точные наборы идут от ближнего к дальнему', () async {
    final distances = [
      for (final option in await nearby(const SearchFilters(sort: ComboSort.nearest)))
        if (exact(option)) option.distanceMeters!,
    ];

    expect(distances, hasLength(greaterThan(1)));
    expect(distances, orderedEquals([...distances]..sort()));
  });

  test('в режиме «Дешевле» точные наборы идут от дешёвого к дорогому', () async {
    final prices = [
      for (final option in await nearby(const SearchFilters(sort: ComboSort.cheapest)))
        if (exact(option) && option.combo.priceMinor != null) option.combo.priceMinor!,
    ];

    expect(prices, hasLength(greaterThan(1)));
    expect(prices, orderedEquals([...prices]..sort()));
  });

  test('в режиме «Точные данные» наборы из официальных меню идут раньше примерных', () async {
    final kinds = [
      for (final option in await nearby(const SearchFilters(sort: ComboSort.accurate), radiusMeters: 3000))
        if (exact(option)) option.combo.sourceKind,
    ];

    expect(kinds, contains(SourceKind.verified));
    expect(kinds.map((kind) => kind.index), orderedEquals([...kinds.map((kind) => kind.index)]..sort()));
  });

  test('не предлагает наборы дороже заданной цены', () async {
    final options = await nearby(const SearchFilters(maxPriceRub: 400), radiusMeters: 3000);

    expect(options, isNotEmpty);
    expect(options.map((option) => option.combo.priceMinor), everyElement(lessThanOrEqualTo(40000)));
  });

  test('поднимает выше наборы с любимой едой, если они попадают в норму', () async {
    bool soup(ComboOption option) =>
        option.combo.dishes.any((dish) => TasteTag.ofDish(dish.name).contains(TasteTag.soup));
    Future<int> firstSoup(Set<TasteTag> tastes) async {
      final options = valueOf(
        await api.searchNearby(
          location: center,
          radiusMeters: 1500,
          target: TestData.lunchTarget,
          price: PricePreference.any,
          tastes: tastes,
        ),
      ).options;
      final index = options.indexWhere(soup);
      return index < 0 ? options.length : index;
    }

    final liked = await firstSoup({TasteTag.soup});
    final usual = await firstSoup(const {});

    expect(liked, 0);
    expect(usual, greaterThan(0));
  });
}
