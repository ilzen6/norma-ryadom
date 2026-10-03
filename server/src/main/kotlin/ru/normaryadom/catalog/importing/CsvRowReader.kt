package ru.normaryadom.catalog.importing

import org.apache.commons.csv.CSVRecord
import java.math.BigDecimal
import java.time.LocalDate

class CsvRowReader(
    private val record: CSVRecord,
) {
    private val collected = mutableListOf<CsvError>()

    val errors: List<CsvError> get() = collected

    val isValid: Boolean get() = collected.isEmpty()

    val line: Long get() = record.recordNumber + 1

    fun requiredText(
        column: String,
        maxLength: Int,
    ): String {
        val value = text(column)
        when {
            value.isEmpty() -> fail(column, CsvErrorCode.REQUIRED)
            value.length > maxLength -> fail(column, CsvErrorCode.TOO_LONG)
        }
        return value
    }

    fun <T : Any> requiredCode(
        column: String,
        fallback: T,
        unknown: CsvErrorCode,
        resolve: (String) -> T?,
    ): T {
        val value = text(column)
        if (value.isEmpty()) {
            fail(column, CsvErrorCode.REQUIRED)
            return fallback
        }
        return resolve(value) ?: fallback.also { fail(column, unknown) }
    }

    fun requiredNumber(
        column: String,
        range: ClosedRange<BigDecimal>,
    ): BigDecimal {
        if (text(column).isEmpty()) fail(column, CsvErrorCode.REQUIRED)
        return optionalNumber(column, range) ?: BigDecimal.ZERO
    }

    fun optionalNumber(
        column: String,
        range: ClosedRange<BigDecimal>,
    ): BigDecimal? {
        val value = text(column).takeIf { it.isNotEmpty() }
        val number = value?.replace(',', '.')?.toBigDecimalOrNull()
        when {
            value == null -> Unit
            number == null -> fail(column, CsvErrorCode.NOT_A_NUMBER)
            number !in range -> fail(column, CsvErrorCode.OUT_OF_RANGE)
        }
        return number?.takeIf { it in range }
    }

    fun optionalDate(column: String): LocalDate? {
        val value = text(column).takeIf { it.isNotEmpty() } ?: return null
        return runCatching { LocalDate.parse(value) }.getOrNull().also { if (it == null) fail(column, CsvErrorCode.NOT_A_DATE) }
    }

    fun <T : Any> codes(
        column: String,
        unknown: CsvErrorCode,
        resolve: (String) -> T?,
    ): Set<T> =
        text(column)
            .split(',')
            .map(String::trim)
            .filter(String::isNotEmpty)
            .mapNotNull { code -> resolve(code).also { if (it == null) fail(column, unknown) } }
            .toSet()

    private fun fail(
        column: String,
        code: CsvErrorCode,
    ) {
        collected += CsvError(line, code, column)
    }

    private fun text(column: String): String = if (record.isSet(column)) record.get(column).orEmpty().trim() else ""
}
