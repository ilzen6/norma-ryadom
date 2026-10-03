import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:norma_ryadom/domain/models/catalog.dart';
import 'package:norma_ryadom/l10n/generated/app_localizations.dart';
import 'package:norma_ryadom/ui/core/l10n_extensions.dart';
import 'package:norma_ryadom/ui/core/widgets/combo_card.dart';
import 'package:norma_ryadom/ui/core/widgets/visuals.dart';

import '../support/fakes.dart';
import '../support/pump_app.dart';

void main() {
  test('показывает километры от тысячи метров, время пешком только до пяти километров', () {
    final l10n = lookupAppLocalizations(const Locale('ru'));

    expect(l10n.walk(144), '144 м · 2 мин');
    expect(l10n.walk(75), '75 м · 1 мин');
    expect(l10n.walk(1480), '1,5 км · 20 мин');
    expect(l10n.walkSemantics(1480), '1,5 км, 20 минут пешком');
    expect(l10n.walk(12340), '12,3 км');
    expect(l10n.walk(630800), '631 км');
  });

  Future<void> pumpPiece(WidgetTester tester, Widget child, {Brightness brightness = Brightness.light}) =>
      TestHarness().pumpComponent(tester, child, brightness: brightness, settle: false).then((_) => tester.pump());

  test('подбирает значок блюда по названию, а для салатов и соусов — по категории', () {
    expect(DishAvatar.iconOf(DishCategory.main, 'Пицца Маргарита, кусок'), Icons.local_pizza_rounded);
    expect(DishAvatar.iconOf(DishCategory.main, 'Борщ со сметаной'), Icons.soup_kitchen_rounded);
    expect(DishAvatar.iconOf(DishCategory.drink, 'Капучино 0,3'), Icons.coffee_rounded);
    expect(DishAvatar.iconOf(DishCategory.side, 'Рис с овощами'), Icons.rice_bowl_rounded);
    expect(DishAvatar.iconOf(DishCategory.salad, 'Салат с тунцом'), Icons.eco_rounded);
    expect(DishAvatar.iconOf(DishCategory.sauce, 'Сметана'), Icons.water_drop_rounded);
    expect(DishAvatar.iconOf(DishCategory.main, 'Неизвестное блюдо'), Icons.restaurant_rounded);
  });

  test('ищет слово блюда только с начала слова, а не внутри другого', () {
    expect(DishAvatar.iconOf(DishCategory.dessert, 'Брауни шоколадный'), Icons.cake_rounded);
    expect(DishAvatar.iconOf(DishCategory.drink, 'Морс барбарисовый'), Icons.local_drink_rounded);
    expect(DishAvatar.iconOf(DishCategory.main, 'Крем-суп тыквенный'), Icons.soup_kitchen_rounded);
  });

  testWidgets('при отключённых анимациях кольца сразу показывают итог', (tester) async {
    await tester.pumpWidget(
      const MediaQuery(
        data: MediaQueryData(disableAnimations: true),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: ProgressRings(rings: [RingSpec(value: 0.6, color: Colors.green)]),
        ),
      ),
    );
    await tester.pump();

    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('сводит одинаковые блюда набора в одну строку с множителем', (tester) async {
    final rice = TestData.dish(2, 'Рис с овощами', 207, category: DishCategory.side);
    await pumpPiece(tester, DishLines(dishes: [TestData.dish(1, 'Куриная грудка гриль', 214), rice, rice]));
    await tester.pumpAndSettle();

    expect(find.text('Рис с овощами'), findsOneWidget);
    expect(find.text('×2'), findsOneWidget);
    expect(find.text('414'), findsOneWidget);
    expect(find.bySemanticsLabel('Куриная грудка гриль + Рис с овощами + Рис с овощами'), findsOneWidget);
  });

  testWidgets('показывает не больше заданного числа строк и называет остаток', (tester) async {
    await pumpPiece(
      tester,
      DishLines(maxLines: 2, dishes: [for (var id = 1; id <= 5; id++) TestData.dish(id, 'Блюдо $id', 100)]),
    );

    expect(find.text('Блюдо 3'), findsNothing);
    expect(find.text('и ещё 3 блюда'), findsOneWidget);
  });

  testWidgets('во время подбора показывает заглушки карточек с подписью для озвучки', (tester) async {
    await pumpPiece(tester, const SkeletonCards(count: 2, label: 'Подбираем'), brightness: Brightness.dark);
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.bySemanticsLabel('Подбираем'), findsOneWidget);
    expect(find.byType(Panel), findsNWidgets(2));
  });

  testWidgets('кольца прогресса плавно доходят до нового значения', (tester) async {
    Widget rings(double value) => ProgressRings(
      rings: [RingSpec(value: value, color: Colors.green)],
    );
    await pumpPiece(tester, rings(0.2));
    await tester.pumpAndSettle();
    await pumpPiece(tester, rings(0.8));
    await tester.pump(const Duration(milliseconds: 100));

    expect(tester.hasRunningAnimations, isTrue);
    await tester.pumpAndSettle();
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('рисует иллюстрацию поиска рядом в обеих темах', (tester) async {
    for (final brightness in Brightness.values) {
      await pumpPiece(tester, const NearbyIllustration(), brightness: brightness);
      expect(find.byType(NearbyIllustration), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });
}
