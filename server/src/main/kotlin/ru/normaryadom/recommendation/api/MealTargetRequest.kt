package ru.normaryadom.recommendation.api

import io.swagger.v3.oas.annotations.media.Schema
import jakarta.validation.constraints.DecimalMax
import jakarta.validation.constraints.DecimalMin
import jakarta.validation.constraints.Size
import ru.normaryadom.catalog.domain.DietTag
import ru.normaryadom.optimizer.MealTarget

data class MealTargetRequest(
    @field:DecimalMin("100")
    @field:DecimalMax("2000")
    val kcal: Double,
    @field:DecimalMin("10")
    @field:DecimalMax("500")
    val kcalTolerance: Double,
    @field:DecimalMin("0")
    @field:DecimalMax("300")
    val minProtein: Double,
    @field:DecimalMin("0")
    @field:DecimalMax("300")
    val maxFat: Double,
    @field:DecimalMin("0")
    @field:DecimalMax("500")
    val maxCarbs: Double,
    @field:Schema(requiredMode = Schema.RequiredMode.NOT_REQUIRED)
    @field:Size(max = 20)
    val excludeTags: Set<DietTag> = emptySet(),
) {
    fun toTarget(): MealTarget =
        MealTarget(
            kcal = kcal,
            kcalTolerance = kcalTolerance,
            minProtein = minProtein,
            maxFat = maxFat,
            maxCarbs = maxCarbs,
            excludedTags = excludeTags,
        )
}
