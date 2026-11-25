package ru.normaryadom.catalog.domain

enum class TasteTag(
    private val prefixes: List<String>,
    private val words: Set<String> = emptySet(),
    private val phrases: List<String> = emptyList(),
    private val categories: Set<DishCategory> = emptySet(),
    private val dietTags: Set<DietTag> = emptySet(),
    private val venueKinds: Set<VenueKind> = emptySet(),
) {
    SOUP(
        prefixes = listOf("суп", "борщ", "солянк", "окрошк", "рамен", "харчо", "лагман", "бульон", "шурп", "гаспачо", "минестрон"),
        words = setOf("щи", "уха", "фо"),
        phrases = listOf("том ям"),
    ),
    SALAD(
        prefixes = listOf("салат", "цезар", "винегрет", "оливье"),
        words = setOf("поке"),
        categories = setOf(DishCategory.SALAD),
    ),
    PORRIDGE(
        prefixes =
            listOf(
                "каш",
                "овсян",
                "гранол",
                "сырник",
                "омлет",
                "яичниц",
                "оладь",
                "творог",
                "йогурт",
                "мюсли",
                "скрэмбл",
                "глазунь",
                "панкейк",
                "завтрак",
                "блин",
            ),
    ),
    PASTRY(
        prefixes =
            listOf(
                "круассан",
                "пирог",
                "пирож",
                "булоч",
                "булк",
                "маффин",
                "чизкейк",
                "торт",
                "печень",
                "кекс",
                "эклер",
                "синнабон",
                "слойк",
                "десерт",
                "тирамису",
                "штрудел",
                "пончик",
                "выпечк",
                "вафл",
                "брауни",
                "ватрушк",
                "наполеон",
                "медовик",
            ),
        categories = setOf(DishCategory.DESSERT),
        venueKinds = setOf(VenueKind.BAKERY),
    ),
    FISH(
        prefixes =
            listOf(
                "рыб",
                "лосос",
                "семг",
                "форел",
                "тунец",
                "тунц",
                "треск",
                "сибас",
                "дорадо",
                "креветк",
                "кальмар",
                "миди",
                "судак",
                "минтай",
                "скумбри",
                "сельд",
                "палтус",
                "морепродукт",
            ),
        words = setOf("хек"),
        dietTags = setOf(DietTag.FISH, DietTag.SEAFOOD),
    ),
    GEORGIAN(
        prefixes =
            listOf(
                "хачапур",
                "хинкал",
                "пхали",
                "лобио",
                "чахохбил",
                "сациви",
                "чкмерул",
                "шкмерул",
                "аджапсандал",
                "харчо",
                "мцвади",
                "чашушул",
                "джонджол",
            ),
        venueKinds = setOf(VenueKind.GEORGIAN),
    ),
    ASIAN(
        prefixes = listOf("лапш", "рамен", "удон", "карри", "димсам", "гедз", "баоцз", "терияк", "кимчи", "бибимбап"),
        words = setOf("вок", "фо"),
        phrases = listOf("том ям", "пад тай"),
        venueKinds = setOf(VenueKind.ASIAN),
    ),
    PIZZA(
        prefixes = listOf("пицц"),
        venueKinds = setOf(VenueKind.PIZZA),
    ),
    BURGER(
        prefixes = listOf("бургер", "чизбургер", "гамбургер", "наггетс", "шаурм", "шаверм", "донер", "стрипс"),
        phrases = listOf("хот дог", "картофель фри"),
        venueKinds = setOf(VenueKind.BURGER, VenueKind.SHAWARMA),
    ),
    SUSHI(
        prefixes = listOf("суши", "ролл", "сашими", "гункан", "нигири", "филадельфи", "калифорни"),
        words = setOf("маки"),
        venueKinds = setOf(VenueKind.SUSHI),
    ),
    ;

    private fun named(
        tokens: List<String>,
        text: String,
    ): Boolean =
        tokens.any { token -> token in words || prefixes.any(token::startsWith) } ||
            phrases.any { text.contains(" $it ") }

    companion object {
        private val SEPARATORS = Regex("[^a-zа-я0-9]+")

        fun ofDish(
            name: String,
            category: DishCategory?,
            dietTags: Set<DietTag>,
        ): Set<TasteTag> {
            val tokens =
                name
                    .lowercase()
                    .replace('ё', 'е')
                    .split(SEPARATORS)
                    .filter(String::isNotEmpty)
            val text = " ${tokens.joinToString(" ")} "
            return entries.filterTo(LinkedHashSet()) { tag ->
                tag.named(tokens, text) || category in tag.categories || tag.dietTags.any(dietTags::contains)
            }
        }

        fun ofDish(item: MenuItem): Set<TasteTag> = ofDish(item.name, item.category, item.tags)

        fun ofVenue(kind: VenueKind?): Set<TasteTag> = entries.filterTo(LinkedHashSet()) { kind != null && kind in it.venueKinds }
    }
}
