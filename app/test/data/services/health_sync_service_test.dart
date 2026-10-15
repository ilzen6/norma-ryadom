import 'package:flutter_test/flutter_test.dart';
import 'package:health/health.dart' as hk;
import 'package:norma_ryadom/data/services/health_sync_service.dart';
import 'package:norma_ryadom/domain/models/diary.dart';
import 'package:norma_ryadom/domain/models/meal.dart';
import 'package:norma_ryadom/domain/models/nutrition_norm.dart';

class FakeHealth implements hk.Health {
  bool available = true;
  bool granted = true;
  List<hk.HealthDataPoint> points = [];
  final List<Invocation> calls = [];

  @override
  Future<void> configure() async {}

  @override
  Future<bool> isHealthConnectAvailable() async => available;

  @override
  Future<bool> requestAuthorization(List<hk.HealthDataType> types, {List<hk.HealthDataAccess>? permissions}) async {
    calls.add(Invocation.method(#requestAuthorization, [types], {#permissions: permissions}));
    return granted;
  }

  @override
  Future<List<hk.HealthDataPoint>> getHealthDataFromTypes({
    required List<hk.HealthDataType> types,
    Map<hk.HealthDataType, hk.HealthDataUnit>? preferredUnits,
    required DateTime startTime,
    required DateTime endTime,
    List<hk.RecordingMethod> recordingMethodsToFilter = const [],
  }) async {
    calls.add(Invocation.method(#getHealthDataFromTypes, [], {#startTime: startTime, #endTime: endTime}));
    return points;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    calls.add(invocation);
    return Future.value(true);
  }
}

hk.HealthDataPoint meal(String source, double kcal) => hk.HealthDataPoint(
  uuid: '$source-$kcal',
  value: hk.NutritionHealthValue(calories: kcal, protein: 10, fat: 5, carbs: 20),
  type: hk.HealthDataType.NUTRITION,
  unit: hk.HealthDataUnit.NO_UNIT,
  dateFrom: DateTime(2026, 10, 15, 9),
  dateTo: DateTime(2026, 10, 15, 9, 20),
  sourcePlatform: hk.HealthPlatformType.appleHealth,
  sourceDeviceId: 'device',
  sourceId: source,
  sourceName: source,
);

void main() {
  late FakeHealth health;
  PlatformHealthSyncService service({bool supported = true, bool appleHealth = false}) => PlatformHealthSyncService(
    health: health,
    ownSource: () async => 'ru.normaryadom',
    supported: supported,
    appleHealth: appleHealth,
  );

  setUp(() => health = FakeHealth());

  test('считает съеденное за день в других приложениях, не учитывая свои записи', () async {
    health.points = [meal('com.fatsecret', 400), meal('ru.normaryadom', 600), meal('com.yazio', 250)];

    final eaten = await service().eatenElsewhere(DateTime(2026, 10, 15, 18));

    expect(eaten, const Intake(kcal: 650, protein: 20, fat: 10, carbs: 40));
    final query = health.calls.singleWhere((call) => call.memberName == #getHealthDataFromTypes);
    expect(query.namedArguments[#startTime], DateTime(2026, 10, 15));
    expect(query.namedArguments[#endTime], DateTime(2026, 10, 16));
  });

  test('в Apple Здоровье складывает калории и БЖУ по отдельным записям, не учитывая свои', () async {
    hk.HealthDataPoint sample(hk.HealthDataType type, String source, num value) => hk.HealthDataPoint(
      uuid: '$type-$source-$value',
      value: hk.NumericHealthValue(numericValue: value),
      type: type,
      unit: hk.HealthDataUnit.GRAM,
      dateFrom: DateTime(2026, 10, 15, 9),
      dateTo: DateTime(2026, 10, 15, 9),
      sourcePlatform: hk.HealthPlatformType.appleHealth,
      sourceDeviceId: 'device',
      sourceId: source,
      sourceName: source,
    );
    health.points = [
      sample(hk.HealthDataType.DIETARY_ENERGY_CONSUMED, 'com.yazio', 500),
      sample(hk.HealthDataType.DIETARY_ENERGY_CONSUMED, 'ru.normaryadom', 900),
      sample(hk.HealthDataType.DIETARY_PROTEIN_CONSUMED, 'com.yazio', 30),
      sample(hk.HealthDataType.DIETARY_FATS_CONSUMED, 'com.yazio', 12.5),
      sample(hk.HealthDataType.DIETARY_CARBS_CONSUMED, 'com.yazio', 60),
    ];

    final eaten = await service(appleHealth: true).eatenElsewhere(DateTime(2026, 10, 15));

    expect(eaten, const Intake(kcal: 500, protein: 30, fat: 12.5, carbs: 60));
  });

  test('в Apple Здоровье просит доступ только к калориям и БЖУ', () async {
    await service(appleHealth: true).connect();

    final request = health.calls.singleWhere((call) => call.memberName == #requestAuthorization);
    expect(request.positionalArguments.single, [
      hk.HealthDataType.DIETARY_ENERGY_CONSUMED,
      hk.HealthDataType.DIETARY_PROTEIN_CONSUMED,
      hk.HealthDataType.DIETARY_FATS_CONSUMED,
      hk.HealthDataType.DIETARY_CARBS_CONSUMED,
    ]);
    expect(request.namedArguments[#permissions], everyElement(hk.HealthDataAccess.READ_WRITE));
  });

  test('записывает приём пищи в «Здоровье» с КБЖУ и типом приёма', () async {
    const entry = NewDiaryEntry(
      meal: MealType.lunch,
      title: 'Боул с курицей',
      intake: Intake(kcal: 446, protein: 34, fat: 14, carbs: 46),
    );

    await service().export(entry, DateTime(2026, 10, 15, 13));

    final write = health.calls.singleWhere((call) => call.memberName == #writeMeal).namedArguments;
    expect(write[#mealType], hk.MealType.LUNCH);
    expect(write[#name], 'Боул с курицей');
    expect([write[#caloriesConsumed], write[#protein], write[#fatTotal], write[#carbohydrates]], [446, 34, 14, 46]);
    expect(write[#startTime], DateTime(2026, 10, 15, 13));
  });

  test('просит доступ на чтение и запись питания', () async {
    expect(await service().connect(), isTrue);
    final request = health.calls.singleWhere((call) => call.memberName == #requestAuthorization);
    expect(request.positionalArguments.single, [hk.HealthDataType.NUTRITION]);
    expect(request.namedArguments[#permissions], [hk.HealthDataAccess.READ_WRITE]);
  });

  test('без «Здоровья» на устройстве ничего не читает и не пишет', () async {
    health.available = false;
    final unavailable = service();

    expect(await unavailable.connect(), isFalse);
    expect(await unavailable.eatenElsewhere(DateTime(2026, 10, 15)), Intake.zero);
    await unavailable.export(
      const NewDiaryEntry(
        meal: MealType.snack,
        title: 'Яблоко',
        intake: Intake(kcal: 50, protein: 0, fat: 0, carbs: 12),
      ),
      DateTime(2026, 10, 15),
    );
    expect(health.calls, isEmpty);
  });

  test('на неподдерживаемой платформе считается недоступным', () async {
    expect(await service(supported: false).isAvailable(), isFalse);
    expect(await const UnavailableHealthSyncService().connect(), isFalse);
  });
}
