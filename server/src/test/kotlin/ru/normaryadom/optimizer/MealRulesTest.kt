package ru.normaryadom.optimizer

import org.assertj.core.api.Assertions.assertThat
import org.assertj.core.api.Assertions.assertThatThrownBy
import org.junit.jupiter.api.Test
import ru.normaryadom.catalog.domain.DietTag
import ru.normaryadom.catalog.domain.DishCategory
import ru.normaryadom.catalog.domain.Nutrients
import ru.normaryadom.support.MenuTestData.dish
import ru.normaryadom.support.MenuTestData.target

class MealRulesTest {
    @Test
    fun `разрешает соус вместе с гарниром, салатом или основным блюдом`() {
        val sauce = dish(1, DishCategory.SAUCE)

        listOf(DishCategory.MAIN, DishCategory.SIDE, DishCategory.SALAD).forEach { carrier ->
            assertThat(MealStructure.isValid(listOf(sauce, dish(2, carrier)))).isTrue()
        }
        assertThat(MealStructure.isValid(listOf(sauce, dish(2, DishCategory.DRINK)))).isFalse()
        assertThat(MealStructure.isValid(listOf(sauce, dish(2, DishCategory.SAUCE), dish(3)))).isFalse()
    }

    @Test
    fun `не считает пустой набор приёмом пищи`() {
        assertThat(MealStructure.isValid(emptyList())).isFalse()
    }

    @Test
    fun `проверяет ограничения цели с учётом погрешности вычислений`() {
        val target = target(kcal = 600.0, tolerance = 60.0, minProtein = 0.3, maxFat = 0.3, maxCarbs = 0.3)

        assertThat(target.isSatisfiedBy(Nutrients(540.0, 0.1 + 0.2, 0.1 + 0.2, 0.1 + 0.2))).isTrue()
        assertThat(target.isSatisfiedBy(Nutrients(539.9, 1.0, 0.0, 0.0))).isFalse()
    }

    @Test
    fun `ослабляет цель по коэффициентам для жёлтой отметки`() {
        val relaxed = target().relaxed(TargetRelaxation(kcalToleranceFactor = 2.0, proteinFactor = 0.8, limitFactor = 1.2))

        assertThat(relaxed.kcalTolerance).isEqualTo(120.0)
        assertThat(relaxed.minProtein).isEqualTo(24.0)
        assertThat(relaxed.maxFat).isEqualTo(30.0)
        assertThat(relaxed.maxCarbs).isEqualTo(108.0)
    }

    @Test
    fun `не допускает некорректную цель`() {
        assertThatThrownBy { target(kcal = 0.0) }.isInstanceOf(IllegalArgumentException::class.java)
        assertThatThrownBy { target(tolerance = 0.0) }.isInstanceOf(IllegalArgumentException::class.java)
        assertThatThrownBy { target(maxFat = -1.0) }.isInstanceOf(IllegalArgumentException::class.java)
    }

    @Test
    fun `исключает блюдо по любому из тегов`() {
        val target = target(excluded = setOf(DietTag.NUTS, DietTag.PORK))

        assertThat(target.allows(dish(1, tags = setOf(DietTag.MILK)))).isTrue()
        assertThat(target.allows(dish(2, tags = setOf(DietTag.MILK, DietTag.NUTS)))).isFalse()
    }

    @Test
    fun `объясняет каждый показатель набора относительно цели`() {
        val checks = ComboExplanation.explain(Nutrients(kcal = 700.0, protein = 28.0, fat = 17.0, carbs = 60.0), target(maxFat = 15.0))

        assertThat(checks.map { it.metric to it.status }).containsExactly(
            Metric.KCAL to MetricStatus.ABOVE,
            Metric.PROTEIN to MetricStatus.BELOW,
            Metric.FAT to MetricStatus.ABOVE,
            Metric.CARBS to MetricStatus.OK,
        )
        assertThat(checks.first { it.metric == Metric.FAT }.delta).isEqualTo(2.0)
        assertThat(ComboExplanation.explain(Nutrients(500.0, 30.0, 10.0, 10.0), target()).first().status).isEqualTo(MetricStatus.BELOW)
    }

    @Test
    fun `не создаёт настройки и веса с некорректными значениями`() {
        assertThatThrownBy { OptimizerSettings(maxItems = 0, heapFactor = 4) }.isInstanceOf(IllegalArgumentException::class.java)
        assertThatThrownBy { OptimizerSettings(maxItems = 3, heapFactor = 0) }.isInstanceOf(IllegalArgumentException::class.java)
        assertThatThrownBy { ScoreWeights(1.0, 1.0, 1.0, 1.0, 0.1, 0.5, 0.5, 0.0) }.isInstanceOf(IllegalArgumentException::class.java)
    }
}
