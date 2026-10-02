import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../data/services/norma_api.dart';
import '../../domain/models/diary.dart';
import '../../domain/models/district.dart';
import '../../domain/models/geo_location.dart';
import '../../domain/models/meal.dart';
import '../../domain/models/nutrition_norm.dart';
import '../../domain/models/profile.dart';
import '../../utils/result.dart';

final profileProvider = AsyncNotifierProvider<ProfileController, UserProfile?>(ProfileController.new);

class ProfileController extends AsyncNotifier<UserProfile?> {
  @override
  Future<UserProfile?> build() => ref.watch(profileRepositoryProvider).load();

  Future<void> save(UserProfile profile) async {
    await ref.read(profileRepositoryProvider).save(profile);
    state = AsyncData(profile);
  }

  Future<AppFailure?> setLocationConsent({required bool consent}) async {
    final profile = state.value;
    if (profile == null) return null;
    if (consent) {
      final location = await ref.read(locationServiceProvider).currentLocation();
      if (location case Err(:final failure)) return failure;
    }
    await save(profile.copyWith(locationConsent: consent));
    return null;
  }

  Future<void> deleteAllData() async {
    await ref.read(profileRepositoryProvider).deleteAllData();
    ref.invalidate(mealSelectionProvider);
    state = const AsyncData(null);
  }
}

final normProvider = Provider<NutritionNorm?>((ref) {
  final profile = ref.watch(profileProvider).value;
  if (profile == null) return null;
  return ref.watch(normCalculatorProvider).effectiveNorm(profile);
});

class MealSelection {
  const MealSelection({required this.meal, this.customTarget, this.price = PricePreference.any});

  final MealType meal;
  final MealTarget? customTarget;
  final PricePreference price;

  MealSelection copyWith({MealType? meal, MealTarget? Function()? customTarget, PricePreference? price}) =>
      MealSelection(
        meal: meal ?? this.meal,
        customTarget: customTarget == null ? this.customTarget : customTarget(),
        price: price ?? this.price,
      );
}

final currentDayProvider = NotifierProvider<CurrentDayController, DateTime>(CurrentDayController.new);

class CurrentDayController extends Notifier<DateTime> {
  @override
  DateTime build() => _today();

  void refresh() {
    final today = _today();
    if (today != state) state = today;
  }

  DateTime _today() {
    final now = ref.read(clockProvider)();
    return DateTime(now.year, now.month, now.day);
  }
}

final mealSelectionProvider = NotifierProvider<MealSelectionController, MealSelection>(MealSelectionController.new);

class MealSelectionController extends Notifier<MealSelection> {
  static const _breakfastUntil = 11;
  static const _lunchUntil = 16;
  static const _dinnerUntil = 21;

  @override
  MealSelection build() {
    ref.watch(currentDayProvider);
    final hour = ref.read(clockProvider)().hour;
    final meal = switch (hour) {
      < _breakfastUntil => MealType.breakfast,
      < _lunchUntil => MealType.lunch,
      < _dinnerUntil => MealType.dinner,
      _ => MealType.snack,
    };
    return MealSelection(meal: meal);
  }

  void selectMeal(MealType meal) => state = state.copyWith(meal: meal, customTarget: () => null);

  void setCustomTarget(MealTarget? target) => state = state.copyWith(customTarget: () => target);

  void setPrice(PricePreference price) => state = state.copyWith(price: price);
}

final currentTargetProvider = Provider<MealTarget?>((ref) {
  final profile = ref.watch(profileProvider).value;
  final norm = ref.watch(normProvider);
  if (profile == null || norm == null) return null;
  final selection = ref.watch(mealSelectionProvider);
  final planned = ref.watch(mealPlannerProvider).targetFor(norm, selection.meal, profile.preferences);
  final custom = selection.customTarget;
  return custom == null ? planned : custom.copyWith(excludeTags: planned.excludeTags);
});

class ResolvedLocation {
  const ResolvedLocation(this.location, {this.notice});

  final GeoLocation location;
  final AppFailure? notice;
}

final locationProvider = AsyncNotifierProvider<LocationController, ResolvedLocation>(LocationController.new);

class LocationController extends AsyncNotifier<ResolvedLocation> {
  @override
  Future<ResolvedLocation> build() async {
    final profile = await ref.watch(profileProvider.future);
    final district = profile?.district ?? District.moscowCity;
    final fallback = GeoLocation(lat: district.lat, lon: district.lon, source: LocationSource.district);
    if (profile == null || !profile.locationConsent) {
      return ResolvedLocation(fallback);
    }
    return switch (await ref.read(locationServiceProvider).currentLocation()) {
      Ok(:final value) => ResolvedLocation(value),
      Err(:final failure) => ResolvedLocation(fallback, notice: failure),
    };
  }
}

final todayProvider = StreamProvider<List<DiaryEntry>>((ref) {
  final today = ref.watch(currentDayProvider);
  return ref.watch(diaryRepositoryProvider).watchDay(today);
});

final daySummaryProvider = Provider<DaySummary?>((ref) {
  final norm = ref.watch(normProvider);
  final entries = ref.watch(todayProvider).value;
  if (norm == null || entries == null) return null;
  return DaySummary(norm: norm, entries: entries);
});
