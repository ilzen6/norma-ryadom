import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:norma_ryadom/domain/models/district.dart';
import 'package:norma_ryadom/domain/models/geo_location.dart';
import 'package:norma_ryadom/ui/core/session.dart';
import 'package:norma_ryadom/utils/result.dart';

import '../support/fakes.dart';
import '../support/pump_app.dart';

void main() {
  Future<ResolvedLocation> resolve(TestHarness harness) async {
    final container = ProviderContainer(overrides: harness.overrides);
    addTearDown(container.dispose);
    return container.read(locationProvider.future);
  }

  test('демо-режим берёт настоящую геопозицию внутри зоны каталога', () async {
    final harness = TestHarness(profile: TestData.profile)..demoServer = true;

    final resolved = await resolve(harness);

    expect(resolved.location, TestData.deviceLocation);
    expect(resolved.notice, isNull);
  });

  test('вне зоны каталога ищет от выбранного района и объясняет почему', () async {
    final harness = TestHarness(profile: TestData.profile)
      ..demoServer = true
      ..location.result = const Ok(GeoLocation(lat: 52.2297, lon: 21.0122, source: LocationSource.device));
    final district = TestData.profile.district ?? District.moscowCity;

    final resolved = await resolve(harness);

    expect(resolved.notice, AppFailure.outsideCoverage);
    expect((resolved.location.lat, resolved.location.lon), (district.lat, district.lon));
    expect(resolved.location.source, LocationSource.district);
  });

  test('с собственным сервером геопозиция не ограничена зоной демо-каталога', () async {
    const warsaw = GeoLocation(lat: 52.2297, lon: 21.0122, source: LocationSource.device);
    final harness = TestHarness(profile: TestData.profile)..location.result = const Ok(warsaw);

    final resolved = await resolve(harness);

    expect(resolved.location, warsaw);
    expect(resolved.notice, isNull);
  });
}
