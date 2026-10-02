import '../models/diet_preference.dart';
import '../models/meal.dart';
import '../models/nutrition_norm.dart';

class MealPlanner {
  const MealPlanner();

  static const _toleranceShare = 0.1;
  static const _minTolerance = 50.0;
  static const _maxTolerance = 500.0;
  static const _proteinShare = 0.8;
  static const _limitShare = 1.2;
  static const _minKcal = 100.0;
  static const _maxKcal = 2000.0;
  static const _maxProtein = 300.0;
  static const _maxFat = 300.0;
  static const _maxCarbs = 500.0;

  MealTarget targetFor(NutritionNorm norm, MealType meal, Set<DietPreference> preferences) {
    final kcal = _clamp(norm.kcal * meal.share, _minKcal, _maxKcal);
    final tolerance = _clamp(kcal * _toleranceShare, _minTolerance, _maxTolerance);
    return MealTarget(
      kcal: _round(kcal),
      kcalTolerance: _round(tolerance),
      minProtein: _round(_clamp(norm.protein * meal.share * _proteinShare, 0, _maxProtein)),
      maxFat: _round(_clamp(norm.fat * meal.share * _limitShare, 0, _maxFat)),
      maxCarbs: _round(_clamp(norm.carbs * meal.share * _limitShare, 0, _maxCarbs)),
      excludeTags: DietPreference.excludedTagsOf(preferences).toList()..sort(),
    );
  }

  static double _clamp(double value, double min, double max) => value < min ? min : (value > max ? max : value);

  static double _round(double value) => (value * 10).roundToDouble() / 10;
}
