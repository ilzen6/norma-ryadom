package ru.normaryadom.recommendation.api

import io.swagger.v3.oas.annotations.Operation
import io.swagger.v3.oas.annotations.tags.Tag
import jakarta.validation.Valid
import jakarta.validation.constraints.DecimalMax
import jakarta.validation.constraints.DecimalMin
import jakarta.validation.constraints.Max
import jakarta.validation.constraints.Min
import org.springdoc.core.annotations.ParameterObject
import org.springframework.web.bind.annotation.GetMapping
import org.springframework.web.bind.annotation.PathVariable
import org.springframework.web.bind.annotation.RequestMapping
import org.springframework.web.bind.annotation.RequestParam
import org.springframework.web.bind.annotation.RestController
import ru.normaryadom.catalog.domain.GeoPoint
import ru.normaryadom.catalog.service.VenueMenuService
import ru.normaryadom.geo.MenuCoverage
import ru.normaryadom.geo.NearbyQuery
import ru.normaryadom.recommendation.DishAssessor
import ru.normaryadom.recommendation.VenueDirectoryService
import ru.normaryadom.recommendation.VenueFit
import ru.normaryadom.recommendation.config.NearbyProperties

@Tag(name = "venues")
@RestController
@RequestMapping("/api/v1/venues")
class VenueController(
    private val directory: VenueDirectoryService,
    private val menus: VenueMenuService,
    private val assessor: DishAssessor,
    private val nearby: NearbyProperties,
) {
    @Operation(summary = "Заведения рядом с точкой; при переданной цели - цвет соответствия")
    @GetMapping
    fun nearby(
        @RequestParam @DecimalMin("-90") @DecimalMax("90") lat: Double,
        @RequestParam @DecimalMin("-180") @DecimalMax("180") lon: Double,
        @RequestParam @Min(100) @Max(MAX_RADIUS_METERS) radius: Int,
        @RequestParam(defaultValue = "false") includeWithoutMenu: Boolean,
        @RequestParam(required = false) @Min(1) @Max(MAX_LIMIT) limit: Int?,
        @Valid @ParameterObject target: MealTargetQuery,
    ): NearbyVenuesResponse {
        val coverage = if (includeWithoutMenu) MenuCoverage.ALL else MenuCoverage.WITH_MENU_ONLY
        val query = NearbyQuery(GeoPoint(lat, lon), radius, coverage, limit ?: nearby.maxResults)
        val fits =
            target.toCriteriaOrNull()?.let { directory.nearbyWithFit(query, it) }
                ?: directory.nearby(query).map { VenueFit(it, null) }
        return RecommendationMapper.nearbyResponse(fits)
    }

    @Operation(summary = "Меню заведения; при переданной цели - отсортировано по близости к цели с пометками")
    @GetMapping("/{venueId}/menu")
    fun menu(
        @PathVariable @Min(1) venueId: Long,
        @Valid @ParameterObject target: MealTargetQuery,
    ): VenueMenuResponse {
        val venue = menus.venue(venueId)
        val items = menus.menu(venue.menuScope)
        return target.toCriteriaOrNull()?.let { RecommendationMapper.assessedMenuResponse(venue, assessor.assessMenu(items, it)) }
            ?: RecommendationMapper.menuResponse(venue, items)
    }

    private companion object {
        const val MAX_RADIUS_METERS = 30_000L
        const val MAX_LIMIT = 500L
    }
}
