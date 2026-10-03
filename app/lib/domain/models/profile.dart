import 'package:freezed_annotation/freezed_annotation.dart';

import 'diet_preference.dart';
import 'district.dart';
import 'nutrition_norm.dart';

part 'profile.freezed.dart';
part 'profile.g.dart';

enum Sex { female, male }

enum ActivityLevel {
  sedentary(1.2),
  light(1.375),
  moderate(1.55),
  high(1.725),
  veryHigh(1.9);

  const ActivityLevel(this.factor);

  final double factor;
}

enum Goal {
  lose(0.85),
  maintain(1.0),
  gain(1.10);

  const Goal(this.factor);

  final double factor;
}

@freezed
abstract class UserProfile with _$UserProfile {
  const factory UserProfile({
    required Sex sex,
    required int age,
    required int heightCm,
    required double weightKg,
    required ActivityLevel activity,
    required Goal goal,
    @Default(<DietPreference>{}) Set<DietPreference> preferences,
    NutritionNorm? manualNorm,
    @Default(false) bool locationConsent,
    @JsonKey(unknownEnumValue: JsonKey.nullForUndefinedEnumValue) District? district,
  }) = _UserProfile;

  factory UserProfile.fromJson(Map<String, dynamic> json) => _$UserProfileFromJson(json);
}
