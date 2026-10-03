import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart' hide Path;

import '../../data/map/basemap.dart';
import '../../data/map/map_atlas.dart';
import '../../data/providers.dart';
import '../../domain/models/catalog.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../routing/routes.dart';
import '../../utils/result.dart';
import '../core/l10n_extensions.dart';
import '../core/session.dart';
import '../core/theme.dart';
import '../core/widgets/state_views.dart';
import '../core/widgets/visuals.dart';
import 'vector_basemap.dart';
import 'map_view_model.dart';

class MapScreen extends ConsumerWidget {
  const MapScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final venues = ref.watch(mapVenuesProvider);
    void retry() => ref.invalidate(mapVenuesProvider);
    return Scaffold(
      backgroundColor: context.palette.canvas,
      body: switch (venues.hasError && !venues.isLoading ? null : venues.value) {
        Ok(:final value) => _MapBody(venues: value.venues, truncated: value.truncated),
        Err(:final failure) => _MapMessage(
          child: FailureView(failure: failure, onRetry: retry),
        ),
        null when venues.hasError => _MapMessage(
          child: FailureView(failure: AppFailure.unexpected, onRetry: retry),
        ),
        null => _MapMessage(
          child: Semantics(label: l10n.navMap, child: const LoadingView()),
        ),
      },
    );
  }
}

class _MapMessage extends StatelessWidget {
  const _MapMessage({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Column(
      children: [
        const _MapToolbar(),
        Expanded(child: Center(child: child)),
      ],
    ),
  );
}

enum _FitMark { good, compromise, none, noData }

_FitMark _markOf(NearbyVenue venue) => switch (venue.fit) {
  _ when !venue.hasMenu => _FitMark.noData,
  FitLevel.good => _FitMark.good,
  FitLevel.compromise => _FitMark.compromise,
  _ => _FitMark.none,
};

Color _colorOf(Palette palette, _FitMark mark) => switch (mark) {
  _FitMark.good => palette.good,
  _FitMark.compromise => palette.warn,
  _FitMark.none => palette.neutral,
  _FitMark.noData => palette.inkSubtle,
};

String _labelOf(AppLocalizations l10n, _FitMark mark) => switch (mark) {
  _FitMark.good => l10n.mapLegendGood,
  _FitMark.compromise => l10n.mapLegendCompromise,
  _FitMark.none => l10n.mapLegendNone,
  _FitMark.noData => l10n.mapLegendNoData,
};

class _MapToolbar extends ConsumerWidget {
  const _MapToolbar({this.onCities, this.city});

  final VoidCallback? onCities;
  final String? city;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: GlassSurface(
        radius: 28,
        padding: const EdgeInsets.fromLTRB(20, 4, 8, 4),
        child: Row(
          children: [
            Expanded(
              child: switch (onCities) {
                final onCities? => Align(
                  alignment: Alignment.centerLeft,
                  heightFactor: 1,
                  child: Semantics(
                    button: true,
                    label: l10n.mapCityButton(city ?? l10n.navMap),
                    excludeSemantics: true,
                    child: InkWell(
                      key: const Key('map-cities'),
                      borderRadius: BorderRadius.circular(20),
                      onTap: onCities,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.location_city_rounded, size: 20, color: context.palette.brand),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                city ?? l10n.navMap,
                                style: textTheme.titleMedium,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(Icons.expand_more_rounded, color: context.palette.inkMuted),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                null => Semantics(header: true, child: Text(l10n.navMap, style: textTheme.titleLarge)),
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _MapBody extends ConsumerStatefulWidget {
  const _MapBody({required this.venues, required this.truncated});

  final List<NearbyVenue> venues;
  final bool truncated;

  @override
  ConsumerState<_MapBody> createState() => _MapBodyState();
}

class _MapBodyState extends ConsumerState<_MapBody> {
  final _map = MapController();
  final _sheet = DraggableScrollableController();
  ScrollController? _sheetScroll;
  Timer? _settle;
  int? _selectedId;
  String? _city;
  MapAtlas? _placesAtlas;
  Basemap? _placesCountry;
  List<MapLabel> _places = const [];

  @override
  void dispose() {
    _settle?.cancel();
    _map.dispose();
    _sheet.dispose();
    super.dispose();
  }

  void _cameraMoved(MapCamera camera, {Duration delay = const Duration(milliseconds: 450)}) {
    _settle?.cancel();
    _settle = Timer(delay, () {
      if (!mounted) return;
      final bounds = camera.visibleBounds;
      final radius = const Distance().as(LengthUnit.Meter, camera.center, bounds.northEast);
      ref.read(mapViewportProvider.notifier).show(camera.center.latitude, camera.center.longitude, radius);
      final atlas = ref.read(mapAtlasProvider).value;
      if (atlas == null) return;
      final city = atlas.regionOf(camera.center)?.name ?? context.l10n.mapWholeCountry;
      if (city != _city) setState(() => _city = city);
    });
  }

  Future<void> _chooseCity(MapAtlas atlas) async {
    final target = await showModalBottomSheet<(LatLng, double)>(
      context: context,
      useRootNavigator: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Text(context.l10n.mapCitiesTitle, style: Theme.of(sheetContext).textTheme.titleLarge),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Text(
                context.l10n.mapServiceArea,
                style: Theme.of(sheetContext).textTheme.bodyMedium?.copyWith(color: sheetContext.palette.inkMuted),
              ),
            ),
            for (final region in atlas.regions)
              ListTile(
                key: Key('city-${region.id}'),
                contentPadding: const EdgeInsets.symmetric(horizontal: 24),
                leading: Icon(Icons.location_city_rounded, color: sheetContext.palette.brand),
                title: Text(region.name),
                onTap: () => Navigator.of(sheetContext).pop((region.center, 13.0)),
              ),
            ListTile(
              key: const Key('city-russia'),
              contentPadding: const EdgeInsets.symmetric(horizontal: 24),
              leading: Icon(Icons.public_rounded, color: sheetContext.palette.inkMuted),
              title: Text(context.l10n.mapWholeCountry),
              onTap: () => Navigator.of(sheetContext).pop((MapAtlas.russiaCenter, MapAtlas.russiaZoom)),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (target == null || !mounted) return;
    setState(() => _selectedId = null);
    _map.move(target.$1, target.$2);
  }

  List<MapLabel> _placesOf(MapAtlas atlas, Basemap? country) {
    if (identical(atlas, _placesAtlas) && identical(country, _placesCountry)) return _places;
    final regional = [for (final region in atlas.regions) ...region.labels];
    final local = {for (final label in regional) label.name};
    final major = {...?country?.labels.where((label) => label.rank <= 3).map((label) => label.name)};
    _placesAtlas = atlas;
    _placesCountry = country;
    return _places = [
      ...?country?.labels.where((label) => label.rank <= 3 || !local.contains(label.name)),
      ...regional.where((label) => !major.contains(label.name)),
    ]..sort((a, b) => a.rank.compareTo(b.rank));
  }

  void _select(NearbyVenue venue) {
    HapticFeedback.selectionClick();
    setState(() => _selectedId = venue.venue.id);
    const motion = (duration: Duration(milliseconds: 280), curve: Curves.easeOutCubic);
    if (_sheetScroll case final scroll? when scroll.hasClients) {
      scroll.animateTo(0, duration: motion.duration, curve: motion.curve);
    }
    if (_sheet.isAttached && _sheet.size < 0.42) {
      _sheet.animateTo(0.42, duration: motion.duration, curve: motion.curve);
    }
    _map.move(LatLng(venue.venue.lat - 0.0025, venue.venue.lon), _map.camera.zoom < 15.5 ? 15.5 : _map.camera.zoom);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final palette = context.palette;
    final venues = widget.venues;
    final location = ref.watch(locationProvider).value?.location;
    final tiles = ref.watch(appConfigProvider).tileUrlTemplate;
    final atlas = tiles.isEmpty ? ref.watch(mapAtlasProvider).value : null;
    final country = atlas == null ? null : ref.watch(mapCountryProvider).value;
    final places = atlas == null ? const <MapLabel>[] : _placesOf(atlas, country);
    if (location == null) return const _MapMessage(child: LoadingView());
    final center = LatLng(location.lat, location.lon);
    final selected = venues.where((venue) => venue.venue.id == _selectedId).firstOrNull;
    return Stack(
      children: [
        Positioned.fill(
          child: Semantics(
            container: true,
            label: l10n.mapAreaLabel(venues.length),
            child: ColoredBox(
              color: palette.mapLand,
              child: FlutterMap(
                mapController: _map,
                options: MapOptions(
                  initialCenter: LatLng(center.latitude - 0.004, center.longitude),
                  initialZoom: 15,
                  minZoom: 3,
                  cameraConstraint: CameraConstraint.containCenter(
                    bounds: LatLngBounds(const LatLng(38, 15), const LatLng(80, 180)),
                  ),
                  maxZoom: 18,
                  backgroundColor: palette.mapLand,
                  onTap: (_, _) => setState(() => _selectedId = null),
                  onPositionChanged: (camera, _) => _cameraMoved(camera),
                  onMapReady: () => _cameraMoved(_map.camera, delay: Duration.zero),
                  interactionOptions: const InteractionOptions(flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
                ),
                children: [
                  if (tiles.isNotEmpty)
                    TileLayer(urlTemplate: tiles, userAgentPackageName: 'ru.normaryadom.norma_ryadom'),
                  if (atlas != null) const VectorBasemap(),
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: center,
                        width: 44,
                        height: 44,
                        child: _MyLocationDot(color: palette.brand),
                      ),
                    ],
                  ),
                  _VenueMarkers(
                    stations: atlas?.stations ?? const [],
                    places: places,
                    venues: venues,
                    selectedId: _selectedId,
                    onSelect: _select,
                    onCluster: (cluster) => _map.move(cluster, (_map.camera.zoom + 2).clamp(12, 18)),
                  ),
                ],
              ),
            ),
          ),
        ),
        SafeArea(
          bottom: false,
          child: _MapToolbar(
            onCities: atlas == null ? null : () => _chooseCity(atlas),
            city: _city ?? atlas?.regionOf(center)?.name,
          ),
        ),
        DraggableScrollableSheet(
          controller: _sheet,
          initialChildSize: 0.42,
          minChildSize: 0.2,
          maxChildSize: 0.86,
          builder: (context, controller) => _VenueSheet(
            controller: _sheetScroll = controller,
            venues: venues,
            attribution: tiles.isNotEmpty || atlas != null ? l10n.mapAttribution : null,
            truncated: widget.truncated,
            header: Row(
              children: [
                Expanded(
                  child: AnimatedSize(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    alignment: Alignment.topCenter,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      child: selected == null
                          ? const SizedBox(width: double.infinity)
                          : _SelectedVenue(
                              key: ValueKey(selected.venue.id),
                              venue: selected,
                              onClose: () => setState(() => _selectedId = null),
                            ),
                    ),
                  ),
                ),
              ],
            ),
            onRecenter: () => _map.move(LatLng(center.latitude - 0.004, center.longitude), 15),
          ),
        ),
      ],
    );
  }
}

class _PlaceLabel extends StatelessWidget {
  const _PlaceLabel({required this.name, required this.size, required this.major});

  final String name;
  final double size;
  final bool major;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return ExcludeSemantics(
      child: Center(
        child: Text(
          name,
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.visible,
          style: TextStyle(
            fontFamily: AppFonts.display,
            fontSize: size,
            height: 1,
            fontWeight: major ? FontWeight.w700 : FontWeight.w600,
            letterSpacing: major ? 0.2 : 0,
            color: major ? palette.ink : palette.inkMuted,
            shadows: [
              Shadow(color: palette.mapLand, blurRadius: 2),
              Shadow(color: palette.mapLand, blurRadius: 5),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetroLabel extends StatelessWidget {
  const _MetroLabel({required this.name, required this.color});

  final String name;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return ExcludeSemantics(
      child: Row(
        children: [
          Container(
            width: 18,
            height: 18,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: palette.surface, width: 2),
            ),
            child: Text(
              context.l10n.metroBadge,
              style: TextStyle(color: palette.surface, fontSize: 9, fontWeight: FontWeight.w800, height: 1),
            ),
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: palette.inkMuted,
                shadows: [
                  Shadow(color: palette.mapLand, blurRadius: 3),
                  Shadow(color: palette.mapLand, blurRadius: 6),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MyLocationDot extends StatelessWidget {
  const _MyLocationDot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [color.withValues(alpha: 0.32), color.withValues(alpha: 0.04)]),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      alignment: Alignment.center,
      child: Container(
        width: 16,
        height: 16,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: context.palette.surface, width: 2.5),
        ),
      ),
    ),
  );
}

class _Cluster {
  _Cluster(this.anchor, NearbyVenue first) : members = [first], seed = LatLng(first.venue.lat, first.venue.lon);

  final Offset anchor;
  final LatLng seed;
  final List<NearbyVenue> members;

  LatLng get center => LatLng(
    members.map((venue) => venue.venue.lat).reduce((a, b) => a + b) / members.length,
    members.map((venue) => venue.venue.lon).reduce((a, b) => a + b) / members.length,
  );

  _FitMark get best => members.map(_markOf).reduce((a, b) => a.index <= b.index ? a : b);
}

class _VenueMarkers extends StatelessWidget {
  const _VenueMarkers({
    required this.stations,
    required this.places,
    required this.venues,
    required this.selectedId,
    required this.onSelect,
    required this.onCluster,
  });

  static const clusterRadius = 60.0;
  static const clusterUntilZoom = 17.0;
  static const placeZoom = <double>[2.5, 3, 4.5, 6, 7.5];
  static const placeUntilZoom = 13.0;

  static double placeSize(int rank) => switch (rank) {
    0 => 17,
    1 => 15,
    2 => 14,
    3 => 13,
    _ => 12,
  };

  final List<MetroStation> stations;
  final List<MapLabel> places;
  final List<NearbyVenue> venues;
  final int? selectedId;
  final ValueChanged<NearbyVenue> onSelect;
  final ValueChanged<LatLng> onCluster;

  static List<_Cluster> clusterOf(List<NearbyVenue> venues, Offset Function(LatLng) project) {
    final clusters = <_Cluster>[];
    final ordered = [...venues]..sort((a, b) => _markOf(a).index.compareTo(_markOf(b).index));
    for (final venue in ordered) {
      final position = project(LatLng(venue.venue.lat, venue.venue.lon));
      final home = clusters.where((cluster) => (cluster.anchor - position).distance < clusterRadius).firstOrNull;
      if (home == null) {
        clusters.add(_Cluster(position, venue));
      } else {
        home.members.add(venue);
      }
    }
    return clusters;
  }

  @override
  Widget build(BuildContext context) {
    final camera = MapCamera.of(context);
    final zoom = (camera.zoom * 2).roundToDouble() / 2;
    final selected = venues.where((venue) => venue.venue.id == selectedId).firstOrNull;
    final rest = venues.where((venue) => venue.venue.id != selectedId).toList();
    final clusters = zoom >= clusterUntilZoom
        ? [
            for (final venue in rest)
              _Cluster(camera.projectAtZoom(LatLng(venue.venue.lat, venue.venue.lon), zoom), venue),
          ]
        : clusterOf(rest, (point) => camera.projectAtZoom(point, zoom));
    Marker pin(NearbyVenue venue) => Marker(
      point: LatLng(venue.venue.lat, venue.venue.lon),
      width: 56,
      height: 64,
      alignment: Alignment.topCenter,
      child: _VenuePin(venue: venue, selected: venue.venue.id == selectedId, onTap: () => onSelect(venue)),
    );
    final occupied = <Rect>[
      for (final cluster in clusters)
        if (cluster.members.length == 1)
          Rect.fromCenter(center: cluster.anchor - const Offset(0, 32), width: 56, height: 64)
        else
          Rect.fromCircle(center: cluster.anchor, radius: 28),
      if (selected != null)
        Rect.fromCenter(
          center: camera.projectAtZoom(LatLng(selected.venue.lat, selected.venue.lon), zoom) - const Offset(0, 36),
          width: 66,
          height: 76,
        ),
    ];
    final labels = <Rect>[];
    final towns = <(MapLabel, Size)>[];
    if (zoom < placeUntilZoom) {
      final visible = camera.visibleBounds;
      for (final place in places) {
        if (zoom < placeZoom[place.rank.clamp(0, placeZoom.length - 1)] || !visible.contains(place.point)) continue;
        final size = Size(place.name.length * placeSize(place.rank) * 0.62 + 16, placeSize(place.rank) + 10);
        final rect = Rect.fromCenter(
          center: camera.projectAtZoom(place.point, zoom),
          width: size.width,
          height: size.height,
        );
        if (occupied.any(rect.overlaps) || labels.any(rect.overlaps)) continue;
        labels.add(rect);
        towns.add((place, size));
      }
    }
    final metro = <MetroStation>[];
    if (zoom >= 14.5) {
      for (final station in stations) {
        final origin = camera.projectAtZoom(station.point, zoom);
        final rect = Rect.fromLTWH(origin.dx - 10, origin.dy - 11, 26 + station.name.length * 7.0, 22);
        if (occupied.any(rect.overlaps) || labels.any(rect.overlaps)) continue;
        labels.add(rect);
        metro.add(station);
      }
    }
    return Stack(
      children: [
        Positioned.fill(
          child: MarkerLayer(
            markers: [
              for (final (place, size) in towns)
                Marker(
                  point: place.point,
                  width: size.width,
                  height: size.height,
                  child: _PlaceLabel(name: place.name, size: placeSize(place.rank), major: place.rank <= 1),
                ),
            ],
          ),
        ),
        Positioned.fill(
          child: MarkerLayer(
            markers: [
              for (final station in metro)
                Marker(
                  point: station.point,
                  width: 160,
                  height: 22,
                  alignment: Alignment.centerRight,
                  child: _MetroLabel(name: station.name, color: context.palette.metro),
                ),
            ],
          ),
        ),
        Positioned.fill(
          child: MarkerLayer(
            markers: [
              for (final cluster in clusters)
                if (cluster.members.length == 1)
                  pin(cluster.members.single)
                else
                  Marker(
                    point: cluster.seed,
                    width: 52,
                    height: 52,
                    child: _ClusterBubble(
                      count: cluster.members.length,
                      mark: cluster.best,
                      onTap: () => onCluster(cluster.center),
                    ),
                  ),
              if (selected != null) pin(selected),
            ],
          ),
        ),
      ],
    );
  }
}

class _ClusterBubble extends StatelessWidget {
  const _ClusterBubble({required this.count, required this.mark, required this.onTap});

  final int count;
  final _FitMark mark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final color = _colorOf(palette, mark);
    final size = count >= 10 ? 48.0 : 42.0;
    return Semantics(
      container: true,
      button: true,
      onTap: onTap,
      label: context.l10n.mapClusterLabel(count),
      child: ExcludeSemantics(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Center(
            child: Container(
              width: size,
              height: size,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color,
                border: Border.all(color: palette.surface, width: 3),
                boxShadow: [
                  BoxShadow(color: color.withValues(alpha: 0.35), spreadRadius: 4),
                  BoxShadow(color: palette.ink.withValues(alpha: 0.25), blurRadius: 8, offset: const Offset(0, 3)),
                ],
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontFamily: AppFonts.display,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  height: 1,
                  color: palette.surface,
                  fontFeatures: AppFonts.tabular,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _VenuePin extends StatelessWidget {
  const _VenuePin({required this.venue, required this.selected, required this.onTap});

  final NearbyVenue venue;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final mark = _markOf(venue);
    final color = _colorOf(palette, mark);
    final name = venue.venue.chainName ?? venue.venue.name;
    return Semantics(
      container: true,
      button: true,
      selected: selected,
      onTap: onTap,
      label: '${venue.venue.name}, ${_labelOf(context.l10n, mark)}',
      child: ExcludeSemantics(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: AnimatedScale(
            scale: selected ? 1.18 : 1,
            alignment: Alignment.bottomCenter,
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutBack,
            child: CustomPaint(
              painter: _PinPainter(
                color: color,
                rim: palette.surface,
                shadow: palette.ink.withValues(alpha: 0.28),
                selected: selected,
              ),
              child: Align(
                alignment: const Alignment(0, -0.42),
                child: SizedBox.square(
                  dimension: 26,
                  child: DecoratedBox(
                    decoration: BoxDecoration(color: palette.surface, shape: BoxShape.circle),
                    child: Center(
                      child: Text(
                        name.characters.first.toUpperCase(),
                        style: TextStyle(
                          fontFamily: AppFonts.display,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          height: 1,
                          color: color,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PinPainter extends CustomPainter {
  const _PinPainter({required this.color, required this.rim, required this.shadow, required this.selected});

  final Color color;
  final Color rim;
  final Color shadow;
  final bool selected;

  Path _shape(Size size) {
    final radius = size.width * 0.36;
    final center = Offset(size.width / 2, radius + 4);
    final tip = Offset(size.width / 2, size.height - 4);
    return Path()
      ..moveTo(tip.dx, tip.dy)
      ..cubicTo(
        center.dx - radius * 0.35,
        tip.dy - 8,
        center.dx - radius,
        center.dy + radius * 0.75,
        center.dx - radius,
        center.dy,
      )
      ..arcToPoint(Offset(center.dx + radius, center.dy), radius: Radius.circular(radius))
      ..cubicTo(center.dx + radius, center.dy + radius * 0.75, center.dx + radius * 0.35, tip.dy - 8, tip.dx, tip.dy)
      ..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final path = _shape(size);
    canvas
      ..drawOval(
        Rect.fromCenter(center: Offset(size.width / 2, size.height - 3), width: 14, height: 5),
        Paint()
          ..color = shadow
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
      )
      ..drawShadow(path, shadow, selected ? 6 : 3, false)
      ..drawPath(path, Paint()..color = rim)
      ..save()
      ..translate(size.width / 2, 0)
      ..scale(0.86, 0.9)
      ..translate(-size.width / 2, 3)
      ..drawPath(path, Paint()..color = color)
      ..restore();
  }

  @override
  bool shouldRepaint(_PinPainter old) =>
      old.color != color || old.rim != rim || old.shadow != shadow || old.selected != selected;
}

class _SelectedVenue extends StatelessWidget {
  const _SelectedVenue({super.key, required this.venue, required this.onClose});

  final NearbyVenue venue;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final palette = context.palette;
    final textTheme = Theme.of(context).textTheme;
    final mark = _markOf(venue);
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Panel(
        key: const Key('map-selected-venue'),
        padding: const EdgeInsets.fromLTRB(18, 14, 8, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: StatusPill(
                    label: _labelOf(l10n, mark),
                    tone: switch (mark) {
                      _FitMark.good => Tone.good,
                      _FitMark.compromise => Tone.warn,
                      _ => Tone.neutral,
                    },
                  ),
                ),
                IconButton(tooltip: l10n.close, icon: const Icon(Icons.close_rounded), onPressed: onClose),
              ],
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: Text(venue.venue.name, style: textTheme.titleLarge),
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: Text(
                '${venue.venue.address} · ${l10n.walk(venue.distanceMeters)}',
                style: textTheme.bodyMedium?.copyWith(color: palette.inkMuted),
              ),
            ),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  key: const Key('map-open-venue'),
                  onPressed: () => context.push(Routes.venue(venue.venue.id)),
                  icon: const Icon(Icons.restaurant_menu_rounded),
                  label: Text(l10n.mapOpenVenue),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VenueSheet extends StatelessWidget {
  const _VenueSheet({
    required this.controller,
    required this.venues,
    required this.attribution,
    required this.header,
    required this.onRecenter,
    this.truncated = false,
  });

  final ScrollController controller;
  final List<NearbyVenue> venues;
  final String? attribution;
  final Widget header;
  final VoidCallback onRecenter;
  final bool truncated;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final palette = context.palette;
    final textTheme = Theme.of(context).textTheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.canvas,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadii.card)),
        boxShadow: [BoxShadow(color: palette.ink.withValues(alpha: 0.12), blurRadius: 24, offset: const Offset(0, -4))],
      ),
      child: ListView(
        key: const Key('map-venue-list'),
        controller: controller,
        padding: EdgeInsets.fromLTRB(16, 10, 16, 16 + MediaQuery.paddingOf(context).bottom),
        children: [
          Center(
            child: Container(
              width: 40,
              height: 5,
              decoration: BoxDecoration(color: palette.hairline, borderRadius: BorderRadius.circular(3)),
            ),
          ),
          const SizedBox(height: 14),
          header,
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              children: [
                Expanded(child: Text(l10n.mapNearbyTitle, style: textTheme.titleLarge)),
                Text('${venues.length}', style: textTheme.labelLarge?.copyWith(color: palette.inkMuted)),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  key: const Key('map-recenter'),
                  tooltip: l10n.mapRecenter,
                  onPressed: onRecenter,
                  icon: const Icon(Icons.my_location_rounded),
                ),
              ],
            ),
          ),
          if (truncated)
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
              child: StatusPill(
                key: const Key('map-truncated'),
                label: l10n.mapTruncated(venues.length),
                tone: Tone.brand,
                icon: Icons.zoom_in_rounded,
              ),
            ),
          const SizedBox(height: 4),
          const _ShowAllSwitch(),
          const SizedBox(height: 8),
          const _Legend(),
          const SizedBox(height: 12),
          if (venues.isEmpty) MessageView(message: l10n.mapEmpty, icon: Icons.location_off_rounded),
          for (final venue in venues) ...[_VenueTile(venue: venue), const SizedBox(height: 8)],
          if (attribution case final attribution?)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(attribution, style: textTheme.bodySmall, textAlign: TextAlign.center),
            ),
        ],
      ),
    );
  }
}

class _VenueTile extends StatelessWidget {
  const _VenueTile({required this.venue});

  final NearbyVenue venue;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final palette = context.palette;
    final mark = _markOf(venue);
    final color = _colorOf(palette, mark);
    return Panel(
      padding: EdgeInsets.zero,
      onTap: () => context.push(Routes.venue(venue.venue.id)),
      child: ListTile(
        key: Key('map-venue-${venue.venue.id}'),
        contentPadding: const EdgeInsets.fromLTRB(16, 6, 12, 6),
        leading: Container(
          width: 42,
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: color.withValues(alpha: 0.16), shape: BoxShape.circle),
          child: ExcludeSemantics(
            child: Text(
              (venue.venue.chainName ?? venue.venue.name).characters.first.toUpperCase(),
              style: TextStyle(fontFamily: AppFonts.display, fontWeight: FontWeight.w700, fontSize: 16, color: color),
            ),
          ),
        ),
        title: Text(venue.venue.name, style: Theme.of(context).textTheme.titleSmall),
        subtitle: Text(
          '${_labelOf(l10n, mark)} · ${venue.venue.address} · ${l10n.walk(venue.distanceMeters)}',
        ),
        trailing: Icon(Icons.chevron_right_rounded, color: palette.inkSubtle),
      ),
    );
  }
}

class _ShowAllSwitch extends ConsumerWidget {
  const _ShowAllSwitch();

  @override
  Widget build(BuildContext context, WidgetRef ref) => MergeSemantics(
    child: Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(context.l10n.mapShowAll, style: Theme.of(context).textTheme.titleSmall),
                Text(
                  context.l10n.mapShowAllHint,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: context.palette.inkMuted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Switch(
            key: const Key('map-show-all'),
            value: ref.watch(mapCoverageProvider) == MapCoverage.all,
            onChanged: (all) =>
                ref.read(mapCoverageProvider.notifier).set(all ? MapCoverage.all : MapCoverage.withMenu),
          ),
        ],
      ),
    ),
  );
}

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final palette = context.palette;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final mark in _FitMark.values)
          DecoratedBox(
            decoration: ShapeDecoration(color: palette.surface, shape: const StadiumBorder()),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              child: Text.rich(
                TextSpan(
                  children: [
                    WidgetSpan(
                      alignment: PlaceholderAlignment.middle,
                      child: Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: Icon(Icons.circle, size: 10, color: _colorOf(palette, mark)),
                      ),
                    ),
                    TextSpan(text: _labelOf(l10n, mark)),
                  ],
                ),
                style: Theme.of(context).textTheme.labelMedium,
              ),
            ),
          ),
      ],
    );
  }
}
