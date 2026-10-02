import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:norma_ryadom/app.dart';
import 'package:norma_ryadom/config/app_config.dart';
import 'package:norma_ryadom/data/providers.dart';

import '../support/fakes.dart';
import '../support/pump_app.dart';

void main() {
  testWidgets('демо-режим подбирает обед на встроенном каталоге без сервера', (tester) async {
    await initializeDateFormatting('ru');
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    final catalog = File('assets/demo/catalog.json').readAsStringSync();
    final diary = InMemoryDiaryRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appConfigProvider.overrideWithValue(
            const AppConfig(apiBaseUrl: 'http://demo', tileUrlTemplate: '', searchRadiusMeters: 1500, demoServer: true),
          ),
          demoCatalogLoaderProvider.overrideWithValue(() async => catalog),
          clockProvider.overrideWithValue(() => DateTime(2026, 10, 2, 13, 5)),
          profileRepositoryProvider.overrideWithValue(InMemoryProfileRepository(TestData.profile)),
          diaryRepositoryProvider.overrideWithValue(diary),
          settingsRepositoryProvider.overrideWithValue(InMemorySettingsRepository()),
        ],
        child: const NormaRyadomApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('find-nearby')));
    await tester.pumpAndSettle();
    await scrollTo(tester, find.byKey(const Key('search-results')));
    expect(find.textContaining('Москва-Сити'), findsWidgets);

    await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text('Профиль')));
    await tester.pumpAndSettle();
    await scrollTo(tester, find.byKey(const Key('server-settings')));
    expect(find.text('Встроенный демо-каталог: 6 сетей в Москве, вы — в Москва-Сити'), findsOneWidget);
  });
}
