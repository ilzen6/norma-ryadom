package ru.normaryadom.optimizer

import org.assertj.core.api.Assertions.assertThat
import org.assertj.core.api.Assertions.within
import org.junit.jupiter.api.Test
import ru.normaryadom.catalog.domain.SourceKind
import ru.normaryadom.support.MenuTestData.WEIGHTS
import ru.normaryadom.support.MenuTestData.criteria
import ru.normaryadom.support.MenuTestData.dish
import ru.normaryadom.support.MenuTestData.scorer
import ru.normaryadom.support.MenuTestData.target

class ComboScorerTest {
    private val scorer = scorer()

    @Test
    fun `считает сумму КБЖУ, цену и худший уровень доверия набора`() {
        val combo =
            scorer.combo(
                listOf(
                    dish(1, kcal = 400.0, protein = 30.0, priceMinor = 25_000),
                    dish(2, kcal = 200.0, protein = 5.0, source = SourceKind.B),
                ),
                criteria(),
            )

        assertThat(combo.totals.kcal).isEqualTo(600.0)
        assertThat(combo.totals.protein).isEqualTo(35.0)
        assertThat(combo.priceMinor).isEqualTo(55_000)
        assertThat(combo.sourceKind).isEqualTo(SourceKind.B)
    }

    @Test
    fun `не знает цену набора, если у одного из блюд нет цены`() {
        val combo = scorer.combo(listOf(dish(1, priceMinor = 25_000), dish(2, priceMinor = null)), criteria())

        assertThat(combo.priceMinor).isNull()
    }

    @Test
    fun `штрафует отклонение по калориям пропорционально допуску`() {
        val exact = scorer.combo(listOf(dish(1, kcal = 600.0, protein = 30.0)), criteria())
        val off = scorer.combo(listOf(dish(2, kcal = 630.0, protein = 30.0)), criteria())

        assertThat(off.score - exact.score).isCloseTo(0.5 * 1.0, within(1e-9))
    }

    @Test
    fun `предпочитает больше белка при прочих равных`() {
        val lean = scorer.combo(listOf(dish(1, kcal = 600.0, protein = 45.0)), criteria())
        val regular = scorer.combo(listOf(dish(2, kcal = 600.0, protein = 30.0)), criteria())

        assertThat(lean.score).isLessThan(regular.score)
    }

    @Test
    fun `учитывает цену только при включённом выборе подешевле`() {
        val cheap = listOf(dish(1, kcal = 600.0, protein = 30.0, priceMinor = 20_000))
        val expensive = listOf(dish(2, kcal = 600.0, protein = 30.0, priceMinor = 60_000))
        val ignore = criteria()
        val cheaper = criteria(price = PricePreference.PREFER_CHEAPER)

        assertThat(scorer.combo(cheap, ignore).score).isEqualTo(scorer.combo(expensive, ignore).score)
        assertThat(scorer.combo(cheap, cheaper).score).isLessThan(scorer.combo(expensive, cheaper).score)
        assertThat(PricePreference.PREFER_CHEAPER.penalty(null, WEIGHTS)).isEqualTo(0.5)
    }

    @Test
    fun `не штрафует белок и макросы при нулевых ограничениях`() {
        val target = target(minProtein = 0.0, maxFat = 0.0, maxCarbs = 0.0)
        val score = scorer.combo(listOf(dish(1, kcal = 600.0, protein = 0.0, fat = 0.0, carbs = 0.0)), criteria(target)).score

        assertThat(score).isZero()
    }
}
