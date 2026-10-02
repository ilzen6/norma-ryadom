import 'package:flutter_test/flutter_test.dart';
import 'package:norma_ryadom/domain/models/diet_preference.dart';
import 'package:norma_ryadom/domain/models/meal.dart';
import 'package:norma_ryadom/domain/models/nutrition_norm.dart';
import 'package:norma_ryadom/domain/nutrition/meal_planner.dart';

void main() {
  const planner = MealPlanner();
  const norm = NutritionNorm(kcal: 1800, protein: 99, fat: 56, carbs: 225);

  test('цель обеда - 35% дневной нормы с допуском 10%', () {
    final target = planner.targetFor(norm, MealType.lunch, const {});

    expect(target.kcal, 630);
    expect(target.kcalTolerance, 63);
    expect(target.minProtein, 27.7);
    expect(target.maxFat, 23.5);
    expect(target.maxCarbs, 94.5);
    expect(target.excludeTags, isEmpty);
  });

  test('доли приёмов пищи в сумме дают всю норму', () {
    final total = MealType.values.fold<double>(0, (sum, meal) => sum + meal.share);

    expect(total, closeTo(1, 1e-9));
  });

  test('держит цель в границах, которые принимает сервер', () {
    final snack = planner.targetFor(
      const NutritionNorm(kcal: 900, protein: 0, fat: 0, carbs: 0),
      MealType.snack,
      const {},
    );
    final huge = planner.targetFor(
      const NutritionNorm(kcal: 9000, protein: 900, fat: 900, carbs: 2000),
      MealType.lunch,
      const {},
    );

    expect(snack.kcal, 100);
    expect(snack.kcalTolerance, 50);
    expect(huge.kcal, 2000);
    expect(huge.kcalTolerance, 200);
    expect(huge.minProtein, 252);
    expect(huge.maxFat, 300);
    expect(huge.maxCarbs, 500);
  });

  test('превращает предпочтения в отсортированные теги исключения', () {
    final target = planner.targetFor(norm, MealType.dinner, {DietPreference.vegetarian, DietPreference.noNuts});

    expect(target.excludeTags, ['fish', 'meat', 'nuts', 'seafood']);
    expect(DietPreference.excludedTagsOf({DietPreference.noPork}), {'pork'});
  });
}
