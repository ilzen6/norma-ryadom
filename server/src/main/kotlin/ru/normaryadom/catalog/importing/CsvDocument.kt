package ru.normaryadom.catalog.importing

class CsvDocument<T : Any>(
    private val header: List<String>,
    private val uniqueColumn: String,
    private val uniqueKey: (T) -> String,
    private val parseRow: (CsvRowReader) -> T?,
) {
    fun parse(content: ByteArray): CsvParseResult<T> =
        CsvEncoding.decode(content)?.let(::parse)
            ?: CsvParseResult.Invalid(listOf(CsvError(FIRST_LINE, CsvErrorCode.MALFORMED, ENCODING)))

    fun parse(text: String): CsvParseResult<T> =
        when (val read = CsvTable.read(text, header)) {
            is CsvTableResult.Rejected -> CsvParseResult.Invalid(listOf(read.error))
            is CsvTableResult.Read -> parseRows(read.table)
        }

    private fun parseRows(table: CsvTable): CsvParseResult<T> {
        val parsed = table.records.map(::CsvRowReader).map { reader -> reader to parseRow(reader) }
        val rowErrors = parsed.flatMap { (reader, _) -> reader.errors }
        val errors = (rowErrors + duplicates(parsed)).sortedBy(CsvError::line)
        return if (errors.isEmpty()) {
            CsvParseResult.Parsed(parsed.mapNotNull { (_, row) -> row })
        } else {
            CsvParseResult.Invalid(errors)
        }
    }

    private fun duplicates(parsed: List<Pair<CsvRowReader, T?>>): List<CsvError> =
        parsed
            .mapNotNull { (reader, row) -> row?.let { reader.line to uniqueKey(it).lowercase() } }
            .groupBy({ (_, key) -> key }, { (line, _) -> line })
            .values
            .flatMap { lines -> lines.drop(1).map { line -> CsvError(line, CsvErrorCode.DUPLICATE, uniqueColumn) } }

    private companion object {
        const val FIRST_LINE = 1L
        const val ENCODING = "encoding"
    }
}
