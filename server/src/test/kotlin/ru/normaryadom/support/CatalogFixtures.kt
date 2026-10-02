package ru.normaryadom.support

import org.springframework.boot.test.context.TestComponent
import ru.normaryadom.catalog.importing.MenuCsvParser
import ru.normaryadom.catalog.importing.VenueCsvParser
import ru.normaryadom.catalog.service.CatalogImportService
import ru.normaryadom.catalog.service.ChainService
import ru.normaryadom.catalog.service.ImportOutcome

@TestComponent
class CatalogFixtures(
    private val chains: ChainService,
    private val imports: CatalogImportService,
) {
    fun chain(
        name: String,
        menu: List<String>,
        venues: List<String>,
    ): Long {
        val chainId = chains.create(name, SOURCE_URL)
        val menuOutcome = imports.importChainMenu(chainId, menuCsv(menu), SOURCE_URL)
        val venueOutcome = imports.importChainVenues(chainId, venueCsv(venues))
        check(menuOutcome is ImportOutcome.Imported && venueOutcome is ImportOutcome.Imported) { "Fixture catalog is invalid" }
        return chainId
    }

    fun menuCsv(rows: List<String>): ByteArray = (listOf(MenuCsvParser.HEADER.joinToString(";")) + rows).joinToString("\n").toByteArray()

    fun venueCsv(rows: List<String>): ByteArray = (listOf(VenueCsvParser.HEADER.joinToString(";")) + rows).joinToString("\n").toByteArray()

    companion object {
        const val SOURCE_URL = "https://chain.example/nutrition"
        const val CITY_LAT = 55.7495
        const val CITY_LON = 37.5374

        val GRILL_MENU =
            listOf(
                "Куриная грудка гриль;main;160;374;38;6;2;299;chicken",
                "Свиные рёбрышки;main;250;624;39;48;9;489;pork",
                "Рис с овощами;side;150;207;4;3;41;119;",
                "Салат овощной;salad;180;129;3;9;9;189;",
                "Морс;drink;300;96;0;0;24;119;",
                "Чай;drink;300;0;0;0;0;99;",
                "Соус барбекю;sauce;30;48;0;0;12;49;",
            )

        val GRILL_VENUES =
            listOf(
                "Гриль, Сити;Пресненская наб., 2;55.7496;37.5397;grill-01",
                "Гриль, Тверская;Тверская, 18;55.7663;37.6046;grill-02",
            )

        val BOWL_MENU =
            listOf(
                "Боул с курицей;main;320;446;34;14;46;389;chicken",
                "Боул с тофу;main;300;387;19;15;44;339;soy",
                "Морс брусничный;drink;300;84;0;0;21;109;",
            )

        val BOWL_VENUES = listOf("Боулы, Сити;Пресненская наб., 10;55.7480;37.5376;bowl-01")
    }
}
