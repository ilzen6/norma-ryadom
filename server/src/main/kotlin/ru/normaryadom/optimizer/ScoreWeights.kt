package ru.normaryadom.optimizer

import ru.normaryadom.catalog.domain.SourceKind

data class ScoreWeights(
    val kcal: Double,
    val protein: Double,
    val fat: Double,
    val carbs: Double,
    val trustB: Double,
    val trustC: Double,
    val price: Double,
    val priceScaleMinor: Double,
) {
    init {
        require(priceScaleMinor > 0) { "Price scale must be positive" }
    }

    fun trustPenalty(kind: SourceKind): Double =
        when (kind) {
            SourceKind.A -> 0.0
            SourceKind.B -> trustB
            SourceKind.C -> trustC
        }
}
