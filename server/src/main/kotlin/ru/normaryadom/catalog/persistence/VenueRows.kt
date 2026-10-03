package ru.normaryadom.catalog.persistence

import ru.normaryadom.catalog.domain.GeoPoint
import ru.normaryadom.catalog.domain.MenuScope
import ru.normaryadom.catalog.domain.Venue
import java.sql.ResultSet
import java.time.LocalDate

object VenueRows {
    const val SELECT_COLUMNS = """
        v.id, v.chain_id, c.name AS chain_name, v.name, v.address, v.is_active, v.menu_version,
        v.confirmed_on, v.under_review,
        coalesce(c.currency, 'RUB') AS currency,
        coalesce(c.menu_version, 0) AS chain_menu_version,
        ST_Y(v.location::geometry) AS lat, ST_X(v.location::geometry) AS lon,
        EXISTS (
            SELECT 1 FROM menu_item own
            WHERE own.venue_id = v.id AND own.is_available AND NOT own.under_review
        ) AS has_own_items,
        EXISTS (
            SELECT 1 FROM menu_item shared
            WHERE shared.chain_id = v.chain_id AND shared.is_available AND NOT shared.under_review
        ) AS has_chain_items
    """

    const val FROM = "FROM venue v LEFT JOIN chain c ON c.id = v.chain_id"

    fun map(rs: ResultSet): Venue {
        val id = rs.getLong("id")
        val chainId = rs.getLong("chain_id").takeUnless { rs.wasNull() }
        val hasOwnItems = rs.getBoolean("has_own_items")
        val scopeVenueId = id.takeIf { hasOwnItems || chainId == null }
        val scope =
            MenuScope(
                chainId = chainId,
                chainMenuVersion = rs.getLong("chain_menu_version"),
                venueId = scopeVenueId,
                venueMenuVersion = if (scopeVenueId == null) 0 else rs.getLong("menu_version"),
            )
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
            hasMenu = hasOwnItems || rs.getBoolean("has_chain_items"),
            confirmedOn = rs.getObject("confirmed_on", LocalDate::class.java),
            underReview = rs.getBoolean("under_review"),
        )
    }
}
