import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../data/providers.dart';
import '../../domain/models/diet_preference.dart';
import '../../domain/models/district.dart';
import '../../domain/models/nutrition_norm.dart';
import '../../domain/models/profile.dart';
import '../../domain/nutrition/norm_calculator.dart';
import '../../utils/result.dart';
import '../core/session.dart';

part 'onboarding_view_model.freezed.dart';

enum BodyField { age, height, weight }

@freezed
abstract class OnboardingState with _$OnboardingState {
  const OnboardingState._();

  const factory OnboardingState({
    @Default(Sex.female) Sex sex,
    int? age,
    int? heightCm,
    double? weightKg,
    @Default(ActivityLevel.moderate) ActivityLevel activity,
    @Default(Goal.lose) Goal goal,
    NutritionNorm? manualNorm,
    @Default(<DietPreference>{}) Set<DietPreference> preferences,
    @Default(false) bool locationConsent,
    @Default(District.moscowCity) District district,
    AppFailure? locationFailure,
    @Default(false) bool requestingLocation,
    @Default(false) bool saving,
  }) = _OnboardingState;

  static const ageRange = (min: 14, max: 100);
  static const heightRange = (min: 120, max: 230);
  static const weightRange = (min: 35, max: 250);

  bool get bodyValid => _inRange(age, ageRange) && _inRange(heightCm, heightRange) && _inRange(weightKg, weightRange);

  UserProfile? toProfile() {
    final age = this.age;
    final height = heightCm;
    final weight = weightKg;
    if (!bodyValid || age == null || height == null || weight == null) return null;
    return UserProfile(
      sex: sex,
      age: age,
      heightCm: height,
      weightKg: weight,
      activity: activity,
      goal: goal,
      preferences: preferences,
      manualNorm: manualNorm,
      locationConsent: locationConsent,
      district: district,
    );
  }

  static bool _inRange(num? value, ({int min, int max}) range) =>
      value != null && value >= range.min && value <= range.max;
}

final onboardingProvider = NotifierProvider.autoDispose<OnboardingController, OnboardingState>(
  OnboardingController.new,
);

final normPreviewProvider = Provider.autoDispose<NormCalculation?>((ref) {
  final profile = ref.watch(onboardingProvider.select((state) => state.toProfile()));
  return profile == null ? null : ref.watch(normCalculatorProvider).calculate(profile);
});

class OnboardingController extends Notifier<OnboardingState> {
  @override
  OnboardingState build() {
    final existing = ref.read(profileProvider).value;
    if (existing == null) return const OnboardingState();
    return OnboardingState(
      sex: existing.sex,
      age: existing.age,
      heightCm: existing.heightCm,
      weightKg: existing.weightKg,
      activity: existing.activity,
      goal: existing.goal,
      manualNorm: existing.manualNorm,
      preferences: existing.preferences,
      locationConsent: existing.locationConsent,
      district: existing.district ?? District.moscowCity,
    );
  }

  void setSex(Sex sex) {
    final manualNorm = state.manualNorm;
    final keepsNorm = manualNorm == null || ref.read(normCalculatorProvider).isSafeManualNorm(sex, manualNorm);
    state = state.copyWith(sex: sex, manualNorm: keepsNorm ? manualNorm : null);
  }

  void setActivity(ActivityLevel activity) => state = state.copyWith(activity: activity);

  void setGoal(Goal goal) => state = state.copyWith(goal: goal);

  void setBodyField(BodyField field, String text) {
    final normalized = text.trim().replaceAll(',', '.');
    state = switch (field) {
      BodyField.age => state.copyWith(age: int.tryParse(normalized)),
      BodyField.height => state.copyWith(heightCm: int.tryParse(normalized)),
      BodyField.weight => state.copyWith(weightKg: double.tryParse(normalized)),
    };
  }

  bool setManualNorm(NutritionNorm? norm) {
    if (norm != null && !ref.read(normCalculatorProvider).isSafeManualNorm(state.sex, norm)) {
      return false;
    }
    state = state.copyWith(manualNorm: norm);
    return true;
  }

  void togglePreference(DietPreference preference) {
    final updated = {...state.preferences};
    if (!updated.remove(preference)) updated.add(preference);
    state = state.copyWith(preferences: updated);
  }

  void setDistrict(District district) => state = state.copyWith(district: district);

  void setLocationConsent(bool consent) => state = state.copyWith(locationConsent: consent, locationFailure: null);

  Future<void> requestLocation() async {
    if (state.requestingLocation) return;
    state = state.copyWith(requestingLocation: true, locationFailure: null);
    final result = await ref.read(locationServiceProvider).currentLocation();
    if (!ref.mounted) return;
    state = switch (result) {
      Ok() => state.copyWith(requestingLocation: false, locationConsent: true),
      Err(:final failure) => state.copyWith(
        requestingLocation: false,
        locationConsent: false,
        locationFailure: failure,
      ),
    };
  }

  Future<bool> complete() async {
    final profile = state.toProfile();
    if (profile == null || state.saving || !_manualNormIsSafe(profile)) return false;
    state = state.copyWith(saving: true);
    try {
      await ref.read(profileProvider.notifier).save(profile);
      return true;
    } finally {
      if (ref.mounted) state = state.copyWith(saving: false);
    }
  }

  bool _manualNormIsSafe(UserProfile profile) {
    final manualNorm = profile.manualNorm;
    return manualNorm == null || ref.read(normCalculatorProvider).isSafeManualNorm(profile.sex, manualNorm);
  }
}
