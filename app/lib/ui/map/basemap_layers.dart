import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Path;

import '../../data/map/basemap.dart';
import '../core/theme.dart';

abstract final class BasemapLayers {
  static final _cache = <(Basemap, Palette), List<Widget>>{};

  static List<Widget> of(Basemap basemap, Palette palette) {
    if (_cache.length > 3 && !_cache.containsKey((basemap, palette))) _cache.clear();
    return _cache[(basemap, palette)] ??= _build(basemap, palette);
  }

  static List<Widget> _build(Basemap basemap, Palette palette) {
    List<List<LatLng>> roads(String kind) => basemap.roads[kind] ?? const [];
    Polyline cased(List<LatLng> line, Color color, double width, double casing) => Polyline(
      points: line,
      color: color,
      strokeWidth: width,
      borderColor: palette.mapRoadCasing,
      borderStrokeWidth: casing,
    );
    return [
      PolygonLayer(
        simplificationTolerance: 0.3,
        polygons: [
          for (final ring in basemap.green) Polygon(points: ring, color: palette.mapGreen),
          for (final ring in basemap.water) Polygon(points: ring, color: palette.mapWater),
        ],
      ),
      ZoomGate(
        minZoom: 15,
        keepAlive: true,
        child: PolygonLayer(
          simplificationTolerance: 0.8,
          polygons: [for (final ring in basemap.buildings) Polygon(points: ring, color: palette.mapBuilding)],
        ),
      ),
      ZoomGate(
        minZoom: 15,
        keepAlive: true,
        child: PolylineLayer(
          simplificationTolerance: 0.3,
          polylines: [
            for (final line in roads('path')) Polyline(points: line, color: palette.mapRoad, strokeWidth: 1.2),
          ],
        ),
      ),
      ZoomGate(
        minZoom: 14,
        keepAlive: true,
        child: PolylineLayer(
          simplificationTolerance: 0.3,
          polylines: [
            for (final line in roads('minor')) Polyline(points: line, color: palette.mapRoad, strokeWidth: 3),
          ],
        ),
      ),
      PolylineLayer(
        simplificationTolerance: 0.3,
        polylines: [
          for (final line in basemap.rail)
            Polyline(
              points: line,
              color: palette.mapRail,
              strokeWidth: 2,
              pattern: StrokePattern.dashed(segments: const [6, 4]),
            ),
          for (final line in roads('medium')) cased(line, palette.mapRoad, 5, 1),
          for (final line in roads('major')) cased(line, palette.mapRoadMajor, 7, 1.2),
        ],
      ),
    ];
  }
}

class ZoomGate extends StatelessWidget {
  const ZoomGate({super.key, required this.minZoom, required this.child, this.keepAlive = false});

  final double minZoom;
  final Widget child;
  final bool keepAlive;

  @override
  Widget build(BuildContext context) {
    final visible = MapCamera.of(context).zoom >= minZoom;
    if (keepAlive) return Offstage(offstage: !visible, child: child);
    return visible ? child : const SizedBox.shrink();
  }
}
