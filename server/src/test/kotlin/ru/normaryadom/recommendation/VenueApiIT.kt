package ru.normaryadom.recommendation

import org.hamcrest.Matchers.hasItem
import org.hamcrest.Matchers.not
import org.junit.jupiter.api.Test
import org.springframework.test.web.servlet.get
import ru.normaryadom.support.CatalogFixtures.Companion.BOWL_MENU
import ru.normaryadom.support.CatalogFixtures.Companion.BOWL_VENUES
import ru.normaryadom.support.CatalogFixtures.Companion.CITY_LAT
import ru.normaryadom.support.CatalogFixtures.Companion.CITY_LON
import ru.normaryadom.support.CatalogFixtures.Companion.GRILL_MENU
import ru.normaryadom.support.CatalogFixtures.Companion.GRILL_VENUES
import ru.normaryadom.support.IntegrationTest

class VenueApiIT : IntegrationTest() {
    @Test
    fun `отдаёт заведения рядом с отметкой о наличии меню`() {
        catalog.chain("Гриль", GRILL_MENU, GRILL_VENUES)

        mockMvc
            .get("/api/v1/venues") {
                param("lat", "$CITY_LAT")
                param("lon", "$CITY_LON")
                param("radius", "1000")
            }.andExpect {
                status { isOk() }
                jsonPath("$.venues.length()") { value(1) }
                jsonPath("$.venues[0].venue.name") { value("Гриль, Сити") }
                jsonPath("$.venues[0].venue.chainName") { value("Гриль") }
                jsonPath("$.venues[0].venue.currency") { value("RUB") }
                jsonPath("$.venues[0].distanceMeters") { value(145) }
                jsonPath("$.venues[0].hasMenu") { value(true) }
                jsonPath("$.venues[0].fit") { doesNotExist() }
            }
    }

    @Test
    fun `отдаёт не больше заведений, чем просит параметр limit, начиная с ближайших`() {
        catalog.chain("Гриль", GRILL_MENU, GRILL_VENUES)
        catalog.chain("Боулы", BOWL_MENU, BOWL_VENUES)

        mockMvc
            .get("/api/v1/venues") {
                param("lat", "$CITY_LAT")
                param("lon", "$CITY_LON")
                param("radius", "30000")
                param("limit", "1")
            }.andExpect {
                status { isOk() }
                jsonPath("$.venues.length()") { value(1) }
            }
    }

    @Test
    fun `красит точки по лучшему набору под цель`() {
        catalog.chain("Гриль", GRILL_MENU, GRILL_VENUES)
        catalog.chain("Боулы", BOWL_MENU, BOWL_VENUES)

        mockMvc
            .get("/api/v1/venues") {
                param("lat", "$CITY_LAT")
                param("lon", "$CITY_LON")
                param("radius", "1000")
                param("kcal", "600")
                param("kcalTolerance", "50")
                param("minProtein", "35")
                param("maxFat", "25")
                param("maxCarbs", "90")
            }.andExpect {
                status { isOk() }
                jsonPath("$.venues[?(@.venue.name == 'Гриль, Сити')].fit") { value("GOOD") }
                jsonPath("$.venues[?(@.venue.name == 'Боулы, Сити')].fit") { value("COMPROMISE") }
            }
    }

    @Test
    fun `отмечает серым заведение, где нет даже компромиссного набора`() {
        catalog.chain("Боулы", BOWL_MENU, BOWL_VENUES)

        mockMvc
            .get("/api/v1/venues") {
                param("lat", "$CITY_LAT")
                param("lon", "$CITY_LON")
                param("radius", "1000")
                param("kcal", "1500")
                param("kcalTolerance", "50")
                param("minProtein", "100")
                param("maxFat", "10")
                param("maxCarbs", "50")
            }.andExpect { jsonPath("$.venues[0].fit") { value("NONE") } }
    }

    @Test
    fun `отмечает заведение сети с официальной таблицей КБЖУ уровнем данных A`() {
        catalog.chain("Гриль", GRILL_MENU, GRILL_VENUES)

        mockMvc
            .get("/api/v1/venues") {
                param("lat", "$CITY_LAT")
                param("lon", "$CITY_LON")
                param("radius", "1000")
            }.andExpect { jsonPath("$.venues[0].dataQuality") { value("A") } }
    }

    @Test
    fun `не даёт уровень данных заведению без доступных блюд`() {
        catalog.chain("Гриль", GRILL_MENU, GRILL_VENUES)
        jdbc.sql("UPDATE menu_item SET is_available = FALSE").update()

        mockMvc
            .get("/api/v1/venues") {
                param("lat", "$CITY_LAT")
                param("lon", "$CITY_LON")
                param("radius", "1000")
                param("includeWithoutMenu", "true")
            }.andExpect {
                jsonPath("$.venues[0].hasMenu") { value(false) }
                jsonPath("$.venues[0].dataQuality") { doesNotExist() }
            }
    }

    @Test
    fun `отдаёт меню заведения с уровнем доверия, без цели - без пометок`() {
        catalog.chain("Гриль", GRILL_MENU, GRILL_VENUES)
        val venueId = venueId("grill-01")

        mockMvc.get("/api/v1/venues/$venueId/menu").andExpect {
            status { isOk() }
            jsonPath("$.venue.id") { value(venueId) }
            jsonPath("$.items.length()") { value(GRILL_MENU.size) }
            jsonPath("$.items[0].source.kind") { value("A") }
            jsonPath("$.items[0].source.url") { value("https://chain.example/nutrition") }
            jsonPath("$.items[0].assessment") { doesNotExist() }
        }
    }

    @Test
    fun `сортирует меню по близости к цели и объясняет, почему блюдо не подходит`() {
        catalog.chain("Гриль", GRILL_MENU, GRILL_VENUES)

        mockMvc
            .get("/api/v1/venues/${venueId("grill-01")}/menu") {
                param("kcal", "500")
                param("kcalTolerance", "60")
                param("minProtein", "30")
                param("maxFat", "20")
                param("maxCarbs", "80")
                param("excludeTags", "pork")
            }.andExpect {
                status { isOk() }
                jsonPath("$.items[0].name") { value("Куриная грудка гриль") }
                jsonPath("$.items[0].assessment.verdict") { value("FITS") }
                jsonPath("$.items[?(@.name == 'Свиные рёбрышки')].assessment.verdict") { value("NOT_FITS") }
                jsonPath("$.items[?(@.name == 'Свиные рёбрышки')].assessment.reasons[0].code") { value("EXCLUDED_TAG") }
                jsonPath("$.items[?(@.name == 'Свиные рёбрышки')].assessment.reasons[0].tag") { value("pork") }
                jsonPath("$.items[-1].assessment.verdict") { value("NOT_FITS") }
            }
    }

    @Test
    fun `не показывает в меню снятые с продажи и проверяемые блюда`() {
        catalog.chain("Гриль", GRILL_MENU, GRILL_VENUES)
        jdbc.sql("UPDATE menu_item SET is_available = FALSE WHERE name = 'Чай'").update()
        jdbc.sql("UPDATE menu_item SET under_review = TRUE WHERE name = 'Морс'").update()

        mockMvc.get("/api/v1/venues/${venueId("grill-01")}/menu").andExpect {
            jsonPath("$.items[*].name") { value(not(hasItem("Чай"))) }
            jsonPath("$.items[*].name") { value(not(hasItem("Морс"))) }
        }
    }

    @Test
    fun `возвращает 404 для неизвестного или неактивного заведения`() {
        catalog.chain("Гриль", GRILL_MENU, GRILL_VENUES)
        jdbc.sql("UPDATE venue SET is_active = FALSE WHERE external_id = 'grill-02'").update()

        listOf(Long.MAX_VALUE, venueId("grill-02")).forEach { id ->
            mockMvc.get("/api/v1/venues/$id/menu").andExpect {
                status { isNotFound() }
                content { contentType("application/problem+json") }
                jsonPath("$.type") { value("urn:norma-ryadom:problem:not-found") }
                jsonPath("$.resource") { value("venue") }
            }
        }
    }

    @Test
    fun `проверяет координаты, радиус и полноту цели`() {
        mockMvc
            .get("/api/v1/venues") {
                param("lat", "91")
                param("lon", "37")
                param("radius", "30001")
                param("limit", "501")
            }.andExpect {
                status { isBadRequest() }
                jsonPath("$.type") { value("urn:norma-ryadom:problem:validation") }
                jsonPath("$.errors[*].field") { value(hasItem("lat")) }
                jsonPath("$.errors[*].field") { value(hasItem("radius")) }
                jsonPath("$.errors[*].field") { value(hasItem("limit")) }
            }
        mockMvc.get("/api/v1/venues") { param("lat", "55") }.andExpect {
            status { isBadRequest() }
            jsonPath("$.errors[0].field") { value("lon") }
        }
        mockMvc
            .get("/api/v1/venues") {
                param("lat", "55")
                param("lon", "37")
                param("radius", "500")
                param("excludeTags", "bacon")
            }.andExpect {
                status { isBadRequest() }
                jsonPath("$.errors[0].field") { value("excludeTags") }
                jsonPath("$.errors[0].message") { value("имеет неверное значение") }
            }
        mockMvc.get("/api/v1/venues/abc/menu").andExpect { status { isBadRequest() } }
    }

    private fun venueId(externalId: String): Long =
        jdbc
            .sql("SELECT id FROM venue WHERE external_id = :externalId")
            .param("externalId", externalId)
            .query(Long::class.java)
            .single()
}
