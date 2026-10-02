import '../local/app_database.dart';

abstract interface class SettingsRepository {
  Future<String?> serverAddress();

  Future<void> saveServerAddress(String address);
}

class LocalSettingsRepository implements SettingsRepository {
  const LocalSettingsRepository(this._db);

  static const _serverAddressKey = 'server_address';

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
}
