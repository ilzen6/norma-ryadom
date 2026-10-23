package ru.normaryadom.geo

import ru.normaryadom.catalog.domain.GeoPoint

data class NearbyQuery(
    val center: GeoPoint,
    val radiusMeters: Int,
    val coverage: MenuCoverage,
    val limit: Int,
    val limitEachMenuKind: Boolean = false,
)

enum class MenuCoverage {
    WITH_MENU_ONLY,
    ALL,
}
