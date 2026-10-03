import 'dart:convert';

import 'package:latlong2/latlong.dart';

class MetroStation {
  const MetroStation(this.name, this.point);

  final String name;
  final LatLng point;
}

class MapShape {
  const MapShape(this.points, [this.holes = const []]);

  final List<LatLng> points;
  final List<List<LatLng>> holes;
}

class MapLabel {
  const MapLabel(this.name, this.point, this.rank);

  final String name;
  final LatLng point;
  final int rank;
}

class Basemap {
  const Basemap({
    required this.south,
    required this.west,
    required this.north,
    required this.east,
    required this.attribution,
    required this.water,
    required this.green,
    required this.buildings,
    required this.roads,
    required this.rail,
    required this.metro,
    this.urban = const [],
    this.rivers = const [],
    this.borders = const [],
    this.admin = const [],
    this.labels = const [],
  });

  factory Basemap.fromJson(String source) => Basemap.fromMap(jsonDecode(source) as Map<String, dynamic>);

  static Map<String, Basemap> packFromJson(String source) => {
    for (final entry in (jsonDecode(source) as Map<String, dynamic>).entries)
      entry.key: Basemap.fromMap(entry.value as Map<String, dynamic>),
  };

  factory Basemap.fromMap(Map<String, dynamic> json) {
    final bounds = json['bounds'] as Map<String, dynamic>;
    final south = (bounds['south'] as num).toDouble();
    final west = (bounds['west'] as num).toDouble();
    final scale = (json['scale'] as num).toDouble();

    List<LatLng> decode(List<dynamic> deltas) {
      final points = <LatLng>[];
      var x = 0;
      var y = 0;
      for (var index = 0; index + 1 < deltas.length; index += 2) {
        x += deltas[index] as int;
        y += deltas[index + 1] as int;
        points.add(LatLng(south + y / scale, west + x / scale));
      }
      return points;
    }

    List<List<LatLng>> shapes(Object? value) => [
      for (final shape in (value as List<dynamic>? ?? const [])) decode(shape as List<dynamic>),
    ];

    List<MapShape> polygons(Object? value) => [
      for (final shape in (value as List<dynamic>? ?? const []).cast<List<dynamic>>())
        if (shape.isNotEmpty)
          shape.first is int
              ? MapShape(decode(shape))
              : MapShape(decode(shape.first as List<dynamic>), [
                  for (final hole in shape.skip(1)) decode(hole as List<dynamic>),
                ]),
    ];

    final roads = json['roads'] as Map<String, dynamic>? ?? const {};
    return Basemap(
      south: south,
      west: west,
      north: (bounds['north'] as num).toDouble(),
      east: (bounds['east'] as num).toDouble(),
      attribution: json['attribution'] as String? ?? '',
      water: polygons(json['water']),
      green: polygons(json['green']),
      buildings: polygons(json['buildings']),
      urban: polygons(json['urban']),
      rivers: shapes(json['rivers']),
      borders: shapes(json['borders']),
      admin: shapes(json['admin']),
      labels: [
        for (final label in (json['labels'] as List<dynamic>? ?? const []).cast<Map<String, dynamic>>())
          MapLabel(label['name'] as String, decode(label['point'] as List<dynamic>).single, label['rank'] as int),
      ],
      roads: {for (final entry in roads.entries) entry.key: shapes(entry.value)},
      rail: shapes(json['rail']),
      metro: [
        for (final station in (json['metro'] as List<dynamic>? ?? const []).cast<Map<String, dynamic>>())
          MetroStation(station['name'] as String, decode(station['point'] as List<dynamic>).single),
      ],
    );
  }

  final double south;
  final double west;
  final double north;
  final double east;
  final String attribution;
  final List<MapShape> water;
  final List<MapShape> green;
  final List<MapShape> buildings;
  final Map<String, List<List<LatLng>>> roads;
  final List<List<LatLng>> rail;
  final List<MetroStation> metro;
  final List<MapShape> urban;
  final List<List<LatLng>> rivers;
  final List<List<LatLng>> borders;
  final List<List<LatLng>> admin;
  final List<MapLabel> labels;

  bool covers(LatLng point) =>
      point.latitude >= south && point.latitude <= north && point.longitude >= west && point.longitude <= east;
}
