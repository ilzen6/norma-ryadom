package ru.normaryadom.optimizer

import net.jqwik.api.Arbitraries
import net.jqwik.api.Arbitrary
import net.jqwik.api.Combinators
import net.jqwik.api.ForAll
import net.jqwik.api.Property
import net.jqwik.api.Provide
import org.assertj.core.api.Assertions.assertThat
import ru.normaryadom.catalog.domain.DietTag
import ru.normaryadom.catalog.domain.DishCategory
import ru.normaryadom.catalog.domain.MenuItem
import ru.normaryadom.catalog.domain.SourceKind
import ru.normaryadom.support.MenuTestData

class ComboOptimizerPropertiesTest {
    private val optimizer = MenuTestData.optimizer()
    private val scorer = MenuTestData.scorer()

    @Property(tries = 300)
    fun `каждый возвращённый набор удовлетворяет всем жёстким ограничениям`(
        @ForAll("menus") menu: List<MenuItem>,
        @ForAll("criteria") criteria: SearchCriteria,
    ) {
        optimizer.bestCombos(menu, criteria, LIMIT).forEach { combo ->
            assertThat(criteria.target.isSatisfiedBy(combo.totals)).isTrue()
            assertThat(MealStructure.isValid(combo.dishes)).isTrue()
            assertThat(combo.dishes.size).isLessThanOrEqualTo(MenuTestData.SETTINGS.maxItems)
        }
    }

    @Property(tries = 300)
    fun `ни один набор не содержит исключённых тегов`(
        @ForAll("menus") menu: List<MenuItem>,
        @ForAll("criteria") criteria: SearchCriteria,
    ) {
        val tags = optimizer.bestCombos(menu, criteria, LIMIT).flatMap { combo -> combo.dishes.flatMap { it.tags } }

        assertThat(tags.intersect(criteria.target.excludedTags)).isEmpty()
    }

    @Property(tries = 300)
    fun `наборы отсортированы по оценке и не повторяют больше одного блюда`(
        @ForAll("menus") menu: List<MenuItem>,
        @ForAll("criteria") criteria: SearchCriteria,
    ) {
        val combos = optimizer.bestCombos(menu, criteria, LIMIT)

        assertThat(combos).isSortedAccordingTo(Combo.ORDER)
        assertThat(combos.size).isLessThanOrEqualTo(LIMIT)
        combos.forEachIndexed { index, first ->
            combos.drop(index + 1).forEach { second ->
                assertThat(ComboDiversifier.sharedDishes(first, second)).isLessThanOrEqualTo(ComboDiversifier.MAX_SHARED_DISHES)
            }
        }
    }

    @Property(tries = 200)
    fun `перебор с отсечением даёт тот же ответ, что полный перебор`(
        @ForAll("menus") menu: List<MenuItem>,
        @ForAll("criteria") criteria: SearchCriteria,
    ) {
        val expected = bruteForce(menu, criteria)

        assertThat(optimizer.bestCombos(menu, criteria, LIMIT)).isEqualTo(expected)
    }

    @Provide
    fun menus(): Arbitrary<List<MenuItem>> =
        dishes().list().ofSize(MENU_SIZE).map { generated ->
            generated.mapIndexed { index, dish -> dish.copy(id = index + 1L, name = "Блюдо ${index + 1}") }
        }

    @Provide
    fun criteria(): Arbitrary<SearchCriteria> =
        Combinators
            .combine(
                Arbitraries.integers().between(250, 900),
                Arbitraries.integers().between(30, 150),
                Arbitraries.integers().between(0, 40),
                Arbitraries.integers().between(10, 60),
                Arbitraries.integers().between(30, 140),
                Arbitraries.of(DietTag::class.java).set().ofMaxSize(3),
                Arbitraries.of(PricePreference::class.java),
            ).`as` { kcal, tolerance, protein, fat, carbs, excluded, price ->
                SearchCriteria(
                    MealTarget(kcal.toDouble(), tolerance.toDouble(), protein.toDouble(), fat.toDouble(), carbs.toDouble(), excluded),
                    price,
                )
            }

    private fun dishes(): Arbitrary<MenuItem> =
        Combinators
            .combine(
                Arbitraries.of(DishCategory::class.java),
                Arbitraries.integers().between(0, 700),
                Arbitraries.integers().between(0, 45),
                Arbitraries.integers().between(0, 35),
                Arbitraries.integers().between(0, 90),
                Arbitraries.integers().between(5_000, 60_000).injectNull(0.1),
                Arbitraries.of(DietTag::class.java).set().ofMaxSize(2),
                Arbitraries.of(SourceKind::class.java),
            ).`as` { category, kcal, protein, fat, carbs, price, tags, source ->
                MenuTestData.dish(
                    id = 0,
                    category = category,
                    kcal = kcal.toDouble(),
                    protein = protein.toDouble(),
                    fat = fat.toDouble(),
                    carbs = carbs.toDouble(),
                    priceMinor = price,
                    tags = tags,
                    source = source,
                )
            }

    private fun bruteForce(
        menu: List<MenuItem>,
        criteria: SearchCriteria,
    ): List<Combo> {
        val allowed = menu.filter(criteria.target::allows).sortedWith(compareBy<MenuItem>({ it.nutrients.kcal }, { it.id }))
        val candidates = mutableListOf<List<MenuItem>>()
        for (first in allowed.indices) {
            candidates += listOf(allowed[first])
            for (second in first until allowed.size) {
                candidates += listOf(allowed[first], allowed[second])
                for (third in second until allowed.size) {
                    candidates += listOf(allowed[first], allowed[second], allowed[third])
                }
            }
        }
        val ranked =
            candidates
                .filter(MealStructure::isValid)
                .map { scorer.combo(it, criteria) }
                .filter { criteria.target.isSatisfiedBy(it.totals) }
                .sortedWith(Combo.ORDER)
                .take(LIMIT * MenuTestData.SETTINGS.heapFactor)
        return ComboDiversifier.diversify(ranked, LIMIT)
    }

    private companion object {
        const val LIMIT = 5
        const val MENU_SIZE = 30
    }
}
