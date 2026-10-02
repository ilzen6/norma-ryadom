package ru.normaryadom.optimizer

enum class PricePreference {
    IGNORE {
        override fun penalty(
            priceMinor: Int?,
            weights: ScoreWeights,
        ): Double = 0.0
    },
    PREFER_CHEAPER {
        override fun penalty(
            priceMinor: Int?,
            weights: ScoreWeights,
        ): Double {
            val price = priceMinor?.toDouble() ?: weights.priceScaleMinor
            return weights.price * price / weights.priceScaleMinor
        }
    },
    ;

    abstract fun penalty(
        priceMinor: Int?,
        weights: ScoreWeights,
    ): Double
}
