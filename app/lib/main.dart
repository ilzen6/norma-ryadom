import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app.dart';
import 'data/local/app_database.dart';
import 'data/providers.dart';
import 'data/repositories/settings_repository.dart';
import 'domain/models/search_filters.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ru');
  final database = AppDatabase.onDevice();
  runApp(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(database),
        initialServerAddressProvider.overrideWithValue(await _savedServerAddress(database)),
        initialHealthSyncProvider.overrideWithValue(await _savedHealthSync(database)),
        initialThemeModeProvider.overrideWithValue(await _savedTheme(database)),
        initialSearchFiltersProvider.overrideWithValue(await _savedSearchFilters(database)),
      ],
      child: const NormaRyadomApp(),
    ),
  );
}

Future<SearchFilters> _savedSearchFilters(AppDatabase database) async {
  try {
    return await LocalSettingsRepository(database).searchFilters();
  } on Exception {
    return const SearchFilters();
  }
}

Future<ThemeMode> _savedTheme(AppDatabase database) async {
  try {
    return themeModeFrom(await LocalSettingsRepository(database).theme());
  } on Exception {
    return ThemeMode.system;
  }
}

Future<bool> _savedHealthSync(AppDatabase database) async {
  try {
    return await LocalSettingsRepository(database).healthSync();
  } on Exception {
    return false;
  }
}

Future<String?> _savedServerAddress(AppDatabase database) async {
  try {
    return await LocalSettingsRepository(database).serverAddress();
  } on Exception {
    return null;
  }
}
