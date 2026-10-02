import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../data/repositories/diary_repository.dart';
import '../../domain/models/diary.dart';
import '../../domain/models/meal.dart';
import '../../domain/models/nutrition_norm.dart';
import '../../utils/result.dart';
import '../combo/selected_combo.dart';

final quickAddProvider = StreamProvider.autoDispose<List<DiaryEntry>>(
  (ref) => ref.watch(diaryRepositoryProvider).watchQuickAdd(),
);

final diaryActionsProvider = Provider<DiaryActions>(
  (ref) => DiaryActions(ref.watch(diaryRepositoryProvider), ref.watch(clockProvider)),
);

class DiaryActions {
  const DiaryActions(this._diary, this._now);

  final DiaryRepository _diary;
  final DateTime Function() _now;

  Future<void> remove(DiaryEntry entry) => _diary.remove(entry.id);

  Future<void> toggleFavorite(DiaryEntry entry) => _diary.setFavorite(entry.id, favorite: !entry.favorite);

  Future<Result<void>> addAgain(DiaryEntry entry, MealType meal) => _guarded(
    () => _diary.add(
      NewDiaryEntry(meal: meal, title: entry.title, venueName: entry.venueName, intake: entry.intake),
      _now(),
    ),
  );

  Future<Result<void>> addCombo(SelectedCombo selected) {
    final combo = selected.option.combo;
    return _guarded(
      () => _diary.add(
        NewDiaryEntry(
          meal: selected.meal,
          title: combo.dishes.map((dish) => dish.name).join(' + '),
          venueName: selected.option.venue.name,
          intake: Intake(
            kcal: combo.totals.kcal,
            protein: combo.totals.protein,
            fat: combo.totals.fat,
            carbs: combo.totals.carbs,
          ),
        ),
        _now(),
      ),
    );
  }

  static Future<Result<void>> _guarded(Future<void> Function() write) async {
    try {
      await write();
      return const Ok(null);
    } on Exception {
      return const Err(AppFailure.unexpected);
    }
  }
}
