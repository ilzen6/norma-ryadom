import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:norma_ryadom/data/map/basemap.dart';
import 'package:norma_ryadom/data/map/map_atlas.dart';

(double, double) near(LatLng point) => ((point.latitude * 1e6).round() / 1e6, (point.longitude * 1e6).round() / 1e6);

void main() {
  const source = '''
{"bounds":{"south":55.7,"west":37.5,"north":55.8,"east":37.7},"scale":100000,
 "attribution":"© участники OpenStreetMap, ODbL",
 "water":[[100,200,50,0,0,50,-50,0,0,-50]],
 "roads":{"major":[[0,0,1000,500]]},
 "metro":[{"name":"Деловой центр","point":[3700,4960]}]}
''';

  test('восстанавливает координаты из дельт относительно юго-западного угла', () {
    final basemap = Basemap.fromJson(source);

    expect(near(basemap.water.single.points.first), (55.702, 37.501));
    expect(near(basemap.water.single.points[1]), (55.702, 37.5015));
    expect(near(basemap.roads['major']!.single.last), (55.705, 37.51));
    expect(basemap.metro.single.name, 'Деловой центр');
    expect(near(basemap.metro.single.point), (55.7496, 37.537));
  });

  test('читает полигон с дыркой: остров в воде остаётся сушей', () {
    final basemap = Basemap.fromJson(
      '{"bounds":{"south":55.7,"west":37.5,"north":55.8,"east":37.7},"scale":100000,'
      '"water":[[[0,0,1000,0,0,1000,-1000,0,0,-1000],[200,200,100,0,0,100,-100,0,0,-100]]]}',
    );

    expect(basemap.water.single.points, hasLength(5));
    expect(basemap.water.single.holes.single, hasLength(5));
    expect(near(basemap.water.single.holes.single.first), (55.702, 37.502));
  });

  test('отсутствующие слои считает пустыми', () {
    final basemap = Basemap.fromJson(source);

    expect(basemap.green, isEmpty);
    expect(basemap.buildings, isEmpty);
    expect(basemap.rail, isEmpty);
    expect(basemap.roads['minor'], isNull);
  });

  test('проверяет, покрывает ли подложка точку', () {
    final basemap = Basemap.fromJson(source);

    expect(basemap.covers(const LatLng(55.7496, 37.537)), isTrue);
    expect(basemap.covers(const LatLng(59.93, 30.31)), isFalse);
  });

  test('атлас описывает Москву с областью и Петербург и находит пачку подробных тайлов вокруг Москва-Сити', () {
    final atlas = MapAtlas.fromJson(File('assets/map/index.json').readAsStringSync());

    expect(atlas.regions.map((region) => region.id), ['moscow', 'spb']);
    expect(atlas.regionOf(const LatLng(55.7496, 37.5397))?.id, 'moscow');
    expect(atlas.regionOf(const LatLng(55.4312, 37.5455))?.id, 'moscow');
    expect(atlas.regionOf(const LatLng(59.9343, 30.3351))?.id, 'spb');
    expect(atlas.regionOf(const LatLng(43.1, 131.9)), isNull);
    expect(atlas.stations.map((station) => station.name), containsAll(['Деловой центр', 'Невский проспект']));

    final city = atlas.tilesets['city']!;
    final tiles = city.tilesIn(const GeoBounds(55.745, 37.53, 55.755, 37.55));
    expect(tiles, isNotEmpty);
    final pack = Basemap.packFromJson(File('assets/map/${city.packOf(tiles.first)}').readAsStringSync());
    final tile = pack[tiles.first]!;
    expect(tile.buildings, isNotEmpty);
    expect(tile.roads.keys, containsAll(['major', 'medium', 'minor']));
  });

  test('атлас ограничивает число тайлов в видимой области', () {
    final atlas = MapAtlas.fromJson(File('assets/map/index.json').readAsStringSync());

    expect(atlas.tilesets['city']!.tilesIn(const GeoBounds(55.5, 37.3, 55.9, 37.9), limit: 10), hasLength(10));
    expect(atlas.regionsIn(const GeoBounds(41, 19, 82, 180)), hasLength(2));
    expect(atlas.regionsIn(const GeoBounds(43, 131, 44, 132)), isEmpty);
  });

  test('обзорные тайлы содержат воду, парки и крупные дороги без зданий', () {
    final atlas = MapAtlas.fromJson(File('assets/map/index.json').readAsStringSync());
    final overview = atlas.tilesets['overview']!;
    final tiles = overview.tilesIn(atlas.regions.first.city);
    final layers = [
      for (final tile in tiles)
        Basemap.packFromJson(File('assets/map/${overview.packOf(tile)}').readAsStringSync())[tile]!,
    ];

    expect(layers.expand((tile) => tile.water), isNotEmpty);
    expect(layers.expand((tile) => tile.green), isNotEmpty);
    expect(layers.expand((tile) => tile.roads['major'] ?? const []), isNotEmpty);
    expect(layers.expand((tile) => tile.buildings), isEmpty);
  });

  test('карта страны покрывает всю Россию: моря, реки, границы и подписи городов', () {
    final atlas = MapAtlas.fromJson(File('assets/map/index.json').readAsStringSync());
    final country = Basemap.fromJson(File('assets/map/${atlas.country}').readAsStringSync());

    expect(country.covers(const LatLng(43.1, 131.9)), isTrue);
    expect(country.covers(const LatLng(54.7, 20.5)), isTrue);
    expect(country.water, isNotEmpty);
    expect(country.rivers, isNotEmpty);
    expect(country.borders, isNotEmpty);
    expect(country.labels.first.rank, 0);
    expect(country.labels.map((label) => label.name), containsAll(['Москва', 'Владивосток', 'Калининград']));
  });

  test('хранилище разбирает файл один раз и вытесняет давно не нужные', () async {
    final loads = <String>[];
    final store = AssetStore<String>(
      (path) async {
        loads.add(path);
        return path;
      },
      (source) async => source.toUpperCase(),
      capacity: 2,
    );

    await Future.wait([store.get('a'), store.get('a')]);
    expect(loads, ['a']);
    expect(store.peek('a'), 'A');
    await store.get('b');
    await store.get('c');

    expect(store.isReady('a'), isFalse);
    expect(store.peek('c'), 'C');
  });

  test('хранилище запоминает сломанный файл как пустой и не роняет карту', () async {
    final store = AssetStore<Basemap>((path) async => '{', (source) async => Basemap.fromJson(source));

    expect(await store.get('broken'), isNull);
    expect(store.isReady('broken'), isTrue);
  });

  test('границы региона отличают область целиком внутри от выходящей за край', () {
    const region = GeoBounds(54, 35, 57, 40);

    expect(region.encloses(const GeoBounds(55, 37, 56, 38)), isTrue);
    expect(region.encloses(const GeoBounds(56.5, 39, 57.5, 41)), isFalse);
    expect(region.overlaps(const GeoBounds(56.5, 39, 57.5, 41)), isTrue);
    expect(region.overlaps(const GeoBounds(59, 29, 60, 31)), isFalse);
  });

  test('номер пачки получается сдвигом номера тайла на разницу масштабов', () {
    const tileset = MapTileset(id: 'city', zoom: 14, packZoom: 11, packs: {'1234_567'});

    expect(tileset.packOf('9879_4539'), 'packs/city/1234_567.json');
    expect(MapTileset.tileX(37.6173, 14), 9904);
    expect(MapTileset.tileY(55.7558, 14), 5121);
  });
}
