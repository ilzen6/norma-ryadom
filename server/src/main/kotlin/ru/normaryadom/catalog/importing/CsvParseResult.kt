package ru.normaryadom.catalog.importing

sealed interface CsvParseResult<out T> {
    data class Parsed<T>(
        val rows: List<T>,
    ) : CsvParseResult<T>

    data class Invalid(
        val errors: List<CsvError>,
    ) : CsvParseResult<Nothing>
}

data class CsvError(
    val line: Long,
    val code: CsvErrorCode,
    val column: String?,
)

enum class CsvErrorCode {
    HEADER_MISMATCH,
    EMPTY_FILE,
    MALFORMED,
    REQUIRED,
    TOO_LONG,
    NOT_A_NUMBER,
    NOT_A_DATE,
    OUT_OF_RANGE,
    UNKNOWN_CATEGORY,
    UNKNOWN_TAG,
    DUPLICATE,
}
