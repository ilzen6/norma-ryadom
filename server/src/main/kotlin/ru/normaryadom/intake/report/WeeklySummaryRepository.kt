package ru.normaryadom.intake.report

import org.springframework.jdbc.core.simple.JdbcClient
import org.springframework.stereotype.Repository
import java.sql.Timestamp
import java.time.Instant

@Repository
class WeeklySummaryRepository(
    private val jdbc: JdbcClient,
) {
    fun summary(
        since: Instant,
        topLimit: Int,
    ): WeeklySummary {
        val from = Timestamp.from(since)
        val topPlaces =
            jdbc
                .sql(
                    """
                    SELECT name, count(*) AS complaints
                    FROM (
                        SELECT v.name
                        FROM venue_report r
                        JOIN venue v ON v.id = r.venue_id
                        WHERE r.created_at >= :since
                        UNION ALL
                        SELECT COALESCE(c.name, v.name)
                        FROM item_report r
                        JOIN menu_item i ON i.id = r.item_id
                        LEFT JOIN chain c ON c.id = i.chain_id
                        LEFT JOIN venue v ON v.id = i.venue_id
                        WHERE r.created_at >= :since
                    ) complaints
                    GROUP BY name
                    ORDER BY complaints DESC, name
                    LIMIT :limit
                    """.trimIndent(),
                ).param("since", from)
                .param("limit", topLimit)
                .query { rs, _ -> PlaceComplaints(rs.getString("name"), rs.getInt("complaints")) }
                .list()
        return jdbc
            .sql(
                """
                SELECT
                    (SELECT count(*) FROM item_report WHERE created_at >= :since) AS item_reports,
                    (SELECT count(*) FROM venue_report WHERE created_at >= :since) AS venue_reports,
                    (SELECT count(*) FROM venue_report WHERE created_at >= :since AND reason = 'closed') AS closed_reports,
                    (SELECT count(*) FROM menu_submission WHERE created_at >= :since) AS photos
                """.trimIndent(),
            ).param("since", from)
            .query { rs, _ ->
                WeeklySummary(
                    itemReports = rs.getInt("item_reports"),
                    venueReports = rs.getInt("venue_reports"),
                    closedReports = rs.getInt("closed_reports"),
                    photos = rs.getInt("photos"),
                    topPlaces = topPlaces,
                )
            }.single()
    }
}
