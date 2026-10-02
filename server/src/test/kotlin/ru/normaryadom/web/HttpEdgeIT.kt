package ru.normaryadom.web

import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.BeforeEach
import org.junit.jupiter.api.Test
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.boot.test.context.SpringBootTest
import org.springframework.boot.test.web.server.LocalServerPort
import org.springframework.context.annotation.Import
import org.springframework.jdbc.core.simple.JdbcClient
import org.springframework.test.context.ActiveProfiles
import ru.normaryadom.support.CatalogFixtures
import ru.normaryadom.support.CatalogFixtures.Companion.GRILL_MENU
import ru.normaryadom.support.CatalogFixtures.Companion.GRILL_VENUES
import ru.normaryadom.support.MenuPhotos
import ru.normaryadom.support.TestcontainersConfiguration
import java.net.URI
import java.net.http.HttpClient
import java.net.http.HttpRequest
import java.net.http.HttpResponse

@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
@ActiveProfiles("test")
@Import(TestcontainersConfiguration::class, CatalogFixtures::class)
class HttpEdgeIT {
    @LocalServerPort
    private var port = 0

    @Autowired
    private lateinit var jdbc: JdbcClient

    @Autowired
    private lateinit var catalog: CatalogFixtures

    private val http = HttpClient.newHttpClient()

    @BeforeEach
    fun cleanState() {
        jdbc.sql("TRUNCATE item_report, menu_submission, menu_item, venue, chain CASCADE").update()
    }

    @Test
    fun `отвечает Problem Details на настоящий multipart больше лимита сервера`() {
        val response = upload(grillVenue(), ByteArray(OVERSIZED_BYTES), forwardedFor = null)

        assertThat(response.statusCode()).isEqualTo(413)
        assertThat(response.headers().firstValue("Content-Type")).hasValueSatisfying {
            assertThat(it).startsWith("application/problem+json")
        }
        assertThat(response.body()).contains("urn:norma-ryadom:problem:photo-too-large")
        assertThat(jdbc.sql("SELECT count(*) FROM menu_submission").query(Int::class.java).single()).isZero()
    }

    @Test
    fun `не даёт обойти лимит загрузок подменой X-Forwarded-For`() {
        val venueId = grillVenue()
        val photo = MenuPhotos.withText(listOf("Борщ"))

        val statuses = (1..4).map { upload(venueId, photo, forwardedFor = "198.51.100.$it").statusCode() }

        assertThat(statuses).containsExactly(202, 202, 202, 429)
    }

    private fun upload(
        venueId: Long,
        photo: ByteArray,
        forwardedFor: String?,
    ): HttpResponse<String> {
        val head =
            "--$BOUNDARY\r\nContent-Disposition: form-data; name=\"photo\"; filename=\"menu.png\"\r\nContent-Type: image/png\r\n\r\n"
        val body = head.toByteArray() + photo + "\r\n--$BOUNDARY--\r\n".toByteArray()
        val request =
            HttpRequest
                .newBuilder(URI.create("http://localhost:$port/api/v1/venues/$venueId/menu-photos"))
                .header("Content-Type", "multipart/form-data; boundary=$BOUNDARY")
                .apply { forwardedFor?.let { header("X-Forwarded-For", it) } }
                .POST(HttpRequest.BodyPublishers.ofByteArray(body))
                .build()
        return http.send(request, HttpResponse.BodyHandlers.ofString())
    }

    private fun grillVenue(): Long {
        catalog.chain("Гриль", GRILL_MENU, GRILL_VENUES)
        return jdbc.sql("SELECT id FROM venue WHERE external_id = 'grill-01'").query(Long::class.java).single()
    }

    private companion object {
        const val BOUNDARY = "norma-boundary"
        const val OVERSIZED_BYTES = 9_500_000
    }
}
