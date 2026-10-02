import 'package:freezed_annotation/freezed_annotation.dart';

part 'meal.freezed.dart';
part 'meal.g.dart';

enum MealType {
  breakfast(0.25),
  lunch(0.35),
  dinner(0.30),
  snack(0.10);

  const MealType(this.share);

  final double share;
}

@freezed
abstract class MealTarget with _$MealTarget {
  const factory MealTarget({
    required double kcal,
    required double kcalTolerance,
    required double minProtein,
    required double maxFat,
    required double maxCarbs,
    @Default(<String>[]) List<String> excludeTags,
  }) = _MealTarget;

  factory MealTarget.fromJson(Map<String, dynamic> json) => _$MealTargetFromJson(json);
}
