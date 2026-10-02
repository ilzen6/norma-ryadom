package ru.normaryadom.catalog.demo

import org.slf4j.LoggerFactory
import org.springframework.boot.ApplicationArguments
import org.springframework.boot.ApplicationRunner
import org.springframework.context.annotation.Profile
import org.springframework.stereotype.Component
import ru.normaryadom.catalog.service.CatalogImportService
import ru.normaryadom.catalog.service.ChainService
import ru.normaryadom.catalog.service.ImportOutcome

@Component
@Profile("demo")
class DemoCatalogLoader(
    private val properties: DemoCatalogProperties,
    private val chains: ChainService,
    private val imports: CatalogImportService,
) : ApplicationRunner {
    override fun run(args: ApplicationArguments) {
        properties.chains.forEach { demo ->
            val chainId = chains.findByName(demo.name)?.id ?: chains.create(demo.name, demo.sourceUrl)
            val menu = imports.importChainMenu(chainId, demo.menu.getContentAsString(Charsets.UTF_8), demo.sourceUrl)
            val venues = imports.importChainVenues(chainId, demo.venues.getContentAsString(Charsets.UTF_8))
            check(menu is ImportOutcome.Imported && venues is ImportOutcome.Imported) { "Demo catalog for ${demo.name} is invalid" }
            log.info("Demo chain loaded: chainId={}, items={}, venues={}", chainId, menu.upserted, venues.upserted)
        }
    }

    private companion object {
        val log = LoggerFactory.getLogger(DemoCatalogLoader::class.java)
    }
}
