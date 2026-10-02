package ru.normaryadom.recommendation

import org.assertj.core.api.Assertions.assertThat
import org.assertj.core.api.Assertions.assertThatThrownBy
import org.junit.jupiter.api.Test
import ru.normaryadom.catalog.domain.DietTag
import ru.normaryadom.optimizer.PricePreference
import ru.normaryadom.recommendation.api.IncompleteTargetException
import ru.normaryadom.recommendation.api.MealTargetQuery

class MealTargetQueryTest {
    @Test
    fun `без параметров цели возвращает отсутствие цели`() {
        assertThat(MealTargetQuery().toCriteriaOrNull()).isNull()
    }

    @Test
    fun `собирает цель из всех параметров`() {
        val criteria = MealTargetQuery(600.0, 60.0, 30.0, 25.0, 90.0, setOf(DietTag.NUTS)).toCriteriaOrNull()

        assertThat(criteria?.target?.maxKcal).isEqualTo(660.0)
        assertThat(criteria?.target?.excludedTags).containsExactly(DietTag.NUTS)
        assertThat(criteria?.pricePreference).isEqualTo(PricePreference.IGNORE)
    }

    @Test
    fun `требует все параметры, если задан хотя бы один`() {
        assertThatThrownBy { MealTargetQuery(kcal = 600.0, maxFat = 20.0).toCriteriaOrNull() }
            .isInstanceOfSatisfying(IncompleteTargetException::class.java) {
                assertThat(it.missingParameters).containsExactly("kcalTolerance", "maxCarbs", "minProtein")
            }
        assertThatThrownBy { MealTargetQuery(excludeTags = setOf(DietTag.PORK)).toCriteriaOrNull() }
            .isInstanceOf(IncompleteTargetException::class.java)
    }
}
