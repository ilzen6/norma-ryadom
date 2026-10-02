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
  }) => _api.nearbyVenues(
    location: location,
    radiusMeters: radiusMeters,
    includeWithoutMenu: includeWithoutMenu,
    target: target,
  );

  @override
  Future<Result<VenueMenu>> menu(int venueId, MealTarget target) => _api.venueMenu(venueId, target);
}
