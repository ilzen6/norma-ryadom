import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../data/repositories/feedback_repository.dart';
import '../../data/services/photo_picker_service.dart';
import '../../domain/models/catalog.dart';
import '../../domain/models/combo.dart';
import '../../utils/result.dart';
import '../combo/selected_combo.dart';
import '../core/session.dart';
import '../home/home_view_model.dart';

final venueMenuProvider = FutureProvider.autoDispose.family<Result<VenueMenu>, int>((ref, venueId) async {
  final target = ref.watch(currentTargetProvider);
  if (target == null) return const Err(AppFailure.invalidRequest);
  return ref.watch(venueRepositoryProvider).menu(venueId, target);
});

final venueComboProvider = NotifierProvider.autoDispose.family<VenueComboController, NearbySearchState, int>(
  VenueComboController.new,
);

class VenueComboController extends Notifier<NearbySearchState> {
  VenueComboController(this.venueId);

  final int venueId;

  @override
  NearbySearchState build() {
    ref.watch(currentTargetProvider);
    return const SearchIdle();
  }

  Future<void> search() async {
    final target = ref.read(currentTargetProvider);
    if (target == null || state is SearchRunning) return;
    state = const SearchRunning();
    final selection = ref.read(mealSelectionProvider);
    final result = await ref
        .read(comboRepositoryProvider)
        .atVenue(venueId: venueId, target: target, price: selection.price);
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

enum FeedbackOutcome { sent, cancelled }

final feedbackActionsProvider = Provider<FeedbackActions>(
  (ref) => FeedbackActions(ref.watch(photoPickerProvider), ref.watch(feedbackRepositoryProvider)),
);

class FeedbackActions {
  const FeedbackActions(this._picker, this._feedback);

  final PhotoPickerService _picker;
  final FeedbackRepository _feedback;

  Future<Result<FeedbackOutcome>> sendMenuPhoto(int venueId, PhotoSource source) async {
    final photo = await _picker.pick(source);
    if (photo == null) return const Ok(FeedbackOutcome.cancelled);
    return switch (await _feedback.sendMenuPhoto(venueId, photo)) {
      Ok() => const Ok(FeedbackOutcome.sent),
      Err(:final failure) => Err(failure),
    };
  }

  Future<Result<void>> reportItem(int itemId, String reason) => _feedback.reportItem(itemId, reason);
}
