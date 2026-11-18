import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:norma_ryadom/data/services/norma_api.dart';
import 'package:norma_ryadom/domain/models/meal.dart';
import 'package:norma_ryadom/l10n/generated/app_localizations.dart';
import 'package:norma_ryadom/ui/combo/combo_share_text.dart';
import 'package:norma_ryadom/ui/combo/selected_combo.dart';

import '../support/fakes.dart';

void main() {
  final l10n = lookupAppLocalizations(const Locale('ru'));
  final option = TestData.option([TestData.dish(1, 'Салат с тунцом', 320)]);

  SelectedCombo selected(int? distance, {int? priceMinor = 32000}) => SelectedCombo(
    option: option.copyWith(
      distanceMeters: distance,
      combo: option.combo.copyWith(priceMinor: priceMinor),
    ),
    target: TestData.lunchTarget,
    meal: MealType.dinner,
    price: PricePreference.any,
  );

  test('без расстояния не пишет время пешком', () {
    expect(
      ComboShareText.of(l10n, selected(null)).split('\n').first,
      'Ужин в «Гриль Хаус, Москва-Сити» (Пресненская наб., 2)',
    );
  });

  test('для далёкого заведения не считает минуты пешком', () {
    expect(ComboShareText.of(l10n, selected(7200)), isNot(contains('пешком')));
  });

  test('без цены не пишет сумму', () {
    final text = ComboShareText.of(l10n, selected(300, priceMinor: null));

    expect(text, contains('Итого: 320 ккал · Б 40 · Ж 18 · У 70\n'));
    expect(text, isNot(contains('₽')));
  });
}
