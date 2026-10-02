package ru.normaryadom.intake.report

import org.springframework.jdbc.core.simple.JdbcClient
import org.springframework.stereotype.Repository
import java.sql.Timestamp
import java.time.Instant

@Repository
class ItemReportRepository(
    private val jdbc: JdbcClient,
) {
    fun insertIfAbsent(
        itemId: Long,
        reason: String,
        reporterHash: String,
    ): Boolean =
        jdbc
            .sql(
                """
                INSERT INTO item_report (item_id, reason, reporter_hash) VALUES (:itemId, :reason, :reporterHash)
                ON CONFLICT (item_id, reporter_hash) WHERE resolved_at IS NULL AND reporter_hash IS NOT NULL DO NOTHING
                """,
            ).param("itemId", itemId)
            .param("reason", reason)
            .param("reporterHash", reporterHash)
            .update() > 0

    fun countOpen(itemId: Long): Int =
        jdbc
            .sql("SELECT count(*) FROM item_report WHERE item_id = :itemId AND resolved_at IS NULL")
            .param("itemId", itemId)
            .query(Int::class.java)
            .single()

    fun openReasons(itemIds: Collection<Long>): Map<Long, List<String>> =
        jdbc
            .sql(
                """
                SELECT item_id, reason FROM item_report
                WHERE item_id = ANY (:itemIds) AND resolved_at IS NULL
                ORDER BY created_at, id
                """,
            ).param("itemIds", itemIds.toTypedArray())
            .query { rs, _ -> rs.getLong("item_id") to rs.getString("reason") }
            .list()
            .groupBy({ it.first }, { it.second })

    fun resolveOpen(
        itemId: Long,
        at: Instant,
    ) {
        jdbc
            .sql("UPDATE item_report SET resolved_at = :at WHERE item_id = :itemId AND resolved_at IS NULL")
            .param("itemId", itemId)
            .param("at", Timestamp.from(at))
            .update()
    }
}
