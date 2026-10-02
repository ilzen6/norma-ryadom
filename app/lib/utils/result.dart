sealed class Result<T> {
  const Result();
}

final class Ok<T> extends Result<T> {
  const Ok(this.value);

  final T value;
}

final class Err<T> extends Result<T> {
  const Err(this.failure);

  final AppFailure failure;
}

enum AppFailure {
  offline,
  notFound,
  invalidRequest,
  rateLimited,
  unsupportedPhoto,
  photoTooLarge,
  serviceUnavailable,
  locationDenied,
  locationUnavailable,
  photoAccessDenied,
  unexpected,
}
