package ru.normaryadom.recommendation.api

import ru.normaryadom.catalog.domain.MenuItem
import ru.normaryadom.catalog.domain.Nutrients
import ru.normaryadom.catalog.domain.Venue
import ru.normaryadom.optimizer.ComboExplanation
import ru.normaryadom.optimizer.MealTarget
import ru.normaryadom.recommendation.ComboOption
import ru.normaryadom.recommendation.ComboSearchResult
import ru.normaryadom.recommendation.DishAssessment
import ru.normaryadom.recommendation.VenueFit
import java.math.BigDecimal
import java.math.RoundingMode
import kotlin.math.roundToInt

object RecommendationMapper {
    private const val NUTRIENT_SCALE = 1
    private const val SCORE_SCALE = 4

    fun searchResponse(result: ComboSearchResult): ComboSearchResponse {
        val target = result.appliedCriteria.target
        return ComboSearchResponse(
            appliedTarget = appliedTarget(target),
            options = result.options.map { option(it, target) },
        )
    }

    fun nearbyResponse(fits: List<VenueFit>): NearbyVenuesResponse =
        NearbyVenuesResponse(
            venues =
                fits.map { fit ->
                    NearbyVenueResponse(
                        venue = venue(fit.nearbyVenue.venue),
                        distanceMeters = fit.nearbyVenue.distanceMeters.roundToInt(),
                        hasMenu = fit.nearbyVenue.venue.hasMenu,
                        fit = fit.fit,
                    )
                },
        )

    fun menuResponse(
        venue: Venue,
        items: List<MenuItem>,
    ): VenueMenuResponse = VenueMenuResponse(venue = venue(venue), items = items.map { menuItem(it, null) })

    fun assessedMenuResponse(
        venue: Venue,
        assessments: List<DishAssessment>,
    ): VenueMenuResponse =
        VenueMenuResponse(
            venue = venue(venue),
            items =
                assessments.map { assessment ->
                    menuItem(
                        assessment.item,
                        AssessmentResponse(
                            verdict = assessment.verdict,
                            reasons = assessment.reasons.map { ReasonResponse(it.code, it.amount?.let(::round1), it.tag) },
                        ),
                    )
                },
        )

    fun venue(venue: Venue): VenueSummaryResponse =
        VenueSummaryResponse(
            id = venue.id,
            name = venue.name,
            chainName = venue.chainName,
            address = venue.address,
            lat = venue.location.lat,
            lon = venue.location.lon,
            currency = venue.currency,
        )

    private fun option(
        option: ComboOption,
        target: MealTarget,
    ): ComboOptionResponse {
        val combo = option.combo
        return ComboOptionResponse(
            venue = venue(option.venue),
            distanceMeters = option.distanceMeters?.roundToInt(),
            combo =
                ComboResponse(
                    dishes = combo.dishes.sortedBy { it.category.ordinal }.map(::dish),
                    totals = nutrients(combo.totals),
                    priceMinor = combo.priceMinor,
                    sourceKind = combo.sourceKind,
                    score = round(combo.score, SCORE_SCALE),
                    checks =
                        ComboExplanation.explain(combo.totals, target).map {
                            MetricCheckResponse(it.metric, round1(it.value), round1(it.goal), round1(it.delta), it.status)
                        },
                ),
        )
    }

    private fun appliedTarget(target: MealTarget): AppliedTargetResponse =
        AppliedTargetResponse(
            kcal = target.kcal,
            kcalTolerance = target.kcalTolerance,
            minProtein = target.minProtein,
            maxFat = target.maxFat,
            maxCarbs = target.maxCarbs,
            excludeTags = target.excludedTags.sorted(),
        )

    private fun dish(item: MenuItem): DishResponse =
        DishResponse(
            id = item.id,
            name = item.name,
            category = item.category,
            portionGrams = item.portionGrams,
            nutrients = nutrients(item.nutrients),
            priceMinor = item.priceMinor,
            sourceKind = item.source.kind,
            tags = item.tags.sorted(),
        )

    private fun menuItem(
        item: MenuItem,
        assessment: AssessmentResponse?,
    ): MenuItemResponse =
        MenuItemResponse(
            id = item.id,
            name = item.name,
            category = item.category,
            portionGrams = item.portionGrams,
            nutrients = nutrients(item.nutrients),
            priceMinor = item.priceMinor,
            tags = item.tags.sorted(),
            source =
                SourceResponse(
                    kind = item.source.kind,
                    url = item.source.url,
                    verifiedAt = item.source.verifiedAt,
                    kcalLow = item.source.kcalRange?.low,
                    kcalHigh = item.source.kcalRange?.high,
                ),
            assessment = assessment,
        )

    private fun nutrients(nutrients: Nutrients): NutrientsResponse =
        NutrientsResponse(
            kcal = round1(nutrients.kcal),
            protein = round1(nutrients.protein),
            fat = round1(nutrients.fat),
            carbs = round1(nutrients.carbs),
        )

    private fun round1(value: Double): Double = round(value, NUTRIENT_SCALE)

    private fun round(
        value: Double,
        scale: Int,
    ): Double = BigDecimal.valueOf(value).setScale(scale, RoundingMode.HALF_UP).toDouble()
}
