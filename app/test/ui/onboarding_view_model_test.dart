import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:norma_ryadom/data/providers.dart';
import 'package:norma_ryadom/domain/models/nutrition_norm.dart';
import 'package:norma_ryadom/domain/models/profile.dart';
import 'package:norma_ryadom/ui/core/session.dart';
import 'package:norma_ryadom/ui/onboarding/onboarding_view_model.dart';

import '../support/fakes.dart';

void main() {
  const femaleSafeNorm = NutritionNorm(kcal: 1300, protein: 80, fat: 40, carbs: 150);

  Future<ProviderContainer> containerWith(UserProfile? profile) async {
    final container = ProviderContainer(
      overrides: [profileRepositoryProvider.overrideWithValue(InMemoryProfileRepository(profile))],
    );
    addTearDown(container.dispose);
    await container.read(profileProvider.future);
    container.listen(onboardingProvider, (_, _) {});
    return container;
  }

  test('сбрасывает ручную норму, если после смены пола она ниже безопасного минимума', () async {
    final container = await containerWith(TestData.profile);
    final controller = container.read(onboardingProvider.notifier);

    expect(controller.setManualNorm(femaleSafeNorm), isTrue);
    controller.setSex(Sex.male);

    expect(container.read(onboardingProvider).manualNorm, isNull);
  });

  test('сохраняет безопасную ручную норму при смене пола', () async {
    final container = await containerWith(TestData.profile);
    final controller = container.read(onboardingProvider.notifier);
    const norm = NutritionNorm(kcal: 1800, protein: 100, fat: 60, carbs: 200);

    controller.setManualNorm(norm);
    controller.setSex(Sex.male);

    expect(container.read(onboardingProvider).manualNorm, norm);
  });

  test('не сохраняет профиль с небезопасной ручной нормой', () async {
    final stored = TestData.profile.copyWith(sex: Sex.male, manualNorm: femaleSafeNorm);
    final container = await containerWith(stored);

    final saved = await container.read(onboardingProvider.notifier).complete();

    expect(saved, isFalse);
    expect(container.read(onboardingProvider).saving, isFalse);
  });

  test('снимает признак сохранения, даже если запись на устройство упала', () async {
    final repository = FailingProfileRepository();
    final container = ProviderContainer(overrides: [profileRepositoryProvider.overrideWithValue(repository)]);
    addTearDown(container.dispose);
    await container.read(profileProvider.future);
    container.listen(onboardingProvider, (_, _) {});
    final controller = container.read(onboardingProvider.notifier)
      ..setBodyField(BodyField.age, '30')
      ..setBodyField(BodyField.height, '170')
      ..setBodyField(BodyField.weight, '70');

    await expectLater(controller.complete(), throwsException);

    expect(container.read(onboardingProvider).saving, isFalse);
  });
}

class FailingProfileRepository extends InMemoryProfileRepository {
  @override
  Future<void> save(UserProfile profile) async => throw Exception('disk is full');
}
