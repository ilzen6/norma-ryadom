import 'package:image_picker/image_picker.dart';

class PickedPhoto {
  const PickedPhoto({required this.bytes, required this.fileName});

  final List<int> bytes;
  final String fileName;
}

enum PhotoSource { camera, gallery }

abstract interface class PhotoPickerService {
  Future<PickedPhoto?> pick(PhotoSource source);
}

class DevicePhotoPickerService implements PhotoPickerService {
  DevicePhotoPickerService([ImagePicker? picker]) : _picker = picker ?? ImagePicker();

  static const _maxDimension = 2400.0;
  static const _quality = 85;

  final ImagePicker _picker;

  @override
  Future<PickedPhoto?> pick(PhotoSource source) async {
    final file = await _picker.pickImage(
      source: source == PhotoSource.camera ? ImageSource.camera : ImageSource.gallery,
      maxWidth: _maxDimension,
      maxHeight: _maxDimension,
      imageQuality: _quality,
    );
    if (file == null) return null;
    return PickedPhoto(bytes: await file.readAsBytes(), fileName: file.name);
  }
}
