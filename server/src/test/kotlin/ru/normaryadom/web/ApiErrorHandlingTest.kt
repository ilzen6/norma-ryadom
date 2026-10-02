package ru.normaryadom.web

import io.mockk.every
import io.mockk.mockk
import org.hamcrest.Matchers.containsString
import org.hamcrest.Matchers.not
import org.junit.jupiter.api.Test
import org.springframework.http.MediaType
import org.springframework.mock.web.MockMultipartFile
import org.springframework.test.web.servlet.MockMvc
import org.springframework.test.web.servlet.multipart
import org.springframework.test.web.servlet.post
import org.springframework.test.web.servlet.setup.MockMvcBuilders
import ru.normaryadom.intake.api.ItemReportController
import ru.normaryadom.intake.api.MenuPhotoController
import ru.normaryadom.intake.photo.MenuPhotoService
import ru.normaryadom.intake.photo.StorageUnavailableException
import ru.normaryadom.intake.report.ItemReportService
import java.io.IOException

class ApiErrorHandlingTest {
    private val photos = mockk<MenuPhotoService>()
    private val reports = mockk<ItemReportService>()
    private val mockMvc: MockMvc =
        MockMvcBuilders
            .standaloneSetup(MenuPhotoController(photos), ItemReportController(reports))
            .setControllerAdvice(ApiExceptionHandler())
            .build()

    @Test
    fun `сообщает о недоступности хранилища кодом 503 без технических подробностей`() {
        every { photos.submit(any(), any(), any()) } throws StorageUnavailableException(IOException("connection refused to 10.0.0.5"))

        mockMvc
            .multipart("/api/v1/venues/1/menu-photos") { file(MockMultipartFile("photo", "m.png", "image/png", ByteArray(8))) }
            .andExpect {
                status { isServiceUnavailable() }
                jsonPath("$.type") { value("urn:norma-ryadom:problem:storage-unavailable") }
                content { string(not(containsString("10.0.0.5"))) }
            }
    }

    @Test
    fun `скрывает внутренности непредвиденной ошибки`() {
        every { reports.report(any(), any(), any()) } throws IllegalStateException("SELECT * FROM secret_table")

        mockMvc
            .post("/api/v1/items/1/reports") {
                contentType = MediaType.APPLICATION_JSON
                content = """{"reason": "неверно"}"""
            }.andExpect {
                status { isInternalServerError() }
                jsonPath("$.type") { value("urn:norma-ryadom:problem:internal") }
                content { string(not(containsString("secret_table"))) }
            }
    }
}
