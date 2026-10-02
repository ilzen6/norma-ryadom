import '../models/nutrition_norm.dart';
import '../models/profile.dart';

class NormCalculation {
  const NormCalculation({
    required this.bmr,
    required this.tdee,
    required this.norm,
    required this.limitedBySafeMinimum,
  });

  final double bmr;
  final double tdee;
  final NutritionNorm norm;
  final bool limitedBySafeMinimum;
}

class NormCalculator {
  const NormCalculator();

  static const _maleOffset = 5;
  static const _femaleOffset = -161;
  static const _proteinPerKgActive = 1.6;
  static const _proteinPerKgMaintain = 1.2;
  static const _fatPerKg = 0.9;
  static const _minFatShare = 0.2;
  static const _kcalPerGramProtein = 4;
  static const _kcalPerGramFat = 9;
  static const _kcalPerGramCarbs = 4;
  static const _kcalStep = 10;

  static int safeMinimumKcal(Sex sex) => switch (sex) {
    Sex.female => 1200,
    Sex.male => 1500,
  };

  NormCalculation calculate(UserProfile profile) {
    final offset = profile.sex == Sex.male ? _maleOffset : _femaleOffset;
    final bmr = 10 * profile.weightKg + 6.25 * profile.heightCm - 5 * profile.age + offset;
    final tdee = bmr * profile.activity.factor;
    final goalKcal = _roundHalfUp(tdee * profile.goal.factor / _kcalStep) * _kcalStep;
    final safeMinimum = safeMinimumKcal(profile.sex);
    final kcal = goalKcal < safeMinimum ? safeMinimum : goalKcal;
    final proteinPerKg = profile.goal == Goal.maintain ? _proteinPerKgMaintain : _proteinPerKgActive;
    final protein = _roundHalfUp(proteinPerKg * profile.weightKg);
    final fatByWeight = _fatPerKg * profile.weightKg;
    final fatByShare = kcal * _minFatShare / _kcalPerGramFat;
    final fat = _roundHalfUp(fatByWeight > fatByShare ? fatByWeight : fatByShare);
    final carbsKcal = kcal - protein * _kcalPerGramProtein - fat * _kcalPerGramFat;
    final carbs = carbsKcal <= 0 ? 0 : _roundHalfUp(carbsKcal / _kcalPerGramCarbs);
    return NormCalculation(
      bmr: bmr,
      tdee: tdee,
      norm: NutritionNorm(kcal: kcal, protein: protein, fat: fat, carbs: carbs),
      limitedBySafeMinimum: goalKcal < safeMinimum,
    );
  }

  NutritionNorm effectiveNorm(UserProfile profile) => profile.manualNorm ?? calculate(profile).norm;

  bool isSafeManualNorm(Sex sex, NutritionNorm norm) =>
      norm.kcal >= safeMinimumKcal(sex) && norm.protein >= 0 && norm.fat >= 0 && norm.carbs >= 0;

  static int _roundHalfUp(double value) => (value + 0.5).floor();
}
