package ru.normaryadom.catalog

import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.boot.ApplicationArguments
import org.springframework.boot.DefaultApplicationArguments
import org.springframework.boot.context.properties.bind.Binder
import org.springframework.boot.env.YamlPropertySourceLoader
import org.springframework.core.env.StandardEnvironment
import org.springframework.core.io.ClassPathResource
import ru.normaryadom.catalog.demo.DemoCatalogLoader
import ru.normaryadom.catalog.demo.DemoCatalogProperties
import ru.normaryadom.catalog.persistence.VenueRepository
import ru.normaryadom.catalog.service.CatalogImportService
import ru.normaryadom.catalog.service.ChainService
import ru.normaryadom.support.IntegrationTest
import java.time.LocalDate

class DemoCatalogIT : IntegrationTest() {
    @Autowired
    private lateinit var chains: ChainService

    @Autowired
    private lateinit var imports: CatalogImportService

    @Autowired
    private lateinit var venues: VenueRepository

    @Test
    fun `демо-каталог валиден и загружается повторно без дублей`() {
        val loader = DemoCatalogLoader(demoProperties(), chains, imports, venues)
        val args: ApplicationArguments = DefaultApplicationArguments()

        loader.run(args)
        loader.run(args)

        assertThat(jdbc.sql("SELECT count(*) FROM chain WHERE template_code IS NULL").query(Int::class.java).single()).isEqualTo(116)
        assertThat(jdbc.sql("SELECT count(*) FROM chain WHERE template_code IS NOT NULL").query(Int::class.java).single()).isEqualTo(15)
        assertThat(jdbc.sql("SELECT count(*) FROM venue").query(Int::class.java).single()).isEqualTo(14604)
        assertThat(jdbc.sql("SELECT count(*) FROM venue WHERE chain_id IS NULL").query(Int::class.java).single()).isEqualTo(9567)
        assertThat(jdbc.sql("SELECT count(*) FROM venue WHERE template_id IS NOT NULL").query(Int::class.java).single()).isEqualTo(13158)
        assertThat(jdbc.sql("SELECT count(*) FROM venue WHERE confirmed_on IS NULL").query(Int::class.java).single()).isZero()
        assertThat(
            jdbc.sql("SELECT count(*) FROM menu_item WHERE is_available AND source_kind = 'A'").query(Int::class.java).single(),
        ).isEqualTo(3682)
        assertThat(
            jdbc.sql("SELECT count(*) FROM menu_item WHERE is_available AND source_kind = 'C'").query(Int::class.java).single(),
        ).isEqualTo(166)
    }

    @Test
    fun `меню сетей помечено датой официального источника, а не датой загрузки`() {
        DemoCatalogLoader(demoProperties(), chains, imports, venues).run(DefaultApplicationArguments())

        val verified =
            jdbc
                .sql(
                    """
                    SELECT DISTINCT c.name, i.verified_at::date AS verified
                    FROM menu_item i JOIN chain c ON c.id = i.chain_id
                    """,
                ).query { rs, _ -> rs.getString("name") to rs.getObject("verified", LocalDate::class.java) }
                .list()
                .toMap()
        assertThat(verified)
            .containsEntry("Бургер Кинг", LocalDate.of(2024, 8, 13))
            .containsEntry("Cofix", LocalDate.of(2026, 10, 15))
    }

    private fun demoProperties(): DemoCatalogProperties {
        val environment = StandardEnvironment()
        YamlPropertySourceLoader()
            .load("demo", ClassPathResource("application-demo.yml"))
            .forEach(environment.propertySources::addLast)
        return Binder.get(environment).bind("demo", DemoCatalogProperties::class.java).get()
    }
}
