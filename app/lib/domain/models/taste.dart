import 'package:freezed_annotation/freezed_annotation.dart';

import 'diary.dart';

enum TasteTag {
  @JsonValue('SOUP')
  soup(
    prefixes: ['суп', 'борщ', 'солянк', 'окрошк', 'рамен', 'харчо', 'лагман', 'бульон', 'шурп', 'гаспачо', 'минестрон'],
    words: {'щи', 'уха', 'фо'},
    phrases: ['том ям'],
  ),
  @JsonValue('SALAD')
  salad(prefixes: ['салат', 'цезар', 'винегрет', 'оливье'], words: {'поке'}, categories: {'salad'}),
  @JsonValue('PORRIDGE')
  porridge(
    prefixes: [
      'каш',
      'овсян',
      'гранол',
      'сырник',
      'омлет',
      'яичниц',
      'оладь',
      'творог',
      'йогурт',
      'мюсли',
      'скрэмбл',
      'глазунь',
      'панкейк',
      'завтрак',
      'блин',
    ],
  ),
  @JsonValue('PASTRY')
  pastry(
    prefixes: [
      'круассан',
      'пирог',
      'пирож',
      'булоч',
      'булк',
      'маффин',
      'чизкейк',
      'торт',
      'печень',
      'кекс',
      'эклер',
      'синнабон',
      'слойк',
      'десерт',
      'тирамису',
      'штрудел',
      'пончик',
      'выпечк',
      'вафл',
      'брауни',
      'ватрушк',
      'наполеон',
      'медовик',
    ],
    categories: {'dessert'},
    venueKinds: {'bakery'},
  ),
  @JsonValue('FISH')
  fish(
    prefixes: [
      'рыб',
      'лосос',
      'семг',
      'форел',
      'тунец',
      'тунц',
      'треск',
      'сибас',
      'дорадо',
      'креветк',
      'кальмар',
      'миди',
      'судак',
      'минтай',
      'скумбри',
      'сельд',
      'палтус',
      'морепродукт',
    ],
    words: {'хек'},
    dietTags: {'fish', 'seafood'},
  ),
  @JsonValue('GEORGIAN')
  georgian(
    prefixes: [
      'хачапур',
      'хинкал',
      'пхали',
      'лобио',
      'чахохбил',
      'сациви',
      'чкмерул',
      'шкмерул',
      'аджапсандал',
      'харчо',
      'мцвади',
      'чашушул',
      'джонджол',
    ],
    venueKinds: {'georgian'},
  ),
  @JsonValue('ASIAN')
  asian(
    prefixes: ['лапш', 'рамен', 'удон', 'карри', 'димсам', 'гедз', 'баоцз', 'терияк', 'кимчи', 'бибимбап'],
    words: {'вок', 'фо'},
    phrases: ['том ям', 'пад тай'],
    venueKinds: {'asian'},
  ),
  @JsonValue('PIZZA')
  pizza(prefixes: ['пицц'], venueKinds: {'pizza'}),
  @JsonValue('BURGER')
  burger(
    prefixes: ['бургер', 'чизбургер', 'гамбургер', 'наггетс', 'шаурм', 'шаверм', 'донер', 'стрипс'],
    phrases: ['хот дог', 'картофель фри'],
    venueKinds: {'burger', 'shawarma'},
  ),
  @JsonValue('SUSHI')
  sushi(
    prefixes: ['суши', 'ролл', 'сашими', 'гункан', 'нигири', 'филадельфи', 'калифорни'],
    words: {'маки'},
    venueKinds: {'sushi'},
  );

  const TasteTag({
    required this.prefixes,
    this.words = const {},
    this.phrases = const [],
    this.categories = const {},
    this.dietTags = const {},
    this.venueKinds = const {},
  });

  final List<String> prefixes;
  final Set<String> words;
  final List<String> phrases;
  final Set<String> categories;
  final Set<String> dietTags;
  final Set<String> venueKinds;

  String get code => name.toUpperCase();

  static final _separators = RegExp('[^a-zа-я0-9]+');

  static Set<TasteTag> ofDish(String name, {String? category, Iterable<String> tags = const []}) {
    final tokens = name
        .toLowerCase()
        .replaceAll('ё', 'е')
        .split(_separators)
        .where((token) => token.isNotEmpty)
        .toList();
    final text = ' ${tokens.join(' ')} ';
    final dietTags = tags.toSet();
    return {
      for (final taste in values)
        if (taste._named(tokens, text) || taste.categories.contains(category) || taste.dietTags.any(dietTags.contains))
          taste,
    };
  }

  static Set<TasteTag> ofVenueKind(String? kind) => {
    for (final taste in values)
      if (kind != null && taste.venueKinds.contains(kind)) taste,
  };

  bool _named(List<String> tokens, String text) =>
      tokens.any((token) => words.contains(token) || prefixes.any(token.startsWith)) ||
      phrases.any((phrase) => text.contains(' $phrase '));
}

abstract final class TasteLearning {
  static const days = 14;
  static const minTimes = 3;

  static Map<TasteTag, int> countByTaste(Iterable<DiaryEntry> entries) {
    final counts = <TasteTag, int>{};
    for (final entry in entries) {
      final tastes = {for (final dish in entry.title.split(' + ')) ...TasteTag.ofDish(dish)};
      for (final taste in tastes) {
        counts[taste] = (counts[taste] ?? 0) + 1;
      }
    }
    final sorted = counts.entries.toList()
      ..sort((left, right) {
        final byCount = right.value.compareTo(left.value);
        return byCount != 0 ? byCount : left.key.index.compareTo(right.key.index);
      });
    return Map.fromEntries(sorted);
  }

  static Set<TasteTag> learned(Map<TasteTag, int> counts) => {
    for (final MapEntry(:key, :value) in counts.entries)
      if (value >= minTimes) key,
  };
}
