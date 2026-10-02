package ru.normaryadom.recommendation

import org.springframework.stereotype.Component
import ru.normaryadom.catalog.domain.MenuItem
import ru.normaryadom.catalog.domain.SourceKind
import ru.normaryadom.optimizer.ComboScorer
import ru.normaryadom.optimizer.MealTarget
import ru.normaryadom.optimizer.SearchCriteria

@Component
class DishAssessor(
    private val scorer: ComboScorer,
) {
    fun assessMenu(
        menu: List<MenuItem>,
        criteria: SearchCriteria,
    ): List<DishAssessment> =
        menu
            .map { assess(it, criteria) }
            .sortedWith(compareBy<DishAssessment>({ it.verdict }, { it.closeness }, { it.item.id }))

    fun assess(
        item: MenuItem,
        criteria: SearchCriteria,
    ): DishAssessment {
        val target = criteria.target
        val blocking = blockingReasons(item, target)
        val warnings = if (blocking.isEmpty()) warningReasons(item, target) else emptyList()
        val verdict =
            when {
                blocking.isNotEmpty() -> Verdict.NOT_FITS
                warnings.isNotEmpty() -> Verdict.PARTIAL
                else -> Verdict.FITS
            }
        return DishAssessment(
            item = item,
            verdict = verdict,
            reasons = blocking + warnings,
            closeness = scorer.score(item.nutrients, item.priceMinor, item.source.kind, criteria),
        )
    }

    private fun blockingReasons(
        item: MenuItem,
        target: MealTarget,
    ): List<AssessmentReason> =
        listOfNotNull(
            item.tags.firstOrNull(target.excludedTags::contains)?.let { AssessmentReason(ReasonCode.EXCLUDED_TAG, null, it) },
            excess(ReasonCode.KCAL_ABOVE, item.nutrients.kcal, target.maxKcal),
            excess(ReasonCode.FAT_ABOVE, item.nutrients.fat, target.maxFat),
            excess(ReasonCode.CARBS_ABOVE, item.nutrients.carbs, target.maxCarbs),
        )

    private fun warningReasons(
        item: MenuItem,
        target: MealTarget,
    ): List<AssessmentReason> {
        val proportionalProtein = item.nutrients.kcal * target.minProtein / target.kcal
        val lowProtein =
            AssessmentReason(ReasonCode.LOW_PROTEIN, proportionalProtein - item.nutrients.protein, null)
                .takeIf { item.nutrients.protein < proportionalProtein * LOW_PROTEIN_SHARE }
        val estimated =
            AssessmentReason(ReasonCode.ESTIMATED_DATA, null, null)
                .takeIf { item.source.kind == SourceKind.C }
        return listOfNotNull(lowProtein, estimated)
    }

    private fun excess(
        code: ReasonCode,
        value: Double,
        limit: Double,
    ): AssessmentReason? = AssessmentReason(code, value - limit, null).takeIf { value > limit + MealTarget.EPSILON }

    private companion object {
        const val LOW_PROTEIN_SHARE = 0.75
    }
}
