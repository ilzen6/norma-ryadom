package ru.normaryadom.recommendation

import org.assertj.core.api.Assertions.assertThat
import org.hamcrest.Matchers.allOf
import org.hamcrest.Matchers.greaterThan
import org.hamcrest.Matchers.hasItem
import org.hamcrest.Matchers.lessThanOrEqualTo
import org.hamcrest.Matchers.not
import org.junit.jupiter.api.Test
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.cache.CacheManager
import org.springframework.http.MediaType
import org.springframework.test.web.servlet.post
import ru.normaryadom.catalog.service.CatalogImportService
import ru.normaryadom.support.CatalogFixtures.Companion.BOWL_MENU
import ru.normaryadom.support.CatalogFixtures.Companion.BOWL_VENUES
import ru.normaryadom.support.CatalogFixtures.Companion.CITY_LAT
import ru.normaryadom.support.CatalogFixtures.Companion.CITY_LON
import ru.normaryadom.support.CatalogFixtures.Companion.GRILL_MENU
import ru.normaryadom.support.CatalogFixtures.Companion.GRILL_VENUES
import ru.normaryadom.support.CatalogFixtures.Companion.SOURCE_URL
import ru.normaryadom.support.IntegrationTest
import com.github.benmanes.caffeine.cache.Cache as CaffeineCache

class ComboApiIT : IntegrationTest() {
    @Autowired
    private lateinit var cacheManager: CacheManager

    @Autowired
    private lateinit var imports: CatalogImportService

    @Test
    fun `подбирает наборы в заведении и объясняет каждый показатель`() {
        catalog.chain("Гриль", GRILL_MENU, GRILL_VENUES)

        mockMvc
            .post("/api/v1/combos/search") {
                contentType = MediaType.APPLICATION_JSON
                content = """{"target": $TARGET, "venueId": ${venueId("grill-01")}, "limit": 3}"""
            }.andExpect {
                status { isOk() }
                jsonPath("$.appliedTarget.kcal") { value(600.0) }
                jsonPath("$.options.length()") { value(allOf(greaterThan(1), lessThanOrEqualTo(3))) }
                jsonPath("$.options[0].venue.name") { value("Гриль, Сити") }
                jsonPath("$.options[0].distanceMeters") { doesNotExist() }
                jsonPath("$.options[0].combo.dishes[*].name") { value(hasItem("Куриная грудка гриль")) }
                jsonPath("$.options[0].combo.checks.length()") { value(4) }
                jsonPath("$.options[0].combo.checks[0].metric") { value("KCAL") }
                jsonPath("$.options[0].combo.checks[0].status") { value("OK") }
                jsonPath("$.options[0].combo.sourceKind") { value("A") }
                jsonPath("$.options[*].combo.dishes[*].name") { value(not(hasItem("Свиные рёбрышки"))) }
            }
    }

    @Test
    fun `подбирает рядом по сетям, ранжируя по качеству набора и расстоянию`() {
        catalog.chain("Гриль", GRILL_MENU, GRILL_VENUES)
        catalog.chain("Боулы", BOWL_MENU, BOWL_VENUES)

        mockMvc
            .post("/api/v1/combos/search") {
                contentType = MediaType.APPLICATION_JSON
                content = """{"target": $TARGET, "location": {"lat": $CITY_LAT, "lon": $CITY_LON, "radiusMeters": 1500}, "limit": 5}"""
            }.andExpect {
                status { isOk() }
                jsonPath("$.options[0].distanceMeters") { exists() }
                jsonPath("$.options[*].venue.name") { value(hasItem("Гриль, Сити")) }
                jsonPath("$.options[*].venue.name") { value(not(hasItem("Гриль, Тверская"))) }
            }
        assertThat(cachedEntries()).isPositive()
    }

    @Test
    fun `после обновления меню сети отдаёт новый подбор, а не устаревший кэш`() {
        val chainId = catalog.chain("Гриль", GRILL_MENU, GRILL_VENUES)
        val request = """{"target": $TARGET, "location": {"lat": $CITY_LAT, "lon": $CITY_LON, "radiusMeters": 1000}}"""
        mockMvc.post("/api/v1/combos/search") {
            contentType = MediaType.APPLICATION_JSON
            content = request
        }

        imports.importChainMenu(chainId, catalog.menuCsv(listOf("Новый боул;main;300;600;40;15;60;399;")), SOURCE_URL)

        mockMvc
            .post("/api/v1/combos/search") {
                contentType = MediaType.APPLICATION_JSON
                content = request
            }.andExpect {
                jsonPath("$.options[0].combo.dishes[0].name") { value("Новый боул") }
                jsonPath("$.options.length()") { value(1) }
            }
    }

    @Test
    fun `заменяет напиток в наборе, оставляя основное блюдо`() {
        catalog.chain("Гриль", GRILL_MENU, GRILL_VENUES)
        val chicken = itemId("Куриная грудка гриль")
        val rice = itemId("Рис с овощами")
        val mors = itemId("Морс")

        mockMvc
            .post("/api/v1/combos/replace") {
                contentType = MediaType.APPLICATION_JSON
                content =
                    """{"venueId": ${venueId("grill-01")}, "target": $WIDE_TARGET,
                    "dishIds": [$chicken, $rice, $mors], "replaceIndex": 2}"""
            }.andExpect {
                status { isOk() }
                jsonPath("$.options[0].combo.dishes[0].id") { value(chicken) }
                jsonPath("$.options[0].combo.dishes[1].id") { value(rice) }
                jsonPath("$.options[*].combo.dishes[2].id") { value(not(hasItem(mors.toInt()))) }
                jsonPath("$.options[*].combo.dishes[2].name") { value(hasItem("Чай")) }
            }
    }

    @Test
    fun `отклоняет замену блюдом не из этого заведения и неверный индекс`() {
        catalog.chain("Гриль", GRILL_MENU, GRILL_VENUES)
        catalog.chain("Боулы", BOWL_MENU, BOWL_VENUES)
        val bowl = itemId("Боул с курицей")

        mockMvc
            .post("/api/v1/combos/replace") {
                contentType = MediaType.APPLICATION_JSON
                content = """{"venueId": ${venueId("grill-01")}, "target": $TARGET, "dishIds": [$bowl], "replaceIndex": 0}"""
            }.andExpect {
                status { isUnprocessableContent() }
                jsonPath("$.type") { value("urn:norma-ryadom:problem:dish-not-in-menu") }
                jsonPath("$.dishIds[0]") { value(bowl) }
            }
        mockMvc
            .post("/api/v1/combos/replace") {
                contentType = MediaType.APPLICATION_JSON
                content = """{"venueId": ${venueId("grill-01")}, "target": $TARGET, "dishIds": [${itemId("Морс")}], "replaceIndex": 1}"""
            }.andExpect {
                status { isBadRequest() }
                jsonPath("$.errors[0].field") { value("replaceIndex") }
            }
    }

    @Test
    fun `требует ровно одну область поиска и проверяет границы цели`() {
        mockMvc
            .post("/api/v1/combos/search") {
                contentType = MediaType.APPLICATION_JSON
                content =
                    """{"target": {"kcal": 50, "kcalTolerance": 60, "minProtein": 30, "maxFat": 25, "maxCarbs": 90,
                    "excludeTags": ["pork"]}, "limit": 6}"""
            }.andExpect {
                status { isBadRequest() }
                content { contentType("application/problem+json") }
                jsonPath("$.errors[*].field") { value(hasItem("target.kcal")) }
                jsonPath("$.errors[*].field") { value(hasItem("limit")) }
                jsonPath("$.errors[*].field") { value(hasItem("singleSearchArea")) }
            }
        mockMvc
            .post("/api/v1/combos/search") {
                contentType = MediaType.APPLICATION_JSON
                content = """{"target": $TARGET, "venueId": 1, "location": {"lat": 55, "lon": 37, "radiusMeters": 6000}}"""
            }.andExpect {
                status { isBadRequest() }
                jsonPath("$.errors[*].field") { value(hasItem("location.radiusMeters")) }
                jsonPath("$.errors[*].field") { value(hasItem("singleSearchArea")) }
            }
    }

    @Test
    fun `называет отсутствующее поле и неизвестный тег в теле запроса`() {
        mockMvc
            .post("/api/v1/combos/search") {
                contentType = MediaType.APPLICATION_JSON
                content = """{"target": {"kcalTolerance": 60, "minProtein": 30, "maxFat": 25, "maxCarbs": 90}, "venueId": 1}"""
            }.andExpect {
                status { isBadRequest() }
                jsonPath("$.errors[0].field") { value("target.kcal") }
            }
        mockMvc
            .post("/api/v1/combos/search") {
                contentType = MediaType.APPLICATION_JSON
                content = """{"target": {"kcal": 600, "kcalTolerance": 60, "minProtein": 30, "maxFat": 25, "maxCarbs": 90,
                    "excludeTags": ["bacon"]}, "venueId": 1}"""
            }.andExpect {
                status { isBadRequest() }
                jsonPath("$.errors[0].field") { value("target.excludeTags[0]") }
            }
        mockMvc
            .post("/api/v1/combos/search") {
                contentType = MediaType.APPLICATION_JSON
                content = "{not json"
            }.andExpect {
                status { isBadRequest() }
                jsonPath("$.errors[0].field") { value("body") }
            }
    }

    @Test
    fun `возвращает 404 при подборе в неизвестном заведении`() {
        mockMvc
            .post("/api/v1/combos/search") {
                contentType = MediaType.APPLICATION_JSON
                content = """{"target": $TARGET, "venueId": ${Long.MAX_VALUE}}"""
            }.andExpect { status { isNotFound() } }
    }

    private fun cachedEntries(): Long {
        val cache = cacheManager.getCache("bestCombos")?.nativeCache as CaffeineCache<*, *>
        return cache.estimatedSize()
    }

    private fun venueId(externalId: String): Long =
        jdbc
            .sql("SELECT id FROM venue WHERE external_id = :externalId")
            .param("externalId", externalId)
            .query(Long::class.java)
            .single()

    private fun itemId(name: String): Long =
        jdbc
            .sql("SELECT id FROM menu_item WHERE name = :name")
            .param("name", name)
            .query(Long::class.java)
            .single()

    private companion object {
        const val TARGET = """{"kcal": 600, "kcalTolerance": 60, "minProtein": 30, "maxFat": 25, "maxCarbs": 90, "excludeTags": ["pork"]}"""
        const val WIDE_TARGET = """{"kcal": 600, "kcalTolerance": 150, "minProtein": 30, "maxFat": 25, "maxCarbs": 90}"""
    }
}
