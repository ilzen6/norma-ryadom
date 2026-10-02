package ru.normaryadom.recommendation.api

import io.swagger.v3.oas.annotations.Operation
import io.swagger.v3.oas.annotations.tags.Tag
import jakarta.validation.Valid
import org.springframework.web.bind.annotation.PostMapping
import org.springframework.web.bind.annotation.RequestBody
import org.springframework.web.bind.annotation.RequestMapping
import org.springframework.web.bind.annotation.RestController
import ru.normaryadom.catalog.domain.GeoPoint
import ru.normaryadom.recommendation.ComboSearchService

@Tag(name = "combos")
@RestController
@RequestMapping("/api/v1/combos")
class ComboController(
    private val search: ComboSearchService,
) {
    @Operation(summary = "Подбор наборов блюд под цель в заведении или рядом с точкой")
    @PostMapping("/search")
    fun search(
        @Valid @RequestBody request: ComboSearchRequest,
    ): ComboSearchResponse {
        val result =
            request.location?.let { location ->
                search.searchNearby(GeoPoint(location.lat, location.lon), location.radiusMeters, request.criteria(), request.limit)
            } ?: search.searchAtVenue(requireNotNull(request.venueId), request.criteria(), request.limit)
        return RecommendationMapper.searchResponse(result)
    }

    @Operation(summary = "Замена одного блюда в наборе, остальные блюда зафиксированы")
    @PostMapping("/replace")
    fun replace(
        @Valid @RequestBody request: ComboReplaceRequest,
    ): ComboSearchResponse =
        RecommendationMapper.searchResponse(
            search.replace(request.venueId, request.criteria(), request.dishIds, request.replaceIndex, request.limit),
        )
}
