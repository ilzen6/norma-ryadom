package ru.normaryadom.intake

import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.http.HttpHeaders
import org.springframework.mock.web.MockMultipartFile
import org.springframework.test.web.servlet.multipart
import ru.normaryadom.intake.ocr.MenuOcrProcessor
import ru.normaryadom.intake.photo.PhotoStorage
import ru.normaryadom.support.CatalogFixtures.Companion.GRILL_MENU
import ru.normaryadom.support.CatalogFixtures.Companion.GRILL_VENUES
import ru.normaryadom.support.IntegrationTest
import ru.normaryadom.support.MenuPhotos

class MenuPhotoApiIT : IntegrationTest() {
    @Autowired
    private lateinit var storage: PhotoStorage

    @Autowired
    private lateinit var ocr: MenuOcrProcessor

    @Test
    fun `принимает фото меню, кладёт его в хранилище и ставит в очередь распознавания`() {
        val venueId = grillVenue()
        val photo = MenuPhotos.withText(listOf("Борщ 250"))

        mockMvc
            .multipart("/api/v1/venues/$venueId/menu-photos") {
                file(MockMultipartFile("photo", "menu.png", "image/png", photo))
                with(uniqueClient())
            }.andExpect {
                status { isAccepted() }
                jsonPath("$.status") { value("NEW") }
                jsonPath("$.submissionId") { isNumber() }
            }

        val stored = jdbc.sql("SELECT photo_key, content_type, status FROM menu_submission").query().singleRow()
        assertThat(stored["status"]).isEqualTo("NEW")
        assertThat(stored["content_type"]).isEqualTo("image/png")
        assertThat(storage.get(stored["photo_key"] as String)).isEqualTo(photo)
    }

    @Test
    fun `распознаёт русский текст меню и оставляет его модератору`() {
        val venueId = grillVenue()
        upload(venueId, MenuPhotos.withText(listOf("Борщ со сметаной", "Белки 7 Жиры 11"), "jpg"), "menu.jpg")

        val processed = ocr.processPending()

        assertThat(processed).isEqualTo(1)
        val row = jdbc.sql("SELECT status, ocr_text FROM menu_submission").query().singleRow()
        assertThat(row["status"]).isEqualTo("OCR_DONE")
        assertThat(row["ocr_text"] as String).containsIgnoringCase("Борщ").contains("11")
    }

    @Test
    fun `помечает нераспознаваемое изображение, не теряя заявку`() {
        val venueId = grillVenue()
        upload(venueId, byteArrayOf(0x89.toByte(), 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 1, 2, 3), "broken.png")

        ocr.processPending()

        assertThat(jdbc.sql("SELECT status FROM menu_submission").query(String::class.java).single()).isEqualTo("OCR_FAILED")
    }

    @Test
    fun `проверяет тип файла по содержимому, а не по заявленному типу`() {
        val venueId = grillVenue()

        mockMvc
            .multipart("/api/v1/venues/$venueId/menu-photos") {
                file(MockMultipartFile("photo", "menu.png", "image/png", "GIF89a....".toByteArray()))
                with(uniqueClient())
            }.andExpect {
                status { isUnsupportedMediaType() }
                jsonPath("$.type") { value("urn:norma-ryadom:problem:unsupported-photo") }
            }
        assertThat(jdbc.sql("SELECT count(*) FROM menu_submission").query(Int::class.java).single()).isZero()
    }

    @Test
    fun `отклоняет слишком большое фото`() {
        val venueId = grillVenue()
        val huge = MenuPhotos.withText(listOf("x")) + ByteArray(9 * 1024 * 1024)

        mockMvc
            .multipart("/api/v1/venues/$venueId/menu-photos") {
                file(MockMultipartFile("photo", "menu.png", "image/png", huge))
                with(uniqueClient())
            }.andExpect {
                status { isContentTooLarge() }
                jsonPath("$.type") { value("urn:norma-ryadom:problem:photo-too-large") }
            }
    }

    @Test
    fun `возвращает 404 для неизвестного заведения и 400 без файла`() {
        mockMvc
            .multipart("/api/v1/venues/${Long.MAX_VALUE}/menu-photos") {
                file(MockMultipartFile("photo", "menu.png", "image/png", MenuPhotos.withText(listOf("x"))))
                with(uniqueClient())
            }.andExpect { status { isNotFound() } }
        mockMvc
            .multipart("/api/v1/venues/1/menu-photos") { with(uniqueClient()) }
            .andExpect { status { isBadRequest() } }
    }

    @Test
    fun `ограничивает число загрузок с одного адреса`() {
        val venueId = grillVenue()
        val client = uniqueClient()
        val photo = MenuPhotos.withText(listOf("x"))
        repeat(3) {
            mockMvc
                .multipart("/api/v1/venues/$venueId/menu-photos") {
                    file(MockMultipartFile("photo", "menu.png", "image/png", photo))
                    with(client)
                }.andExpect { status { isAccepted() } }
        }

        mockMvc
            .multipart("/api/v1/venues/$venueId/menu-photos") {
                file(MockMultipartFile("photo", "menu.png", "image/png", photo))
                with(client)
            }.andExpect {
                status { isTooManyRequests() }
                header { exists(HttpHeaders.RETRY_AFTER) }
                jsonPath("$.type") { value("urn:norma-ryadom:problem:rate-limit") }
            }
    }

    private fun upload(
        venueId: Long,
        photo: ByteArray,
        fileName: String,
    ) {
        mockMvc
            .multipart("/api/v1/venues/$venueId/menu-photos") {
                file(MockMultipartFile("photo", fileName, "application/octet-stream", photo))
                with(uniqueClient())
            }.andExpect { status { isAccepted() } }
    }

    private fun grillVenue(): Long {
        catalog.chain("Гриль", GRILL_MENU, GRILL_VENUES)
        return jdbc.sql("SELECT id FROM venue WHERE external_id = 'grill-01'").query(Long::class.java).single()
    }
}
