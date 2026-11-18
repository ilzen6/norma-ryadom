import 'package:freezed_annotation/freezed_annotation.dart';

part 'search_filters.freezed.dart';
part 'search_filters.g.dart';

enum ComboSort {
  @JsonValue('RECOMMENDED')
  recommended('RECOMMENDED'),
  @JsonValue('NEAREST')
  nearest('NEAREST'),
  @JsonValue('CHEAPEST')
  cheapest('CHEAPEST'),
  @JsonValue('ACCURATE')
  accurate('ACCURATE');

  const ComboSort(this.code);

  final String code;
}

enum VenueKind {
  @JsonValue('cafe')
  cafe('cafe'),
  @JsonValue('coffee')
  coffee('coffee'),
  @JsonValue('georgian')
  georgian('georgian'),
  @JsonValue('asian')
  asian('asian'),
  @JsonValue('canteen')
  canteen('canteen'),
  @JsonValue('bakery')
  bakery('bakery'),
  @JsonValue('central-asian')
  centralAsian('central-asian'),
  @JsonValue('italian')
  italian('italian'),
  @JsonValue('sushi')
  sushi('sushi'),
  @JsonValue('blini')
  blini('blini'),
  @JsonValue('bar')
  bar('bar'),
  @JsonValue('ready-food')
  readyFood('ready-food'),
  @JsonValue('pizza')
  pizza('pizza', fastFood: true),
  @JsonValue('burger')
  burger('burger', fastFood: true),
  @JsonValue('shawarma')
  shawarma('shawarma', fastFood: true);

  const VenueKind(this.code, {this.fastFood = false});

  final String code;
  final bool fastFood;
}

@freezed
abstract class SearchFilters with _$SearchFilters {
  const SearchFilters._();

  const factory SearchFilters({
    @Default(ComboSort.recommended) ComboSort sort,
    @Default(<VenueKind>{}) Set<VenueKind> kinds,
    @Default(false) bool hideFastFood,
    int? maxPriceRub,
  }) = _SearchFilters;

  factory SearchFilters.fromJson(Map<String, dynamic> json) => _$SearchFiltersFromJson(json);

  static const minPriceRub = 200;
  static const maxPriceRubLimit = 2000;
  static const priceStepRub = 50;

  bool get isDefault => this == const SearchFilters();

  bool get prefersCheaper => sort == ComboSort.cheapest;

  Set<VenueKind> get effectiveKinds => switch ((hideFastFood, kinds.isEmpty)) {
    (true, true) => {
      for (final kind in VenueKind.values)
        if (!kind.fastFood) kind,
    },
    (true, false) => {
      for (final kind in kinds)
        if (!kind.fastFood) kind,
    },
    (false, _) => kinds,
  };

  SearchFilters toggleKind(VenueKind kind) {
    final selected = kinds.contains(kind);
    return copyWith(
      kinds: selected ? ({...kinds}..remove(kind)) : {...kinds, kind},
      hideFastFood: hideFastFood && (selected || !kind.fastFood),
    );
  }

  SearchFilters withHiddenFastFood({required bool hidden}) => copyWith(
    hideFastFood: hidden,
    kinds: hidden
        ? {
            for (final kind in kinds)
              if (!kind.fastFood) kind,
          }
        : kinds,
  );

  SearchFilters withMaxPrice(double rubles) =>
      copyWith(maxPriceRub: rubles >= maxPriceRubLimit ? null : rubles.round());
}
