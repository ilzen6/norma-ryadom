package ru.normaryadom.catalog.service

import org.springframework.dao.DuplicateKeyException
import org.springframework.stereotype.Service
import ru.normaryadom.catalog.domain.Chain
import ru.normaryadom.catalog.domain.Venue
import ru.normaryadom.catalog.persistence.ChainRepository
import ru.normaryadom.catalog.persistence.ChainSummary
import ru.normaryadom.catalog.persistence.MenuItemRecord
import ru.normaryadom.catalog.persistence.MenuItemRepository
import ru.normaryadom.catalog.persistence.VenueRepository

@Service
class ChainService(
    private val chains: ChainRepository,
    private val venues: VenueRepository,
    private val items: MenuItemRepository,
) {
    fun list(): List<ChainSummary> = chains.findAll()

    fun get(chainId: Long): Chain = chains.findById(chainId) ?: throw ChainNotFoundException(chainId)

    fun findByName(name: String): Chain? = chains.findByName(name)

    fun create(
        name: String,
        sourceUrl: String?,
    ): Long =
        try {
            chains.create(name.trim(), sourceUrl?.trim()?.takeIf(String::isNotEmpty))
        } catch (e: DuplicateKeyException) {
            throw ChainNameTakenException(name.trim())
        }

    fun items(chainId: Long): List<MenuItemRecord> = items.findByChain(get(chainId).id)

    fun venues(chainId: Long): List<Venue> = venues.findByChain(get(chainId).id)
}
