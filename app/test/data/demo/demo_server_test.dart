import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:norma_ryadom/data/demo/demo_server.dart';
import 'package:norma_ryadom/data/services/location_service.dart';
import 'package:norma_ryadom/data/services/norma_api.dart';
import 'package:norma_ryadom/domain/models/catalog.dart';
import 'package:norma_ryadom/domain/models/combo.dart';
import 'package:norma_ryadom/utils/result.dart';

import '../../support/fakes.dart';

void main() {
  final api = NormaApi(
    NormaApi.createDio('http://demo')
      ..httpClientAdapter = DemoServerAdapter(() async => File('assets/demo/catalog.json').readAsStringSync()),
  );
  const center = DemoLocationService.moscowCity;

  T valueOf<T>(Result<T> result) => switch (result) {
    Ok(:final value) => value,
    Err(:final failure) => throw StateError('$failure'),
  };

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
    expect(result.options, hasLength(5));
    expect(result.options.map((option) => option.venue.name).toSet().length, greaterThanOrEqualTo(2));
    for (final option in result.options) {
      expect(option.combo.dishes.expand((dish) => dish.tags), isNot(contains('pork')));
      expect(option.combo.checks.map((check) => check.metric), [Metric.kcal, Metric.protein, Metric.fat, Metric.carbs]);
      expect(option.distanceMeters, isNotNull);
    }
  });

  test('меню заведения отсортировано по близости к цели и с пометками', () async {
    final menu = valueOf(await api.venueMenu(1, TestData.lunchTarget));

    expect(menu.venue.name, 'Гриль Хаус, Москва-Сити');
    expect(menu.items.first.assessment?.verdict, Verdict.fits);
    final ribs = menu.items.firstWhere((item) => item.name == 'Свиные рёбрышки');
    expect(ribs.assessment?.verdict, Verdict.notFits);
    expect(ribs.assessment?.reasons.first.code, ReasonCode.excludedTag);
    expect(ribs.source.kind, SourceKind.verified);
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
}
