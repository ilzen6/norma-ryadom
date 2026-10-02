import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:norma_ryadom/data/map/basemap.dart';

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

    expect(near(basemap.water.single.first), (55.702, 37.501));
    expect(near(basemap.water.single[1]), (55.702, 37.5015));
    expect(near(basemap.roads['major']!.single.last), (55.705, 37.51));
    expect(basemap.metro.single.name, 'Деловой центр');
    expect(near(basemap.metro.single.point), (55.7496, 37.537));
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

  test('встроенная подложка покрывает демо-район и содержит все слои', () {
    final basemap = Basemap.fromJson(File('assets/map/basemap.json').readAsStringSync());

    expect(basemap.covers(const LatLng(55.7496, 37.5397)), isTrue);
    expect(basemap.attribution, contains('OpenStreetMap'));
    for (final layer in [basemap.water, basemap.green, basemap.buildings, basemap.rail]) {
      expect(layer, isNotEmpty);
    }
    expect(basemap.roads.keys, containsAll(['major', 'medium', 'minor', 'path']));
    expect(basemap.metro.map((station) => station.name), contains('Деловой центр'));
  });
}
