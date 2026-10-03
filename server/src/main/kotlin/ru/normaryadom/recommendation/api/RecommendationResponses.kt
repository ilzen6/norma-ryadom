package ru.normaryadom.recommendation.api

import ru.normaryadom.catalog.domain.DietTag
import ru.normaryadom.catalog.domain.DishCategory
import ru.normaryadom.catalog.domain.SourceKind
import ru.normaryadom.optimizer.Metric
import ru.normaryadom.optimizer.MetricStatus
import ru.normaryadom.recommendation.FitLevel
import ru.normaryadom.recommendation.ReasonCode
import ru.normaryadom.recommendation.Verdict
import java.time.Instant
import java.time.LocalDate

data class NutrientsResponse(
    val kcal: Double,
    val protein: Double,
    val fat: Double,
    val carbs: Double,
)

data class AppliedTargetResponse(
    val kcal: Double,
    val kcalTolerance: Double,
    val minProtein: Double,
    val maxFat: Double,
    val maxCarbs: Double,
    val excludeTags: List<DietTag>,
)

data class VenueSummaryResponse(
    val id: Long,
    val name: String,
    val chainName: String?,
    val address: String,
    val lat: Double,
    val lon: Double,
    val currency: String,
    val confirmedOn: LocalDate?,
)

data class DishResponse(
    val id: Long,
    val name: String,
    val category: DishCategory,
    val portionGrams: Double?,
    val nutrients: NutrientsResponse,
    val priceMinor: Int?,
    val sourceKind: SourceKind,
    val tags: List<DietTag>,
)

data class MetricCheckResponse(
    val metric: Metric,
    val value: Double,
    val goal: Double,
    val delta: Double,
    val status: MetricStatus,
)

data class ComboResponse(
    val dishes: List<DishResponse>,
    val totals: NutrientsResponse,
    val priceMinor: Int?,
    val sourceKind: SourceKind,
    val score: Double,
    val checks: List<MetricCheckResponse>,
)

data class ComboOptionResponse(
    val venue: VenueSummaryResponse,
    val distanceMeters: Int?,
    val combo: ComboResponse,
)

data class ComboSearchResponse(
    val appliedTarget: AppliedTargetResponse,
    val options: List<ComboOptionResponse>,
)

data class NearbyVenueResponse(
    val venue: VenueSummaryResponse,
    val distanceMeters: Int,
    val hasMenu: Boolean,
    val fit: FitLevel?,
)

data class NearbyVenuesResponse(
    val venues: List<NearbyVenueResponse>,
)

data class SourceResponse(
    val kind: SourceKind,
    val url: String?,
    val verifiedAt: Instant?,
    val kcalLow: Double?,
    val kcalHigh: Double?,
)

data class ReasonResponse(
    val code: ReasonCode,
    val amount: Double?,
    val tag: DietTag?,
)

data class AssessmentResponse(
    val verdict: Verdict,
    val reasons: List<ReasonResponse>,
)

data class MenuItemResponse(
    val id: Long,
    val name: String,
    val category: DishCategory,
    val portionGrams: Double?,
    val nutrients: NutrientsResponse,
    val priceMinor: Int?,
    val tags: List<DietTag>,
    val source: SourceResponse,
    val assessment: AssessmentResponse?,
)

data class VenueMenuResponse(
    val venue: VenueSummaryResponse,
    val items: List<MenuItemResponse>,
)
