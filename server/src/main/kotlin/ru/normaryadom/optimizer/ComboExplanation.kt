package ru.normaryadom.optimizer

import ru.normaryadom.catalog.domain.Nutrients
import kotlin.math.abs

enum class Metric { KCAL, PROTEIN, FAT, CARBS }

enum class MetricStatus { OK, ABOVE, BELOW }

data class MetricCheck(
    val metric: Metric,
    val value: Double,
    val goal: Double,
    val delta: Double,
    val status: MetricStatus,
)

object ComboExplanation {
    fun explain(
        totals: Nutrients,
        target: MealTarget,
    ): List<MetricCheck> =
        listOf(
            kcal(totals.kcal, target),
            minimum(Metric.PROTEIN, totals.protein, target.minProtein),
            maximum(Metric.FAT, totals.fat, target.maxFat),
            maximum(Metric.CARBS, totals.carbs, target.maxCarbs),
        )

    private fun kcal(
        value: Double,
        target: MealTarget,
    ): MetricCheck {
        val delta = value - target.kcal
        val status =
            when {
                abs(delta) <= target.kcalTolerance + MealTarget.EPSILON -> MetricStatus.OK
                delta > 0 -> MetricStatus.ABOVE
                else -> MetricStatus.BELOW
            }
        return MetricCheck(Metric.KCAL, value, target.kcal, delta, status)
    }

    private fun minimum(
        metric: Metric,
        value: Double,
        goal: Double,
    ): MetricCheck {
        val status = if (value >= goal - MealTarget.EPSILON) MetricStatus.OK else MetricStatus.BELOW
        return MetricCheck(metric, value, goal, value - goal, status)
    }

    private fun maximum(
        metric: Metric,
        value: Double,
        goal: Double,
    ): MetricCheck {
        val status = if (value <= goal + MealTarget.EPSILON) MetricStatus.OK else MetricStatus.ABOVE
        return MetricCheck(metric, value, goal, value - goal, status)
    }
}
