package ru.normaryadom.intake

import org.assertj.core.api.Assertions.assertThat
import org.hamcrest.Matchers.hasItem
import org.hamcrest.Matchers.not
import org.junit.jupiter.api.Test
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.http.MediaType
import org.springframework.test.web.servlet.get
import org.springframework.test.web.servlet.post
import org.springframework.test.web.servlet.request.RequestPostProcessor
import ru.normaryadom.catalog.importing.VenueCsvParser
import ru.normaryadom.catalog.service.CatalogImportService
import ru.normaryadom.intake.report.VenueReviewService
import ru.normaryadom.support.CatalogFixtures.Companion.CITY_LAT
import ru.normaryadom.support.CatalogFixtures.Companion.CITY_LON
import ru.normaryadom.support.CatalogFixtures.Companion.GRILL_MENU
import ru.normaryadom.support.CatalogFixtures.Companion.GRILL_VENUES
import ru.normaryadom.support.IntegrationTest
import java.time.LocalDate

class VenueReportApiIT : IntegrationTest() {
    @Autowired
    private lateinit var reviews: VenueReviewService

    @Autowired
    private lateinit var imports: CatalogImportService

    @Test
    fun `после сообщений от трёх разных людей убирает точку из поиска рядом и ставит в очередь проверки`() {
        catalog.chain("Гриль", GRILL_MENU, GRILL_VENUES)
        val venueId = venueId("Гриль, Сити")

        report(venueId, "closed")
        report(venueId, "moved")
        nearby().andExpect { jsonPath("$.venues[*].venue.name") { value(hasItem("Гриль, Сити")) } }
        report(venueId, "closed")

        nearby().andExpect { jsonPath("$.venues[*].venue.name") { value(not(hasItem("Гриль, Сити"))) } }
        assertThat(reviews.cases().map { it.venue.id }).containsExactly(venueId)
        assertThat(
            reviews
                .cases()
                .single()
                .reasons
                .mapKeys { it.key.code },
        ).containsEntry("closed", 2).containsEntry("moved", 1)
    }

    @Test
    fun `считает повторные сообщения одного человека за одно`() {
        catalog.chain("Гриль", GRILL_MENU, GRILL_VENUES)
        val venueId = venueId("Гриль, Сити")
        val sameClient = uniqueClient()

        repeat(3) { report(venueId, "closed", sameClient) }

        assertThat(jdbc.sql("SELECT count(*) FROM venue_report").query(Int::class.java).single()).isOne()
        assertThat(reviews.cases()).isEmpty()
    }

    @Test
    fun `возвращает точку в поиск и обновляет дату подтверждения, если модератор подтвердил, что она работает`() {
        catalog.chain("Гриль", GRILL_MENU, GRILL_VENUES)
        val venueId = venueId("Гриль, Сити")
        repeat(3) { report(venueId, "not_found") }

        reviews.restore(venueId)

        nearby().andExpect {
            jsonPath("$.venues[?(@.venue.name == 'Гриль, Сити')].venue.confirmedOn") { value(hasItem(LocalDate.now().toString())) }
        }
        assertThat(reviews.cases()).isEmpty()
        assertThat(jdbc.sql("SELECT count(*) FROM venue_report WHERE resolved_at IS NULL").query(Int::class.java).single()).isZero()
    }

    @Test
    fun `закрывает точку насовсем по решению модератора`() {
        catalog.chain("Гриль", GRILL_MENU, GRILL_VENUES)
        val venueId = venueId("Гриль, Сити")
        repeat(3) { report(venueId, "closed") }

        reviews.close(venueId)

        nearby().andExpect { jsonPath("$.venues[*].venue.name") { value(not(hasItem("Гриль, Сити"))) } }
        assertThat(reviews.cases()).isEmpty()
        mockMvc
            .post("/api/v1/venues/$venueId/reports") {
                contentType = MediaType.APPLICATION_JSON
                content = """{"reason": "closed"}"""
                with(uniqueClient())
            }.andExpect { status { isNotFound() } }
    }

    @Test
    fun `не возвращает закрытую модератором точку, когда сеть снова присылает её в списке точек`() {
        val chainId = catalog.chain("Гриль", GRILL_MENU, GRILL_VENUES)
        val venueId = venueId("Гриль, Сити")
        repeat(3) { report(venueId, "closed") }
        reviews.close(venueId)

        imports.importChainVenues(chainId, catalog.venueCsv(GRILL_VENUES))

        nearby().andExpect { jsonPath("$.venues[*].venue.name") { value(not(hasItem("Гриль, Сити"))) } }
    }

    @Test
    fun `возвращает закрытую точку, если источник подтвердил её позже решения модератора`() {
        val chainId = catalog.chain("Гриль", GRILL_MENU, GRILL_VENUES)
        val venueId = venueId("Гриль, Сити")
        repeat(3) { report(venueId, "closed") }
        reviews.close(venueId)
        val confirmedLater = LocalDate.now().plusDays(1)

        imports.importChainVenues(
            chainId,
            "${VenueCsvParser.HEADER.joinToString(";")};confirmed_on\n${GRILL_VENUES.first()};$confirmedLater".toByteArray(),
        )

        nearby().andExpect { jsonPath("$.venues[*].venue.name") { value(hasItem("Гриль, Сити")) } }
    }

    @Test
    fun `отклоняет неизвестную причину и сообщение о несуществующей точке`() {
        catalog.chain("Гриль", GRILL_MENU, GRILL_VENUES)

        mockMvc
            .post("/api/v1/venues/${venueId("Гриль, Сити")}/reports") {
                contentType = MediaType.APPLICATION_JSON
                content = """{"reason": "dirty"}"""
                with(uniqueClient())
            }.andExpect { status { isBadRequest() } }
        mockMvc
            .post("/api/v1/venues/${Long.MAX_VALUE}/reports") {
                contentType = MediaType.APPLICATION_JSON
                content = """{"reason": "closed"}"""
                with(uniqueClient())
            }.andExpect { status { isNotFound() } }
        assertThat(jdbc.sql("SELECT count(*) FROM venue_report").query(Int::class.java).single()).isZero()
    }

    private fun report(
        venueId: Long,
        reason: String,
        client: RequestPostProcessor = uniqueClient(),
    ) {
        mockMvc
            .post("/api/v1/venues/$venueId/reports") {
                contentType = MediaType.APPLICATION_JSON
                content = """{"reason": "$reason"}"""
                with(client)
            }.andExpect { status { isNoContent() } }
    }

    private fun nearby() =
        mockMvc.get("/api/v1/venues") {
            param("lat", "$CITY_LAT")
            param("lon", "$CITY_LON")
            param("radius", "30000")
        }

    private fun venueId(name: String): Long =
        jdbc
            .sql("SELECT id FROM venue WHERE name = :name")
            .param("name", name)
            .query(Long::class.java)
            .single()
}
