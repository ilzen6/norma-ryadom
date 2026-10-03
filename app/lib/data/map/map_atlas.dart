import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

import 'basemap.dart';

class GeoBounds {
  const GeoBounds(this.south, this.west, this.north, this.east);

  factory GeoBounds.fromJson(Map<String, dynamic> json) => GeoBounds(
    (json['south'] as num).toDouble(),
    (json['west'] as num).toDouble(),
    (json['north'] as num).toDouble(),
    (json['east'] as num).toDouble(),
  );

  final double south;
  final double west;
  final double north;
  final double east;

  bool contains(LatLng point) =>
      point.latitude >= south && point.latitude <= north && point.longitude >= west && point.longitude <= east;

  bool encloses(GeoBounds other) =>
      other.south >= south && other.north <= north && other.west >= west && other.east <= east;

  bool overlaps(GeoBounds other) =>
      other.south <= north && other.north >= south && other.west <= east && other.east >= west;
}

class MapRegion {
  const MapRegion({
    required this.id,
    required this.name,
    required this.bounds,
    required this.city,
    required this.center,
    required this.metro,
    required this.labels,
  });

  factory MapRegion.fromJson(Map<String, dynamic> json) {
    final center = json['center'] as Map<String, dynamic>;
    LatLng point(Map<String, dynamic> item) => LatLng((item['lat'] as num).toDouble(), (item['lon'] as num).toDouble());
    return MapRegion(
      id: json['id'] as String,
      name: json['name'] as String,
      bounds: GeoBounds.fromJson(json['bounds'] as Map<String, dynamic>),
      city: GeoBounds.fromJson(json['city'] as Map<String, dynamic>),
      center: point(center),
      metro: [
        for (final station in (json['metro'] as List<dynamic>? ?? const []).cast<Map<String, dynamic>>())
          MetroStation(station['name'] as String, point(station)),
      ],
      labels: [
        for (final label in (json['labels'] as List<dynamic>? ?? const []).cast<Map<String, dynamic>>())
          MapLabel(label['name'] as String, point(label), label['rank'] as int),
      ],
    );
  }

  final String id;
  final String name;
  final GeoBounds bounds;
  final GeoBounds city;
  final LatLng center;
  final List<MetroStation> metro;
  final List<MapLabel> labels;

  bool covers(LatLng point) => bounds.contains(point);
}

class MapTileset {
  const MapTileset({required this.id, required this.zoom, required this.packZoom, required this.packs});

  final String id;
  final int zoom;
  final int packZoom;
  final Set<String> packs;

  static int tileX(double lon, int zoom) => ((lon + 180) / 360 * (1 << zoom)).floor();

  static int tileY(double lat, int zoom) {
    final rad = lat.clamp(-85.0, 85.0) * math.pi / 180;
    return ((1 - math.log(math.tan(rad) + 1 / math.cos(rad)) / math.pi) / 2 * (1 << zoom)).floor();
  }

  String packOf(String tile) {
    final [x, y] = tile.split('_').map(int.parse).toList();
    final shift = zoom - packZoom;
    return 'packs/$id/${x >> shift}_${y >> shift}.json';
  }

  List<String> tilesIn(GeoBounds view, {int limit = 48}) {
    final tiles = <String>[];
    final shift = zoom - packZoom;
    for (var x = tileX(view.west, zoom); x <= tileX(view.east, zoom); x++) {
      for (var y = tileY(view.north, zoom); y <= tileY(view.south, zoom); y++) {
        if (!packs.contains('${x >> shift}_${y >> shift}')) continue;
        tiles.add('${x}_$y');
        if (tiles.length >= limit) return tiles;
      }
    }
    return tiles;
  }
}

class MapAtlas {
  const MapAtlas({required this.country, required this.regions, required this.tilesets});

  factory MapAtlas.fromJson(String source) {
    final json = jsonDecode(source) as Map<String, dynamic>;
    return MapAtlas(
      country: json['country'] as String,
      regions: [
        for (final region in (json['regions'] as List<dynamic>).cast<Map<String, dynamic>>())
          MapRegion.fromJson(region),
      ],
      tilesets: {
        for (final entry in (json['tilesets'] as Map<String, dynamic>).entries)
          entry.key: MapTileset(
            id: entry.key,
            zoom: (entry.value as Map<String, dynamic>)['zoom'] as int,
            packZoom: (entry.value as Map<String, dynamic>)['packZoom'] as int,
            packs: {for (final pack in (entry.value as Map<String, dynamic>)['packs'] as List<dynamic>) pack as String},
          ),
      },
    );
  }

  static const russiaCenter = LatLng(52, 64);
  static const russiaZoom = 3.0;

  final String country;
  final List<MapRegion> regions;
  final Map<String, MapTileset> tilesets;

  List<MetroStation> get stations => [for (final region in regions) ...region.metro];

  MapRegion? regionOf(LatLng point) => regions.where((region) => region.covers(point)).firstOrNull;

  List<MapRegion> regionsIn(GeoBounds view) => regions.where((region) => region.bounds.overlaps(view)).toList();
}

class AssetStore<T extends Object> {
  AssetStore(this._load, this._parse, {this.capacity = 24});

  final Future<String> Function(String path) _load;
  final Future<T> Function(String source) _parse;
  final int capacity;
  final _ready = <String, T?>{};
  final _pending = <String, Future<T?>>{};

  bool isReady(String path) => _ready.containsKey(path);

  T? peek(String path) {
    final value = _ready.remove(path);
    if (value != null) _ready[path] = value;
    return value;
  }

  Future<T?> get(String path) {
    if (_ready.containsKey(path)) return Future.value(peek(path));
    return _pending[path] ??= _fetch(path);
  }

  Future<T?> _fetch(String path) async {
    T? value;
    try {
      value = await _parse(await _load(path));
    } on Object {
      value = null;
    }
    _pending.remove(path)?.ignore();
    _ready[path] = value;
    while (_ready.length > capacity) {
      _ready.remove(_ready.keys.first);
    }
    return value;
  }
}

typedef BasemapPack = Map<String, Basemap>;

Future<BasemapPack> parsePackInBackground(String source) => compute(Basemap.packFromJson, source);

Future<Basemap> parseBasemapInBackground(String source) => compute(Basemap.fromJson, source);
