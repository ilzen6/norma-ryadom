package ru.normaryadom.catalog.service

import org.springframework.stereotype.Service
import ru.normaryadom.catalog.domain.MenuItem
import ru.normaryadom.catalog.domain.MenuScope
import ru.normaryadom.catalog.domain.Venue
import ru.normaryadom.catalog.persistence.MenuItemRepository
import ru.normaryadom.catalog.persistence.VenueRepository

@Service
class VenueMenuService(
    private val venues: VenueRepository,
    private val items: MenuItemRepository,
) {
    fun venue(venueId: Long): Venue = venues.findActiveById(venueId) ?: throw VenueNotFoundException(venueId)

    fun menu(scope: MenuScope): List<MenuItem> = items.findAvailable(scope)
}
