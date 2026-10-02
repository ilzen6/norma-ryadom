package ru.normaryadom.recommendation.config

import jakarta.validation.Valid
import jakarta.validation.constraints.DecimalMin
import jakarta.validation.constraints.Min
import org.springframework.boot.context.properties.ConfigurationProperties
import org.springframework.validation.annotation.Validated

@Validated
@ConfigurationProperties("optimizer")
data class OptimizerProperties(
    @field:Min(1)
    val maxItems: Int,
    @field:Min(1)
    val heapFactor: Int,
    @field:Valid
    val weights: Weights,
    @field:Valid
    val relaxation: Relaxation,
) {
    data class Weights(
        @field:DecimalMin("0.0")
        val kcal: Double,
        @field:DecimalMin("0.0")
        val protein: Double,
        @field:DecimalMin("0.0")
        val fat: Double,
        @field:DecimalMin("0.0")
        val carbs: Double,
        @field:DecimalMin("0.0")
        val trustB: Double,
        @field:DecimalMin("0.0")
        val trustC: Double,
        @field:DecimalMin("0.0")
        val price: Double,
        @field:DecimalMin("1.0")
        val priceScaleMinor: Double,
    )

    data class Relaxation(
        @field:DecimalMin("1.0")
        val kcalToleranceFactor: Double,
        @field:DecimalMin("0.0")
        val proteinFactor: Double,
        @field:DecimalMin("1.0")
        val limitFactor: Double,
    )
}
