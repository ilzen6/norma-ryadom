import 'package:drift/drift.dart';

import '../../domain/models/diary.dart';
import '../../domain/models/meal.dart';
import '../../domain/models/nutrition_norm.dart';
import '../local/app_database.dart';

abstract interface class DiaryRepository {
  Stream<List<DiaryEntry>> watchDay(DateTime day);

  Stream<List<DiaryEntry>> watchQuickAdd({int limit});

  Future<void> add(NewDiaryEntry entry, DateTime now);

  Future<void> remove(int id);

  Future<void> setFavorite(int id, {required bool favorite});
}

class LocalDiaryRepository implements DiaryRepository {
  const LocalDiaryRepository(this._db);

  final AppDatabase _db;

  @override
  Stream<List<DiaryEntry>> watchDay(DateTime day) =>
      (_db.select(_db.diaryRecords)
            ..where((row) => row.day.equals(dayKey(day)))
            ..orderBy([(row) => OrderingTerm.asc(row.createdAt)]))
          .watch()
          .map((rows) => rows.map(_toEntry).toList());

  @override
  Stream<List<DiaryEntry>> watchQuickAdd({int limit = 10}) =>
      (_db.select(_db.diaryRecords)
            ..orderBy([(row) => OrderingTerm.desc(row.favorite), (row) => OrderingTerm.desc(row.createdAt)]))
          .watch()
          .map((rows) {
            final seen = <String>{};
            return rows.where((row) => seen.add(row.title)).take(limit).map(_toEntry).toList();
          });

  @override
  Future<void> add(NewDiaryEntry entry, DateTime now) => _db
      .into(_db.diaryRecords)
      .insert(
        DiaryRecordsCompanion.insert(
          day: dayKey(now),
          meal: entry.meal.name,
          title: entry.title,
          venueName: Value(entry.venueName),
          kcal: entry.intake.kcal,
          protein: entry.intake.protein,
          fat: entry.intake.fat,
          carbs: entry.intake.carbs,
          createdAt: now,
        ),
      );

  @override
  Future<void> remove(int id) => (_db.delete(_db.diaryRecords)..where((row) => row.id.equals(id))).go();

  @override
  Future<void> setFavorite(int id, {required bool favorite}) => (_db.update(
    _db.diaryRecords,
  )..where((row) => row.id.equals(id))).write(DiaryRecordsCompanion(favorite: Value(favorite)));

  static String dayKey(DateTime day) =>
      '${day.year.toString().padLeft(4, '0')}-'
      '${day.month.toString().padLeft(2, '0')}-'
      '${day.day.toString().padLeft(2, '0')}';

  DiaryEntry _toEntry(DiaryRecord row) => DiaryEntry(
    id: row.id,
    day: DateTime.parse(row.day),
    meal: MealType.values.byName(row.meal),
    title: row.title,
    venueName: row.venueName,
    intake: Intake(kcal: row.kcal, protein: row.protein, fat: row.fat, carbs: row.carbs),
    createdAt: row.createdAt,
    favorite: row.favorite,
  );
}
