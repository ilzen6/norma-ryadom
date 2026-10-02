import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart' hide Path;

import '../../data/map/basemap.dart';
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
import 'map_view_model.dart';

class MapScreen extends ConsumerWidget {
  const MapScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final venues = ref.watch(mapVenuesProvider);
    return Scaffold(
      body: switch (venues) {
        AsyncData(value: Ok(:final value)) => _MapBody(venues: value),
        AsyncData(value: Err(:final failure)) => _MapMessage(
          child: FailureView(failure: failure, onRetry: () => ref.invalidate(mapVenuesProvider)),
        ),
        AsyncError() => _MapMessage(
          child: FailureView(failure: AppFailure.unexpected, onRetry: () => ref.invalidate(mapVenuesProvider)),
        ),
        _ => _MapMessage(
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
  const _MapToolbar();

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
              child: Semantics(header: true, child: Text(l10n.navMap, style: textTheme.titleLarge)),
            ),
            Flexible(
              child: MergeSemantics(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(l10n.mapShowAll, style: textTheme.labelLarge, textAlign: TextAlign.end),
                    ),
                    const SizedBox(width: 4),
                    Switch(
                      key: const Key('map-show-all'),
                      value: ref.watch(mapCoverageProvider) == MapCoverage.all,
                      onChanged: (all) =>
                          ref.read(mapCoverageProvider.notifier).set(all ? MapCoverage.all : MapCoverage.withMenu),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MapBody extends ConsumerStatefulWidget {
  const _MapBody({required this.venues});

  final List<NearbyVenue> venues;

  @override
  ConsumerState<_MapBody> createState() => _MapBodyState();
}

class _MapBodyState extends ConsumerState<_MapBody> {
  final _map = MapController();
  final _sheet = DraggableScrollableController();
  ScrollController? _sheetScroll;
  int? _selectedId;

  @override
  void dispose() {
    _map.dispose();
    _sheet.dispose();
    super.dispose();
  }

  void _select(NearbyVenue venue) {
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
    final basemap = ref.watch(basemapProvider).value;
    if (location == null) return const _MapMessage(child: LoadingView());
    final center = LatLng(location.lat, location.lon);
    final vector = tiles.isEmpty && basemap != null && basemap.covers(center) ? basemap : null;
    final selected = venues.where((venue) => venue.venue.id == _selectedId).firstOrNull;
    final ordered = [
      ...venues.where((venue) => venue.venue.id != _selectedId),
      ?selected,
    ];
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
                  minZoom: 12,
                  maxZoom: 18,
                  backgroundColor: palette.mapLand,
                  onTap: (_, _) => setState(() => _selectedId = null),
                  cameraConstraint: vector == null
                      ? const CameraConstraint.unconstrained()
                      : CameraConstraint.containCenter(
                          bounds: LatLngBounds(LatLng(vector.south, vector.west), LatLng(vector.north, vector.east)),
                        ),
                  interactionOptions: const InteractionOptions(flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
                ),
                children: [
                  if (tiles.isNotEmpty)
                    TileLayer(urlTemplate: tiles, userAgentPackageName: 'ru.normaryadom.norma_ryadom'),
                  if (vector != null) ..._vectorLayers(vector, palette),
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: center,
                        width: 44,
                        height: 44,
                        child: _MyLocationDot(color: palette.brand),
                      ),
                      for (final venue in ordered)
                        Marker(
                          point: LatLng(venue.venue.lat, venue.venue.lon),
                          width: 56,
                          height: 64,
                          alignment: Alignment.topCenter,
                          child: _VenuePin(
                            venue: venue,
                            selected: venue.venue.id == _selectedId,
                            onTap: () => _select(venue),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        const SafeArea(bottom: false, child: _MapToolbar()),
        DraggableScrollableSheet(
          controller: _sheet,
          initialChildSize: 0.42,
          minChildSize: 0.2,
          maxChildSize: 0.86,
          builder: (context, controller) => _VenueSheet(
            controller: _sheetScroll = controller,
            venues: venues,
            attribution: tiles.isNotEmpty ? l10n.mapAttribution : vector?.attribution,
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

  List<Widget> _vectorLayers(Basemap basemap, Palette palette) => [
    PolygonLayer(
      simplificationTolerance: 0.3,
      polygons: [
        for (final ring in basemap.green) Polygon(points: ring, color: palette.mapGreen),
        for (final ring in basemap.water) Polygon(points: ring, color: palette.mapWater),
      ],
    ),
    _ZoomGate(
      minZoom: 15,
      child: PolygonLayer(
        simplificationTolerance: 0.4,
        polygons: [
          for (final ring in basemap.buildings)
            Polygon(
              points: ring,
              color: palette.mapBuilding,
              borderColor: palette.mapBuildingEdge,
              borderStrokeWidth: 0.6,
            ),
        ],
      ),
    ),
    PolylineLayer(
      simplificationTolerance: 0.3,
      polylines: [
        for (final line in basemap.roads['path'] ?? const <List<LatLng>>[])
          Polyline(points: line, color: palette.mapRoad, strokeWidth: 1.2),
        for (final line in basemap.rail)
          Polyline(
            points: line,
            color: palette.mapRail,
            strokeWidth: 2,
            pattern: StrokePattern.dashed(segments: const [6, 4]),
          ),
        for (final line in basemap.roads['minor'] ?? const <List<LatLng>>[])
          Polyline(
            points: line,
            color: palette.mapRoad,
            strokeWidth: 3,
            borderColor: palette.mapRoadCasing,
            borderStrokeWidth: 0.8,
          ),
        for (final line in basemap.roads['medium'] ?? const <List<LatLng>>[])
          Polyline(
            points: line,
            color: palette.mapRoad,
            strokeWidth: 5,
            borderColor: palette.mapRoadCasing,
            borderStrokeWidth: 1,
          ),
        for (final line in basemap.roads['major'] ?? const <List<LatLng>>[])
          Polyline(
            points: line,
            color: palette.mapRoadMajor,
            strokeWidth: 7,
            borderColor: palette.mapRoadCasing,
            borderStrokeWidth: 1.2,
          ),
      ],
    ),
    _ZoomGate(
      minZoom: 14.5,
      child: MarkerLayer(
        markers: [
          for (final station in basemap.metro)
            Marker(
              point: station.point,
              width: 160,
              height: 22,
              alignment: Alignment.centerRight,
              child: _MetroLabel(name: station.name, color: palette.metro),
            ),
        ],
      ),
    ),
  ];
}

class _ZoomGate extends StatelessWidget {
  const _ZoomGate({required this.minZoom, required this.child});

  final double minZoom;
  final Widget child;

  @override
  Widget build(BuildContext context) => MapCamera.of(context).zoom >= minZoom ? child : const SizedBox.shrink();
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
              'М',
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
      button: true,
      selected: selected,
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
                '${venue.venue.address} · ${l10n.distanceMeters(venue.distanceMeters)}',
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
  });

  final ScrollController controller;
  final List<NearbyVenue> venues;
  final String? attribution;
  final Widget header;
  final VoidCallback onRecenter;

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
          const SizedBox(height: 12),
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
          '${_labelOf(l10n, mark)} · ${venue.venue.address} · ${l10n.distanceMeters(venue.distanceMeters)}',
        ),
        trailing: Icon(Icons.chevron_right_rounded, color: palette.inkSubtle),
      ),
    );
  }
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
