import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:norma_ryadom/app.dart';
import 'package:norma_ryadom/config/app_config.dart';
import 'package:norma_ryadom/data/providers.dart';
import 'package:norma_ryadom/domain/models/profile.dart';

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
  DateTime now = DateTime(2026, 10, 2, 13, 5);

  List<Override> get overrides => [
    appConfigProvider.overrideWithValue(
      const AppConfig(apiBaseUrl: 'http://test', tileUrlTemplate: '', searchRadiusMeters: 1500),
    ),
    clockProvider.overrideWithValue(() => now),
    profileRepositoryProvider.overrideWithValue(profiles),
    diaryRepositoryProvider.overrideWithValue(diary),
    comboRepositoryProvider.overrideWithValue(combos),
    venueRepositoryProvider.overrideWithValue(venues),
    feedbackRepositoryProvider.overrideWithValue(feedback),
    locationServiceProvider.overrideWithValue(location),
    photoPickerProvider.overrideWithValue(picker),
  ];

  Future<void> pump(WidgetTester tester) async {
    await initializeDateFormatting('ru');
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(overrides: overrides, child: const NormaRyadomApp()));
    await tester.pumpAndSettle();
  }
}

Future<void> scrollTo(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(finder, 300, scrollable: find.byType(Scrollable).first);
  await tester.pumpAndSettle();
}

Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await scrollTo(tester, finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}
