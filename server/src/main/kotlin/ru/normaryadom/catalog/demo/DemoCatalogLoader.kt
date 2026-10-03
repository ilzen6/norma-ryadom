package ru.normaryadom.catalog.demo

import org.slf4j.LoggerFactory
import org.springframework.boot.ApplicationArguments
import org.springframework.boot.ApplicationRunner
import org.springframework.context.annotation.Profile
import org.springframework.stereotype.Component
import ru.normaryadom.catalog.persistence.VenueRepository
import ru.normaryadom.catalog.service.CatalogImportService
import ru.normaryadom.catalog.service.ChainService
import ru.normaryadom.catalog.service.ImportOutcome

@Component
@Profile("demo")
class DemoCatalogLoader(
    private val properties: DemoCatalogProperties,
    private val chains: ChainService,
    private val imports: CatalogImportService,
    private val venues: VenueRepository,
) : ApplicationRunner {
    override fun run(args: ApplicationArguments) {
        properties.chains.forEach { demo ->
            if (chains.findByName(demo.name) != null) {
                log.info("Demo chain already present, skipped: name={}", demo.name)
                return@forEach
            }
            val chainId = chains.create(demo.name, demo.sourceUrl)
            val menu = demo.menu?.let { imports.importChainMenu(chainId, it.contentAsByteArray, demo.sourceUrl) }
            val venues = imports.importChainVenues(chainId, demo.venues.contentAsByteArray)
            check((menu == null || menu is ImportOutcome.Imported) && venues is ImportOutcome.Imported) {
                "Demo catalog for ${demo.name} is invalid"
            }
            log.info(
                "Demo chain loaded: chainId={}, items={}, venues={}",
                chainId,
                menu?.upserted ?: 0,
                venues.upserted,
            )
        }
        loadPlaces()
    }

    private fun loadPlaces() {
        val places = properties.places ?: return
        if (venues.countStandalone() > 0) {
            log.info("Demo places already present, skipped")
            return
        }
        val outcome = imports.importStandaloneVenues(places.contentAsByteArray)
        check(outcome is ImportOutcome.Imported) { "Demo places are invalid" }
        log.info("Demo places loaded: venues={}", outcome.upserted)
    }

    private companion object {
        val log = LoggerFactory.getLogger(DemoCatalogLoader::class.java)
    }
}
