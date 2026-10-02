package ru.normaryadom.catalog

import org.assertj.core.api.Assertions.assertThat
import org.assertj.core.api.Assertions.assertThatThrownBy
import org.junit.jupiter.api.Test
import org.springframework.beans.factory.annotation.Autowired
import ru.normaryadom.catalog.domain.DietTag
import ru.normaryadom.catalog.domain.SourceKind
import ru.normaryadom.catalog.importing.CsvErrorCode
import ru.normaryadom.catalog.service.CatalogImportService
import ru.normaryadom.catalog.service.ChainNameTakenException
import ru.normaryadom.catalog.service.ChainNotFoundException
import ru.normaryadom.catalog.service.ChainService
import ru.normaryadom.catalog.service.ImportOutcome
import ru.normaryadom.support.CatalogFixtures
import ru.normaryadom.support.CatalogFixtures.Companion.GRILL_MENU
import ru.normaryadom.support.CatalogFixtures.Companion.GRILL_VENUES
import ru.normaryadom.support.IntegrationTest

class CatalogImportIT : IntegrationTest() {
    @Autowired
    private lateinit var chains: ChainService

    @Autowired
    private lateinit var imports: CatalogImportService

    @Test
    fun `импортирует меню сети с уровнем доверия A и ссылкой на источник`() {
        val chainId = catalog.chain("Гриль", GRILL_MENU, GRILL_VENUES)

        val items = chains.items(chainId)

        assertThat(items).hasSize(GRILL_MENU.size).allSatisfy {
            assertThat(it.item.source.kind).isEqualTo(SourceKind.A)
            assertThat(it.item.source.url).isEqualTo(CatalogFixtures.SOURCE_URL)
            assertThat(it.item.source.verifiedAt).isNotNull()
        }
        assertThat(items.first { it.item.name == "Свиные рёбрышки" }.item.tags).containsExactlyInAnyOrder(DietTag.PORK, DietTag.MEAT)
        assertThat(chains.venues(chainId)).hasSize(2)
        assertThat(chains.get(chainId).menuVersion).isEqualTo(1)
    }

    @Test
    fun `при повторном импорте обновляет блюда, снимает пропавшие и повышает версию меню`() {
        val chainId = catalog.chain("Гриль", GRILL_MENU, GRILL_VENUES)
        val updated = GRILL_MENU.filterNot { it.startsWith("Чай") }.map { it.replace("Морс;drink;300;96", "Морс;drink;300;110") }

        val outcome = imports.importChainMenu(chainId, catalog.menuCsv(updated), "https://chain.example/v2")

        assertThat(outcome).isEqualTo(ImportOutcome.Imported(upserted = GRILL_MENU.size - 1, withdrawn = 1))
        val items = chains.items(chainId).associateBy { it.item.name }
        assertThat(items.getValue("Чай").isAvailable).isFalse()
        assertThat(
            items
                .getValue("Морс")
                .item.nutrients.kcal,
        ).isEqualTo(110.0)
        assertThat(chains.get(chainId).menuVersion).isEqualTo(2)
        assertThat(chains.get(chainId).sourceUrl).isEqualTo("https://chain.example/v2")
    }

    @Test
    fun `не меняет базу, если в файле есть хотя бы одна ошибка`() {
        val chainId = catalog.chain("Гриль", GRILL_MENU, GRILL_VENUES)

        val csv = catalog.menuCsv(listOf("Новое;main;200;300;20;10;30;100;", "Сломанное;main;;x;1;1;1;;"))

        val outcome = imports.importChainMenu(chainId, csv, "https://x.example")

        assertThat((outcome as ImportOutcome.Rejected).errors.map { it.code }).contains(CsvErrorCode.NOT_A_NUMBER)
        assertThat(chains.items(chainId).map { it.item.name }).doesNotContain("Новое")
        assertThat(chains.get(chainId).menuVersion).isEqualTo(1)
    }

    @Test
    fun `повторный импорт точек обновляет их по внешнему идентификатору без дублей`() {
        val chainId = catalog.chain("Гриль", GRILL_MENU, GRILL_VENUES)

        val moved = "Гриль, Сити (новый адрес);Пресненская наб., 4;55.7497;37.5398;grill-01"

        imports.importChainVenues(chainId, catalog.venueCsv(listOf(moved)))

        val venues = chains.venues(chainId)
        assertThat(venues).hasSize(2)
        assertThat(venues.first { it.address == "Пресненская наб., 4" }.name).isEqualTo("Гриль, Сити (новый адрес)")
    }

    @Test
    fun `не создаёт вторую сеть с тем же названием и не импортирует в несуществующую`() {
        chains.create("Гриль", null)

        assertThatThrownBy { chains.create(" Гриль ", null) }.isInstanceOf(ChainNameTakenException::class.java)
        assertThatThrownBy { imports.importChainMenu(-1, catalog.menuCsv(GRILL_MENU), "https://x.example") }
            .isInstanceOf(ChainNotFoundException::class.java)
        assertThatThrownBy { imports.importChainVenues(-1, catalog.venueCsv(GRILL_VENUES)) }
            .isInstanceOf(ChainNotFoundException::class.java)
    }
}
