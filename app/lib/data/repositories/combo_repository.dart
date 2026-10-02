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

  final NormaApi _api;
  final int radiusMeters;

  @override
  Future<Result<ComboSearchResult>> nearby({
    required GeoLocation location,
    required MealTarget target,
    required PricePreference price,
  }) => _api.searchNearby(location: location, radiusMeters: radiusMeters, target: target, price: price);

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
