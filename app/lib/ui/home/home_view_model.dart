import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../data/services/norma_api.dart';
import '../../domain/models/combo.dart';
import '../../domain/models/meal.dart';
import '../../utils/result.dart';
import '../combo/selected_combo.dart';
import '../core/session.dart';

sealed class NearbySearchState {
  const NearbySearchState();
}

final class SearchIdle extends NearbySearchState {
  const SearchIdle();
}

final class SearchRunning extends NearbySearchState {
  const SearchRunning();
}

final class SearchDone extends NearbySearchState {
  const SearchDone(this.result, {required this.meal, required this.price});

  final ComboSearchResult result;
  final MealType meal;
  final PricePreference price;

  SelectedCombo select(ComboOption option) =>
      SelectedCombo(option: option, target: result.appliedTarget, meal: meal, price: price);
}

final class SearchFailed extends NearbySearchState {
  const SearchFailed(this.failure);

  final AppFailure failure;
}

abstract class ComboSearchController extends Notifier<NearbySearchState> {
  int _generation = 0;

  @override
  NearbySearchState build() {
    ref.watch(currentTargetProvider);
    ref.watch(mealSelectionProvider.select((selection) => selection.price));
    _generation++;
    return const SearchIdle();
  }

  Future<Result<ComboSearchResult>> find(MealTarget target, PricePreference price);

  Future<void> search() async {
    final target = ref.read(currentTargetProvider);
    if (target == null || state is SearchRunning) return;
    final selection = ref.read(mealSelectionProvider);
    final generation = ++_generation;
    state = const SearchRunning();
    final result = await _guarded(() => find(target, selection.price));
    if (!ref.mounted || generation != _generation) return;
    state = switch (result) {
      Ok(:final value) => SearchDone(value, meal: selection.meal, price: selection.price),
      Err(:final failure) => SearchFailed(failure),
    };
  }

  void open(ComboOption option) {
    final current = state;
    if (current is SearchDone) ref.read(selectedComboProvider.notifier).select(current.select(option));
  }

  static Future<Result<ComboSearchResult>> _guarded(Future<Result<ComboSearchResult>> Function() action) async {
    try {
      return await action();
    } on Exception {
      return const Err(AppFailure.unexpected);
    }
  }
}

final nearbySearchProvider = NotifierProvider<NearbySearchController, NearbySearchState>(NearbySearchController.new);

class NearbySearchController extends ComboSearchController {
  @override
  Future<Result<ComboSearchResult>> find(MealTarget target, PricePreference price) async {
    final repository = ref.read(comboRepositoryProvider);
    final location = await ref.read(locationProvider.future);
    return repository.nearby(location: location.location, target: target, price: price);
  }
}
