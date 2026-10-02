package ru.normaryadom.optimizer

import ru.normaryadom.catalog.domain.DietTag
import ru.normaryadom.catalog.domain.MenuItem
import ru.normaryadom.catalog.domain.Nutrients

data class MealTarget(
    val kcal: Double,
    val kcalTolerance: Double,
    val minProtein: Double,
    val maxFat: Double,
    val maxCarbs: Double,
    val excludedTags: Set<DietTag>,
) {
    init {
        require(kcal > 0) { "Target kcal must be positive" }
        require(kcalTolerance > 0) { "Kcal tolerance must be positive" }
        require(minProtein >= 0 && maxFat >= 0 && maxCarbs >= 0) { "Macro limits must not be negative" }
    }

    val minKcal: Double get() = kcal - kcalTolerance

    val maxKcal: Double get() = kcal + kcalTolerance

    fun allows(item: MenuItem): Boolean = item.tags.none(excludedTags::contains)

    fun isSatisfiedBy(totals: Nutrients): Boolean =
        totals.kcal >= minKcal - EPSILON &&
            totals.kcal <= maxKcal + EPSILON &&
            totals.protein >= minProtein - EPSILON &&
            totals.fat <= maxFat + EPSILON &&
            totals.carbs <= maxCarbs + EPSILON

    fun relaxed(relaxation: TargetRelaxation): MealTarget =
        copy(
            kcalTolerance = kcalTolerance * relaxation.kcalToleranceFactor,
            minProtein = minProtein * relaxation.proteinFactor,
            maxFat = maxFat * relaxation.limitFactor,
            maxCarbs = maxCarbs * relaxation.limitFactor,
        )

    companion object {
        const val EPSILON = 1e-6
    }
}

data class TargetRelaxation(
    val kcalToleranceFactor: Double,
    val proteinFactor: Double,
    val limitFactor: Double,
)
