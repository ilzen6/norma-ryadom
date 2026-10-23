package ru.normaryadom.catalog.persistence

import ru.normaryadom.catalog.domain.GeoPoint
import ru.normaryadom.catalog.domain.MenuScope
import ru.normaryadom.catalog.domain.SourceKind
import ru.normaryadom.catalog.domain.Venue
import java.sql.ResultSet
import java.time.LocalDate

object VenueRows {
    const val SELECT_COLUMNS = """
        v.id, v.chain_id, c.name AS chain_name, v.name, v.address, v.is_active, v.menu_version,
        v.confirmed_on, v.under_review,
        coalesce(c.currency, 'RUB') AS currency,
        coalesce(c.menu_version, 0) AS chain_menu_version,
        v.template_id, coalesce(t.menu_version, 0) AS template_menu_version,
        ST_Y(v.location::geometry) AS lat, ST_X(v.location::geometry) AS lon,
        EXISTS (
            SELECT 1 FROM menu_item own
            WHERE own.venue_id = v.id AND own.is_available AND NOT own.under_review
        ) AS has_own_items,
        EXISTS (
            SELECT 1 FROM menu_item shared
            WHERE shared.chain_id = v.chain_id AND shared.is_available AND NOT shared.under_review
        ) AS has_chain_items,
        EXISTS (
            SELECT 1 FROM menu_item typical
            WHERE typical.chain_id = v.template_id AND typical.is_available AND NOT typical.under_review
        ) AS has_template_items,
        coalesce(
            (
                SELECT mode() WITHIN GROUP (ORDER BY item.source_kind)
                FROM menu_item item
                WHERE (item.venue_id = v.id OR item.chain_id = v.chain_id) AND item.is_available AND NOT item.under_review
            ),
            (
                SELECT max(item.source_kind)
                FROM menu_item item
                WHERE item.chain_id = v.template_id AND item.is_available AND NOT item.under_review
            )
        ) AS data_quality
    """

    const val FROM = "FROM venue v LEFT JOIN chain c ON c.id = v.chain_id LEFT JOIN chain t ON t.id = v.template_id"

    fun map(rs: ResultSet): Venue {
        val id = rs.getLong("id")
        val chainId = rs.getLong("chain_id").takeUnless { rs.wasNull() }
        val hasOwnItems = rs.getBoolean("has_own_items")
        val hasChainItems = rs.getBoolean("has_chain_items")
        val templateId = rs.getLong("template_id").takeUnless { rs.wasNull() }
        val usesTemplate = !hasOwnItems && !hasChainItems && templateId != null && rs.getBoolean("has_template_items")
        val scope =
            if (usesTemplate) {
                MenuScope(
                    chainId = templateId,
                    chainMenuVersion = rs.getLong("template_menu_version"),
                    venueId = null,
                    venueMenuVersion = 0,
                )
            } else {
                ownOrChainScope(rs, id, chainId, hasOwnItems)
            }
        return Venue(
            id = id,
            chainId = chainId,
            chainName = rs.getString("chain_name"),
            name = rs.getString("name"),
            address = rs.getString("address"),
            location = GeoPoint(lat = rs.getDouble("lat"), lon = rs.getDouble("lon")),
            isActive = rs.getBoolean("is_active"),
            currency = rs.getString("currency"),
            menuScope = scope,
            hasMenu = hasOwnItems || hasChainItems || usesTemplate,
            confirmedOn = rs.getObject("confirmed_on", LocalDate::class.java),
            underReview = rs.getBoolean("under_review"),
            dataQuality = rs.getString("data_quality")?.let(SourceKind::fromCode),
            usesTemplateMenu = usesTemplate,
        )
    }

    private fun ownOrChainScope(
        rs: ResultSet,
        venueId: Long,
        chainId: Long?,
        hasOwnItems: Boolean,
    ): MenuScope {
        val scopeVenueId = venueId.takeIf { hasOwnItems || chainId == null }
        return MenuScope(
            chainId = chainId,
            chainMenuVersion = rs.getLong("chain_menu_version"),
            venueId = scopeVenueId,
            venueMenuVersion = if (scopeVenueId == null) 0 else rs.getLong("menu_version"),
        )
    }
}
