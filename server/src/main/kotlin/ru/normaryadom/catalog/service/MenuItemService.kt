package ru.normaryadom.catalog.service

import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional
import ru.normaryadom.catalog.domain.Nutrients
import ru.normaryadom.catalog.domain.SourceKind
import ru.normaryadom.catalog.persistence.ChainRepository
import ru.normaryadom.catalog.persistence.MenuItemDraft
import ru.normaryadom.catalog.persistence.MenuItemRecord
import ru.normaryadom.catalog.persistence.MenuItemRepository
import ru.normaryadom.catalog.persistence.Provenance
import ru.normaryadom.catalog.persistence.VenueRepository
import java.time.Clock

@Service
class MenuItemService(
    private val items: MenuItemRepository,
    private val chains: ChainRepository,
    private val venues: VenueRepository,
    private val clock: Clock,
) {
    fun find(itemId: Long): MenuItemRecord = items.findById(itemId) ?: throw MenuItemNotFoundException(itemId)

    @Transactional
    fun lockAvailable(itemId: Long): MenuItemRecord = items.lockAvailable(itemId) ?: throw MenuItemNotFoundException(itemId)

    @Transactional
    fun sendToReview(record: MenuItemRecord): Boolean {
        val marked = items.markUnderReview(record.item.id)
        if (marked) bumpOwnerOf(record)
        return marked
    }

    @Transactional
    fun confirm(itemId: Long) {
        val record = find(itemId)
        items.confirm(itemId)
        bumpOwnerOf(record)
    }

    @Transactional
    fun correct(
        itemId: Long,
        nutrients: Nutrients,
    ) {
        val record = find(itemId)
        items.correctNutrients(itemId, nutrients, clock.instant())
        bumpOwnerOf(record)
    }

    @Transactional
    fun withdraw(itemId: Long) {
        val record = find(itemId)
        items.withdraw(itemId)
        bumpOwnerOf(record)
    }

    @Transactional
    fun addVenueItems(
        venueId: Long,
        drafts: List<MenuItemDraft>,
    ) {
        items.upsertForVenue(venueId, drafts, Provenance(SourceKind.B, null, clock.instant()))
        venues.bumpMenuVersion(venueId)
    }

    private fun bumpOwnerOf(record: MenuItemRecord) {
        record.chainId?.let(chains::bumpMenuVersion)
        record.venueId?.let(venues::bumpMenuVersion)
    }
}
