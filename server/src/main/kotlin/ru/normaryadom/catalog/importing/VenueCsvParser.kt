package ru.normaryadom.catalog.importing

import org.springframework.stereotype.Component
import ru.normaryadom.catalog.domain.GeoPoint
import ru.normaryadom.catalog.persistence.VenueDraft
import java.math.BigDecimal

@Component
class VenueCsvParser {
    private val document = CsvDocument(HEADER, EXTERNAL_ID, VenueDraft::externalId, ::parseRow)

    fun parse(text: String): CsvParseResult<VenueDraft> = document.parse(text)

    fun parse(content: ByteArray): CsvParseResult<VenueDraft> = document.parse(content)

    private fun parseRow(row: CsvRowReader): VenueDraft? {
        val name = row.requiredText(NAME, MAX_TEXT_LENGTH)
        val address = row.requiredText(ADDRESS, MAX_TEXT_LENGTH)
        val lat = row.requiredNumber(LAT, LAT_RANGE)
        val lon = row.requiredNumber(LON, LON_RANGE)
        val externalId = row.requiredText(EXTERNAL_ID, MAX_TEXT_LENGTH)
        return if (row.isValid) {
            VenueDraft(name = name, address = address, location = GeoPoint(lat.toDouble(), lon.toDouble()), externalId = externalId)
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
        val HEADER = listOf(NAME, ADDRESS, LAT, LON, EXTERNAL_ID)

        private const val MAX_TEXT_LENGTH = 300
        private val LAT_RANGE = BigDecimal("-90")..BigDecimal("90")
        private val LON_RANGE = BigDecimal("-180")..BigDecimal("180")
    }
}
