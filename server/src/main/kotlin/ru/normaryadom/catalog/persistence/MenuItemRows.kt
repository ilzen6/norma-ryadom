package ru.normaryadom.catalog.persistence

import ru.normaryadom.catalog.domain.DataSource
import ru.normaryadom.catalog.domain.DietTag
import ru.normaryadom.catalog.domain.DishCategory
import ru.normaryadom.catalog.domain.KcalRange
import ru.normaryadom.catalog.domain.MenuItem
import ru.normaryadom.catalog.domain.Nutrients
import ru.normaryadom.catalog.domain.SourceKind
import java.sql.ResultSet
import java.time.OffsetDateTime

object MenuItemRows {
    const val SELECT_COLUMNS = """
        m.id, m.name, m.category, m.portion_g, m.kcal, m.protein_g, m.fat_g, m.carbs_g, m.price_minor,
        m.tags, m.source_kind, m.source_url, m.verified_at, m.kcal_low, m.kcal_high
    """

    fun map(rs: ResultSet): MenuItem =
        MenuItem(
            id = rs.getLong("id"),
            name = rs.getString("name"),
            category = requireNotNull(DishCategory.fromCode(rs.getString("category"))) { "Unknown category" },
            portionGrams = rs.getBigDecimal("portion_g")?.toDouble(),
            nutrients =
                Nutrients(
                    kcal = rs.getBigDecimal("kcal").toDouble(),
                    protein = rs.getBigDecimal("protein_g").toDouble(),
                    fat = rs.getBigDecimal("fat_g").toDouble(),
                    carbs = rs.getBigDecimal("carbs_g").toDouble(),
                ),
            priceMinor = rs.getInt("price_minor").takeUnless { rs.wasNull() },
            tags = tags(rs),
            source =
                DataSource(
                    kind = SourceKind.fromCode(rs.getString("source_kind")),
                    url = rs.getString("source_url"),
                    verifiedAt = rs.getObject("verified_at", OffsetDateTime::class.java)?.toInstant(),
                    kcalRange = kcalRange(rs),
                ),
        )

    private fun tags(rs: ResultSet): Set<DietTag> {
        val codes = rs.getArray("tags").array as Array<*>
        return codes.map { code -> requireNotNull(DietTag.fromCode(code.toString())) { "Unknown diet tag" } }.toSet()
    }

    private fun kcalRange(rs: ResultSet): KcalRange? {
        val low = rs.getBigDecimal("kcal_low")
        val high = rs.getBigDecimal("kcal_high")
        return if (low != null && high != null) KcalRange(low = low.toDouble(), high = high.toDouble()) else null
    }
}
