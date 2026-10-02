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
  final Map<(int, MealTarget), VenueMenu> _menus = {};

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
  Future<Result<VenueMenu>> menu(int venueId, MealTarget target) async {
    final cached = _menus[(venueId, target)];
    if (cached != null) return Ok(cached);
    final result = await _api.venueMenu(venueId, target);
    if (result case Ok(:final value)) _menus[(venueId, target)] = value;
    return result;
  }
}
