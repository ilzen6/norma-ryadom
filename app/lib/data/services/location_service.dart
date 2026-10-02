import 'package:geolocator/geolocator.dart';

import '../../domain/models/geo_location.dart';
import '../../utils/result.dart';

abstract interface class LocationService {
  Future<Result<GeoLocation>> currentLocation();
}

class DeviceLocationService implements LocationService {
  const DeviceLocationService();

  static const _timeLimit = Duration(seconds: 10);

  @override
  Future<Result<GeoLocation>> currentLocation() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return const Err(AppFailure.locationUnavailable);
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        return const Err(AppFailure.locationDenied);
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(timeLimit: _timeLimit),
      );
      return Ok(GeoLocation(lat: position.latitude, lon: position.longitude, source: LocationSource.device));
    } on Exception {
      return const Err(AppFailure.locationUnavailable);
    }
  }
}
