package ru.normaryadom.recommendation

import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test
import ru.normaryadom.catalog.domain.DietTag
import ru.normaryadom.catalog.domain.DishCategory
import ru.normaryadom.catalog.domain.SourceKind
import ru.normaryadom.support.MenuTestData.criteria
import ru.normaryadom.support.MenuTestData.dish
import ru.normaryadom.support.MenuTestData.scorer
import ru.normaryadom.support.MenuTestData.target

class DishAssessorTest {
    private val assessor = DishAssessor(scorer())

    @Test
    fun `помечает подходящее блюдо без причин`() {
        val assessment = assessor.assess(dish(1, kcal = 500.0, protein = 35.0, fat = 15.0, carbs = 40.0), criteria())

        assertThat(assessment.verdict).isEqualTo(Verdict.FITS)
        assertThat(assessment.reasons).isEmpty()
    }

    @Test
    fun `не подходит блюдо с исключённым тегом или жиром выше цели`() {
        val pork = assessor.assess(dish(1, tags = setOf(DietTag.PORK)), criteria(target(excluded = setOf(DietTag.PORK))))
        val fatty = assessor.assess(dish(2, kcal = 500.0, protein = 30.0, fat = 33.0), criteria())

        assertThat(pork.verdict).isEqualTo(Verdict.NOT_FITS)
        assertThat(pork.reasons.single()).isEqualTo(AssessmentReason(ReasonCode.EXCLUDED_TAG, null, DietTag.PORK))
        assertThat(fatty.verdict).isEqualTo(Verdict.NOT_FITS)
        assertThat(fatty.reasons.single()).isEqualTo(AssessmentReason(ReasonCode.FAT_ABOVE, 8.0, null))
    }

    @Test
    fun `не подходит блюдо калорийнее всего приёма пищи и с лишними углеводами`() {
        val heavy = assessor.assess(dish(1, kcal = 700.0, protein = 40.0, fat = 20.0, carbs = 95.0), criteria())

        assertThat(heavy.reasons.map { it.code }).containsExactly(ReasonCode.KCAL_ABOVE, ReasonCode.CARBS_ABOVE)
        assertThat(heavy.reasons.first().amount).isEqualTo(40.0)
    }

    @Test
    fun `можно, но мало белка и данные-оценка`() {
        val lowProtein = assessor.assess(dish(1, DishCategory.SIDE, kcal = 300.0, protein = 5.0, fat = 10.0, carbs = 40.0), criteria())
        val estimated = assessor.assess(dish(2, kcal = 500.0, protein = 35.0, source = SourceKind.C), criteria())

        assertThat(lowProtein.verdict).isEqualTo(Verdict.PARTIAL)
        assertThat(lowProtein.reasons.single().code).isEqualTo(ReasonCode.LOW_PROTEIN)
        assertThat(lowProtein.reasons.single().amount).isEqualTo(10.0)
        assertThat(estimated.verdict).isEqualTo(Verdict.PARTIAL)
        assertThat(estimated.reasons.single().code).isEqualTo(ReasonCode.ESTIMATED_DATA)
    }

    @Test
    fun `сортирует меню - сначала подходящие, затем ближе к цели`() {
        val menu =
            listOf(
                dish(1, kcal = 900.0, protein = 50.0),
                dish(2, DishCategory.SIDE, kcal = 300.0, protein = 2.0),
                dish(3, kcal = 400.0, protein = 30.0),
                dish(4, kcal = 590.0, protein = 40.0),
            )

        val sorted = assessor.assessMenu(menu, criteria())

        assertThat(sorted.map { it.item.id }).containsExactly(4, 3, 2, 1)
    }
}
