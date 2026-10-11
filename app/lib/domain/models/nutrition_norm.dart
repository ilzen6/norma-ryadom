import 'package:freezed_annotation/freezed_annotation.dart';

part 'nutrition_norm.freezed.dart';
part 'nutrition_norm.g.dart';

@freezed
abstract class NutritionNorm with _$NutritionNorm {
  const NutritionNorm._();

  const factory NutritionNorm({required int kcal, required int protein, required int fat, required int carbs}) =
      _NutritionNorm;

  factory NutritionNorm.fromJson(Map<String, dynamic> json) => _$NutritionNormFromJson(json);

  MacroSplit get split => kcal <= 0
      ? MacroSplit.standard
      : MacroSplit(
          protein: (protein * MacroSplit.kcalPerGramProtein * 100 / kcal).round(),
          fat: (fat * MacroSplit.kcalPerGramFat * 100 / kcal).round(),
          carbs: (carbs * MacroSplit.kcalPerGramCarbs * 100 / kcal).round(),
        );

  NutritionNorm minus(Intake intake) => NutritionNorm(
    kcal: kcal - intake.kcal.round(),
    protein: protein - intake.protein.round(),
    fat: fat - intake.fat.round(),
    carbs: carbs - intake.carbs.round(),
  );
}

class MacroSplit {
  const MacroSplit({required this.protein, required this.fat, required this.carbs});

  static const standard = MacroSplit(protein: 30, fat: 30, carbs: 40);
  static const kcalPerGramProtein = 4;
  static const kcalPerGramFat = 9;
  static const kcalPerGramCarbs = 4;

  final int protein;
  final int fat;
  final int carbs;

  int get total => protein + fat + carbs;

  NutritionNorm normFor(int kcal) => NutritionNorm(
    kcal: kcal,
    protein: _grams(kcal, protein, kcalPerGramProtein),
    fat: _grams(kcal, fat, kcalPerGramFat),
    carbs: _grams(kcal, carbs, kcalPerGramCarbs),
  );

  static int _grams(int kcal, int percent, int kcalPerGram) => (kcal * percent / 100 / kcalPerGram + 0.5).floor();

  @override
  bool operator ==(Object other) =>
      other is MacroSplit && other.protein == protein && other.fat == fat && other.carbs == carbs;

  @override
  int get hashCode => Object.hash(protein, fat, carbs);
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
