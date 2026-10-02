import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../domain/models/combo.dart';
import '../../utils/result.dart';
import 'selected_combo.dart';

sealed class ReplacementState {
  const ReplacementState();
}

final class ReplacementIdle extends ReplacementState {
  const ReplacementIdle();
}

final class ReplacementLoading extends ReplacementState {
  const ReplacementLoading(this.index);

  final int index;
}

final class ReplacementOptions extends ReplacementState {
  const ReplacementOptions(this.index, this.options);

  final int index;
  final List<ComboOption> options;
}

final class ReplacementFailed extends ReplacementState {
  const ReplacementFailed(this.index, this.failure);

  final int index;
  final AppFailure failure;
}

final replacementProvider = NotifierProvider.autoDispose<ReplacementController, ReplacementState>(
  ReplacementController.new,
);

class ReplacementController extends Notifier<ReplacementState> {
  @override
  ReplacementState build() => const ReplacementIdle();

  Future<void> load(int index) async {
    final selected = ref.read(selectedComboProvider);
    if (selected == null || state is ReplacementLoading) return;
    state = ReplacementLoading(index);
    final result = await ref
        .read(comboRepositoryProvider)
        .replace(
          venueId: selected.option.venue.id,
          target: selected.target,
          dishIds: [for (final dish in selected.option.combo.dishes) dish.id],
          replaceIndex: index,
          price: selected.price,
        );
    if (!ref.mounted) return;
    state = switch (result) {
      Ok(:final value) => ReplacementOptions(index, value.options),
      Err(:final failure) => ReplacementFailed(index, failure),
    };
  }

  void choose(ComboOption option) {
    final selected = ref.read(selectedComboProvider);
    if (selected == null) return;
    ref
        .read(selectedComboProvider.notifier)
        .replaceOption(option.copyWith(distanceMeters: selected.option.distanceMeters));
    state = const ReplacementIdle();
  }

  void dismiss() => state = const ReplacementIdle();
}
