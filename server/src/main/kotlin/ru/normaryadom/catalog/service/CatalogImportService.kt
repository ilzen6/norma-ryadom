package ru.normaryadom.catalog.service

import org.slf4j.LoggerFactory
import org.springframework.stereotype.Service
import org.springframework.transaction.support.TransactionOperations
import ru.normaryadom.catalog.domain.KcalRange
import ru.normaryadom.catalog.domain.SourceKind
import ru.normaryadom.catalog.importing.CsvParseResult
import ru.normaryadom.catalog.importing.MenuCsvParser
import ru.normaryadom.catalog.importing.VenueCsvParser
import ru.normaryadom.catalog.persistence.ChainRepository
import ru.normaryadom.catalog.persistence.MenuItemDraft
import ru.normaryadom.catalog.persistence.MenuItemRepository
import ru.normaryadom.catalog.persistence.Provenance
import ru.normaryadom.catalog.persistence.VenueRepository
import java.time.Clock
import java.time.Instant

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
        verifiedAt: Instant? = null,
    ): ImportOutcome {
        val chain = chains.findById(chainId) ?: throw ChainNotFoundException(chainId)
        return when (val parsed = menuParser.parse(csv)) {
            is CsvParseResult.Invalid -> ImportOutcome.Rejected(parsed.errors)
            is CsvParseResult.Parsed -> {
                val kind = if (chain.isTemplate) SourceKind.C else SourceKind.A
                val provenance = Provenance(kind = kind, url = sourceUrl, verifiedAt = verifiedAt ?: clock.instant())
                val drafts = parsed.rows.map { draft -> withRangeFor(kind, draft) }
                val withdrawn =
                    transactions.execute {
                        items.upsertForChain(chainId, drafts, provenance)
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
        return when (val parsed = venueParser.parse(csv, chains.findTemplateIds())) {
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

    fun importStandaloneVenues(csv: ByteArray): ImportOutcome =
        when (val parsed = venueParser.parse(csv, chains.findTemplateIds())) {
            is CsvParseResult.Invalid -> ImportOutcome.Rejected(parsed.errors)
            is CsvParseResult.Parsed -> {
                val closed =
                    transactions.execute {
                        venues.upsertStandalone(parsed.rows)
                        venues.deactivateStandaloneExcept(parsed.rows.map { it.externalId })
                    }
                log.info("Standalone venues imported: upserted={}, closed={}", parsed.rows.size, closed)
                ImportOutcome.Imported(upserted = parsed.rows.size, withdrawn = closed)
            }
        }

    private fun withRangeFor(
        kind: SourceKind,
        draft: MenuItemDraft,
    ): MenuItemDraft =
        when {
            kind != SourceKind.C -> draft.copy(kcalRange = null)
            draft.kcalRange != null -> draft
            else -> {
                val kcal = draft.nutrients.kcal
                draft.copy(kcalRange = KcalRange(low = kcal * (1 - DEFAULT_SPREAD), high = kcal * (1 + DEFAULT_SPREAD)))
            }
        }

    private companion object {
        const val DEFAULT_SPREAD = 0.15
        val log = LoggerFactory.getLogger(CatalogImportService::class.java)
    }
}
