import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../data/providers.dart';
import '../../domain/models/catalog.dart';
import '../../routing/routes.dart';
import '../../utils/result.dart';
import '../core/l10n_extensions.dart';
import '../core/session.dart';
import '../core/theme.dart';
import '../core/widgets/state_views.dart';
import 'map_view_model.dart';

class MapScreen extends ConsumerWidget {
  const MapScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final venues = ref.watch(mapVenuesProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.navMap),
        actions: [
          Row(
            children: [
              Text(l10n.mapShowAll),
              Switch(
                key: const Key('map-show-all'),
                value: ref.watch(mapCoverageProvider) == MapCoverage.all,
                onChanged: (all) =>
                    ref.read(mapCoverageProvider.notifier).set(all ? MapCoverage.all : MapCoverage.withMenu),
              ),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: switch (venues) {
          AsyncData(value: Ok(:final value)) => _MapBody(venues: value),
          AsyncData(value: Err(:final failure)) => FailureView(
            failure: failure,
            onRetry: () => ref.invalidate(mapVenuesProvider),
          ),
          AsyncError() => FailureView(failure: AppFailure.unexpected, onRetry: () => ref.invalidate(mapVenuesProvider)),
          _ => const LoadingView(),
        },
      ),
    );
  }
}

Color fitColor(NearbyVenue venue) => switch (venue.fit) {
  _ when !venue.hasMenu => AppColors.noData,
  FitLevel.good => AppColors.good,
  FitLevel.compromise => AppColors.compromise,
  _ => AppColors.none,
};

class _MapBody extends ConsumerWidget {
  const _MapBody({required this.venues});

  final List<NearbyVenue> venues;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final location = ref.watch(locationProvider).value?.location;
    final tiles = ref.watch(appConfigProvider).tileUrlTemplate;
    if (location == null) return const LoadingView();
    final center = LatLng(location.lat, location.lon);
    return Column(
      children: [
        SizedBox(
          height: 320,
          child: FlutterMap(
            options: MapOptions(initialCenter: center, initialZoom: 15),
            children: [
              if (tiles.isNotEmpty) TileLayer(urlTemplate: tiles, userAgentPackageName: 'ru.normaryadom.app'),
              MarkerLayer(
                markers: [
                  Marker(
                    point: center,
                    width: 24,
                    height: 24,
                    child: const Icon(Icons.my_location, color: AppColors.brand),
                  ),
                  for (final venue in venues)
                    Marker(
                      point: LatLng(venue.venue.lat, venue.venue.lon),
                      width: 48,
                      height: 48,
                      child: IconButton(
                        tooltip: venue.venue.name,
                        icon: Icon(Icons.location_on, color: fitColor(venue), size: 36),
                        onPressed: () => context.push(Routes.venue(venue.venue.id)),
                      ),
                    ),
                ],
              ),
              if (tiles.isNotEmpty) RichAttributionWidget(attributions: [TextSourceAttribution(l10n.mapAttribution)]),
            ],
          ),
        ),
        const _Legend(),
        Expanded(
          child: venues.isEmpty
              ? MessageView(message: l10n.mapEmpty, icon: Icons.location_off)
              : ListView.builder(
                  key: const Key('map-venue-list'),
                  itemCount: venues.length,
                  itemBuilder: (context, index) {
                    final venue = venues[index];
                    return ListTile(
                      key: Key('map-venue-${venue.venue.id}'),
                      leading: Icon(Icons.circle, color: fitColor(venue)),
                      title: Text(venue.venue.name),
                      subtitle: Text('${venue.venue.address} · ${l10n.distanceMeters(venue.distanceMeters)}'),
                      onTap: () => context.push(Routes.venue(venue.venue.id)),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final items = [
      (AppColors.good, l10n.mapLegendGood),
      (AppColors.compromise, l10n.mapLegendCompromise),
      (AppColors.none, l10n.mapLegendNone),
      (AppColors.noData, l10n.mapLegendNoData),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Wrap(
        spacing: 16,
        runSpacing: 4,
        children: [
          for (final (color, label) in items)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.circle, size: 12, color: color),
                const SizedBox(width: 4),
                Text(label),
              ],
            ),
        ],
      ),
    );
  }
}
