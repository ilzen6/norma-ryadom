import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:norma_ryadom/domain/models/diet_preference.dart';
import 'package:norma_ryadom/domain/models/profile.dart';
import 'package:norma_ryadom/utils/result.dart';

import '../support/pump_app.dart';

void main() {
  Future<void> fillBody(WidgetTester tester) async {
    await tester.enterText(find.byKey(const Key('age-field')), '25');
    await tester.enterText(find.byKey(const Key('height-field')), '165');
    await tester.enterText(find.byKey(const Key('weight-field')), '62');
    await tester.pumpAndSettle();
  }

  testWidgets('без профиля открывает онбординг и не пускает дальше без параметров', (tester) async {
    final harness = TestHarness();
    await harness.pump(tester);

    expect(find.text('ШАГ 1 ИЗ 3'), findsOneWidget);
    expect(tester.widget<FilledButton>(find.byKey(const Key('onboarding-next'))).onPressed, isNull);
    await tester.enterText(find.byKey(const Key('age-field')), '7');
    await tester.pumpAndSettle();
    expect(find.text('Допустимо от 14 до 100'), findsOneWidget);
  });

  testWidgets('считает норму по параметрам и объясняет расчёт', (tester) async {
    final harness = TestHarness();
    await harness.pump(tester);

    await fillBody(tester);
    await scrollTo(tester, find.text('1800 ккал'));

    expect(find.text('1800 ккал'), findsOneWidget);
    expect(find.text('Белки 135 г · Жиры 60 г · Углеводы 180 г'), findsOneWidget);
    expect(find.textContaining('Базовый обмен по формуле Миффлина — Сан Жеора: 1365 ккал'), findsOneWidget);
    await tester.tap(find.text('Поддержание'));
    await tester.pumpAndSettle();
    await scrollTo(tester, find.text('2120 ккал'));
    expect(find.text('2120 ккал'), findsOneWidget);
  });

  testWidgets('не даёт задать ручную норму ниже безопасного минимума', (tester) async {
    final harness = TestHarness();
    await harness.pump(tester);
    await fillBody(tester);

    await tapVisible(tester, find.text('Изменить вручную'));
    await tester.enterText(find.widgetWithText(TextFormField, 'Калории, ккал'), '1000');
    await tapVisible(tester, find.text('Сохранить'));
    expect(find.text('Не меньше 1200 ккал — это безопасный минимум'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextFormField, 'Калории, ккал'), '1700');
    await tapVisible(tester, find.text('Сохранить'));
    await scrollTo(tester, find.text('1700 ккал'));
    expect(find.text('1700 ккал'), findsOneWidget);
    expect(find.text('Норма задана вручную'), findsOneWidget);
  });

  testWidgets('задаёт норму вручную в процентах калорий и не принимает доли с суммой не 100%', (tester) async {
    final harness = TestHarness();
    await harness.pump(tester);
    await fillBody(tester);
    await scrollTo(tester, find.byKey(const Key('norm-shares')));

    expect(find.text('Доли калорий: белки 30% · жиры 30% · углеводы 40%'), findsOneWidget);
    await tapVisible(tester, find.text('Изменить вручную'));
    await tester.enterText(find.byKey(const Key('norm-manual-kcal')), '2000');
    await tester.enterText(find.byKey(const Key('norm-manual-protein')), '35');
    await tester.pumpAndSettle();
    expect(find.text('≈ 175 г'), findsOneWidget);
    await tapVisible(tester, find.text('Сохранить'));
    expect(find.text('Сумма долей 105%, нужно ровно 100%'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('norm-manual-carbs')), '35');
    await tapVisible(tester, find.text('Сохранить'));
    await scrollTo(tester, find.text('2000 ккал'));
    expect(find.text('Белки 175 г · Жиры 67 г · Углеводы 175 г'), findsOneWidget);
    expect(find.text('Доли калорий: белки 35% · жиры 30% · углеводы 35%'), findsOneWidget);
  });

  testWidgets('предупреждает, что отметки исключений зависят от состава, опубликованного сетью', (tester) async {
    await TestHarness().pump(tester);
    await fillBody(tester);

    await tester.tap(find.byKey(const Key('onboarding-next')));
    await tester.pumpAndSettle();

    expect(
      find.text('Отметки берутся из состава, который публикует сеть. При аллергии уточняйте состав у персонала.'),
      findsOneWidget,
    );
  });

  testWidgets('проходит три шага и сохраняет профиль на устройстве', (tester) async {
    final harness = TestHarness();
    await harness.pump(tester);
    await fillBody(tester);

    await tester.tap(find.byKey(const Key('onboarding-next')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Без свинины'));
    await tester.tap(find.text('Без орехов'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('onboarding-next')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('allow-location')));
    await tester.pumpAndSettle();
    expect(find.text('Геолокация разрешена'), findsOneWidget);
    await tester.tap(find.byKey(const Key('onboarding-next')));
    await tester.pumpAndSettle();

    final saved = harness.profiles.profile;
    expect(saved?.age, 25);
    expect(saved?.goal, Goal.lose);
    expect(saved?.preferences, {DietPreference.noPork, DietPreference.noNuts});
    expect(saved?.locationConsent, isTrue);
    expect(find.text('ОСТАЛОСЬ НА СЕГОДНЯ'), findsOneWidget);
  });

  testWidgets('прячет клавиатуру по нажатию мимо поля ввода', (tester) async {
    final harness = TestHarness();
    await harness.pump(tester);

    await tester.tap(find.widgetWithText(TextFormField, 'Возраст, лет'));
    await tester.pumpAndSettle();
    expect(tester.testTextInput.isVisible, isTrue);

    await tester.tap(find.text('Параметры и цель'));
    await tester.pumpAndSettle();
    expect(tester.testTextInput.isVisible, isFalse);
  });

  testWidgets('с разрешённой геолокацией не просит выбирать район', (tester) async {
    final harness = TestHarness();
    await harness.pump(tester);
    await fillBody(tester);
    await tester.tap(find.byKey(const Key('onboarding-next')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('onboarding-next')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('district-field')), findsOneWidget);
    await tester.tap(find.byKey(const Key('allow-location')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('district-field')), findsNothing);
  });

  testWidgets('без доступа к геолокации предлагает выбрать район', (tester) async {
    final harness = TestHarness()..location.result = const Err(AppFailure.locationDenied);
    await harness.pump(tester);
    await fillBody(tester);
    await tester.tap(find.byKey(const Key('onboarding-next')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('onboarding-next')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('allow-location')));
    await tester.pumpAndSettle();

    expect(find.text('Нет доступа к геолокации — выберите район вручную в профиле.'), findsOneWidget);
    await tester.tap(find.byKey(const Key('district-field')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Арбат').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('onboarding-next')));
    await tester.pumpAndSettle();
    expect(harness.profiles.profile?.locationConsent, isFalse);
    expect(harness.profiles.profile?.district?.name, 'arbat');
  });

  testWidgets('кнопка «Назад» возвращает на предыдущий шаг', (tester) async {
    final harness = TestHarness();
    await harness.pump(tester);
    await fillBody(tester);
    await tester.tap(find.byKey(const Key('onboarding-next')));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Назад'));
    await tester.pumpAndSettle();

    expect(find.text('ШАГ 1 ИЗ 3'), findsOneWidget);
  });
}
