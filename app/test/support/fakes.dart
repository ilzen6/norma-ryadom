import 'dart:async';

import 'package:norma_ryadom/data/repositories/combo_repository.dart';
import 'package:norma_ryadom/data/repositories/diary_repository.dart';
import 'package:norma_ryadom/data/repositories/feedback_repository.dart';
import 'package:norma_ryadom/data/repositories/profile_repository.dart';
import 'package:norma_ryadom/data/repositories/settings_repository.dart';
import 'package:norma_ryadom/data/repositories/venue_repository.dart';
import 'package:norma_ryadom/data/services/location_service.dart';
import 'package:norma_ryadom/data/services/norma_api.dart';
import 'package:norma_ryadom/data/services/photo_picker_service.dart';
import 'package:norma_ryadom/domain/models/catalog.dart';
import 'package:norma_ryadom/domain/models/combo.dart';
import 'package:norma_ryadom/domain/models/diary.dart';
import 'package:norma_ryadom/domain/models/geo_location.dart';
import 'package:norma_ryadom/domain/models/meal.dart';
import 'package:norma_ryadom/domain/models/profile.dart';
import 'package:norma_ryadom/utils/result.dart';

class InMemoryProfileRepository implements ProfileRepository {
  InMemoryProfileRepository([this.profile]);

  UserProfile? profile;
  bool deleted = false;
  Exception? loadError;

  @override
  Future<UserProfile?> load() async {
    final error = loadError;
    if (error != null) throw error;
    return profile;
  }

  @override
  Future<void> save(UserProfile profile) async => this.profile = profile;

  @override
  Future<void> deleteAllData() async {
    profile = null;
    loadError = null;
    deleted = true;
  }
}

class InMemoryDiaryRepository implements DiaryRepository {
  final List<DiaryEntry> entries = [];
  final _changes = StreamController<void>.broadcast();
  int _nextId = 1;
  Exception? writeError;
  Completer<void>? gate;

  @override
  Stream<List<DiaryEntry>> watchDay(DateTime day) => _watch(
    () => entries.where((entry) => LocalDiaryRepository.dayKey(entry.day) == LocalDiaryRepository.dayKey(day)).toList(),
  );

  @override
  Stream<List<DiaryEntry>> watchQuickAdd({int limit = 10}) => _watch(() {
    final sorted = [...entries]
      ..sort((a, b) {
        if (a.favorite != b.favorite) return a.favorite ? -1 : 1;
        return b.createdAt.compareTo(a.createdAt);
      });
    final seen = <String>{};
    return sorted.where((entry) => seen.add(entry.title)).take(limit).toList();
  });

  @override
  Future<void> add(NewDiaryEntry entry, DateTime now) async {
    final error = writeError;
    if (error != null) throw error;
    await gate?.future;
    entries.add(
      DiaryEntry(
        id: _nextId++,
        day: now,
        meal: entry.meal,
        title: entry.title,
        venueName: entry.venueName,
        intake: entry.intake,
        createdAt: now,
      ),
    );
    _changes.add(null);
  }

  @override
  Future<void> remove(int id) async {
    entries.removeWhere((entry) => entry.id == id);
    _changes.add(null);
  }

  @override
  Future<void> setFavorite(int id, {required bool favorite}) async {
    final index = entries.indexWhere((entry) => entry.id == id);
    entries[index] = entries[index].copyWith(favorite: favorite);
    _changes.add(null);
  }

  Stream<List<DiaryEntry>> _watch(List<DiaryEntry> Function() query) async* {
    yield query();
    await for (final _ in _changes.stream) {
      yield query();
    }
  }
}

class InMemorySettingsRepository implements SettingsRepository {
  String? address;

  @override
  Future<String?> serverAddress() async => address;

  @override
  Future<void> saveServerAddress(String address) async => this.address = address;
}

class FakeServerProbe {
  Result<void> result = const Ok(null);
  final List<String> checked = [];

  Future<Result<void>> call(String address) async {
    checked.add(address);
    return result;
  }
}

class FakeComboRepository implements ComboRepository {
  Result<ComboSearchResult> nearbyResult = const Ok(ComboSearchResult(appliedTarget: TestData.lunchTarget));
  Result<ComboSearchResult> venueResult = const Ok(ComboSearchResult(appliedTarget: TestData.lunchTarget));
  Result<ComboSearchResult> replaceResult = const Ok(ComboSearchResult(appliedTarget: TestData.lunchTarget));
  final List<MealTarget> requestedTargets = [];
  final List<PricePreference> requestedPrices = [];
  final List<GeoLocation> requestedLocations = [];
  final List<int> requestedVenues = [];
  final List<(List<int>, int)> replaceRequests = [];
  final List<MealTarget> replaceTargets = [];
  Completer<void>? gate;

  @override
  Future<Result<ComboSearchResult>> nearby({
    required GeoLocation location,
    required MealTarget target,
    required PricePreference price,
  }) async {
    requestedTargets.add(target);
    requestedPrices.add(price);
    requestedLocations.add(location);
    final result = nearbyResult;
    await gate?.future;
    return result;
  }

  @override
  Future<Result<ComboSearchResult>> atVenue({
    required int venueId,
    required MealTarget target,
    required PricePreference price,
  }) async {
    requestedTargets.add(target);
    requestedPrices.add(price);
    requestedVenues.add(venueId);
    return venueResult;
  }

  @override
  Future<Result<ComboSearchResult>> replace({
    required int venueId,
    required MealTarget target,
    required List<int> dishIds,
    required int replaceIndex,
    required PricePreference price,
  }) async {
    replaceRequests.add((dishIds, replaceIndex));
    replaceTargets.add(target);
    requestedVenues.add(venueId);
    return replaceResult;
  }
}

class FakeVenueRepository implements VenueRepository {
  Result<List<NearbyVenue>> nearbyResult = const Ok([]);
  final requestedRadii = <int?>[];
  final requestedCenters = <GeoLocation>[];
  Result<VenueMenu> menuResult = const Err(AppFailure.notFound);
  final List<bool> includeWithoutMenuRequests = [];

  @override
  Future<Result<List<NearbyVenue>>> nearby({
    required GeoLocation location,
    required MealTarget target,
    required bool includeWithoutMenu,
    int? radiusMeters,
    int? limit,
  }) async {
    includeWithoutMenuRequests.add(includeWithoutMenu);
    requestedRadii.add(radiusMeters);
    requestedCenters.add(location);
    return nearbyResult;
  }

  @override
  Future<Result<VenueMenu>> menu(int venueId, MealTarget target) async => menuResult;
}

class FakeFeedbackRepository implements FeedbackRepository {
  Result<SubmissionReceipt> photoResult = const Ok(SubmissionReceipt(submissionId: 1));
  Result<void> reportResult = const Ok(null);
  final List<(int, String)> reports = [];
  final List<(int, PickedPhoto)> photos = [];
  final List<(int, VenueReportReason)> venueReports = [];
  Completer<void>? gate;

  @override
  Future<Result<SubmissionReceipt>> sendMenuPhoto(int venueId, PickedPhoto photo) async {
    photos.add((venueId, photo));
    await gate?.future;
    return photoResult;
  }

  @override
  Future<Result<void>> reportItem(int itemId, String reason) async {
    reports.add((itemId, reason));
    return reportResult;
  }

  @override
  Future<Result<void>> reportVenue(int venueId, VenueReportReason reason) async {
    venueReports.add((venueId, reason));
    return reportResult;
  }
}

class FakeLocationService implements LocationService {
  FakeLocationService([this.result = const Ok(TestData.deviceLocation)]);

  Result<GeoLocation> result;
  int calls = 0;

  @override
  Future<Result<GeoLocation>> currentLocation() async {
    calls++;
    return result;
  }
}

class FakePhotoPicker implements PhotoPickerService {
  Result<PickedPhoto?> result = const Ok(PickedPhoto(bytes: [0x89, 0x50, 0x4E, 0x47], fileName: 'menu.png'));
  final List<PhotoSource> sources = [];

  @override
  Future<Result<PickedPhoto?>> pick(PhotoSource source) async {
    sources.add(source);
    return result;
  }
}

abstract final class TestData {
  static const deviceLocation = GeoLocation(lat: 55.75, lon: 37.54, source: LocationSource.device);

  static const lunchTarget = MealTarget(
    kcal: 630,
    kcalTolerance: 63,
    minProtein: 27.7,
    maxFat: 23.5,
    maxCarbs: 94.5,
    excludeTags: ['pork'],
  );

  static const profile = UserProfile(
    sex: Sex.female,
    age: 25,
    heightCm: 165,
    weightKg: 62,
    activity: ActivityLevel.moderate,
    goal: Goal.lose,
    locationConsent: true,
  );

  static const venue = VenueSummary(
    id: 7,
    name: 'Гриль Хаус, Москва-Сити',
    chainName: 'Гриль Хаус',
    address: 'Пресненская наб., 2',
    lat: 55.7496,
    lon: 37.5397,
  );

  static Dish dish(int id, String name, double kcal, {DishCategory category = DishCategory.main}) => Dish(
    id: id,
    name: name,
    category: category,
    nutrients: Nutrients(kcal: kcal, protein: kcal / 15, fat: kcal / 30, carbs: kcal / 8),
    priceMinor: 25000,
    sourceKind: SourceKind.verified,
  );

  static ComboOption option(List<Dish> dishes, {int distance = 145, VenueSummary venue = TestData.venue}) {
    final kcal = dishes.fold<double>(0, (sum, dish) => sum + dish.nutrients.kcal);
    return ComboOption(
      venue: venue,
      distanceMeters: distance,
      combo: Combo(
        dishes: dishes,
        totals: Nutrients(kcal: kcal, protein: 40, fat: 18, carbs: 70),
        priceMinor: 53700,
        sourceKind: SourceKind.verified,
        score: 0.5,
        checks: [
          MetricCheck(metric: Metric.kcal, value: kcal, goal: 630, delta: kcal - 630, status: MetricStatus.ok),
          const MetricCheck(metric: Metric.protein, value: 40, goal: 28, delta: 12, status: MetricStatus.ok),
          const MetricCheck(metric: Metric.fat, value: 26, goal: 24, delta: 2, status: MetricStatus.above),
          const MetricCheck(metric: Metric.carbs, value: 70, goal: 95, delta: -25, status: MetricStatus.ok),
        ],
      ),
    );
  }
}
