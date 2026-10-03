package ru.normaryadom.intake.report

import org.springframework.jdbc.core.simple.JdbcClient
import org.springframework.stereotype.Repository
import java.sql.Timestamp
import java.time.Instant

@Repository
class VenueReportRepository(
    private val jdbc: JdbcClient,
) {
    fun insertIfAbsent(
        venueId: Long,
        reason: VenueReportReason,
        reporterHash: String,
    ): Boolean =
        jdbc
            .sql(
                """
                INSERT INTO venue_report (venue_id, reason, reporter_hash) VALUES (:venueId, :reason, :reporterHash)
                ON CONFLICT (venue_id, reporter_hash) WHERE resolved_at IS NULL DO NOTHING
                """,
            ).param("venueId", venueId)
            .param("reason", reason.code)
            .param("reporterHash", reporterHash)
            .update() > 0

    fun countOpen(venueId: Long): Int =
        jdbc
            .sql("SELECT count(*) FROM venue_report WHERE venue_id = :venueId AND resolved_at IS NULL")
            .param("venueId", venueId)
            .query(Int::class.java)
            .single()

    fun openReasons(venueIds: Collection<Long>): Map<Long, Map<VenueReportReason, Int>> =
        jdbc
            .sql(
                """
                SELECT venue_id, reason, count(*) AS reports FROM venue_report
                WHERE venue_id = ANY (:venueIds) AND resolved_at IS NULL
                GROUP BY venue_id, reason
                """,
            ).param("venueIds", venueIds.toTypedArray())
            .query { rs, _ -> Triple(rs.getLong("venue_id"), VenueReportReason.of(rs.getString("reason")), rs.getInt("reports")) }
            .list()
            .filter { it.second != null }
            .groupBy({ it.first }, { it.second!! to it.third })
            .mapValues { (_, counts) -> counts.toMap() }

    fun resolveOpen(
        venueId: Long,
        at: Instant,
    ) {
        jdbc
            .sql("UPDATE venue_report SET resolved_at = :at WHERE venue_id = :venueId AND resolved_at IS NULL")
            .param("venueId", venueId)
            .param("at", Timestamp.from(at))
            .update()
    }
}
