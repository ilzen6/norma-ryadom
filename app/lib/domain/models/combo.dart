import 'package:freezed_annotation/freezed_annotation.dart';

import 'catalog.dart';
import 'meal.dart';

part 'combo.freezed.dart';
part 'combo.g.dart';

@JsonEnum(alwaysCreate: true)
enum Metric {
  @JsonValue('KCAL')
  kcal,
  @JsonValue('PROTEIN')
  protein,
  @JsonValue('FAT')
  fat,
  @JsonValue('CARBS')
  carbs,
  unknown,
}

@JsonEnum(alwaysCreate: true)
enum MetricStatus {
  @JsonValue('OK')
  ok,
  @JsonValue('ABOVE')
  above,
  @JsonValue('BELOW')
  below,
  unknown,
}

@freezed
abstract class Dish with _$Dish {
  const factory Dish({
    required int id,
    required String name,
    @JsonKey(unknownEnumValue: DishCategory.unknown) required DishCategory category,
    double? portionGrams,
    required Nutrients nutrients,
    int? priceMinor,
    @JsonKey(unknownEnumValue: SourceKind.unknown) required SourceKind sourceKind,
    @Default(<String>[]) List<String> tags,
  }) = _Dish;

  factory Dish.fromJson(Map<String, dynamic> json) => _$DishFromJson(json);
}

@freezed
abstract class MetricCheck with _$MetricCheck {
  const factory MetricCheck({
    @JsonKey(unknownEnumValue: Metric.unknown) required Metric metric,
    required double value,
    required double goal,
    required double delta,
    @JsonKey(unknownEnumValue: MetricStatus.unknown) required MetricStatus status,
  }) = _MetricCheck;

  factory MetricCheck.fromJson(Map<String, dynamic> json) => _$MetricCheckFromJson(json);
}

@freezed
abstract class Combo with _$Combo {
  const factory Combo({
    required List<Dish> dishes,
    required Nutrients totals,
    int? priceMinor,
    @JsonKey(unknownEnumValue: SourceKind.unknown) required SourceKind sourceKind,
    required double score,
    @Default(<MetricCheck>[]) List<MetricCheck> checks,
  }) = _Combo;

  factory Combo.fromJson(Map<String, dynamic> json) => _$ComboFromJson(json);
}

@freezed
abstract class ComboOption with _$ComboOption {
  const factory ComboOption({required VenueSummary venue, int? distanceMeters, required Combo combo}) = _ComboOption;

  factory ComboOption.fromJson(Map<String, dynamic> json) => _$ComboOptionFromJson(json);
}

@freezed
abstract class ComboSearchResult with _$ComboSearchResult {
  const factory ComboSearchResult({
    required MealTarget appliedTarget,
    @Default(<ComboOption>[]) List<ComboOption> options,
  }) = _ComboSearchResult;

  factory ComboSearchResult.fromJson(Map<String, dynamic> json) => _$ComboSearchResultFromJson(json);
}
