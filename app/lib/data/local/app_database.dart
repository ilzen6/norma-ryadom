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

@DriftDatabase(tables: [ProfileRecords, DiaryRecords])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.executor);

  factory AppDatabase.onDevice() => AppDatabase(
    driftDatabase(
      name: 'norma_ryadom',
      web: DriftWebOptions(sqlite3Wasm: Uri.parse('sqlite3.wasm'), driftWorker: Uri.parse('drift_worker.js')),
    ),
  );

  @override
  int get schemaVersion => 1;

  Future<void> deleteEverything() => transaction(() async {
    await delete(diaryRecords).go();
    await delete(profileRecords).go();
  });
}
