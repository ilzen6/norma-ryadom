import 'package:dio/dio.dart';

import '../../domain/models/catalog.dart';
import '../../domain/models/combo.dart';
import '../../domain/models/geo_location.dart';
import '../../domain/models/meal.dart';
import '../../utils/result.dart';

enum PricePreference { any, cheaper }

class SubmissionReceipt {
  const SubmissionReceipt({required this.submissionId});

  final int submissionId;
}

class NormaApi {
  NormaApi(this._dio);

  final Dio _dio;

  Future<Result<List<NearbyVenue>>> nearbyVenues({
    required GeoLocation location,
    required int radiusMeters,
    required bool includeWithoutMenu,
    MealTarget? target,
    int? limit,
  }) => _call(
    () => _dio.get<Map<String, dynamic>>(
      '/api/v1/venues',
      queryParameters: {
        'lat': location.lat,
        'lon': location.lon,
        'radius': radiusMeters,
        'includeWithoutMenu': includeWithoutMenu,
        'limit': ?limit,
        if (target != null) ..._targetQuery(target),
      },
    ),
    (json) =>
        (json['venues'] as List<dynamic>).map((venue) => NearbyVenue.fromJson(venue as Map<String, dynamic>)).toList(),
  );

  Future<Result<VenueMenu>> venueMenu(int venueId, MealTarget? target) => _call(
    () => _dio.get<Map<String, dynamic>>(
      '/api/v1/venues/$venueId/menu',
      queryParameters: target == null ? null : _targetQuery(target),
    ),
    VenueMenu.fromJson,
  );

  Future<Result<ComboSearchResult>> searchNearby({
    required GeoLocation location,
    required int radiusMeters,
    required MealTarget target,
    required PricePreference price,
  }) => _call(
    () => _dio.post<Map<String, dynamic>>(
      '/api/v1/combos/search',
      data: {
        'target': target.toJson(),
        'location': {'lat': location.lat, 'lon': location.lon, 'radiusMeters': radiusMeters},
        'preferCheaper': price == PricePreference.cheaper,
        'limit': 5,
      },
    ),
    ComboSearchResult.fromJson,
  );

  Future<Result<ComboSearchResult>> searchAtVenue({
    required int venueId,
    required MealTarget target,
    required PricePreference price,
  }) => _call(
    () => _dio.post<Map<String, dynamic>>(
      '/api/v1/combos/search',
      data: {
        'target': target.toJson(),
        'venueId': venueId,
        'preferCheaper': price == PricePreference.cheaper,
        'limit': 5,
      },
    ),
    ComboSearchResult.fromJson,
  );

  Future<Result<ComboSearchResult>> replaceDish({
    required int venueId,
    required MealTarget target,
    required List<int> dishIds,
    required int replaceIndex,
    required PricePreference price,
  }) => _call(
    () => _dio.post<Map<String, dynamic>>(
      '/api/v1/combos/replace',
      data: {
        'venueId': venueId,
        'target': target.toJson(),
        'dishIds': dishIds,
        'replaceIndex': replaceIndex,
        'preferCheaper': price == PricePreference.cheaper,
        'limit': 5,
      },
    ),
    ComboSearchResult.fromJson,
  );

  Future<Result<SubmissionReceipt>> uploadMenuPhoto({
    required int venueId,
    required List<int> bytes,
    required String fileName,
  }) => _call(
    () => _dio.post<Map<String, dynamic>>(
      '/api/v1/venues/$venueId/menu-photos',
      data: FormData.fromMap({'photo': MultipartFile.fromBytes(bytes, filename: fileName)}),
    ),
    (json) => SubmissionReceipt(submissionId: json['submissionId'] as int),
  );

  Future<Result<void>> reportVenue(int venueId, VenueReportReason reason) =>
      _call(() => _dio.post<void>('/api/v1/venues/$venueId/reports', data: {'reason': reason.code}), (_) {});

  Future<Result<void>> reportItem(int itemId, String reason) =>
      _call(() => _dio.post<void>('/api/v1/items/$itemId/reports', data: {'reason': reason}), (_) {});

  Future<Result<void>> health() => _call(() => _dio.get<void>('/actuator/health'), (_) {});

  Map<String, Object> _targetQuery(MealTarget target) => {
    'kcal': target.kcal,
    'kcalTolerance': target.kcalTolerance,
    'minProtein': target.minProtein,
    'maxFat': target.maxFat,
    'maxCarbs': target.maxCarbs,
    if (target.excludeTags.isNotEmpty) 'excludeTags': target.excludeTags.join(','),
  };

  Future<Result<T>> _call<T, B>(Future<Response<B>> Function() request, T Function(B body) parse) async {
    final Response<B> response;
    try {
      response = await request();
    } on DioException catch (error) {
      return Err(failureOf(error));
    }
    try {
      return Ok(parse(response.data as B));
    } on Object {
      return const Err(AppFailure.unexpected);
    }
  }

  static AppFailure failureOf(DioException error) {
    final status = error.response?.statusCode;
    if (status == null) return AppFailure.offline;
    return switch (status) {
      400 => AppFailure.invalidRequest,
      404 => AppFailure.notFound,
      413 => AppFailure.photoTooLarge,
      415 => AppFailure.unsupportedPhoto,
      422 => AppFailure.invalidRequest,
      429 => AppFailure.rateLimited,
      503 => AppFailure.serviceUnavailable,
      _ => AppFailure.unexpected,
    };
  }

  static Dio createDio(String baseUrl) => Dio(
    BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 5),
      receiveTimeout: const Duration(seconds: 15),
      sendTimeout: const Duration(seconds: 30),
      responseType: ResponseType.json,
    ),
  );
}
