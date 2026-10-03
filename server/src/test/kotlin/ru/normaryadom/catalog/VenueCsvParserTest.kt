package ru.normaryadom.catalog

import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test
import ru.normaryadom.catalog.domain.GeoPoint
import ru.normaryadom.catalog.importing.CsvError
import ru.normaryadom.catalog.importing.CsvErrorCode
import ru.normaryadom.catalog.importing.CsvParseResult
import ru.normaryadom.catalog.importing.VenueCsvParser
import ru.normaryadom.catalog.persistence.VenueDraft
import java.time.LocalDate

class VenueCsvParserTest {
    private val parser = VenueCsvParser()

    @Test
    fun `разбирает точку с координатами`() {
        val result = parser.parse("$HEADER\nГриль Хаус, Сити;Пресненская наб., 2;55.7496;37.5397;gh-01\n")

        assertThat((result as CsvParseResult.Parsed<VenueDraft>).rows).containsExactly(
            VenueDraft("Гриль Хаус, Сити", "Пресненская наб., 2", GeoPoint(55.7496, 37.5397), "gh-01"),
        )
    }

    @Test
    fun `отклоняет координаты вне диапазона и повтор внешнего идентификатора`() {
        val result = parser.parse("$HEADER\nА;адрес;91;37;a-1\nБ;адрес;55;181;a-2\nВ;адрес;55;37;a-3\nГ;адрес;55;37;A-3\n")

        assertThat((result as CsvParseResult.Invalid).errors).containsExactly(
            CsvError(2, CsvErrorCode.OUT_OF_RANGE, "lat"),
            CsvError(3, CsvErrorCode.OUT_OF_RANGE, "lon"),
            CsvError(5, CsvErrorCode.DUPLICATE, "external_id"),
        )
    }

    @Test
    fun `читает необязательную дату подтверждения точки`() {
        val result =
            parser.parse("$HEADER;confirmed_on\nА;адрес;55;37;a-1;2026-03-14\nБ;адрес;55.1;37.1;a-2;\n")

        assertThat((result as CsvParseResult.Parsed<VenueDraft>).rows.map { it.confirmedOn })
            .containsExactly(LocalDate.of(2026, 3, 14), null)
    }

    @Test
    fun `отклоняет дату подтверждения не в формате ГГГГ-ММ-ДД`() {
        val result = parser.parse("$HEADER;confirmed_on\nА;адрес;55;37;a-1;14.03.2026\n")

        assertThat((result as CsvParseResult.Invalid).errors).containsExactly(CsvError(2, CsvErrorCode.NOT_A_DATE, "confirmed_on"))
    }

    @Test
    fun `не принимает лишние колонки кроме даты подтверждения`() {
        val result = parser.parse("$HEADER;rating\nА;адрес;55;37;a-1;5\n")

        assertThat((result as CsvParseResult.Invalid).errors.single().code).isEqualTo(CsvErrorCode.HEADER_MISMATCH)
    }

    @Test
    fun `требует внешний идентификатор точки`() {
        val result = parser.parse("$HEADER\nА;адрес;55;37;\n")

        assertThat((result as CsvParseResult.Invalid).errors).containsExactly(CsvError(2, CsvErrorCode.REQUIRED, "external_id"))
    }

    private companion object {
        val HEADER = VenueCsvParser.HEADER.joinToString(";")
    }
}
