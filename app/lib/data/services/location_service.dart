import 'dart:async';

import 'package:geolocator/geolocator.dart';

import '../../domain/models/geo_location.dart';
import '../../utils/result.dart';

abstract interface class LocationService {
  Future<Result<GeoLocation>> currentLocation();
}

class DeviceLocationService implements LocationService {
  const DeviceLocationService();

  static const _timeLimit = Duration(seconds: 20);
  static const _recent = Duration(minutes: 10);

  @override
  Future<Result<GeoLocation>> currentLocation() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return const Err(AppFailure.locationOff);
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        return const Err(AppFailure.locationDenied);
      }
      final lastKnown = await Geolocator.getLastKnownPosition();
      final isRecent = lastKnown != null && DateTime.now().difference(lastKnown.timestamp) < _recent;
      final position = isRecent ? lastKnown : await _fresh() ?? lastKnown;
      if (position == null) return const Err(AppFailure.locationUnavailable);
      return Ok(GeoLocation(lat: position.latitude, lon: position.longitude, source: LocationSource.device));
    } on Exception {
      return const Err(AppFailure.locationUnavailable);
    }
  }

  static Future<Position?> _fresh() async {
    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium, timeLimit: _timeLimit),
      );
    } on TimeoutException {
      return null;
    }
  }
}
