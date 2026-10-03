import 'package:flutter/widgets.dart';

import '../../domain/models/catalog.dart';
import '../../domain/models/diet_preference.dart';
import '../../domain/models/district.dart';
import '../../domain/models/meal.dart';
import '../../domain/models/profile.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../utils/result.dart';
import 'formatting.dart';

extension LocalizationsContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}

extension MealLabels on AppLocalizations {
  String meal(MealType meal) => switch (meal) {
    MealType.breakfast => mealBreakfast,
    MealType.lunch => mealLunch,
    MealType.dinner => mealDinner,
    MealType.snack => mealSnack,
  };

  String districtName(District district) => switch (district) {
    District.moscowCity => districtMoscowCity,
    District.tverskaya => districtTverskaya,
    District.arbat => districtArbat,
    District.chistyePrudy => districtChistyePrudy,
    District.kurskaya => districtKurskaya,
    District.belorusskaya => districtBelorusskaya,
    District.zelenograd => districtZelenograd,
    District.balashikha => districtBalashikha,
    District.dmitrov => districtDmitrov,
    District.dolgoprudny => districtDolgoprudny,
    District.domodedovo => districtDomodedovo,
    District.zhukovsky => districtZhukovsky,
    District.istra => districtIstra,
    District.kolomna => districtKolomna,
    District.korolev => districtKorolev,
    District.krasnogorsk => districtKrasnogorsk,
    District.lyubertsy => districtLyubertsy,
    District.mytishchi => districtMytishchi,
    District.noginsk => districtNoginsk,
    District.odintsovo => districtOdintsovo,
    District.podolsk => districtPodolsk,
    District.pushkino => districtPushkino,
    District.reutov => districtReutov,
    District.sergievPosad => districtSergievPosad,
    District.serpukhov => districtSerpukhov,
    District.khimki => districtKhimki,
    District.shchyolkovo => districtShchyolkovo,
    District.elektrostal => districtElektrostal,
    District.spbNevsky => districtSpbNevsky,
    District.spbPetrogradka => districtSpbPetrogradka,
    District.spbVasileostrovsky => districtSpbVasileostrovsky,
    District.spbMoskovsky => districtSpbMoskovsky,
    District.spbPushkin => districtSpbPushkin,
  };

  String region(DistrictRegion region) => switch (region) {
    DistrictRegion.moscow => regionMoscow,
    DistrictRegion.oblast => regionOblast,
    DistrictRegion.spb => regionSpb,
  };

  String district(District district) => switch (district.region) {
    DistrictRegion.spb => districtInRegion(region(district.region), districtName(district)),
    _ => districtName(district),
  };

  String preference(DietPreference preference) => switch (preference) {
    DietPreference.noPork => preferenceNoPork,
    DietPreference.vegetarian => preferenceVegetarian,
    DietPreference.noNuts => preferenceNoNuts,
    DietPreference.noMilk => preferenceNoMilk,
    DietPreference.noGluten => preferenceNoGluten,
  };

  String preferenceHint(DietPreference preference) => switch (preference) {
    DietPreference.noPork => preferenceHintNoPork,
    DietPreference.vegetarian => preferenceHintVegetarian,
    DietPreference.noNuts => preferenceHintNoNuts,
    DietPreference.noMilk => preferenceHintNoMilk,
    DietPreference.noGluten => preferenceHintNoGluten,
  };

  String activity(ActivityLevel level) => switch (level) {
    ActivityLevel.sedentary => activitySedentary,
    ActivityLevel.light => activityLight,
    ActivityLevel.moderate => activityModerate,
    ActivityLevel.high => activityHigh,
    ActivityLevel.veryHigh => activityVeryHigh,
  };

  String goal(Goal goal) => switch (goal) {
    Goal.lose => goalLose,
    Goal.maintain => goalMaintain,
    Goal.gain => goalGain,
  };

  String priceOf(int? priceMinor) => priceMinor == null ? priceUnknown : price(Formatting.rubles(priceMinor));

  String trust(SourceKind kind) => switch (kind) {
    SourceKind.verified => trustVerified,
    SourceKind.fromMenu => trustFromMenu,
    SourceKind.estimate => trustEstimate,
    SourceKind.unknown => trustUnknown,
  };

  String tag(String code) => switch (code) {
    'pork' => tagPork,
    'meat' || 'beef' || 'chicken' => tagMeat,
    'fish' => tagFish,
    'seafood' => tagSeafood,
    'nuts' => tagNuts,
    'milk' => tagMilk,
    'gluten' => tagGluten,
    _ => tagOther,
  };

  String failure(AppFailure failure) => switch (failure) {
    AppFailure.offline => errorOffline,
    AppFailure.notFound => errorNotFound,
    AppFailure.invalidRequest => errorInvalid,
    AppFailure.rateLimited => errorRateLimited,
    AppFailure.unsupportedPhoto => errorUnsupportedPhoto,
    AppFailure.photoTooLarge => errorPhotoTooLarge,
    AppFailure.serviceUnavailable => errorUnavailable,
    AppFailure.locationDenied => errorLocationDenied,
    AppFailure.locationUnavailable => errorLocationUnavailable,
    AppFailure.photoAccessDenied => errorPhotoAccessDenied,
    AppFailure.unexpected => errorUnexpected,
  };

  static const walkingMetersPerMinute = 75;

  static const walkingLimitMeters = 5000;

  String distance(int meters) => switch (meters) {
    < 1000 => distanceMeters(meters),
    < 100000 => distanceKilometers(Formatting.decimal((meters / 100).round() / 10)),
    _ => distanceKilometers(Formatting.integer(meters / 1000)),
  };

  int walkMinutesOf(int meters) => meters <= 0 ? 1 : (meters / walkingMetersPerMinute).ceil();

  String walk(int meters) =>
      meters > walkingLimitMeters ? distance(meters) : '${distance(meters)} · ${walkMinutes(walkMinutesOf(meters))}';

  String walkSemantics(int meters) =>
      meters > walkingLimitMeters ? distance(meters) : walkSpoken(distance(meters), walkMinutesOf(meters));
}
