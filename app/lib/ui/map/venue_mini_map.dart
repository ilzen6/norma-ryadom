import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart' hide Path;

import '../../data/providers.dart';
import '../core/l10n_extensions.dart';
import '../core/session.dart';
import '../core/theme.dart';
import 'vector_basemap.dart';

class VenueMiniMap extends ConsumerWidget {
  const VenueMiniMap({
    super.key,
    required this.lat,
    required this.lon,
    this.height = 150,
    this.margin = EdgeInsets.zero,
  });

  static const nearbyMeters = 1800;

  final double lat;
  final double lon;
  final double height;
  final EdgeInsets margin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final atlas = ref.watch(mapAtlasProvider).value;
    final venue = LatLng(lat, lon);
    if (ref.watch(appConfigProvider).tileUrlTemplate.isNotEmpty || atlas == null || atlas.regionOf(venue) == null) {
      return const SizedBox.shrink();
    }
    final location = ref.watch(locationProvider).value?.location;
    final user = location == null ? null : LatLng(location.lat, location.lon);
    final showUser = user != null && const Distance().as(LengthUnit.Meter, user, venue) <= nearbyMeters;
    return Padding(
      padding: margin,
      child: Semantics(
        image: true,
        label: context.l10n.venueMapLabel,
        child: ExcludeSemantics(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadii.tile),
            child: SizedBox(
              height: height,
              child: IgnorePointer(
                child: FlutterMap(
                  options: MapOptions(
                    initialCameraFit: showUser
                        ? CameraFit.coordinates(
                            coordinates: [venue, user],
                            padding: const EdgeInsets.fromLTRB(40, 56, 40, 24),
                            maxZoom: 17,
                          )
                        : null,
                    initialCenter: venue,
                    initialZoom: 16,
                    backgroundColor: palette.mapLand,
                    interactionOptions: const InteractionOptions(flags: InteractiveFlag.none),
                  ),
                  children: [
                    const VectorBasemap(),
                    if (showUser)
                      PolylineLayer(
                        polylines: [
                          Polyline(
                            points: [user, venue],
                            color: palette.brand.withValues(alpha: 0.7),
                            strokeWidth: 3,
                            pattern: const StrokePattern.dotted(spacingFactor: 2),
                          ),
                        ],
                      ),
                    MarkerLayer(
                      markers: [
                        if (showUser)
                          Marker(
                            point: user,
                            width: 22,
                            height: 22,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: palette.brand,
                                shape: BoxShape.circle,
                                border: Border.all(color: palette.surface, width: 3),
                              ),
                            ),
                          ),
                        Marker(
                          point: venue,
                          width: 40,
                          height: 40,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: palette.brand,
                              shape: BoxShape.circle,
                              border: Border.all(color: palette.surface, width: 3),
                              boxShadow: [
                                BoxShadow(
                                  color: palette.ink.withValues(alpha: 0.25),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Icon(Icons.storefront_rounded, size: 18, color: palette.onBrand),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
