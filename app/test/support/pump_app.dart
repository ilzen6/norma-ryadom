import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:norma_ryadom/app.dart';
import 'package:norma_ryadom/config/app_config.dart';
import 'package:norma_ryadom/data/map/basemap.dart';
import 'package:norma_ryadom/data/providers.dart';
import 'package:norma_ryadom/domain/models/profile.dart';
import 'package:norma_ryadom/l10n/generated/app_localizations.dart';
import 'package:norma_ryadom/ui/core/theme.dart';

import 'fakes.dart';

class TestHarness {
  TestHarness({UserProfile? profile}) : profiles = InMemoryProfileRepository(profile);

  final InMemoryProfileRepository profiles;
  final diary = InMemoryDiaryRepository();
  final combos = FakeComboRepository();
  final venues = FakeVenueRepository();
  final feedback = FakeFeedbackRepository();
  final location = FakeLocationService();
  final picker = FakePhotoPicker();
  final settings = InMemorySettingsRepository();
  final probe = FakeServerProbe();
  bool allowCleartextServer = false;
  DateTime now = DateTime(2026, 10, 2, 13, 5);

  List<Override> get overrides => [
    appConfigProvider.overrideWithValue(
      AppConfig(
        apiBaseUrl: 'http://test',
        tileUrlTemplate: '',
        searchRadiusMeters: 1500,
        allowCleartextServer: allowCleartextServer,
      ),
    ),
    settingsRepositoryProvider.overrideWithValue(settings),
    serverProbeProvider.overrideWithValue(probe.call),
    clockProvider.overrideWithValue(() => now),
    profileRepositoryProvider.overrideWithValue(profiles),
    diaryRepositoryProvider.overrideWithValue(diary),
    comboRepositoryProvider.overrideWithValue(combos),
    venueRepositoryProvider.overrideWithValue(venues),
    feedbackRepositoryProvider.overrideWithValue(feedback),
    locationServiceProvider.overrideWithValue(location),
    photoPickerProvider.overrideWithValue(picker),
    mapAssetLoaderProvider.overrideWithValue((path) async => File('assets/map/$path').readAsStringSync()),
    mapParsersProvider.overrideWithValue((
      (source) async => Basemap.packFromJson(source),
      (source) async => Basemap.fromJson(source),
    )),
  ];

  Size screen = const Size(1080 / 2.625, 2400 / 2.625);

  Future<void> pump(WidgetTester tester) async {
    await initializeDateFormatting('ru');
    tester.view.devicePixelRatio = 2.625;
    tester.view.physicalSize = screen * 2.625;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(overrides: overrides, child: const NormaRyadomApp()));
    await tester.pumpAndSettle();
  }

  Future<void> pumpComponent(
    WidgetTester tester,
    Widget child, {
    Brightness brightness = Brightness.light,
    bool settle = true,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides,
        child: MaterialApp(
          theme: buildTheme(brightness),
          locale: const Locale('ru'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: SingleChildScrollView(child: child)),
        ),
      ),
    );
    if (settle) await tester.pumpAndSettle();
  }
}

Future<void> scrollTo(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(finder, 300, scrollable: find.byType(Scrollable).first);
  await tester.pumpAndSettle();
}

Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await scrollTo(tester, finder);
  final screen = tester.view.physicalSize.height / tester.view.devicePixelRatio;
  final bottom = tester.getBottomLeft(finder.first).dy;
  if (bottom > screen - 140) {
    await tester.drag(find.byType(Scrollable).first, Offset(0, screen - 160 - bottom));
    await tester.pumpAndSettle();
  }
  await tester.tap(finder.first);
  await tester.pumpAndSettle();
}
