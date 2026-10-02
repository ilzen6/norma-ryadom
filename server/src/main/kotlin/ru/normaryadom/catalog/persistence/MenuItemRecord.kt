package ru.normaryadom.catalog.persistence

import ru.normaryadom.catalog.domain.MenuItem
import java.sql.ResultSet

data class MenuItemRecord(
    val item: MenuItem,
    val chainId: Long?,
    val venueId: Long?,
    val isAvailable: Boolean,
    val underReview: Boolean,
) {
    companion object {
        fun map(rs: ResultSet): MenuItemRecord =
            MenuItemRecord(
                item = MenuItemRows.map(rs),
                chainId = rs.getLong("chain_id").takeUnless { rs.wasNull() },
                venueId = rs.getLong("venue_id").takeUnless { rs.wasNull() },
                isAvailable = rs.getBoolean("is_available"),
                underReview = rs.getBoolean("under_review"),
            )
    }
}
