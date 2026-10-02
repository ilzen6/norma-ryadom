package ru.normaryadom.catalog.domain

data class Nutrients(
    val kcal: Double,
    val protein: Double,
    val fat: Double,
    val carbs: Double,
) {
    operator fun plus(other: Nutrients): Nutrients =
        Nutrients(
            kcal = kcal + other.kcal,
            protein = protein + other.protein,
            fat = fat + other.fat,
            carbs = carbs + other.carbs,
        )

    companion object {
        val ZERO = Nutrients(kcal = 0.0, protein = 0.0, fat = 0.0, carbs = 0.0)
    }
}
