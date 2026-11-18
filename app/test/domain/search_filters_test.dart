import 'package:flutter_test/flutter_test.dart';
import 'package:norma_ryadom/domain/models/search_filters.dart';

void main() {
  test('без фастфуда ищет во всех видах, кроме бургерных, шаурмы и пиццерий', () {
    const filters = SearchFilters(hideFastFood: true);

    expect(filters.effectiveKinds, hasLength(12));
    expect(filters.effectiveKinds, isNot(contains(VenueKind.pizza)));
    expect(filters.effectiveKinds, isNot(contains(VenueKind.burger)));
    expect(filters.effectiveKinds, isNot(contains(VenueKind.shawarma)));
  });

  test('без выбранных видов и без «Скрыть фастфуд» не ограничивает виды', () {
    expect(const SearchFilters().effectiveKinds, isEmpty);
    expect(const SearchFilters().isDefault, isTrue);
  });

  test('выбор пиццерии снимает «Скрыть фастфуд»', () {
    final filters = const SearchFilters(hideFastFood: true).toggleKind(VenueKind.pizza);

    expect(filters.hideFastFood, isFalse);
    expect(filters.kinds, {VenueKind.pizza});
  });

  test('выбор кафе не снимает «Скрыть фастфуд»', () {
    final filters = const SearchFilters(hideFastFood: true).toggleKind(VenueKind.cafe);

    expect(filters.hideFastFood, isTrue);
    expect(filters.effectiveKinds, {VenueKind.cafe});
  });

  test('«Скрыть фастфуд» убирает уже выбранные виды фастфуда', () {
    final filters = const SearchFilters(
      kinds: {VenueKind.burger, VenueKind.georgian},
    ).withHiddenFastFood(hidden: true);

    expect(filters.kinds, {VenueKind.georgian});
  });

  test('повторное касание вида снимает выбор', () {
    final filters = const SearchFilters().toggleKind(VenueKind.sushi).toggleKind(VenueKind.sushi);

    expect(filters.kinds, isEmpty);
  });

  test('цена на правом краю шкалы означает «любая»', () {
    expect(const SearchFilters().withMaxPrice(2000).maxPriceRub, isNull);
    expect(const SearchFilters().withMaxPrice(799.6).maxPriceRub, 800);
  });

  test('«Дешевле» просит у сервера дешёвые наборы', () {
    expect(const SearchFilters(sort: ComboSort.cheapest).prefersCheaper, isTrue);
    expect(const SearchFilters(sort: ComboSort.nearest).prefersCheaper, isFalse);
  });

  test('сохраняется в JSON с кодами сервера и читается обратно', () {
    const filters = SearchFilters(
      sort: ComboSort.accurate,
      kinds: {VenueKind.centralAsian, VenueKind.readyFood},
      hideFastFood: true,
      maxPriceRub: 650,
    );

    final json = filters.toJson();

    expect(json['sort'], 'ACCURATE');
    expect(json['kinds'], unorderedEquals(['central-asian', 'ready-food']));
    expect(SearchFilters.fromJson(json), filters);
  });
}
