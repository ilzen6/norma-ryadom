package ru.normaryadom.geo

import ru.normaryadom.catalog.domain.Venue

data class NearbyVenue(
    val venue: Venue,
    val distanceMeters: Double,
)
