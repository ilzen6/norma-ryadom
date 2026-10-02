package ru.normaryadom.catalog.domain

data class GeoPoint(
    val lat: Double,
    val lon: Double,
) {
    init {
        require(lat in MIN_LAT..MAX_LAT) { "Latitude out of range" }
        require(lon in MIN_LON..MAX_LON) { "Longitude out of range" }
    }

    private companion object {
        const val MIN_LAT = -90.0
        const val MAX_LAT = 90.0
        const val MIN_LON = -180.0
        const val MAX_LON = 180.0
    }
}
