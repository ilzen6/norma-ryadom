package ru.normaryadom.catalog.service

import org.springframework.stereotype.Component
import ru.normaryadom.catalog.persistence.ChainRepository
import ru.normaryadom.catalog.persistence.MenuItemRecord
import ru.normaryadom.catalog.persistence.VenueRepository

@Component
class MenuVersions(
    private val chains: ChainRepository,
    private val venues: VenueRepository,
) {
    fun bumpOwnerOf(record: MenuItemRecord) {
        record.chainId?.let(chains::bumpMenuVersion)
        record.venueId?.let(venues::bumpMenuVersion)
    }

    fun bumpVenue(venueId: Long) = venues.bumpMenuVersion(venueId)
}
