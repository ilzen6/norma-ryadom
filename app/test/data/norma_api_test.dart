import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:norma_ryadom/data/repositories/combo_repository.dart';
import 'package:norma_ryadom/data/repositories/feedback_repository.dart';
import 'package:norma_ryadom/data/repositories/venue_repository.dart';
import 'package:norma_ryadom/data/services/photo_picker_service.dart';
import 'package:norma_ryadom/data/services/norma_api.dart';
import 'package:norma_ryadom/domain/models/catalog.dart';
import 'package:norma_ryadom/domain/models/combo.dart';
import 'package:norma_ryadom/domain/models/geo_location.dart';
import 'package:norma_ryadom/utils/result.dart';

import '../support/fakes.dart';

class RecordingAdapter implements HttpClientAdapter {
  RecordingAdapter(this.respond);

  final ResponseBody Function(RequestOptions options) respond;
  final List<RequestOptions> requests = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return respond(options);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody json(Object body, {int status = 200}) => ResponseBody.fromString(
  jsonEncode(body),
  status,
  headers: {
    Headers.contentTypeHeader: ['application/json'],
  },
);

void main() {
  late RecordingAdapter adapter;
  late NormaApi api;

  NormaApi apiWith(ResponseBody Function(RequestOptions options) respond) {
    adapter = RecordingAdapter(respond);
    final dio = NormaApi.createDio('http://api.test')..httpClientAdapter = adapter;
    return NormaApi(dio);
  }

  const venueJson = {
    'id': 7,
    'name': 'Гриль',
    'chainName': 'Гриль Хаус',
    'address': 'Пресненская наб., 2',
    'lat': 55.7,
    'lon': 37.5,
    'currency': 'RUB',
  };

  test('запрашивает заведения рядом с целью и разбирает цвет точки, переживая неизвестные значения', () async {
    api = apiWith(
      (_) => json({
        'venues': [
          {'venue': venueJson, 'distanceMeters': 145, 'hasMenu': true, 'fit': 'GOOD'},
          {'venue': venueJson, 'distanceMeters': 300, 'hasMenu': true, 'fit': 'SUPER'},
        ],
      }),
    );

    final result = await api.nearbyVenues(
      location: TestData.deviceLocation,
      radiusMeters: 1500,
      includeWithoutMenu: false,
      target: TestData.lunchTarget,
    );

    final venues = (result as Ok<List<NearbyVenue>>).value;
    expect(venues.map((venue) => venue.fit), [FitLevel.good, FitLevel.unknown]);
    final query = adapter.requests.single.queryParameters;
    expect(adapter.requests.single.path, '/api/v1/venues');
    expect(query['lat'], 55.75);
    expect(query['radius'], 1500);
    expect(query['kcal'], 630);
    expect(query['excludeTags'], 'pork');
    expect(query['includeWithoutMenu'], false);
  });

  test('отправляет подбор рядом с целью, координатами и предпочтением цены', () async {
    api = apiWith(
      (_) => json({
        'appliedTarget': {
          'kcal': 650,
          'kcalTolerance': 50,
          'minProtein': 30,
          'maxFat': 25,
          'maxCarbs': 95,
          'excludeTags': ['pork'],
        },
        'options': <Object>[],
      }),
    );

    final result = await api.searchNearby(
      location: TestData.deviceLocation,
      radiusMeters: 1500,
      target: TestData.lunchTarget,
      price: PricePreference.cheaper,
    );

    expect((result as Ok<ComboSearchResult>).value.appliedTarget.kcal, 650);
    final request = adapter.requests.single;
    final body = request.data as Map<String, dynamic>;
    expect(body.keys, unorderedEquals(['target', 'location', 'preferCheaper', 'limit']));
    expect(
      (body['target'] as Map<String, dynamic>).keys,
      unorderedEquals(['kcal', 'kcalTolerance', 'minProtein', 'maxFat', 'maxCarbs', 'excludeTags']),
    );
    expect(request.queryParameters, isEmpty);
    expect(request.headers.keys.map((key) => key.toLowerCase()), isNot(contains('authorization')));
    expect(body['preferCheaper'], isTrue);
    expect(body['location'], {'lat': 55.75, 'lon': 37.54, 'radiusMeters': 1500});
    expect((body['target'] as Map<String, dynamic>)['excludeTags'], ['pork']);
  });

  test('отправляет замену блюда с порядком блюд и индексом', () async {
    api = apiWith((_) => json({'appliedTarget': TestData.lunchTarget.toJson(), 'options': <Object>[]}));

    await api.replaceDish(
      venueId: 7,
      target: TestData.lunchTarget,
      dishIds: [1, 2],
      replaceIndex: 1,
      price: PricePreference.any,
    );

    final body = adapter.requests.single.data as Map<String, dynamic>;
    expect(adapter.requests.single.path, '/api/v1/combos/replace');
    expect(body['dishIds'], [1, 2]);
    expect(body['replaceIndex'], 1);
    expect(body['preferCheaper'], isFalse);
  });

  test('отправляет фото меню как multipart и жалобу с причиной', () async {
    api = apiWith(
      (options) => options.path.endsWith('reports')
          ? ResponseBody.fromString('', 204)
          : json({'submissionId': 5, 'status': 'NEW'}),
    );

    final photo = await api.uploadMenuPhoto(venueId: 7, bytes: [1, 2, 3], fileName: 'menu.png');
    final report = await api.reportItem(3, 'Цифры другие');

    expect((photo as Ok<SubmissionReceipt>).value.submissionId, 5);
    expect(report, isA<Ok<void>>());
    expect(adapter.requests.first.data, isA<FormData>());
    expect(adapter.requests.last.data, {'reason': 'Цифры другие'});
  });

  for (final (status, failure) in [
    (400, AppFailure.invalidRequest),
    (404, AppFailure.notFound),
    (413, AppFailure.photoTooLarge),
    (415, AppFailure.unsupportedPhoto),
    (422, AppFailure.invalidRequest),
    (429, AppFailure.rateLimited),
    (503, AppFailure.serviceUnavailable),
    (500, AppFailure.unexpected),
  ]) {
    test('превращает ответ $status в понятную ошибку $failure', () async {
      api = apiWith((_) => json({'type': 'urn:x', 'status': status}, status: status));

      final result = await api.venueMenu(1, null);

      expect((result as Err<VenueMenu>).failure, failure);
    });
  }

  test('считает обрыв соединения отсутствием сети', () async {
    api = apiWith((options) => throw DioException.connectionError(requestOptions: options, reason: 'refused'));

    final result = await api.venueMenu(1, TestData.lunchTarget);

    expect((result as Err<VenueMenu>).failure, AppFailure.offline);
    expect(adapter.requests.single.queryParameters['minProtein'], 27.7);
  });

  test('репозиторий заведений каждый раз берёт свежее меню, чтобы не показывать снятые блюда', () async {
    var calls = 0;
    api = apiWith((_) {
      calls++;
      return json({'venue': venueJson, 'items': <Object>[]});
    });
    final repository = RemoteVenueRepository(api, radiusMeters: 1500);

    await repository.menu(7, TestData.lunchTarget);
    await repository.menu(7, TestData.lunchTarget);

    expect(calls, 2);
  });

  test('неожиданный формат ответа превращает в ошибку, а не в падение', () async {
    api = apiWith((_) => json({'venue': venueJson, 'items': 'not-a-list'}));

    final result = await api.venueMenu(7, null);

    expect((result as Err<VenueMenu>).failure, AppFailure.unexpected);
  });

  test('модели переживают неизвестные значения перечислений', () {
    final item = MenuItem.fromJson({
      'id': 1,
      'name': 'Новое',
      'category': 'soup',
      'nutrients': {'kcal': 1, 'protein': 1, 'fat': 1, 'carbs': 1},
      'source': {'kind': 'D'},
      'assessment': {
        'verdict': 'MAYBE',
        'reasons': [
          {'code': 'NEW_REASON'},
        ],
      },
    });

    expect(item.category, DishCategory.unknown);
    expect(item.source.kind, SourceKind.unknown);
    expect(item.assessment?.verdict, Verdict.unknown);
    expect(item.assessment?.reasons.single.code, ReasonCode.unknown);
    expect(const GeoLocation(lat: 1, lon: 2, source: LocationSource.district).source, LocationSource.district);
  });

  test('репозитории подбора и обратной связи передают радиус, заведение и обрезанную причину', () async {
    api = apiWith(
      (options) => options.path.endsWith('reports')
          ? ResponseBody.fromString('', 204)
          : options.path.endsWith('menu-photos')
          ? json({'submissionId': 9, 'status': 'NEW'})
          : json({'appliedTarget': TestData.lunchTarget.toJson(), 'options': <Object>[]}),
    );
    final combos = RemoteComboRepository(api, radiusMeters: 900);
    final feedback = RemoteFeedbackRepository(api);

    await combos.nearby(location: TestData.deviceLocation, target: TestData.lunchTarget, price: PricePreference.any);
    await combos.atVenue(venueId: 7, target: TestData.lunchTarget, price: PricePreference.any);
    await combos.replace(
      venueId: 7,
      target: TestData.lunchTarget,
      dishIds: [1],
      replaceIndex: 0,
      price: PricePreference.any,
    );
    await feedback.sendMenuPhoto(7, const PickedPhoto(bytes: [1], fileName: 'menu.jpg'));
    await feedback.reportItem(3, '  Другие цифры  ');

    final bodies = adapter.requests.map((request) => request.data).toList();
    expect(((bodies[0] as Map<String, dynamic>)['location'] as Map<String, dynamic>)['radiusMeters'], 900);
    expect((bodies[1] as Map<String, dynamic>)['venueId'], 7);
    expect(adapter.requests[2].path, '/api/v1/combos/replace');
    expect(adapter.requests[3].path, '/api/v1/venues/7/menu-photos');
    expect(bodies[4], {'reason': 'Другие цифры'});
  });

  test('репозиторий заведений передаёт радиус и признак «показать все»', () async {
    api = apiWith((_) => json({'venues': <Object>[]}));

    await RemoteVenueRepository(api, radiusMeters: 700).nearby(
      location: TestData.deviceLocation,
      target: TestData.lunchTarget,
      includeWithoutMenu: true,
    );

    expect(adapter.requests.single.queryParameters['radius'], 700);
    expect(adapter.requests.single.queryParameters['includeWithoutMenu'], true);
  });
}
