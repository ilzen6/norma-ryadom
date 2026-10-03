import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../data/repositories/feedback_repository.dart';
import '../../data/services/photo_picker_service.dart';
import '../../domain/models/catalog.dart';
import '../../domain/models/combo.dart';
import '../../data/services/norma_api.dart';
import '../../domain/models/meal.dart';
import '../../utils/result.dart';
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

class VenueComboController extends ComboSearchController {
  VenueComboController(this.venueId);

  final int venueId;

  @override
  Future<Result<ComboSearchResult>> find(MealTarget target, PricePreference price) =>
      ref.read(comboRepositoryProvider).atVenue(venueId: venueId, target: target, price: price);
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
    final PickedPhoto? photo;
    switch (await _picker.pick(source)) {
      case Err(:final failure):
        return Err(failure);
      case Ok(:final value):
        photo = value;
    }
    if (photo == null) return const Ok(FeedbackOutcome.cancelled);
    return switch (await _feedback.sendMenuPhoto(venueId, photo)) {
      Ok() => const Ok(FeedbackOutcome.sent),
      Err(:final failure) => Err(failure),
    };
  }

  Future<Result<void>> reportItem(int itemId, String reason) => _feedback.reportItem(itemId, reason);

  Future<Result<void>> reportVenue(int venueId, VenueReportReason reason) => _feedback.reportVenue(venueId, reason);
}
