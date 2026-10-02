package ru.normaryadom.recommendation

import ru.normaryadom.catalog.domain.DietTag
import ru.normaryadom.catalog.domain.MenuItem

enum class Verdict {
    FITS,
    PARTIAL,
    NOT_FITS,
}

enum class ReasonCode {
    EXCLUDED_TAG,
    KCAL_ABOVE,
    FAT_ABOVE,
    CARBS_ABOVE,
    LOW_PROTEIN,
    ESTIMATED_DATA,
}

data class AssessmentReason(
    val code: ReasonCode,
    val amount: Double?,
    val tag: DietTag?,
)

data class DishAssessment(
    val item: MenuItem,
    val verdict: Verdict,
    val reasons: List<AssessmentReason>,
    val closeness: Double,
)
