package ru.normaryadom.recommendation

import ru.normaryadom.optimizer.MealTarget
import kotlin.math.max
import kotlin.math.roundToLong

object TargetRounding {
    const val KCAL_STEP = 50.0
    const val GRAM_STEP = 5.0

    fun round(target: MealTarget): MealTarget =
        target.copy(
            kcal = max(KCAL_STEP, roundTo(target.kcal, KCAL_STEP)),
            kcalTolerance = max(KCAL_STEP, roundTo(target.kcalTolerance, KCAL_STEP)),
            minProtein = roundTo(target.minProtein, GRAM_STEP),
            maxFat = roundTo(target.maxFat, GRAM_STEP),
            maxCarbs = roundTo(target.maxCarbs, GRAM_STEP),
        )

    private fun roundTo(
        value: Double,
        step: Double,
    ): Double = (value / step).roundToLong() * step
}
