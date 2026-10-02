package ru.normaryadom.optimizer

import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test
import ru.normaryadom.catalog.domain.DietTag
import ru.normaryadom.catalog.domain.DishCategory
import ru.normaryadom.catalog.domain.SourceKind
import ru.normaryadom.support.MenuTestData.criteria
import ru.normaryadom.support.MenuTestData.dish
import ru.normaryadom.support.MenuTestData.optimizer
import ru.normaryadom.support.MenuTestData.target

class ComboOptimizerTest {
    private val optimizer = optimizer()

    @Test
    fun `подбирает очевидный лучший набор на маленьком меню`() {
        val chicken = dish(1, kcal = 450.0, protein = 38.0, fat = 12.0, carbs = 40.0)
        val salad = dish(2, DishCategory.SALAD, kcal = 150.0, protein = 3.0, fat = 9.0, carbs = 9.0)
        val cola = dish(3, DishCategory.DRINK, kcal = 170.0, protein = 0.0, fat = 0.0, carbs = 42.0)
        val burger = dish(4, kcal = 680.0, protein = 41.0, fat = 39.0, carbs = 40.0)

        val combos = optimizer.bestCombos(listOf(chicken, salad, cola, burger), criteria(), limit = 5)

        assertThat(combos.first().dishIds).containsExactly(2, 1)
        assertThat(combos.first().totals.kcal).isEqualTo(600.0)
    }

    @Test
    fun `не предлагает блюда с исключёнными тегами`() {
        val pork = dish(1, kcal = 600.0, protein = 40.0, fat = 20.0, tags = setOf(DietTag.PORK, DietTag.MEAT))
        val chicken = dish(2, kcal = 560.0, protein = 35.0, fat = 15.0, tags = setOf(DietTag.CHICKEN, DietTag.MEAT))

        val combos = optimizer.bestCombos(listOf(pork, chicken), criteria(target(excluded = setOf(DietTag.PORK))), limit = 5)

        assertThat(combos.map { it.dishIds }).containsExactly(listOf(2L))
    }

    @Test
    fun `возвращает пустой список, когда ни один набор не попадает в цель`() {
        val tooSmall = dish(1, kcal = 100.0, protein = 5.0)

        assertThat(optimizer.bestCombos(listOf(tooSmall), criteria(), limit = 5)).isEmpty()
    }

    @Test
    fun `включает границы диапазона калорий`() {
        val lower = dish(1, kcal = 540.0, protein = 30.0, fat = 10.0, carbs = 40.0)
        val upper = dish(2, kcal = 660.0, protein = 30.0, fat = 10.0, carbs = 40.0)
        val outside = dish(3, kcal = 660.1, protein = 30.0, fat = 10.0, carbs = 40.0)

        val combos = optimizer.bestCombos(listOf(lower, upper, outside), criteria(), limit = 5)

        assertThat(combos.flatMap { it.dishIds }).containsExactlyInAnyOrder(1L, 2L)
    }

    @Test
    fun `соблюдает жёсткие ограничения по белку, жирам и углеводам`() {
        val lowProtein = dish(1, kcal = 600.0, protein = 29.0, fat = 10.0, carbs = 40.0)
        val fatty = dish(2, kcal = 600.0, protein = 30.0, fat = 25.1, carbs = 40.0)
        val sweet = dish(3, kcal = 600.0, protein = 30.0, fat = 10.0, carbs = 90.1)
        val fits = dish(4, kcal = 600.0, protein = 30.0, fat = 25.0, carbs = 90.0)

        val combos = optimizer.bestCombos(listOf(lowProtein, fatty, sweet, fits), criteria(), limit = 5)

        assertThat(combos.map { it.dishIds }).containsExactly(listOf(4L))
    }

    @Test
    fun `не кладёт в набор два основных блюда и два напитка`() {
        val mainA = dish(1, kcal = 300.0, protein = 20.0)
        val mainB = dish(2, kcal = 300.0, protein = 20.0)
        val drinkA = dish(3, DishCategory.DRINK, kcal = 100.0, protein = 5.0, fat = 0.0, carbs = 10.0)
        val drinkB = dish(4, DishCategory.DRINK, kcal = 100.0, protein = 5.0, fat = 0.0, carbs = 10.0)
        val sideA = dish(5, DishCategory.SIDE, kcal = 200.0, protein = 5.0, fat = 5.0, carbs = 30.0)

        val combos =
            optimizer.bestCombos(
                listOf(mainA, mainB, drinkA, drinkB, sideA),
                criteria(target(kcal = 500.0, tolerance = 100.0, minProtein = 20.0)),
                limit = 5,
            )

        assertThat(combos).isNotEmpty.allSatisfy { combo ->
            assertThat(combo.dishes.count { it.category == DishCategory.MAIN }).isLessThanOrEqualTo(1)
            assertThat(combo.dishes.count { it.category == DishCategory.DRINK }).isLessThanOrEqualTo(1)
        }
    }

    @Test
    fun `не предлагает соус без блюда, к которому он подаётся`() {
        val sauce = dish(1, DishCategory.SAUCE, kcal = 100.0, protein = 0.0, fat = 10.0, carbs = 2.0)
        val dessert = dish(2, DishCategory.DESSERT, kcal = 500.0, protein = 30.0, fat = 10.0, carbs = 40.0)
        val side = dish(3, DishCategory.SIDE, kcal = 500.0, protein = 30.0, fat = 10.0, carbs = 40.0)

        val combos = optimizer.bestCombos(listOf(sauce, dessert, side), criteria(), limit = 5)

        assertThat(combos.map { it.dishIds.toSet() }).contains(setOf(1L, 3L)).doesNotContain(setOf(1L, 2L))
    }

    @Test
    fun `повторяет одно блюдо в наборе не больше двух раз`() {
        val side = dish(1, DishCategory.SIDE, kcal = 200.0, protein = 10.0, fat = 5.0, carbs = 25.0)

        val threePortions = optimizer.bestCombos(listOf(side), criteria(target(kcal = 600.0, minProtein = 0.0)), limit = 5)
        val twoPortions = optimizer.bestCombos(listOf(side), criteria(target(kcal = 400.0, minProtein = 0.0)), limit = 5)

        assertThat(threePortions).isEmpty()
        assertThat(twoPortions.single().dishIds).containsExactly(1, 1)
    }

    @Test
    fun `показывает разные наборы, у которых не больше одного общего блюда`() {
        val main = dish(1, kcal = 300.0, protein = 30.0)
        val side = dish(2, DishCategory.SIDE, kcal = 150.0, protein = 3.0, fat = 4.0, carbs = 25.0)
        val drinks = (3L..7L).map { dish(it, DishCategory.DRINK, kcal = 140.0 + it, protein = 1.0, fat = 0.0, carbs = 10.0) }
        val salad = dish(8, DishCategory.SALAD, kcal = 290.0, protein = 3.0, fat = 9.0, carbs = 9.0)

        val combos = optimizer.bestCombos(listOf(main, side, salad) + drinks, criteria(), limit = 5)

        assertThat(combos).hasSizeGreaterThan(1)
        combos.forEachIndexed { index, first ->
            combos.drop(index + 1).forEach { second ->
                assertThat(ComboDiversifier.sharedDishes(first, second)).isLessThanOrEqualTo(1)
            }
        }
        assertThat(combos.count { it.dishIds.containsAll(listOf(1L, 2L)) }).isEqualTo(1)
    }

    @Test
    fun `ставит блюдо с проверенными данными выше оценки при равной близости к цели`() {
        val estimated = dish(1, kcal = 600.0, protein = 30.0, source = SourceKind.C)
        val verified = dish(2, kcal = 600.0, protein = 30.0, source = SourceKind.A)
        val fromMenu = dish(3, kcal = 600.0, protein = 30.0, source = SourceKind.B)

        val combos = optimizer.bestCombos(listOf(estimated, verified, fromMenu), criteria(), limit = 5)

        assertThat(combos.map { it.dishIds.single() }).containsExactly(2, 3, 1)
        assertThat(combos.map { it.sourceKind }).containsExactly(SourceKind.A, SourceKind.B, SourceKind.C)
    }

    @Test
    fun `возвращает не больше заданного числа наборов`() {
        val menu = (1L..20L).map { dish(it, kcal = 560.0 + it * 4, protein = 31.0) }

        assertThat(optimizer.bestCombos(menu, criteria(), limit = 3)).hasSize(3)
    }

    @Test
    fun `заменяет блюдо на той же позиции, сохраняя остальные`() {
        val main = dish(1, kcal = 400.0, protein = 30.0)
        val cola = dish(2, DishCategory.DRINK, kcal = 170.0, protein = 0.0, fat = 0.0, carbs = 42.0)
        val juice = dish(3, DishCategory.DRINK, kcal = 160.0, protein = 1.0, fat = 0.0, carbs = 38.0)
        val tea = dish(4, DishCategory.DRINK, kcal = 0.0, protein = 0.0, fat = 0.0, carbs = 0.0)
        val milkshake = dish(5, DishCategory.DRINK, kcal = 400.0, protein = 10.0, fat = 12.0, carbs = 54.0)

        val replacements = optimizer.replacements(listOf(main, cola, juice, tea, milkshake), criteria(), listOf(main, cola), 1, 5)

        assertThat(replacements.map { it.dishIds }).containsExactly(listOf(1L, 3L))
    }

    @Test
    fun `не предлагает замену, которая нарушает состав приёма пищи`() {
        val main = dish(1, kcal = 400.0, protein = 30.0)
        val drink = dish(2, DishCategory.DRINK, kcal = 180.0, protein = 1.0, fat = 0.0, carbs = 20.0)
        val otherMain = dish(3, kcal = 180.0, protein = 5.0)
        val side = dish(4, DishCategory.SIDE, kcal = 190.0, protein = 3.0, fat = 5.0, carbs = 30.0)

        val replacements = optimizer.replacements(listOf(main, drink, otherMain, side), criteria(), listOf(main, drink), 1, 5)

        assertThat(replacements.map { it.dishIds }).containsExactly(listOf(1L, 4L))
    }
}
