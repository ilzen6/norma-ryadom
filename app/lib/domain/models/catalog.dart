import 'package:freezed_annotation/freezed_annotation.dart';

part 'catalog.freezed.dart';
part 'catalog.g.dart';

@JsonEnum(alwaysCreate: true)
enum SourceKind {
  @JsonValue('A')
  verified,
  @JsonValue('B')
  fromMenu,
  @JsonValue('C')
  estimate,
  unknown,
}

@JsonEnum(alwaysCreate: true)
enum FitLevel {
  @JsonValue('GOOD')
  good,
  @JsonValue('COMPROMISE')
  compromise,
  @JsonValue('NONE')
  none,
  unknown,
}

@JsonEnum(alwaysCreate: true)
enum DishCategory {
  @JsonValue('main')
  main,
  @JsonValue('side')
  side,
  @JsonValue('salad')
  salad,
  @JsonValue('drink')
  drink,
  @JsonValue('dessert')
  dessert,
  @JsonValue('sauce')
  sauce,
  unknown,
}

@JsonEnum(alwaysCreate: true)
enum Verdict {
  @JsonValue('FITS')
  fits,
  @JsonValue('PARTIAL')
  partial,
  @JsonValue('NOT_FITS')
  notFits,
  unknown,
}

@JsonEnum(alwaysCreate: true)
enum ReasonCode {
  @JsonValue('EXCLUDED_TAG')
  excludedTag,
  @JsonValue('KCAL_ABOVE')
  kcalAbove,
  @JsonValue('FAT_ABOVE')
  fatAbove,
  @JsonValue('CARBS_ABOVE')
  carbsAbove,
  @JsonValue('LOW_PROTEIN')
  lowProtein,
  @JsonValue('ESTIMATED_DATA')
  estimatedData,
  unknown,
}

@freezed
abstract class Nutrients with _$Nutrients {
  const factory Nutrients({required double kcal, required double protein, required double fat, required double carbs}) =
      _Nutrients;

  factory Nutrients.fromJson(Map<String, dynamic> json) => _$NutrientsFromJson(json);
}

@freezed
abstract class VenueSummary with _$VenueSummary {
  const factory VenueSummary({
    required int id,
    required String name,
    String? chainName,
    required String address,
    required double lat,
    required double lon,
    @Default('RUB') String currency,
    DateTime? confirmedOn,
  }) = _VenueSummary;

  factory VenueSummary.fromJson(Map<String, dynamic> json) => _$VenueSummaryFromJson(json);
}

@freezed
abstract class NearbyVenue with _$NearbyVenue {
  const factory NearbyVenue({
    required VenueSummary venue,
    required int distanceMeters,
    required bool hasMenu,
    @JsonKey(unknownEnumValue: FitLevel.unknown) FitLevel? fit,
  }) = _NearbyVenue;

  factory NearbyVenue.fromJson(Map<String, dynamic> json) => _$NearbyVenueFromJson(json);
}

@freezed
abstract class DataSource with _$DataSource {
  const factory DataSource({
    @JsonKey(unknownEnumValue: SourceKind.unknown) required SourceKind kind,
    String? url,
    DateTime? verifiedAt,
    double? kcalLow,
    double? kcalHigh,
  }) = _DataSource;

  factory DataSource.fromJson(Map<String, dynamic> json) => _$DataSourceFromJson(json);
}

@freezed
abstract class AssessmentReason with _$AssessmentReason {
  const factory AssessmentReason({
    @JsonKey(unknownEnumValue: ReasonCode.unknown) required ReasonCode code,
    double? amount,
    String? tag,
  }) = _AssessmentReason;

  factory AssessmentReason.fromJson(Map<String, dynamic> json) => _$AssessmentReasonFromJson(json);
}

@freezed
abstract class Assessment with _$Assessment {
  const factory Assessment({
    @JsonKey(unknownEnumValue: Verdict.unknown) required Verdict verdict,
    @Default(<AssessmentReason>[]) List<AssessmentReason> reasons,
  }) = _Assessment;

  factory Assessment.fromJson(Map<String, dynamic> json) => _$AssessmentFromJson(json);
}

@freezed
abstract class MenuItem with _$MenuItem {
  const factory MenuItem({
    required int id,
    required String name,
    @JsonKey(unknownEnumValue: DishCategory.unknown) required DishCategory category,
    double? portionGrams,
    required Nutrients nutrients,
    int? priceMinor,
    @Default(<String>[]) List<String> tags,
    required DataSource source,
    Assessment? assessment,
  }) = _MenuItem;

  factory MenuItem.fromJson(Map<String, dynamic> json) => _$MenuItemFromJson(json);
}

@freezed
abstract class VenueMenu with _$VenueMenu {
  const factory VenueMenu({required VenueSummary venue, @Default(<MenuItem>[]) List<MenuItem> items}) = _VenueMenu;

  factory VenueMenu.fromJson(Map<String, dynamic> json) => _$VenueMenuFromJson(json);
}

enum VenueReportReason {
  @JsonValue('closed')
  closed,
  @JsonValue('moved')
  moved,
  @JsonValue('not_found')
  notFound;

  String get code => switch (this) {
    VenueReportReason.closed => 'closed',
    VenueReportReason.moved => 'moved',
    VenueReportReason.notFound => 'not_found',
  };
}
