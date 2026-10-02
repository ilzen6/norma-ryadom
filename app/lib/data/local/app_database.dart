import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'app_database.g.dart';

class ProfileRecords extends Table {
  IntColumn get id => integer()();

  TextColumn get json => text()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class DiaryRecords extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get day => text()();

  TextColumn get meal => text()();

  TextColumn get title => text()();

  TextColumn get venueName => text().nullable()();

  RealColumn get kcal => real()();

  RealColumn get protein => real()();

  RealColumn get fat => real()();

  RealColumn get carbs => real()();

  DateTimeColumn get createdAt => dateTime()();

  BoolColumn get favorite => boolean().withDefault(const Constant(false))();
}

class SettingRecords extends Table {
  TextColumn get key => text()();

  TextColumn get value => text()();

  @override
  Set<Column<Object>> get primaryKey => {key};
}

@DriftDatabase(tables: [ProfileRecords, DiaryRecords, SettingRecords])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  factory AppDatabase.onDevice() => AppDatabase(
    driftDatabase(
      name: 'norma_ryadom',
      web: DriftWebOptions(sqlite3Wasm: Uri.parse('sqlite3.wasm'), driftWorker: Uri.parse('drift_worker.js')),
    ),
  );

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (migrator, from, to) async {
      if (from < 2) await migrator.createTable(settingRecords);
    },
    beforeOpen: (_) => customStatement('PRAGMA secure_delete = ON'),
  );

  Future<void> deleteEverything() async {
    await transaction(() async {
      await delete(diaryRecords).go();
      await delete(profileRecords).go();
    });
    await customStatement('VACUUM');
  }
}
