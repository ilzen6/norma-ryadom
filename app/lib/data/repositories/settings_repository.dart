import '../local/app_database.dart';

abstract interface class SettingsRepository {
  Future<String?> serverAddress();

  Future<void> saveServerAddress(String address);

  Future<bool> healthSync();

  Future<void> saveHealthSync({required bool enabled});
}

class LocalSettingsRepository implements SettingsRepository {
  const LocalSettingsRepository(this._db);

  static const _serverAddressKey = 'server_address';
  static const _healthSyncKey = 'health_sync';

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
}
