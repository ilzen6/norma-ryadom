package ru.normaryadom.catalog.importing

import org.springframework.stereotype.Component
import ru.normaryadom.catalog.domain.GeoPoint
import ru.normaryadom.catalog.persistence.VenueDraft
import java.math.BigDecimal

@Component
class VenueCsvParser {
    fun parse(
        text: String,
        templates: Map<String, Long> = emptyMap(),
    ): CsvParseResult<VenueDraft> = document(templates).parse(text)

    fun parse(
        content: ByteArray,
        templates: Map<String, Long> = emptyMap(),
    ): CsvParseResult<VenueDraft> = document(templates).parse(content)

    private fun document(templates: Map<String, Long>) =
        CsvDocument(HEADER, EXTERNAL_ID, VenueDraft::externalId, { row -> parseRow(row, templates) }, OPTIONAL)

    private fun parseRow(
        row: CsvRowReader,
        templates: Map<String, Long>,
    ): VenueDraft? {
        val name = row.requiredText(NAME, MAX_TEXT_LENGTH)
        val address = row.requiredText(ADDRESS, MAX_TEXT_LENGTH)
        val lat = row.requiredNumber(LAT, LAT_RANGE)
        val lon = row.requiredNumber(LON, LON_RANGE)
        val externalId = row.requiredText(EXTERNAL_ID, MAX_TEXT_LENGTH)
        val confirmedOn = row.optionalDate(CONFIRMED_ON)
        val templateId = row.optionalCode(TEMPLATE, CsvErrorCode.UNKNOWN_TEMPLATE, templates::get)
        return if (row.isValid) {
            VenueDraft(
                name = name,
                address = address,
                location = GeoPoint(lat.toDouble(), lon.toDouble()),
                externalId = externalId,
                confirmedOn = confirmedOn,
                templateId = templateId,
            )
        } else {
            null
        }
    }

    companion object {
        const val NAME = "name"
        const val ADDRESS = "address"
        const val LAT = "lat"
        const val LON = "lon"
        const val EXTERNAL_ID = "external_id"
        const val CONFIRMED_ON = "confirmed_on"
        const val TEMPLATE = "template"
        val HEADER = listOf(NAME, ADDRESS, LAT, LON, EXTERNAL_ID)
        val OPTIONAL = listOf(CONFIRMED_ON, TEMPLATE)

        private const val MAX_TEXT_LENGTH = 300
        private val LAT_RANGE = BigDecimal("-90")..BigDecimal("90")
        private val LON_RANGE = BigDecimal("-180")..BigDecimal("180")
    }
}
