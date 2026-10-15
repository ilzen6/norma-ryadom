import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:health/health.dart' as hk;
import 'package:package_info_plus/package_info_plus.dart';

import '../../domain/models/diary.dart';
import '../../domain/models/meal.dart';
import '../../domain/models/nutrition_norm.dart';

abstract interface class HealthSyncService {
  Future<bool> isAvailable();

  Future<bool> connect();

  Future<Intake> eatenElsewhere(DateTime day);

  Future<void> export(NewDiaryEntry entry, DateTime at);
}

class UnavailableHealthSyncService implements HealthSyncService {
  const UnavailableHealthSyncService();

  @override
  Future<bool> isAvailable() async => false;

  @override
  Future<bool> connect() async => false;

  @override
  Future<Intake> eatenElsewhere(DateTime day) async => Intake.zero;

  @override
  Future<void> export(NewDiaryEntry entry, DateTime at) async {}
}

class PlatformHealthSyncService implements HealthSyncService {
  PlatformHealthSyncService({
    hk.Health? health,
    Future<String> Function()? ownSource,
    bool? supported,
    bool? appleHealth,
  }) : _health = health ?? hk.Health(),
       _ownSourceOf = ownSource ?? _packageName,
       _supported = supported ?? PlatformHealthSyncService.supported,
       _appleHealth = appleHealth ?? (PlatformHealthSyncService.supported && Platform.isIOS);

  static const _healthConnectTypes = [hk.HealthDataType.NUTRITION];
  static const _appleHealthTypes = [
    hk.HealthDataType.DIETARY_ENERGY_CONSUMED,
    hk.HealthDataType.DIETARY_PROTEIN_CONSUMED,
    hk.HealthDataType.DIETARY_FATS_CONSUMED,
    hk.HealthDataType.DIETARY_CARBS_CONSUMED,
  ];
  static const _mealDuration = Duration(minutes: 20);

  static bool get supported => !kIsWeb && (Platform.isIOS || Platform.isAndroid);

  final hk.Health _health;
  final Future<String> Function() _ownSourceOf;
  final bool _supported;
  final bool _appleHealth;
  Future<void>? _configured;
  String? _ownSource;

  List<hk.HealthDataType> get _types => _appleHealth ? _appleHealthTypes : _healthConnectTypes;

  static Future<String> _packageName() async => (await PackageInfo.fromPlatform()).packageName;

  Future<void> _ready() => _configured ??= () async {
    await _health.configure();
    _ownSource = await _ownSourceOf();
  }();

  @override
  Future<bool> isAvailable() async {
    if (!_supported) return false;
    await _ready();
    return _health.isHealthConnectAvailable();
  }

  @override
  Future<bool> connect() async {
    if (!await isAvailable()) return false;
    return _health.requestAuthorization(
      _types,
      permissions: List.filled(_types.length, hk.HealthDataAccess.READ_WRITE),
    );
  }

  @override
  Future<Intake> eatenElsewhere(DateTime day) async {
    if (!await isAvailable()) return Intake.zero;
    final start = DateTime(day.year, day.month, day.day);
    final points = await _health.getHealthDataFromTypes(
      types: _types,
      startTime: start,
      endTime: start.add(const Duration(days: 1)),
    );
    final others = points.where((point) => point.sourceId != _ownSource);
    if (_appleHealth) {
      double total(hk.HealthDataType type) => others
          .where((point) => point.type == type)
          .map((point) => point.value)
          .whereType<hk.NumericHealthValue>()
          .fold(0, (sum, value) => sum + value.numericValue);
      return Intake(
        kcal: total(hk.HealthDataType.DIETARY_ENERGY_CONSUMED),
        protein: total(hk.HealthDataType.DIETARY_PROTEIN_CONSUMED),
        fat: total(hk.HealthDataType.DIETARY_FATS_CONSUMED),
        carbs: total(hk.HealthDataType.DIETARY_CARBS_CONSUMED),
      );
    }
    return others
        .map((point) => point.value)
        .whereType<hk.NutritionHealthValue>()
        .fold<Intake>(
          Intake.zero,
          (sum, value) =>
              sum +
              Intake(
                kcal: value.calories ?? 0,
                protein: value.protein ?? 0,
                fat: value.fat ?? 0,
                carbs: value.carbs ?? 0,
              ),
        );
  }

  @override
  Future<void> export(NewDiaryEntry entry, DateTime at) async {
    if (!await isAvailable()) return;
    await _health.writeMeal(
      mealType: switch (entry.meal) {
        MealType.breakfast => hk.MealType.BREAKFAST,
        MealType.lunch => hk.MealType.LUNCH,
        MealType.dinner => hk.MealType.DINNER,
        MealType.snack => hk.MealType.SNACK,
      },
      startTime: at,
      endTime: at.add(_mealDuration),
      name: entry.title,
      caloriesConsumed: entry.intake.kcal,
      protein: entry.intake.protein,
      fatTotal: entry.intake.fat,
      carbohydrates: entry.intake.carbs,
      recordingMethod: hk.RecordingMethod.manual,
    );
  }
}
