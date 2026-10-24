import 'dart:async';

import 'package:geolocator/geolocator.dart';

import '../../domain/models/geo_location.dart';
import '../../utils/result.dart';

abstract interface class LocationService {
  Future<AppFailure?> ensureAccess();

  Future<Result<GeoLocation>> currentLocation();
}

class DeviceLocationService implements LocationService {
  const DeviceLocationService();

  static const _timeLimit = Duration(seconds: 15);
  static const _preciseMeters = 30.0;
  static const _fullAccuracyPurpose = 'NearbyVenues';

  @override
  Future<AppFailure?> ensureAccess() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return AppFailure.locationOff;
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        return AppFailure.locationDenied;
      }
      await _askForFullAccuracy();
      return null;
    } on Exception {
      return AppFailure.locationUnavailable;
    }
  }

  @override
  Future<Result<GeoLocation>> currentLocation() async {
    try {
      if (await ensureAccess() case final failure?) return Err(failure);
      final position = await _mostAccurate() ?? await Geolocator.getLastKnownPosition();
      if (position == null) return const Err(AppFailure.locationUnavailable);
      return Ok(GeoLocation(lat: position.latitude, lon: position.longitude, source: LocationSource.device));
    } on Exception {
      return const Err(AppFailure.locationUnavailable);
    }
  }

  static Future<void> _askForFullAccuracy() async {
    try {
      if (await Geolocator.getLocationAccuracy() == LocationAccuracyStatus.reduced) {
        await Geolocator.requestTemporaryFullAccuracy(purposeKey: _fullAccuracyPurpose);
      }
    } on Exception {
      return;
    }
  }

  static Future<Position?> _mostAccurate() async {
    final elapsed = Stopwatch()..start();
    Position? best;
    try {
      final positions = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.best),
      ).timeout(_timeLimit);
      await for (final position in positions) {
        if (best == null || position.accuracy < best.accuracy) best = position;
        if (position.accuracy <= _preciseMeters || elapsed.elapsed >= _timeLimit) break;
      }
    } on TimeoutException {
      return best;
    }
    return best;
  }
}
