import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:norma_ryadom/domain/models/catalog.dart';
import 'package:norma_ryadom/domain/models/combo.dart';
import 'package:norma_ryadom/domain/models/meal.dart';
import 'package:norma_ryadom/utils/result.dart';

import '../support/fakes.dart';
import '../support/pump_app.dart';

void main() {
  final chicken = TestData.dish(1, 'Куриная грудка гриль', 374);
  final mors = TestData.dish(2, 'Морс', 96, category: DishCategory.drink);
  final tea = TestData.dish(3, 'Чай', 0, category: DishCategory.drink);
  final juice = TestData.dish(4, 'Сок яблочный', 110, category: DishCategory.drink);

  Future<TestHarness> openCombo(WidgetTester tester) async {
    final harness = TestHarness(profile: TestData.profile)
      ..combos.nearbyResult = Ok(
        ComboSearchResult(
          appliedTarget: TestData.lunchTarget.copyWith(kcal: 650),
          options: [
            TestData.option([chicken, mors]),
          ],
        ),
      );
    await harness.pump(tester);
    await tester.tap(find.byKey(const Key('find-nearby')));
    await tester.pumpAndSettle();
    await tapVisible(tester, find.bySemanticsLabel(RegExp(r'Куриная грудка гриль \+ Морс')));
    return harness;
  }

  testWidgets('сообщает, что поиск расширили, когда рядом было мало вариантов', (tester) async {
    final harness = TestHarness(profile: TestData.profile)
      ..combos.nearbyResult = Ok(
        ComboSearchResult(
          appliedTarget: TestData.lunchTarget,
          options: [
            TestData.option([chicken, mors]),
          ],
          radiusMeters: 3000,
        ),
      );
    await harness.pump(tester);
    await tester.tap(find.byKey(const Key('find-nearby')));
    await tester.pumpAndSettle();

    await scrollTo(tester, find.byKey(const Key('wider-search')));
    expect(find.byKey(const Key('wider-search')), findsOneWidget);
    expect(find.text('Рядом было мало вариантов — расширили поиск до 3 км'), findsOneWidget);
  });

  testWidgets('на экране набора из примерного меню показывает плашку «Меню примерное»', (tester) async {
    final option = TestData.option([chicken, mors]);
    final harness = TestHarness(profile: TestData.profile)
      ..combos.nearbyResult = Ok(
        ComboSearchResult(
          appliedTarget: TestData.lunchTarget,
          options: [option.copyWith(combo: option.combo.copyWith(sourceKind: SourceKind.estimate))],
        ),
      );
    await harness.pump(tester);
    await tester.tap(find.byKey(const Key('find-nearby')));
    await tester.pumpAndSettle();
    await tapVisible(tester, find.bySemanticsLabel(RegExp(r'Куриная грудка гриль \+ Морс')));

    expect(find.byKey(const Key('combo-screen-estimate-menu')), findsOneWidget);
  });

  testWidgets('не показывает плашку «Меню примерное» у набора с данными сети', (tester) async {
    await openCombo(tester);

    expect(find.byKey(const Key('combo-screen-estimate-menu')), findsNothing);
  });

  testWidgets('объясняет попадание в цель по каждому показателю', (tester) async {
    await openCombo(tester);

    expect(find.text('537 ₽'), findsOneWidget);
    expect(find.text('данные сети'), findsWidgets);
    await scrollTo(tester, find.text('Калории 470 из 630'));
    expect(find.text('Калории 470 из 630'), findsOneWidget);
    expect(find.text('Белок 40 г, нужно от 28 г'), findsOneWidget);
    expect(find.text('Жиры 26 г, цель до 24 г'), findsOneWidget);
    expect(find.text('больше на 2'), findsOneWidget);
  });

  testWidgets('заменяет блюдо, оставляя остальные, по той же цели поиска', (tester) async {
    final harness = await openCombo(tester);
    harness.combos.replaceResult = Ok(
      ComboSearchResult(
        appliedTarget: TestData.lunchTarget,
        options: [
          TestData.option([chicken, tea]),
          TestData.option([chicken, juice]),
        ],
      ),
    );

    await tapVisible(tester, find.byKey(const Key('replace-1')));
    expect(find.text('Чем заменить'), findsOneWidget);
    expect(harness.combos.replaceRequests.single.$1, [1, 2]);
    expect(harness.combos.replaceRequests.single.$2, 1);
    expect(harness.combos.replaceTargets.single, TestData.lunchTarget.copyWith(kcal: 650));
    expect(harness.combos.requestedVenues.single, TestData.venue.id);
    await tapVisible(tester, find.text('Сок яблочный'));

    expect(find.text('Чем заменить'), findsNothing);
    await scrollTo(tester, find.text('Сок яблочный'));
    expect(find.text('Сок яблочный'), findsOneWidget);
    expect(find.text('Морс'), findsNothing);
    expect(find.text('Куриная грудка гриль'), findsOneWidget);
  });

  testWidgets('сообщает, если замены нет, и показывает ошибку замены', (tester) async {
    final harness = await openCombo(tester);

    await tapVisible(tester, find.byKey(const Key('replace-0')));
    expect(find.textContaining('Подходящей замены нет'), findsOneWidget);

    harness.combos.replaceResult = const Err(AppFailure.rateLimited);
    await tapVisible(tester, find.byKey(const Key('replace-0')));
    expect(find.text('Слишком много запросов. Попробуйте чуть позже.'), findsOneWidget);
  });

  testWidgets('«Записать в дневник» сохраняет набор и открывает дневник', (tester) async {
    final harness = await openCombo(tester);

    await tester.tap(find.byKey(const Key('eat-combo')));
    await tester.pumpAndSettle();

    final entry = harness.diary.entries.single;
    expect(entry.title, 'Куриная грудка гриль + Морс');
    expect(entry.meal, MealType.lunch);
    expect(entry.venueName, 'Гриль Хаус, Москва-Сити');
    expect(entry.intake.kcal, 470);
    expect(find.text('СЪЕДЕНО'), findsOneWidget);
  });

  testWidgets('двойное нажатие «Записать в дневник» сохраняет набор один раз', (tester) async {
    final harness = await openCombo(tester);
    final gate = Completer<void>();
    harness.diary.gate = gate;

    await tester.tap(find.byKey(const Key('eat-combo')));
    await tester.pump();
    expect(tester.widget<ButtonStyleButton>(find.byKey(const Key('eat-combo'))).onPressed, isNull);
    await tester.tap(find.byKey(const Key('eat-combo')), warnIfMissed: false);
    gate.complete();
    await tester.pumpAndSettle();

    expect(harness.diary.entries, hasLength(1));
  });

  testWidgets('сообщает об ошибке записи и остаётся на экране набора', (tester) async {
    final harness = await openCombo(tester);
    harness.diary.writeError = Exception('disk full');

    await tester.tap(find.byKey(const Key('eat-combo')));
    await tester.pumpAndSettle();

    expect(harness.diary.entries, isEmpty);
    expect(find.text('Что-то пошло не так. Повторите попытку.'), findsOneWidget);
    await scrollTo(tester, find.text('Попадание в цель'));
    expect(find.text('Попадание в цель'), findsOneWidget);
  });

  testWidgets('делится набором: в тексте заведение, блюда, КБЖУ и цена', (tester) async {
    final harness = await openCombo(tester);

    await tester.tap(find.byKey(const Key('share-combo')));
    await tester.pumpAndSettle();

    expect(
      harness.share.shared.single,
      'Обед в «Гриль Хаус, Москва-Сити» (Пресненская наб., 2), 2 мин пешком\n'
      '• Куриная грудка гриль — 374 ккал\n'
      '• Морс — 96 ккал\n'
      'Итого: 470 ккал · Б 40 · Ж 18 · У 70 · ≈ 537 ₽\n'
      'Подобрано в «Норма рядом»',
    );
    expect(harness.share.subjects.single, 'Обед в «Норма рядом»');
  });

  testWidgets('помечает в тексте для друга, что КБЖУ примерные', (tester) async {
    final soup = TestData.dish(5, 'Борщ со сметаной', 227).copyWith(sourceKind: SourceKind.estimate);
    final harness = TestHarness(profile: TestData.profile)
      ..combos.nearbyResult = Ok(
        ComboSearchResult(
          appliedTarget: TestData.lunchTarget,
          options: [
            TestData.option([soup, mors]),
          ],
        ),
      );
    await harness.pump(tester);
    await tester.tap(find.byKey(const Key('find-nearby')));
    await tester.pumpAndSettle();
    await tapVisible(tester, find.bySemanticsLabel(RegExp(r'Борщ со сметаной \+ Морс')));

    await tester.tap(find.byKey(const Key('share-combo')));
    await tester.pumpAndSettle();

    expect(harness.share.shared.single, endsWith('КБЖУ примерные · подобрано в «Норма рядом»'));
  });

  testWidgets('показывает под набором, как текст увидит друг', (tester) async {
    await openCombo(tester);

    await scrollTo(tester, find.byKey(const Key('share-preview')));

    expect(find.bySemanticsLabel('Так увидит друг'), findsOneWidget);
    expect(find.textContaining('• Куриная грудка гриль — 374 ккал'), findsOneWidget);
  });

  testWidgets('если поделиться не получилось, копирует текст и сообщает об этом', (tester) async {
    final copied = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') copied.add((call.arguments as Map<Object?, Object?>)['text']! as String);
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
    final harness = await openCombo(tester);
    harness.share.fails = true;

    await tester.tap(find.byKey(const Key('share-combo')));
    await tester.pumpAndSettle();

    expect(find.text('Не получилось открыть «Поделиться» — текст набора скопирован'), findsOneWidget);
    expect(copied.single, startsWith('Обед в «Гриль Хаус, Москва-Сити»'));
    expect(harness.share.shared, isEmpty);
  });
}
