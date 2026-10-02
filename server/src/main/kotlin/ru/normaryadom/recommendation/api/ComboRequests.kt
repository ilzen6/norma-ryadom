package ru.normaryadom.recommendation.api

import com.fasterxml.jackson.annotation.JsonIgnore
import io.swagger.v3.oas.annotations.media.Schema
import jakarta.validation.Valid
import jakarta.validation.constraints.AssertTrue
import jakarta.validation.constraints.DecimalMax
import jakarta.validation.constraints.DecimalMin
import jakarta.validation.constraints.Max
import jakarta.validation.constraints.Min
import jakarta.validation.constraints.Positive
import jakarta.validation.constraints.Size
import ru.normaryadom.optimizer.PricePreference
import ru.normaryadom.optimizer.SearchCriteria

data class LocationRequest(
    @field:DecimalMin("-90")
    @field:DecimalMax("90")
    val lat: Double,
    @field:DecimalMin("-180")
    @field:DecimalMax("180")
    val lon: Double,
    @field:Min(100)
    @field:Max(5000)
    val radiusMeters: Int,
)

data class ComboSearchRequest(
    @field:Valid
    val target: MealTargetRequest,
    @field:Positive
    val venueId: Long? = null,
    @field:Valid
    val location: LocationRequest? = null,
    @field:Schema(requiredMode = Schema.RequiredMode.NOT_REQUIRED)
    val preferCheaper: Boolean = false,
    @field:Schema(requiredMode = Schema.RequiredMode.NOT_REQUIRED)
    @field:Min(1)
    @field:Max(5)
    val limit: Int = 5,
) {
    fun criteria(): SearchCriteria = SearchCriteria(target.toTarget(), PricePreferences.of(preferCheaper))

    @get:JsonIgnore
    @get:Schema(hidden = true)
    @get:AssertTrue(message = "нужно указать либо venueId, либо location")
    val isSingleSearchArea: Boolean get() = (venueId == null) != (location == null)
}

data class ComboReplaceRequest(
    @field:Positive
    val venueId: Long,
    @field:Valid
    val target: MealTargetRequest,
    @field:Size(min = 1, max = 3)
    val dishIds: List<Long>,
    @field:Min(0)
    val replaceIndex: Int,
    @field:Schema(requiredMode = Schema.RequiredMode.NOT_REQUIRED)
    val preferCheaper: Boolean = false,
    @field:Schema(requiredMode = Schema.RequiredMode.NOT_REQUIRED)
    @field:Min(1)
    @field:Max(5)
    val limit: Int = 5,
) {
    fun criteria(): SearchCriteria = SearchCriteria(target.toTarget(), PricePreferences.of(preferCheaper))
}

object PricePreferences {
    fun of(preferCheaper: Boolean): PricePreference = if (preferCheaper) PricePreference.PREFER_CHEAPER else PricePreference.IGNORE
}
