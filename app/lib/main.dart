import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app.dart';
import 'data/local/app_database.dart';
import 'data/providers.dart';
import 'data/repositories/settings_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ru');
  final database = AppDatabase.onDevice();
  runApp(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(database),
        initialServerAddressProvider.overrideWithValue(await _savedServerAddress(database)),
      ],
      child: const NormaRyadomApp(),
    ),
  );
}

Future<String?> _savedServerAddress(AppDatabase database) async {
  try {
    return await LocalSettingsRepository(database).serverAddress();
  } on Exception {
    return null;
  }
}
