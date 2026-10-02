import 'package:freezed_annotation/freezed_annotation.dart';

import 'meal.dart';
import 'nutrition_norm.dart';

part 'diary.freezed.dart';

@freezed
abstract class DiaryEntry with _$DiaryEntry {
  const DiaryEntry._();

  const factory DiaryEntry({
    required int id,
    required DateTime day,
    required MealType meal,
    required String title,
    String? venueName,
    required Intake intake,
    required DateTime createdAt,
    @Default(false) bool favorite,
  }) = _DiaryEntry;
}

@freezed
abstract class NewDiaryEntry with _$NewDiaryEntry {
  const factory NewDiaryEntry({
    required MealType meal,
    required String title,
    String? venueName,
    required Intake intake,
  }) = _NewDiaryEntry;
}

@freezed
abstract class DaySummary with _$DaySummary {
  const DaySummary._();

  const factory DaySummary({required NutritionNorm norm, required List<DiaryEntry> entries}) = _DaySummary;

  Intake get eaten => entries.fold(Intake.zero, (sum, entry) => sum + entry.intake);

  NutritionNorm get remaining => norm.minus(eaten);
}
