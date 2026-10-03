import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../domain/models/catalog.dart' show VenueReportReason;
import 'demo_engine.dart';

class DemoVenue {
  const DemoVenue({
    required this.id,
    required this.name,
    required this.chainName,
    required this.address,
    required this.lat,
    required this.lon,
    this.confirmedOn,
  });

  final int id;
  final String name;
  final String chainName;
  final String address;
  final double lat;
  final double lon;
  final String? confirmedOn;
}

class DemoChain {
  const DemoChain({required this.name, required this.sourceUrl, required this.menu, required this.venues});

  final String name;
  final String sourceUrl;
  final List<DemoDish> menu;
  final List<DemoVenue> venues;
}

class DemoCatalog {
  const DemoCatalog({required this.verifiedAt, required this.chains});

  factory DemoCatalog.fromJson(String json) {
    final root = jsonDecode(json) as Map<String, dynamic>;
    var nextDishId = 1;
    var nextVenueId = 1;
    final chains = [
      for (final chain in (root['chains'] as List<dynamic>).cast<Map<String, dynamic>>())
        DemoChain(
          name: chain['name'] as String,
          sourceUrl: chain['sourceUrl'] as String,
          menu: [
            for (final item in (chain['items'] as List<dynamic>).cast<Map<String, dynamic>>())
              DemoDish(
                id: nextDishId++,
                name: item['name'] as String,
                category: item['category'] as String,
                portionGrams: (item['portionGrams'] as num?)?.toDouble(),
                nutrients: DemoNutrients(
                  (item['kcal'] as num).toDouble(),
                  (item['protein'] as num).toDouble(),
                  (item['fat'] as num).toDouble(),
                  (item['carbs'] as num).toDouble(),
                ),
                priceMinor: item['priceMinor'] as int?,
                tags: (item['tags'] as List<dynamic>).cast<String>(),
              ),
          ],
          venues: [
            for (final venue in (chain['venues'] as List<dynamic>).cast<Map<String, dynamic>>())
              DemoVenue(
                id: nextVenueId++,
                name: venue['name'] as String,
                chainName: chain['name'] as String,
                address: venue['address'] as String,
                lat: (venue['lat'] as num).toDouble(),
                lon: (venue['lon'] as num).toDouble(),
                confirmedOn: venue['confirmedOn'] as String?,
              ),
          ],
        ),
    ];
    return DemoCatalog(verifiedAt: root['verifiedAt'] as String, chains: chains);
  }

  final String verifiedAt;
  final List<DemoChain> chains;

  DemoChain? chainOfVenue(int venueId) => chains.where((chain) => chain.venues.any((v) => v.id == venueId)).firstOrNull;

  DemoVenue? venue(int venueId) =>
      chains.expand((chain) => chain.venues).where((venue) => venue.id == venueId).firstOrNull;
}

class DemoServerAdapter implements HttpClientAdapter {
  DemoServerAdapter(Future<String> Function() loadCatalog) : _catalog = loadCatalog().then(DemoCatalog.fromJson);

  static const _maxNearby = 100;
  static const _maxLimit = 500;
  static const _combosPerVenue = 2;
  static const _cachedCombos = 5;
  static const _distanceWeightPerKm = 0.5;
  static const _dietTagOrder = [
    'meat',
    'pork',
    'beef',
    'chicken',
    'fish',
    'seafood',
    'nuts',
    'milk',
    'gluten',
    'egg',
    'soy',
  ];
  static const _categoryOrder = ['main', 'side', 'salad', 'drink', 'dessert', 'sauce'];

  final Future<DemoCatalog> _catalog;
  int _submissions = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final catalog = await _catalog;
    final path = options.uri.path;
    final method = options.method.toUpperCase();
    final venueMenu = RegExp(r'^/api/v1/venues/(\d+)/menu$').firstMatch(path);
    final menuPhotos = RegExp(r'^/api/v1/venues/(\d+)/menu-photos$').firstMatch(path);
    final reports = RegExp(r'^/api/v1/items/(\d+)/reports$').firstMatch(path);
    final venueReports = RegExp(r'^/api/v1/venues/(\d+)/reports$').firstMatch(path);
    return switch ((method, path)) {
      ('GET', '/actuator/health') => _json({'status': 'UP'}),
      ('GET', '/api/v1/venues') => _nearbyVenues(catalog, options.uri.queryParameters),
      ('GET', _) when venueMenu != null => _venueMenu(
        catalog,
        int.parse(venueMenu.group(1)!),
        options.uri.queryParameters,
      ),
      ('POST', '/api/v1/combos/search') => _search(catalog, _body(options)),
      ('POST', '/api/v1/combos/replace') => _replace(catalog, _body(options)),
      ('POST', _) when menuPhotos != null =>
        catalog.venue(int.parse(menuPhotos.group(1)!)) == null
            ? _problem(404)
            : _json({'submissionId': ++_submissions, 'status': 'NEW'}, status: 202),
      ('POST', _) when reports != null => ResponseBody.fromString('', 204),
      ('POST', _) when venueReports != null => _venueReport(catalog, int.parse(venueReports.group(1)!), _body(options)),
      _ => _problem(404),
    };
  }

  @override
  void close({bool force = false}) {}

  ResponseBody _nearbyVenues(DemoCatalog catalog, Map<String, String> query) {
    final center = (double.parse(query['lat']!), double.parse(query['lon']!));
    final radius = double.parse(query['radius']!);
    final limit = (int.tryParse(query['limit'] ?? '') ?? _maxNearby).clamp(1, _maxLimit);
    final target = _queryTarget(query);
    final strict = target?.rounded();
    const optimizer = DemoOptimizer(DemoScorer());
    final venues = _within(catalog, center, radius, limit: limit);
    final fits = <DemoChain, String?>{};
    String? fitOf(DemoChain chain) => fits.putIfAbsent(
      chain,
      () => strict == null
          ? null
          : optimizer.bestCombos(chain.menu, strict, _cachedCombos).isNotEmpty
          ? 'GOOD'
          : optimizer.bestCombos(chain.menu, strict.relaxed(), _cachedCombos).isNotEmpty
          ? 'COMPROMISE'
          : 'NONE',
    );
    return _json({
      'venues': [
        for (final (chain, venue, distance) in venues)
          {'venue': _venueJson(venue), 'distanceMeters': distance.round(), 'hasMenu': true, 'fit': fitOf(chain)},
      ],
    });
  }

  ResponseBody _venueMenu(DemoCatalog catalog, int venueId, Map<String, String> query) {
    final chain = catalog.chainOfVenue(venueId);
    final venue = catalog.venue(venueId);
    if (chain == null || venue == null) return _problem(404);
    final target = _queryTarget(query);
    final items = target == null
        ? [for (final dish in chain.menu) _menuItemJson(catalog, chain, dish, null)]
        : [
            for (final assessment in const DemoAssessor(DemoScorer()).assessMenu(chain.menu, target))
              _menuItemJson(catalog, chain, assessment.dish, assessment),
          ];
    return _json({'venue': _venueJson(venue), 'items': items});
  }

  ResponseBody _search(DemoCatalog catalog, Map<String, dynamic> body) {
    final target = _bodyTarget(body['target'] as Map<String, dynamic>);
    final scorer = DemoScorer(preferCheaper: body['preferCheaper'] == true);
    final optimizer = DemoOptimizer(scorer);
    final limit = (body['limit'] as int?) ?? 5;
    final location = body['location'] as Map<String, dynamic>?;
    if (location == null) {
      final venueId = body['venueId'] as int;
      final chain = catalog.chainOfVenue(venueId);
      final venue = catalog.venue(venueId);
      if (chain == null || venue == null) return _problem(404);
      return _searchResponse(target, [
        for (final combo in optimizer.bestCombos(chain.menu, target, limit)) (venue, null, combo),
      ]);
    }
    final applied = target.rounded();
    final center = ((location['lat'] as num).toDouble(), (location['lon'] as num).toDouble());
    final ranked =
        <(double, DemoVenue, double, DemoCombo)>[
          for (final (chain, venue, distance) in _within(catalog, center, (location['radiusMeters'] as num).toDouble()))
            for (final combo in optimizer.bestCombos(chain.menu, applied, _cachedCombos).take(_combosPerVenue))
              (combo.score + _distanceWeightPerKm * distance / 1000, venue, distance, combo),
        ]..sort((left, right) {
          final byRank = left.$1.compareTo(right.$1);
          return byRank != 0 ? byRank : DemoCombo.compare(left.$4, right.$4);
        });
    return _searchResponse(applied, [
      for (final (_, venue, distance, combo) in ranked.take(limit)) (venue, distance, combo),
    ]);
  }

  ResponseBody _replace(DemoCatalog catalog, Map<String, dynamic> body) {
    final venueId = body['venueId'] as int;
    final chain = catalog.chainOfVenue(venueId);
    final venue = catalog.venue(venueId);
    if (chain == null || venue == null) return _problem(404);
    final target = _bodyTarget(body['target'] as Map<String, dynamic>);
    final dishIds = (body['dishIds'] as List<dynamic>).cast<int>();
    final replaceIndex = body['replaceIndex'] as int;
    if (replaceIndex < 0 || replaceIndex >= dishIds.length) return _problem(400);
    final byId = {for (final dish in chain.menu) dish.id: dish};
    if (dishIds.any((id) => !byId.containsKey(id))) return _problem(422);
    final dishes = [for (final id in dishIds) byId[id]!];
    if ([
      for (final (index, dish) in dishes.indexed)
        if (index != replaceIndex && !target.allows(dish)) dish,
    ].isNotEmpty) {
      return _problem(422);
    }
    final optimizer = DemoOptimizer(DemoScorer(preferCheaper: body['preferCheaper'] == true));
    final combos = optimizer.replacements(chain.menu, target, dishes, replaceIndex, (body['limit'] as int?) ?? 5);
    return _searchResponse(target, [for (final combo in combos) (venue, null, combo)]);
  }

  List<(DemoChain, DemoVenue, double)> _within(
    DemoCatalog catalog,
    (double, double) center,
    double radius, {
    int limit = _maxNearby,
  }) {
    final found =
        [
          for (final chain in catalog.chains)
            for (final venue in chain.venues)
              if (_distanceMeters(center, (venue.lat, venue.lon)) case final distance when distance <= radius)
                (chain, venue, distance),
        ]..sort((left, right) {
          final byDistance = left.$3.compareTo(right.$3);
          return byDistance != 0 ? byDistance : left.$2.id.compareTo(right.$2.id);
        });
    return found.take(limit).toList();
  }

  static double _distanceMeters((double, double) from, (double, double) to) {
    const earthRadius = 6371008.8;
    double radians(double degrees) => degrees * math.pi / 180;
    final dLat = radians(to.$1 - from.$1);
    final dLon = radians(to.$2 - from.$2);
    final a =
        math.pow(math.sin(dLat / 2), 2) +
        math.cos(radians(from.$1)) * math.cos(radians(to.$1)) * math.pow(math.sin(dLon / 2), 2);
    return 2 * earthRadius * math.asin(math.sqrt(a));
  }

  ResponseBody _searchResponse(DemoTarget applied, List<(DemoVenue, double?, DemoCombo)> options) => _json({
    'appliedTarget': {
      'kcal': applied.kcal,
      'kcalTolerance': applied.kcalTolerance,
      'minProtein': applied.minProtein,
      'maxFat': applied.maxFat,
      'maxCarbs': applied.maxCarbs,
      'excludeTags': _sortedTags(applied.excludedTags),
    },
    'options': [
      for (final (venue, distance, combo) in options)
        {
          'venue': _venueJson(venue),
          'distanceMeters': distance?.round(),
          'combo': {
            'dishes': [
              for (final dish in [
                ...combo.dishes,
              ]..sort((a, b) => _categoryOrder.indexOf(a.category).compareTo(_categoryOrder.indexOf(b.category))))
                {
                  'id': dish.id,
                  'name': dish.name,
                  'category': dish.category,
                  'portionGrams': dish.portionGrams,
                  'nutrients': _nutrientsJson(dish.nutrients),
                  'priceMinor': dish.priceMinor,
                  'sourceKind': 'A',
                  'tags': _sortedTags(dish.tags),
                },
            ],
            'totals': _nutrientsJson(combo.totals),
            'priceMinor': combo.priceMinor,
            'sourceKind': 'A',
            'score': _round(combo.score, 4),
            'checks': [
              for (final check in DemoExplanation.explain(combo.totals, applied))
                {
                  'metric': check.metric,
                  'value': _round(check.value, 1),
                  'goal': _round(check.goal, 1),
                  'delta': _round(check.delta, 1),
                  'status': check.status.name.toUpperCase(),
                },
            ],
          },
        },
    ],
  });

  Map<String, Object?> _menuItemJson(DemoCatalog catalog, DemoChain chain, DemoDish dish, DemoAssessment? assessment) =>
      {
        'id': dish.id,
        'name': dish.name,
        'category': dish.category,
        'portionGrams': dish.portionGrams,
        'nutrients': _nutrientsJson(dish.nutrients),
        'priceMinor': dish.priceMinor,
        'tags': _sortedTags(dish.tags),
        'source': {'kind': 'A', 'url': chain.sourceUrl, 'verifiedAt': catalog.verifiedAt},
        if (assessment != null)
          'assessment': {
            'verdict': switch (assessment.verdict) {
              DemoVerdict.fits => 'FITS',
              DemoVerdict.partial => 'PARTIAL',
              DemoVerdict.notFits => 'NOT_FITS',
            },
            'reasons': [
              for (final reason in assessment.reasons)
                {
                  'code': reason.code,
                  'amount': reason.amount == null ? null : _round(reason.amount!, 1),
                  'tag': reason.tag,
                },
            ],
          },
      };

  static ResponseBody _venueReport(DemoCatalog catalog, int venueId, Map<String, dynamic> body) {
    if (catalog.venue(venueId) == null) return _problem(404);
    final reason = body['reason'];
    final known = VenueReportReason.values.any((value) => value.code == reason);
    return known ? ResponseBody.fromString('', 204) : _problem(400);
  }

  static Map<String, Object> _venueJson(DemoVenue venue) => {
    'id': venue.id,
    'name': venue.name,
    'chainName': venue.chainName,
    'address': venue.address,
    'lat': venue.lat,
    'lon': venue.lon,
    'currency': 'RUB',
    'confirmedOn': ?venue.confirmedOn,
  };

  static Map<String, double> _nutrientsJson(DemoNutrients nutrients) => {
    'kcal': _round(nutrients.kcal, 1),
    'protein': _round(nutrients.protein, 1),
    'fat': _round(nutrients.fat, 1),
    'carbs': _round(nutrients.carbs, 1),
  };

  static List<String> _sortedTags(Iterable<String> tags) =>
      tags.toList()..sort((a, b) => _dietTagOrder.indexOf(a).compareTo(_dietTagOrder.indexOf(b)));

  static double _round(double value, int digits) {
    final scale = math.pow(10, digits);
    return (value * scale).round() / scale;
  }

  static DemoTarget? _queryTarget(Map<String, String> query) {
    if (query['kcal'] == null) return null;
    return DemoTarget(
      kcal: double.parse(query['kcal']!),
      kcalTolerance: double.parse(query['kcalTolerance']!),
      minProtein: double.parse(query['minProtein']!),
      maxFat: double.parse(query['maxFat']!),
      maxCarbs: double.parse(query['maxCarbs']!),
      excludedTags: {...?query['excludeTags']?.split(',').where((tag) => tag.isNotEmpty)},
    );
  }

  static DemoTarget _bodyTarget(Map<String, dynamic> json) => DemoTarget(
    kcal: (json['kcal'] as num).toDouble(),
    kcalTolerance: (json['kcalTolerance'] as num).toDouble(),
    minProtein: (json['minProtein'] as num).toDouble(),
    maxFat: (json['maxFat'] as num).toDouble(),
    maxCarbs: (json['maxCarbs'] as num).toDouble(),
    excludedTags: {...((json['excludeTags'] as List<dynamic>?) ?? const []).cast<String>()},
  );

  static Map<String, dynamic> _body(RequestOptions options) => switch (options.data) {
    final Map<String, dynamic> map => map,
    final String text => jsonDecode(text) as Map<String, dynamic>,
    _ => const <String, dynamic>{},
  };

  static ResponseBody _json(Object body, {int status = 200}) => ResponseBody.fromString(
    jsonEncode(body),
    status,
    headers: {
      Headers.contentTypeHeader: ['application/json'],
    },
  );

  static ResponseBody _problem(int status) => ResponseBody.fromString(
    jsonEncode({'type': 'urn:norma-ryadom:problem:demo', 'status': status}),
    status,
    headers: {
      Headers.contentTypeHeader: ['application/problem+json'],
    },
  );
}
