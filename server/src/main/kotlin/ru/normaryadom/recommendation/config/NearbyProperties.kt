package ru.normaryadom.recommendation.config

import jakarta.validation.constraints.DecimalMin
import jakarta.validation.constraints.Max
import jakarta.validation.constraints.Min
import org.springframework.boot.context.properties.ConfigurationProperties
import org.springframework.validation.annotation.Validated

@Validated
@ConfigurationProperties("nearby")
data class NearbyProperties(
    @field:Min(1)
    @field:Max(200)
    val maxResults: Int,
    @field:DecimalMin("0.0")
    val distanceWeightPerKm: Double,
    @field:Min(1)
    val combosPerVenue: Int,
)
