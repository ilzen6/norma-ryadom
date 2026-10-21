import '../../domain/models/combo.dart';
import '../../domain/models/geo_location.dart';
import '../../domain/models/meal.dart';
import '../../utils/result.dart';
import '../services/norma_api.dart';

abstract interface class ComboRepository {
  Future<Result<ComboSearchResult>> nearby({
    required GeoLocation location,
    required MealTarget target,
    required PricePreference price,
  });

  Future<Result<ComboSearchResult>> atVenue({
    required int venueId,
    required MealTarget target,
    required PricePreference price,
  });

  Future<Result<ComboSearchResult>> replace({
    required int venueId,
    required MealTarget target,
    required List<int> dishIds,
    required int replaceIndex,
    required PricePreference price,
  });
}

class RemoteComboRepository implements ComboRepository {
  const RemoteComboRepository(this._api, {required this.radiusMeters});

  static const wideRadiiMeters = [3000, 6000];
  static const enoughOptions = 8;

  final NormaApi _api;
  final int radiusMeters;

  @override
  Future<Result<ComboSearchResult>> nearby({
    required GeoLocation location,
    required MealTarget target,
    required PricePreference price,
  }) async {
    final radii = [radiusMeters, ...wideRadiiMeters.where((radius) => radius > radiusMeters)];
    late Result<ComboSearchResult> found;
    for (final radius in radii) {
      found = await _api.searchNearby(location: location, radiusMeters: radius, target: target, price: price);
      switch (found) {
        case Ok(:final value) when value.options.length >= enoughOptions || radius == radii.last:
          return Ok(value.copyWith(radiusMeters: radius));
        case Ok():
          continue;
        case Err():
          return found;
      }
    }
    return found;
  }

  @override
  Future<Result<ComboSearchResult>> atVenue({
    required int venueId,
    required MealTarget target,
    required PricePreference price,
  }) => _api.searchAtVenue(venueId: venueId, target: target, price: price);

  @override
  Future<Result<ComboSearchResult>> replace({
    required int venueId,
    required MealTarget target,
    required List<int> dishIds,
    required int replaceIndex,
    required PricePreference price,
  }) => _api.replaceDish(venueId: venueId, target: target, dishIds: dishIds, replaceIndex: replaceIndex, price: price);
}
