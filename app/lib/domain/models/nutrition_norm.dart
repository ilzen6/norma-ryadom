import 'package:freezed_annotation/freezed_annotation.dart';

part 'nutrition_norm.freezed.dart';
part 'nutrition_norm.g.dart';

@freezed
abstract class NutritionNorm with _$NutritionNorm {
  const NutritionNorm._();

  const factory NutritionNorm({required int kcal, required int protein, required int fat, required int carbs}) =
      _NutritionNorm;

  factory NutritionNorm.fromJson(Map<String, dynamic> json) => _$NutritionNormFromJson(json);

  NutritionNorm minus(Intake intake) => NutritionNorm(
    kcal: kcal - intake.kcal.round(),
    protein: protein - intake.protein.round(),
    fat: fat - intake.fat.round(),
    carbs: carbs - intake.carbs.round(),
  );
}

@freezed
abstract class Intake with _$Intake {
  const Intake._();

  const factory Intake({required double kcal, required double protein, required double fat, required double carbs}) =
      _Intake;

  factory Intake.fromJson(Map<String, dynamic> json) => _$IntakeFromJson(json);

  static const zero = Intake(kcal: 0, protein: 0, fat: 0, carbs: 0);

  Intake operator +(Intake other) => Intake(
    kcal: kcal + other.kcal,
    protein: protein + other.protein,
    fat: fat + other.fat,
    carbs: carbs + other.carbs,
  );
}
