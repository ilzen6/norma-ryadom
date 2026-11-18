package ru.normaryadom.geo

import ru.normaryadom.catalog.domain.GeoPoint
import ru.normaryadom.catalog.domain.VenueKind

data class NearbyQuery(
    val center: GeoPoint,
    val radiusMeters: Int,
    val coverage: MenuCoverage,
    val limit: Int,
    val limitEachMenuKind: Boolean = false,
    val kinds: Set<VenueKind> = emptySet(),
)

enum class MenuCoverage {
    WITH_MENU_ONLY,
    ALL,
}
