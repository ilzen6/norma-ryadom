import 'dart:convert';

import 'package:latlong2/latlong.dart';

class MetroStation {
  const MetroStation(this.name, this.point);

  final String name;
  final LatLng point;
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
  });

  factory Basemap.fromJson(String source) {
    final json = jsonDecode(source) as Map<String, dynamic>;
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

    final roads = json['roads'] as Map<String, dynamic>? ?? const {};
    return Basemap(
      south: south,
      west: west,
      north: (bounds['north'] as num).toDouble(),
      east: (bounds['east'] as num).toDouble(),
      attribution: json['attribution'] as String? ?? '',
      water: shapes(json['water']),
      green: shapes(json['green']),
      buildings: shapes(json['buildings']),
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
  final List<List<LatLng>> water;
  final List<List<LatLng>> green;
  final List<List<LatLng>> buildings;
  final Map<String, List<List<LatLng>>> roads;
  final List<List<LatLng>> rail;
  final List<MetroStation> metro;

  bool covers(LatLng point) =>
      point.latitude >= south && point.latitude <= north && point.longitude >= west && point.longitude <= east;
}
