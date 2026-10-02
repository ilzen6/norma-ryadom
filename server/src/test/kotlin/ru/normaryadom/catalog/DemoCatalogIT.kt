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
import ru.normaryadom.catalog.service.CatalogImportService
import ru.normaryadom.catalog.service.ChainService
import ru.normaryadom.support.IntegrationTest

class DemoCatalogIT : IntegrationTest() {
    @Autowired
    private lateinit var chains: ChainService

    @Autowired
    private lateinit var imports: CatalogImportService

    @Test
    fun `демо-каталог валиден и загружается повторно без дублей`() {
        val loader = DemoCatalogLoader(demoProperties(), chains, imports)
        val args: ApplicationArguments = DefaultApplicationArguments()

        loader.run(args)
        loader.run(args)

        assertThat(jdbc.sql("SELECT count(*) FROM chain").query(Int::class.java).single()).isEqualTo(10)
        assertThat(jdbc.sql("SELECT count(*) FROM venue").query(Int::class.java).single()).isEqualTo(349)
        assertThat(jdbc.sql("SELECT count(*) FROM menu_item WHERE is_available").query(Int::class.java).single()).isEqualTo(217)
    }

    private fun demoProperties(): DemoCatalogProperties {
        val environment = StandardEnvironment()
        YamlPropertySourceLoader()
            .load("demo", ClassPathResource("application-demo.yml"))
            .forEach(environment.propertySources::addLast)
        return Binder.get(environment).bind("demo", DemoCatalogProperties::class.java).get()
    }
}
