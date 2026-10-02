import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/services/norma_api.dart';
import '../../domain/models/combo.dart';
import '../../domain/models/meal.dart';

class SelectedCombo {
  const SelectedCombo({required this.option, required this.target, required this.meal, required this.price});

  final ComboOption option;
  final MealTarget target;
  final MealType meal;
  final PricePreference price;

  SelectedCombo withOption(ComboOption option) =>
      SelectedCombo(option: option, target: target, meal: meal, price: price);
}

final selectedComboProvider = NotifierProvider<SelectedComboController, SelectedCombo?>(SelectedComboController.new);

class SelectedComboController extends Notifier<SelectedCombo?> {
  @override
  SelectedCombo? build() => null;

  void select(SelectedCombo combo) => state = combo;

  void replaceOption(ComboOption option) {
    final current = state;
    if (current != null) state = current.withOption(option);
  }
}
