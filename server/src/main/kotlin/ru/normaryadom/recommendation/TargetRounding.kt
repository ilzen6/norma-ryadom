package ru.normaryadom.recommendation

import ru.normaryadom.optimizer.MealTarget
import kotlin.math.abs
import kotlin.math.ceil
import kotlin.math.floor
import kotlin.math.roundToLong

object TargetRounding {
    const val KCAL_STEP = 10.0
    const val GRAM_STEP = 5.0
    private const val PRECISION = 1e-9

    fun round(target: MealTarget): MealTarget {
        val kcal = ((target.kcal / KCAL_STEP).roundToLong() * KCAL_STEP).coerceAtLeast(KCAL_STEP)
        val shift = abs(kcal - target.kcal)
        return target.copy(
            kcal = kcal,
            kcalTolerance = floorTo(target.kcalTolerance - shift).coerceAtLeast(GRAM_STEP),
            minProtein = ceilTo(target.minProtein),
            maxFat = floorTo(target.maxFat),
            maxCarbs = floorTo(target.maxCarbs),
        )
    }

    private fun floorTo(value: Double): Double = floor(value / GRAM_STEP + PRECISION) * GRAM_STEP

    private fun ceilTo(value: Double): Double = ceil(value / GRAM_STEP - PRECISION) * GRAM_STEP
}
