import 'dart:convert';

import 'package:drift/drift.dart';

import '../../domain/models/profile.dart';
import '../local/app_database.dart';

abstract interface class ProfileRepository {
  Future<UserProfile?> load();

  Future<void> save(UserProfile profile);

  Future<void> deleteAllData();
}

class LocalProfileRepository implements ProfileRepository {
  const LocalProfileRepository(this._db);

  static const _singleProfileId = 1;

  final AppDatabase _db;

  @override
  Future<UserProfile?> load() async {
    final record = await (_db.select(
      _db.profileRecords,
    )..where((row) => row.id.equals(_singleProfileId))).getSingleOrNull();
    if (record == null) return null;
    return UserProfile.fromJson(jsonDecode(record.json) as Map<String, dynamic>);
  }

  @override
  Future<void> save(UserProfile profile) => _db
      .into(_db.profileRecords)
      .insertOnConflictUpdate(
        ProfileRecordsCompanion.insert(id: const Value(_singleProfileId), json: jsonEncode(profile.toJson())),
      );

  @override
  Future<void> deleteAllData() => _db.deleteEverything();
}
