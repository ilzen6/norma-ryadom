import '../../utils/result.dart';
import '../services/norma_api.dart';
import '../services/photo_picker_service.dart';

abstract interface class FeedbackRepository {
  Future<Result<SubmissionReceipt>> sendMenuPhoto(int venueId, PickedPhoto photo);

  Future<Result<void>> reportItem(int itemId, String reason);
}

class RemoteFeedbackRepository implements FeedbackRepository {
  const RemoteFeedbackRepository(this._api);

  final NormaApi _api;

  @override
  Future<Result<SubmissionReceipt>> sendMenuPhoto(int venueId, PickedPhoto photo) =>
      _api.uploadMenuPhoto(venueId: venueId, bytes: photo.bytes, fileName: photo.fileName);

  @override
  Future<Result<void>> reportItem(int itemId, String reason) => _api.reportItem(itemId, reason.trim());
}
