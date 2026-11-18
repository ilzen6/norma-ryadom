package ru.normaryadom.recommendation

import ru.normaryadom.catalog.domain.VenueKind

enum class ComboSort {
    RECOMMENDED,
    NEAREST,
    CHEAPEST,
    ACCURATE,
}

data class NearbyPreferences(
    val sort: ComboSort = ComboSort.RECOMMENDED,
    val kinds: Set<VenueKind> = emptySet(),
)
