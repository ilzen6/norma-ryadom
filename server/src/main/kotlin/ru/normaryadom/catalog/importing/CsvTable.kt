package ru.normaryadom.catalog.importing

import org.apache.commons.csv.CSVFormat
import org.apache.commons.csv.CSVRecord
import java.io.IOException
import java.io.StringReader
import java.io.UncheckedIOException

class CsvTable private constructor(
    val records: List<CSVRecord>,
) {
    companion object {
        private const val DELIMITER = ';'
        private const val HEADER_LINE = 1L

        fun read(
            text: String,
            expectedHeader: List<String>,
            optionalColumns: List<String> = emptyList(),
        ): CsvTableResult {
            val format =
                CSVFormat.DEFAULT
                    .builder()
                    .setDelimiter(DELIMITER)
                    .setHeader()
                    .setSkipHeaderRecord(true)
                    .setTrim(true)
                    .setIgnoreEmptyLines(true)
                    .get()
            return try {
                format.parse(StringReader(text.removePrefix("\uFEFF"))).use { parser ->
                    val header = parser.headerNames.map { it.trim().lowercase() }
                    when {
                        header != expectedHeader && header != expectedHeader + optionalColumns ->
                            CsvTableResult.Rejected(
                                CsvError(HEADER_LINE, CsvErrorCode.HEADER_MISMATCH, null),
                            )
                        else -> tableOrEmpty(parser.records)
                    }
                }
            } catch (e: IllegalArgumentException) {
                CsvTableResult.Rejected(CsvError(HEADER_LINE, CsvErrorCode.MALFORMED, e.javaClass.simpleName))
            } catch (e: UncheckedIOException) {
                CsvTableResult.Rejected(CsvError(HEADER_LINE, CsvErrorCode.MALFORMED, e.javaClass.simpleName))
            } catch (e: IOException) {
                CsvTableResult.Rejected(CsvError(HEADER_LINE, CsvErrorCode.MALFORMED, e.javaClass.simpleName))
            }
        }

        private fun tableOrEmpty(records: List<CSVRecord>): CsvTableResult =
            if (records.isEmpty()) {
                CsvTableResult.Rejected(CsvError(HEADER_LINE, CsvErrorCode.EMPTY_FILE, null))
            } else {
                CsvTableResult.Read(CsvTable(records))
            }
    }
}

sealed interface CsvTableResult {
    data class Read(
        val table: CsvTable,
    ) : CsvTableResult

    data class Rejected(
        val error: CsvError,
    ) : CsvTableResult
}
