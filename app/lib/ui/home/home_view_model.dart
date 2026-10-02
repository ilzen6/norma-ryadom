import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../domain/models/combo.dart';
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
  const SearchDone(this.result);

  final ComboSearchResult result;
}

final class SearchFailed extends NearbySearchState {
  const SearchFailed(this.failure);

  final AppFailure failure;
}

final nearbySearchProvider = NotifierProvider<NearbySearchController, NearbySearchState>(NearbySearchController.new);

class NearbySearchController extends Notifier<NearbySearchState> {
  @override
  NearbySearchState build() {
    ref.watch(currentTargetProvider);
    return const SearchIdle();
  }

  Future<void> search() async {
    final target = ref.read(currentTargetProvider);
    if (target == null || state is SearchRunning) return;
    state = const SearchRunning();
    final location = await ref.read(locationProvider.future);
    final selection = ref.read(mealSelectionProvider);
    final result = await ref
        .read(comboRepositoryProvider)
        .nearby(location: location.location, target: target, price: selection.price);
    if (!ref.mounted) return;
    state = switch (result) {
      Ok(:final value) => SearchDone(value),
      Err(:final failure) => SearchFailed(failure),
    };
  }

  void open(ComboOption option) {
    final current = state;
    if (current is! SearchDone) return;
    final target = current.result.appliedTarget;
    final selection = ref.read(mealSelectionProvider);
    ref
        .read(selectedComboProvider.notifier)
        .select(SelectedCombo(option: option, target: target, meal: selection.meal, price: selection.price));
  }
}
