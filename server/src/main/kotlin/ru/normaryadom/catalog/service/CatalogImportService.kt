package ru.normaryadom.catalog.service

import org.slf4j.LoggerFactory
import org.springframework.stereotype.Service
import org.springframework.transaction.support.TransactionOperations
import ru.normaryadom.catalog.domain.SourceKind
import ru.normaryadom.catalog.importing.CsvParseResult
import ru.normaryadom.catalog.importing.MenuCsvParser
import ru.normaryadom.catalog.importing.VenueCsvParser
import ru.normaryadom.catalog.persistence.ChainRepository
import ru.normaryadom.catalog.persistence.MenuItemRepository
import ru.normaryadom.catalog.persistence.Provenance
import ru.normaryadom.catalog.persistence.VenueRepository
import java.time.Clock

@Service
class CatalogImportService(
    private val chains: ChainRepository,
    private val venues: VenueRepository,
    private val items: MenuItemRepository,
    private val menuParser: MenuCsvParser,
    private val venueParser: VenueCsvParser,
    private val transactions: TransactionOperations,
    private val clock: Clock,
) {
    fun importChainMenu(
        chainId: Long,
        csv: ByteArray,
        sourceUrl: String,
    ): ImportOutcome {
        chains.findById(chainId) ?: throw ChainNotFoundException(chainId)
        return when (val parsed = menuParser.parse(csv)) {
            is CsvParseResult.Invalid -> ImportOutcome.Rejected(parsed.errors)
            is CsvParseResult.Parsed -> {
                val provenance = Provenance(kind = SourceKind.A, url = sourceUrl, verifiedAt = clock.instant())
                val withdrawn =
                    transactions.execute {
                        items.upsertForChain(chainId, parsed.rows, provenance)
                        val withdrawnCount = items.withdrawChainItemsExcept(chainId, parsed.rows.map { it.name })
                        chains.updateSourceUrl(chainId, sourceUrl)
                        chains.bumpMenuVersion(chainId)
                        withdrawnCount
                    }
                log.info("Chain menu imported: chainId={}, upserted={}, withdrawn={}", chainId, parsed.rows.size, withdrawn)
                ImportOutcome.Imported(upserted = parsed.rows.size, withdrawn = withdrawn)
            }
        }
    }

    fun importChainVenues(
        chainId: Long,
        csv: ByteArray,
    ): ImportOutcome {
        chains.findById(chainId) ?: throw ChainNotFoundException(chainId)
        return when (val parsed = venueParser.parse(csv)) {
            is CsvParseResult.Invalid -> ImportOutcome.Rejected(parsed.errors)
            is CsvParseResult.Parsed -> {
                val closed =
                    transactions.execute {
                        venues.upsertForChain(chainId, parsed.rows)
                        venues.deactivateChainVenuesExcept(chainId, parsed.rows.map { it.externalId })
                    }
                log.info("Chain venues imported: chainId={}, upserted={}, closed={}", chainId, parsed.rows.size, closed)
                ImportOutcome.Imported(upserted = parsed.rows.size, withdrawn = closed)
            }
        }
    }

    private companion object {
        val log = LoggerFactory.getLogger(CatalogImportService::class.java)
    }
}
