package ru.normaryadom.recommendation.api

import jakarta.validation.constraints.DecimalMax
import jakarta.validation.constraints.DecimalMin
import jakarta.validation.constraints.Size
import ru.normaryadom.catalog.domain.DietTag
import ru.normaryadom.optimizer.MealTarget
import ru.normaryadom.optimizer.PricePreference
import ru.normaryadom.optimizer.SearchCriteria

data class MealTargetQuery(
    @field:DecimalMin("100")
    @field:DecimalMax("2000")
    val kcal: Double? = null,
    @field:DecimalMin("10")
    @field:DecimalMax("500")
    val kcalTolerance: Double? = null,
    @field:DecimalMin("0")
    @field:DecimalMax("300")
    val minProtein: Double? = null,
    @field:DecimalMin("0")
    @field:DecimalMax("300")
    val maxFat: Double? = null,
    @field:DecimalMin("0")
    @field:DecimalMax("500")
    val maxCarbs: Double? = null,
    @field:Size(max = 20)
    val excludeTags: Set<DietTag>? = null,
) {
    fun toCriteriaOrNull(): SearchCriteria? {
        val required =
            mapOf(
                "kcal" to kcal,
                "kcalTolerance" to kcalTolerance,
                "maxCarbs" to maxCarbs,
                "maxFat" to maxFat,
                "minProtein" to minProtein,
            )
        val missing = required.filterValues { it == null }.keys.toList()
        return when {
            missing.size == required.size && excludeTags.isNullOrEmpty() -> null
            missing.isNotEmpty() -> throw IncompleteTargetException(missing)
            else ->
                SearchCriteria(
                    target =
                        MealTarget(
                            kcal = checkNotNull(kcal),
                            kcalTolerance = checkNotNull(kcalTolerance),
                            minProtein = checkNotNull(minProtein),
                            maxFat = checkNotNull(maxFat),
                            maxCarbs = checkNotNull(maxCarbs),
                            excludedTags = excludeTags.orEmpty(),
                        ),
                    pricePreference = PricePreference.IGNORE,
                )
        }
    }
}

class IncompleteTargetException(
    val missingParameters: List<String>,
) : RuntimeException("Meal target parameters are incomplete")
