import 'dart:convert';

import '../../domain/models/combo.dart';
import '../../domain/models/search_filters.dart';
import '../local/app_database.dart';

abstract interface class SettingsRepository {
  Future<String?> serverAddress();

  Future<void> saveServerAddress(String address);

  Future<bool> healthSync();

  Future<void> saveHealthSync({required bool enabled});

  Future<String?> theme();

  Future<void> saveTheme(String theme);

  Future<SearchFilters> searchFilters();

  Future<void> saveSearchFilters(SearchFilters filters);

  Future<SavedSearch?> lastSearch();

  Future<void> saveLastSearch(SavedSearch search);
}

class LocalSettingsRepository implements SettingsRepository {
  const LocalSettingsRepository(this._db);

  static const _serverAddressKey = 'server_address';
  static const _healthSyncKey = 'health_sync';
  static const _themeKey = 'theme';
  static const _searchFiltersKey = 'search_filters';
  static const _lastSearchKey = 'last_search';

  final AppDatabase _db;

  @override
  Future<String?> serverAddress() async {
    final record = await (_db.select(
      _db.settingRecords,
    )..where((row) => row.key.equals(_serverAddressKey))).getSingleOrNull();
    return record?.value;
  }

  @override
  Future<void> saveServerAddress(String address) => _db
      .into(_db.settingRecords)
      .insertOnConflictUpdate(SettingRecordsCompanion.insert(key: _serverAddressKey, value: address));

  @override
  Future<bool> healthSync() async {
    final record = await (_db.select(
      _db.settingRecords,
    )..where((row) => row.key.equals(_healthSyncKey))).getSingleOrNull();
    return record?.value == 'on';
  }

  @override
  Future<void> saveHealthSync({required bool enabled}) => _db
      .into(_db.settingRecords)
      .insertOnConflictUpdate(SettingRecordsCompanion.insert(key: _healthSyncKey, value: enabled ? 'on' : 'off'));

  @override
  Future<String?> theme() async {
    final record = await (_db.select(_db.settingRecords)..where((row) => row.key.equals(_themeKey))).getSingleOrNull();
    return record?.value;
  }

  @override
  Future<void> saveTheme(String theme) =>
      _db.into(_db.settingRecords).insertOnConflictUpdate(SettingRecordsCompanion.insert(key: _themeKey, value: theme));

  @override
  Future<SearchFilters> searchFilters() async {
    final record = await (_db.select(
      _db.settingRecords,
    )..where((row) => row.key.equals(_searchFiltersKey))).getSingleOrNull();
    if (record == null) return const SearchFilters();
    try {
      return SearchFilters.fromJson(jsonDecode(record.value) as Map<String, dynamic>);
    } on Object {
      return const SearchFilters();
    }
  }

  @override
  Future<void> saveSearchFilters(SearchFilters filters) => _db
      .into(_db.settingRecords)
      .insertOnConflictUpdate(
        SettingRecordsCompanion.insert(key: _searchFiltersKey, value: jsonEncode(filters.toJson())),
      );

  @override
  Future<SavedSearch?> lastSearch() async {
    final record = await (_db.select(
      _db.settingRecords,
    )..where((row) => row.key.equals(_lastSearchKey))).getSingleOrNull();
    if (record == null) return null;
    try {
      return SavedSearch.fromJson(jsonDecode(record.value) as Map<String, dynamic>);
    } on Object {
      return null;
    }
  }

  @override
  Future<void> saveLastSearch(SavedSearch search) => _db
      .into(_db.settingRecords)
      .insertOnConflictUpdate(SettingRecordsCompanion.insert(key: _lastSearchKey, value: jsonEncode(search.toJson())));
}
