import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../data/providers.dart';
import '../../domain/models/catalog.dart';
import '../../domain/models/geo_location.dart';
import '../../utils/result.dart';
import '../core/session.dart';

enum MapCoverage { withMenu, all }

final mapCoverageProvider = NotifierProvider<MapCoverageController, MapCoverage>(MapCoverageController.new);

class MapCoverageController extends Notifier<MapCoverage> {
  @override
  MapCoverage build() => MapCoverage.withMenu;

  void set(MapCoverage coverage) => state = coverage;
}

class MapViewport {
  const MapViewport({required this.center, required this.radiusMeters});

  final GeoLocation center;
  final int radiusMeters;

  @override
  bool operator ==(Object other) =>
      other is MapViewport && other.center == center && other.radiusMeters == radiusMeters;

  @override
  int get hashCode => Object.hash(center, radiusMeters);
}

final mapViewportProvider = NotifierProvider<MapViewportController, MapViewport?>(MapViewportController.new);

class MapViewportController extends Notifier<MapViewport?> {
  static const minRadius = 500;
  static const maxRadius = 30000;

  @override
  MapViewport? build() => null;

  void show(double lat, double lon, double radiusMeters) {
    final next = MapViewport(
      center: GeoLocation(lat: lat, lon: lon, source: LocationSource.district),
      radiusMeters: radiusMeters.round().clamp(minRadius, maxRadius),
    );
    if (next != state) state = next;
  }
}

class MapVenues {
  const MapVenues(this.venues, {required this.truncated});

  final List<NearbyVenue> venues;
  final bool truncated;
}

const mapVenueLimit = 400;

final mapVenuesProvider = FutureProvider.autoDispose<Result<MapVenues>>((ref) async {
  final target = ref.watch(currentTargetProvider);
  if (target == null) return const Err(AppFailure.invalidRequest);
  final user = (await ref.watch(locationProvider.future)).location;
  final viewport = ref.watch(mapViewportProvider);
  final result = await ref
      .watch(venueRepositoryProvider)
      .nearby(
        location: viewport?.center ?? user,
        target: target,
        includeWithoutMenu: ref.watch(mapCoverageProvider) == MapCoverage.all,
        radiusMeters: viewport?.radiusMeters,
        limit: mapVenueLimit,
      );
  return switch (result) {
    Ok(:final value) => Ok(
      MapVenues(
        [
          for (final venue in value)
            venue.copyWith(
              distanceMeters: const Distance()
                  .as(LengthUnit.Meter, LatLng(user.lat, user.lon), LatLng(venue.venue.lat, venue.venue.lon))
                  .round(),
            ),
        ]..sort((a, b) => a.distanceMeters.compareTo(b.distanceMeters)),
        truncated: value.length >= mapVenueLimit,
      ),
    ),
    Err(:final failure) => Err(failure),
  };
});
