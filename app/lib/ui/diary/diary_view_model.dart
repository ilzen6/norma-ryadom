import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../data/repositories/diary_repository.dart';
import '../../data/services/health_sync_service.dart';
import '../../domain/models/diary.dart';
import '../../domain/models/meal.dart';
import '../../domain/models/nutrition_norm.dart';
import '../../utils/result.dart';
import '../combo/selected_combo.dart';

enum DiaryMode { day, week }

final diaryModeProvider = NotifierProvider<DiaryModeController, DiaryMode>(DiaryModeController.new);

class DiaryModeController extends Notifier<DiaryMode> {
  @override
  DiaryMode build() => DiaryMode.day;

  void select(DiaryMode mode) => state = mode;
}

final quickAddProvider = StreamProvider.autoDispose<List<DiaryEntry>>(
  (ref) => ref.watch(diaryRepositoryProvider).watchQuickAdd(),
);

final diaryActionsProvider = Provider<DiaryActions>(
  (ref) => DiaryActions(
    ref.watch(diaryRepositoryProvider),
    ref.watch(clockProvider),
    ref.watch(healthSyncProvider) ? ref.watch(healthSyncServiceProvider) : null,
  ),
);

class DiaryActions {
  const DiaryActions(this._diary, this._now, [this._health]);

  final DiaryRepository _diary;
  final DateTime Function() _now;
  final HealthSyncService? _health;

  Future<void> remove(DiaryEntry entry) => _diary.remove(entry.id);

  Future<void> toggleFavorite(DiaryEntry entry) => _diary.setFavorite(entry.id, favorite: !entry.favorite);

  Future<Result<void>> addAgain(DiaryEntry entry, MealType meal) => _record(
    NewDiaryEntry(meal: meal, title: entry.title, venueName: entry.venueName, intake: entry.intake),
  );

  Future<Result<void>> addManual(NewDiaryEntry entry) => _record(entry);

  Future<Result<List<int>>> repeat(Iterable<DiaryEntry> entries) async {
    final now = _now();
    final added = <int>[];
    try {
      for (final entry in entries) {
        final copy = NewDiaryEntry(
          meal: entry.meal,
          title: entry.title,
          venueName: entry.venueName,
          intake: entry.intake,
        );
        added.add(await _diary.add(copy, now));
        unawaited(_export(copy, now));
      }
      return Ok(added);
    } on Exception {
      await undoRepeat(added);
      return const Err(AppFailure.unexpected);
    }
  }

  Future<void> undoRepeat(List<int> ids) async {
    for (final id in ids) {
      await _diary.remove(id);
    }
  }

  Future<Result<void>> addCombo(SelectedCombo selected) {
    final combo = selected.option.combo;
    return _record(
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
    );
  }

  Future<Result<void>> _record(NewDiaryEntry entry) async {
    final now = _now();
    final result = await _guarded(() => _diary.add(entry, now));
    if (result is Ok) unawaited(_export(entry, now));
    return result;
  }

  Future<void> _export(NewDiaryEntry entry, DateTime at) async {
    try {
      await _health?.export(entry, at);
    } on Exception {
      return;
    }
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
