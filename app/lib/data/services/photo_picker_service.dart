import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../utils/result.dart';

class PickedPhoto {
  const PickedPhoto({required this.bytes, required this.fileName});

  final List<int> bytes;
  final String fileName;
}

enum PhotoSource { camera, gallery }

abstract interface class PhotoPickerService {
  Future<Result<PickedPhoto?>> pick(PhotoSource source);
}

class DevicePhotoPickerService implements PhotoPickerService {
  DevicePhotoPickerService([ImagePicker? picker]) : _picker = picker ?? ImagePicker();

  static const _maxDimension = 2400.0;
  static const _quality = 85;

  final ImagePicker _picker;

  @override
  Future<Result<PickedPhoto?>> pick(PhotoSource source) async {
    try {
      final file = await _picker.pickImage(
        source: source == PhotoSource.camera ? ImageSource.camera : ImageSource.gallery,
        maxWidth: _maxDimension,
        maxHeight: _maxDimension,
        imageQuality: _quality,
      );
      if (file == null) return const Ok(null);
      return Ok(PickedPhoto(bytes: await file.readAsBytes(), fileName: file.name));
    } on PlatformException {
      return const Err(AppFailure.photoAccessDenied);
    }
  }
}
