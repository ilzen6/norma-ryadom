import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../data/services/norma_api.dart';
import '../../domain/models/combo.dart';
import '../../domain/models/meal.dart';
import '../../domain/models/search_filters.dart';
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
    ref.watch(searchFiltersProvider.select((filters) => filters.prefersCheaper));
    _generation++;
    return const SearchIdle();
  }

  Future<Result<ComboSearchResult>> find(MealTarget target, PricePreference price);

  Future<void> search({bool restart = false}) async {
    final target = ref.read(currentTargetProvider);
    if (target == null || (state is SearchRunning && !restart)) return;
    final meal = ref.read(mealSelectionProvider).meal;
    final price = priceOf(ref.read(searchFiltersProvider));
    final generation = ++_generation;
    state = const SearchRunning();
    final result = await _guarded(() => find(target, price));
    if (!ref.mounted || generation != _generation) return;
    state = switch (result) {
      Ok(:final value) => SearchDone(value, meal: meal, price: price),
      Err(:final failure) => SearchFailed(failure),
    };
  }

  static PricePreference priceOf(SearchFilters filters) =>
      filters.prefersCheaper ? PricePreference.cheaper : PricePreference.any;

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
  NearbySearchState build() {
    ref.listen(searchTastesProvider, (_, _) {});
    return super.build();
  }

  @override
  Future<Result<ComboSearchResult>> find(MealTarget target, PricePreference price) async {
    final repository = ref.read(comboRepositoryProvider);
    final location = await ref.read(locationProvider.future);
    return repository.nearby(
      location: location.location,
      target: target,
      price: price,
      filters: ref.read(searchFiltersProvider),
      tastes: ref.read(searchTastesProvider),
    );
  }

  Future<void> applyFilters(SearchFilters filters, {bool show = false}) async {
    final shown = show || state is! SearchIdle;
    await ref.read(searchFiltersProvider.notifier).apply(filters);
    if (shown && ref.mounted) await search(restart: true);
  }
}

final filterPreviewProvider = FutureProvider.autoDispose.family<int?, SearchFilters>((ref, filters) async {
  final target = ref.watch(currentTargetProvider);
  if (target == null) return null;
  final location = await ref.watch(locationProvider.future);
  final result = await ref
      .read(comboRepositoryProvider)
      .nearby(
        location: location.location,
        target: target,
        price: ComboSearchController.priceOf(filters),
        filters: filters,
        tastes: ref.read(searchTastesProvider),
      );
  return switch (result) {
    Ok(:final value) => value.options.length,
    Err() => null,
  };
});
