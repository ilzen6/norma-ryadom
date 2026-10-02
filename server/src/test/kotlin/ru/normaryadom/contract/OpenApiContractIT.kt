package ru.normaryadom.contract

import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test
import org.springframework.test.web.servlet.get
import ru.normaryadom.support.IntegrationTest
import tools.jackson.databind.SerializationFeature
import tools.jackson.databind.cfg.EnumFeature
import tools.jackson.databind.json.JsonMapper
import java.nio.file.Files
import java.nio.file.Path

class OpenApiContractIT : IntegrationTest() {
    private val mapper =
        JsonMapper
            .builder()
            .enable(SerializationFeature.INDENT_OUTPUT)
            .enable(SerializationFeature.ORDER_MAP_ENTRIES_BY_KEYS)
            .disable(EnumFeature.WRITE_ENUMS_TO_LOWERCASE)
            .build()

    @Test
    fun `опубликованный контракт API совпадает с тем, что отдаёт сервер`() {
        val served =
            mockMvc
                .get("/v3/api-docs")
                .andReturn()
                .response.contentAsString
        val normalized = mapper.writeValueAsString(mapper.readValue(served, Map::class.java)) + "\n"
        val contract = Path.of(System.getProperty("contract.dir"), "openapi.json")

        if (System.getProperty("contract.update").toBoolean()) Files.writeString(contract, normalized)

        assertThat(contract).exists()
        assertThat(Files.readString(contract))
            .`as`("Контракт изменился: обновите его командой ./gradlew test --tests '*OpenApiContractIT' -PupdateContract=true")
            .isEqualTo(normalized)
    }
}
