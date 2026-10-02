package ru.normaryadom.intake

import org.assertj.core.api.Assertions.assertThat
import org.hamcrest.Matchers.hasItem
import org.hamcrest.Matchers.not
import org.junit.jupiter.api.Test
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.http.MediaType
import org.springframework.test.web.servlet.get
import org.springframework.test.web.servlet.post
import ru.normaryadom.intake.report.ItemReportService
import ru.normaryadom.support.CatalogFixtures.Companion.CITY_LAT
import ru.normaryadom.support.CatalogFixtures.Companion.CITY_LON
import ru.normaryadom.support.CatalogFixtures.Companion.GRILL_MENU
import ru.normaryadom.support.CatalogFixtures.Companion.GRILL_VENUES
import ru.normaryadom.support.IntegrationTest
import java.util.concurrent.CountDownLatch
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit

class ItemReportApiIT : IntegrationTest() {
    @Autowired
    private lateinit var reports: ItemReportService

    @Test
    fun `после трёх жалоб отправляет блюдо на перепроверку и убирает его из подбора`() {
        catalog.chain("Гриль", GRILL_MENU, GRILL_VENUES)
        val itemId = itemId("Куриная грудка гриль")

        repeat(2) { report(itemId, "Калорий явно больше") }
        assertThat(underReview(itemId)).isFalse()
        report(itemId, "На стенде другие цифры")

        assertThat(underReview(itemId)).isTrue()
        assertThat(chainMenuVersion()).isEqualTo(2)
        mockMvc.get("/api/v1/venues/${venueId()}/menu").andExpect {
            jsonPath("$.items[*].name") { value(not(hasItem("Куриная грудка гриль"))) }
        }
    }

    @Test
    fun `убирает блюдо из подбора рядом, даже если результат уже был в кэше`() {
        catalog.chain("Гриль", GRILL_MENU, GRILL_VENUES)
        val itemId = itemId("Куриная грудка гриль")
        nearbySearch().andExpect { jsonPath("$.options[*].combo.dishes[*].name") { value(hasItem("Куриная грудка гриль")) } }

        repeat(3) { report(itemId, "Цифры не совпадают") }

        nearbySearch().andExpect { jsonPath("$.options[*].combo.dishes[*].name") { value(not(hasItem("Куриная грудка гриль"))) } }
    }

    @Test
    fun `считает повторные жалобы одного человека за одну`() {
        catalog.chain("Гриль", GRILL_MENU, GRILL_VENUES)
        val itemId = itemId("Морс")
        val sameClient = uniqueClient()

        repeat(3) {
            mockMvc
                .post("/api/v1/items/$itemId/reports") {
                    contentType = MediaType.APPLICATION_JSON
                    content = """{"reason": "Слишком сладкий"}"""
                    with(sameClient)
                }.andExpect { status { isNoContent() } }
        }

        assertThat(jdbc.sql("SELECT count(*) FROM item_report").query(Int::class.java).single()).isOne()
        assertThat(jdbc.sql("SELECT reporter_hash FROM item_report").query(String::class.java).single())
            .hasSize(64)
            .doesNotContain("10.")
        assertThat(underReview(itemId)).isFalse()
    }

    @Test
    fun `при одновременных жалобах отправляет блюдо на перепроверку ровно один раз`() {
        catalog.chain("Гриль", GRILL_MENU, GRILL_VENUES)
        val itemId = itemId("Рис с овощами")
        val start = CountDownLatch(1)
        val executor = Executors.newFixedThreadPool(PARALLEL_REPORTS)

        try {
            val results =
                (1..PARALLEL_REPORTS).map { client ->
                    executor.submit {
                        start.await()
                        reports.report(itemId, "Порция меньше", "10.200.0.$client")
                    }
                }
            start.countDown()
            results.forEach { it.get(30, TimeUnit.SECONDS) }
        } finally {
            executor.shutdownNow()
        }

        assertThat(jdbc.sql("SELECT count(*) FROM item_report").query(Int::class.java).single()).isEqualTo(PARALLEL_REPORTS)
        assertThat(underReview(itemId)).isTrue()
        assertThat(chainMenuVersion()).isEqualTo(2)
    }

    @Test
    fun `принимает жалобу без идентификатора пользователя и ответа в теле`() {
        catalog.chain("Гриль", GRILL_MENU, GRILL_VENUES)

        mockMvc
            .post("/api/v1/items/${itemId("Морс")}/reports") {
                contentType = MediaType.APPLICATION_JSON
                content = """{"reason": "  Сладкий, не 96 ккал  "}"""
                with(uniqueClient())
            }.andExpect {
                status { isNoContent() }
                content { string("") }
            }
        assertThat(jdbc.sql("SELECT reason FROM item_report").query(String::class.java).single()).isEqualTo("Сладкий, не 96 ккал")
    }

    @Test
    fun `отклоняет пустую причину и жалобу на неизвестное блюдо`() {
        catalog.chain("Гриль", GRILL_MENU, GRILL_VENUES)

        mockMvc
            .post("/api/v1/items/${itemId("Морс")}/reports") {
                contentType = MediaType.APPLICATION_JSON
                content = """{"reason": "   "}"""
            }.andExpect {
                status { isBadRequest() }
                jsonPath("$.errors[0].field") { value("reason") }
            }
        mockMvc
            .post("/api/v1/items/${Long.MAX_VALUE}/reports") {
                contentType = MediaType.APPLICATION_JSON
                content = """{"reason": "неверно"}"""
            }.andExpect { status { isNotFound() } }
        assertThat(jdbc.sql("SELECT count(*) FROM item_report").query(Int::class.java).single()).isZero()
    }

    private fun report(
        itemId: Long,
        reason: String,
    ) {
        mockMvc
            .post("/api/v1/items/$itemId/reports") {
                contentType = MediaType.APPLICATION_JSON
                content = """{"reason": "$reason"}"""
                with(uniqueClient())
            }.andExpect { status { isNoContent() } }
    }

    private fun nearbySearch() =
        mockMvc.post("/api/v1/combos/search") {
            contentType = MediaType.APPLICATION_JSON
            content =
                """{"target": {"kcal": 600, "kcalTolerance": 150, "minProtein": 20, "maxFat": 40, "maxCarbs": 120},
                "location": {"lat": $CITY_LAT, "lon": $CITY_LON, "radiusMeters": 1500}, "limit": 5}"""
        }

    private fun underReview(itemId: Long): Boolean =
        jdbc
            .sql("SELECT under_review FROM menu_item WHERE id = :id")
            .param("id", itemId)
            .query(Boolean::class.java)
            .single()

    private fun chainMenuVersion(): Long = jdbc.sql("SELECT menu_version FROM chain").query(Long::class.java).single()

    private fun venueId(): Long = jdbc.sql("SELECT id FROM venue WHERE external_id = 'grill-01'").query(Long::class.java).single()

    private fun itemId(name: String): Long =
        jdbc
            .sql("SELECT id FROM menu_item WHERE name = :name")
            .param("name", name)
            .query(Long::class.java)
            .single()

    private companion object {
        const val PARALLEL_REPORTS = 8
    }
}
