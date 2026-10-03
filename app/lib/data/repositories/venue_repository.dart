import '../../domain/models/catalog.dart';
import '../../domain/models/geo_location.dart';
import '../../domain/models/meal.dart';
import '../../utils/result.dart';
import '../services/norma_api.dart';

abstract interface class VenueRepository {
  Future<Result<List<NearbyVenue>>> nearby({
    required GeoLocation location,
    required MealTarget target,
    required bool includeWithoutMenu,
    int? radiusMeters,
    int? limit,
  });

  Future<Result<VenueMenu>> menu(int venueId, MealTarget target);
}

class RemoteVenueRepository implements VenueRepository {
  RemoteVenueRepository(this._api, {required this.radiusMeters});

  final NormaApi _api;
  final int radiusMeters;

  @override
  Future<Result<List<NearbyVenue>>> nearby({
    required GeoLocation location,
    required MealTarget target,
    required bool includeWithoutMenu,
    int? radiusMeters,
    int? limit,
  }) => _api.nearbyVenues(
    location: location,
    radiusMeters: radiusMeters ?? this.radiusMeters,
    includeWithoutMenu: includeWithoutMenu,
    target: target,
    limit: limit,
  );

  @override
  Future<Result<VenueMenu>> menu(int venueId, MealTarget target) => _api.venueMenu(venueId, target);
}
