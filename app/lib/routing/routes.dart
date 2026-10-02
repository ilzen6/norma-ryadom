abstract final class Routes {
  static const onboarding = '/onboarding';
  static const dataError = '/data-error';
  static const home = '/home';
  static const map = '/map';
  static const diary = '/diary';
  static const profile = '/profile';
  static const profileEdit = '/profile/edit';
  static const combo = '/combo';

  static String venue(int id) => '/venue/$id';
}
