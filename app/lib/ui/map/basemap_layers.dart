import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' hide Path;

import '../../data/map/basemap.dart';
import '../core/theme.dart';

abstract final class BasemapLayers {
  static const capacity = 96;
  static const _roadBands = [(0.0, 11.5, 0.4), (11.5, 13.0, 0.55), (13.0, 14.5, 0.8), (14.5, 99.0, 1.0)];
  static final _cache = <(Basemap, Palette), List<Widget>>{};

  static List<Widget> of(Basemap basemap, Palette palette) {
    final key = (basemap, palette);
    final layers = _cache.remove(key) ?? _build(basemap, palette);
    _cache[key] = layers;
    while (_cache.length > capacity) {
      _cache.remove(_cache.keys.first);
    }
    return layers;
  }

  static List<Widget> _build(Basemap basemap, Palette palette) {
    if (basemap.borders.isNotEmpty || basemap.rivers.isNotEmpty) return _country(basemap, palette);
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
          for (final shape in basemap.urban)
            Polygon(points: shape.points, holePointsList: shape.holes, color: palette.mapUrban),
          for (final shape in basemap.green)
            Polygon(points: shape.points, holePointsList: shape.holes, color: palette.mapGreen),
          for (final shape in basemap.water)
            Polygon(points: shape.points, holePointsList: shape.holes, color: palette.mapWater),
        ],
      ),
      ZoomGate(
        minZoom: 15,
        keepAlive: true,
        child: PolygonLayer(
          simplificationTolerance: 0.8,
          polygons: [
            for (final shape in basemap.buildings)
              Polygon(points: shape.points, holePointsList: shape.holes, color: palette.mapBuilding),
          ],
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
      for (final (from, until, scale) in _roadBands)
        ZoomGate(
          minZoom: from,
          maxZoom: until,
          child: PolylineLayer(
            simplificationTolerance: 0.3,
            polylines: [
              for (final line in roads('minor')) Polyline(points: line, color: palette.mapRoad, strokeWidth: 3 * scale),
              for (final line in basemap.rail)
                Polyline(
                  points: line,
                  color: palette.mapRail,
                  strokeWidth: 2 * scale,
                  pattern: StrokePattern.dashed(segments: [6 * scale, 4 * scale]),
                ),
              for (final line in roads('medium')) cased(line, palette.mapRoad, 5 * scale, scale),
              for (final line in roads('major')) cased(line, palette.mapRoadMajor, 7 * scale, 1.2 * scale),
            ],
          ),
        ),
    ];
  }
}

List<Widget> _country(Basemap basemap, Palette palette) {
  List<List<LatLng>> roads(String kind) => basemap.roads[kind] ?? const [];
  return [
    PolygonLayer(
      simplificationTolerance: 0.5,
      polygons: [
        for (final shape in basemap.water)
          Polygon(points: shape.points, holePointsList: shape.holes, color: palette.mapWater),
      ],
    ),
    PolylineLayer(
      simplificationTolerance: 0.5,
      polylines: [
        for (final line in basemap.rivers) Polyline(points: line, color: palette.mapWater, strokeWidth: 1.2),
      ],
    ),
    ZoomGate(
      minZoom: 4,
      keepAlive: true,
      child: PolylineLayer(
        simplificationTolerance: 0.5,
        polylines: [
          for (final line in basemap.admin)
            Polyline(
              points: line,
              color: palette.mapAdmin,
              strokeWidth: 1,
              pattern: StrokePattern.dashed(segments: const [4, 4]),
            ),
        ],
      ),
    ),
    ZoomGate(
      minZoom: 6.5,
      keepAlive: true,
      child: PolylineLayer(
        simplificationTolerance: 0.5,
        polylines: [
          for (final line in roads('medium'))
            Polyline(
              points: line,
              color: palette.mapRoad,
              strokeWidth: 1.6,
              borderColor: palette.mapRoadCasing,
              borderStrokeWidth: 0.5,
            ),
        ],
      ),
    ),
    ZoomGate(
      minZoom: 5,
      keepAlive: true,
      child: PolylineLayer(
        simplificationTolerance: 0.5,
        polylines: [
          for (final line in basemap.rail)
            Polyline(
              points: line,
              color: palette.mapRail,
              strokeWidth: 1.2,
              pattern: StrokePattern.dashed(segments: const [5, 3]),
            ),
          for (final line in roads('major'))
            Polyline(
              points: line,
              color: palette.mapRoadMajor,
              strokeWidth: 2.4,
              borderColor: palette.mapRoadCasing,
              borderStrokeWidth: 0.6,
            ),
        ],
      ),
    ),
    PolylineLayer(
      simplificationTolerance: 0.5,
      polylines: [
        for (final line in basemap.borders) Polyline(points: line, color: palette.mapBorder, strokeWidth: 1.8),
      ],
    ),
  ];
}

class ZoomGate extends StatelessWidget {
  const ZoomGate({
    super.key,
    required this.minZoom,
    required this.child,
    this.maxZoom = double.infinity,
    this.keepAlive = false,
  });

  final double minZoom;
  final double maxZoom;
  final Widget child;
  final bool keepAlive;

  @override
  Widget build(BuildContext context) {
    final zoom = MapCamera.of(context).zoom;
    final visible = zoom >= minZoom && zoom < maxZoom;
    if (keepAlive) return Offstage(offstage: !visible, child: child);
    return visible ? child : const SizedBox.shrink();
  }
}
