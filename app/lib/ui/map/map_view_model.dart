import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../domain/models/catalog.dart';
import '../../utils/result.dart';
import '../core/session.dart';

enum MapCoverage { withMenu, all }

final mapCoverageProvider = NotifierProvider<MapCoverageController, MapCoverage>(MapCoverageController.new);

class MapCoverageController extends Notifier<MapCoverage> {
  @override
  MapCoverage build() => MapCoverage.withMenu;

  void set(MapCoverage coverage) => state = coverage;
}

final mapVenuesProvider = FutureProvider.autoDispose<Result<List<NearbyVenue>>>((ref) async {
  final target = ref.watch(currentTargetProvider);
  if (target == null) return const Err(AppFailure.invalidRequest);
  final location = await ref.watch(locationProvider.future);
  return ref
      .watch(venueRepositoryProvider)
      .nearby(
        location: location.location,
        target: target,
        includeWithoutMenu: ref.watch(mapCoverageProvider) == MapCoverage.all,
      );
});
