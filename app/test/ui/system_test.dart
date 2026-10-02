import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:norma_ryadom/domain/models/diary.dart';
import 'package:norma_ryadom/domain/models/meal.dart';
import 'package:norma_ryadom/domain/models/nutrition_norm.dart';

import '../support/fakes.dart';
import '../support/pump_app.dart';

void main() {
  Future<void> resumeApp(WidgetTester tester) async {
    for (final state in [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(state);
    }
    await tester.pumpAndSettle();
  }

  testWidgets('если данные на устройстве не читаются, предлагает повторить или сбросить их', (tester) async {
    final harness = TestHarness(profile: TestData.profile)..profiles.loadError = Exception('database is corrupted');
    await harness.pump(tester);

    expect(find.textContaining('Не удалось прочитать данные на устройстве'), findsOneWidget);
    await tester.tap(find.text('Повторить'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Не удалось прочитать данные на устройстве'), findsOneWidget);

    await tester.tap(find.byKey(const Key('data-reset')));
    await tester.pumpAndSettle();
    expect(harness.profiles.deleted, isTrue);
    expect(find.text('Шаг 1 из 3'), findsOneWidget);
  });

  testWidgets('неизвестный адрес заведения ведёт на понятный экран, а не к падению', (tester) async {
    await TestHarness(profile: TestData.profile).pump(tester);

    unawaited(GoRouter.of(tester.element(find.byType(Scaffold).first)).push('/venue/abc'));
    await tester.pumpAndSettle();
    expect(find.text('Заведение не найдено — возможно, оно закрылось.'), findsOneWidget);

    await tester.tap(find.text('На главную'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('find-nearby')), findsOneWidget);
  });

  testWidgets('после полуночи при возврате в приложение открывает новый день дневника', (tester) async {
    final harness = TestHarness(profile: TestData.profile)..now = DateTime(2026, 10, 2, 23, 50);
    await harness.diary.add(
      const NewDiaryEntry(
        meal: MealType.dinner,
        title: 'Ужин',
        intake: Intake(kcal: 600, protein: 30, fat: 20, carbs: 60),
      ),
      harness.now,
    );
    await harness.pump(tester);
    await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text('Дневник')));
    await tester.pumpAndSettle();
    expect(find.text('Сегодня, 02.10.2026'), findsOneWidget);
    expect(find.text('600 из 1800'), findsOneWidget);
    final locationCalls = harness.location.calls;

    harness.now = DateTime(2026, 10, 3, 8, 15);
    await resumeApp(tester);

    expect(find.text('Сегодня, 03.10.2026'), findsOneWidget);
    expect(find.text('0 из 1800'), findsOneWidget);
    await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text('Что взять')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('find-nearby')));
    await tester.pumpAndSettle();
    expect(harness.location.calls, greaterThan(locationCalls));
  });
}
