import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';
import '../domain/nutrition/meal_planner.dart';
import '../domain/nutrition/norm_calculator.dart';
import 'local/app_database.dart';
import 'repositories/combo_repository.dart';
import 'repositories/diary_repository.dart';
import 'repositories/feedback_repository.dart';
import 'repositories/profile_repository.dart';
import 'repositories/venue_repository.dart';
import 'services/location_service.dart';
import 'services/norma_api.dart';
import 'services/photo_picker_service.dart';

final appConfigProvider = Provider<AppConfig>((ref) => AppConfig.fromEnvironment());

final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

final normCalculatorProvider = Provider<NormCalculator>((ref) => const NormCalculator());

final mealPlannerProvider = Provider<MealPlanner>((ref) => const MealPlanner());

final databaseProvider = Provider<AppDatabase>((ref) {
  final database = AppDatabase.onDevice();
  ref.onDispose(database.close);
  return database;
});

final normaApiProvider = Provider<NormaApi>(
  (ref) => NormaApi(NormaApi.createDio(ref.watch(appConfigProvider).apiBaseUrl)),
);

final profileRepositoryProvider = Provider<ProfileRepository>(
  (ref) => LocalProfileRepository(ref.watch(databaseProvider)),
);

final diaryRepositoryProvider = Provider<DiaryRepository>((ref) => LocalDiaryRepository(ref.watch(databaseProvider)));

final venueRepositoryProvider = Provider<VenueRepository>(
  (ref) =>
      RemoteVenueRepository(ref.watch(normaApiProvider), radiusMeters: ref.watch(appConfigProvider).searchRadiusMeters),
);

final comboRepositoryProvider = Provider<ComboRepository>(
  (ref) =>
      RemoteComboRepository(ref.watch(normaApiProvider), radiusMeters: ref.watch(appConfigProvider).searchRadiusMeters),
);

final feedbackRepositoryProvider = Provider<FeedbackRepository>(
  (ref) => RemoteFeedbackRepository(ref.watch(normaApiProvider)),
);

final locationServiceProvider = Provider<LocationService>((ref) => const DeviceLocationService());

final photoPickerProvider = Provider<PhotoPickerService>((ref) => DevicePhotoPickerService());
