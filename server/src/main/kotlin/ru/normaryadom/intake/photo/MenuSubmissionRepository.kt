package ru.normaryadom.intake.photo

import org.springframework.jdbc.core.simple.JdbcClient
import org.springframework.stereotype.Repository
import java.sql.ResultSet
import java.sql.Timestamp
import java.time.Instant
import java.time.OffsetDateTime

@Repository
class MenuSubmissionRepository(
    private val jdbc: JdbcClient,
) {
    fun insert(
        venueId: Long,
        photoKey: String,
        contentType: String,
    ): Long =
        jdbc
            .sql(
                """
                INSERT INTO menu_submission (venue_id, photo_key, content_type)
                VALUES (:venueId, :photoKey, :contentType)
                RETURNING id
                """,
            ).param("venueId", venueId)
            .param("photoKey", photoKey)
            .param("contentType", contentType)
            .query(Long::class.java)
            .single()

    fun findById(id: Long): MenuSubmission? =
        jdbc
            .sql("$SELECT WHERE s.id = :id")
            .param("id", id)
            .query { rs, _ -> map(rs) }
            .optional()
            .orElse(null)

    fun findByStatuses(
        statuses: Set<SubmissionStatus>,
        limit: Int,
    ): List<MenuSubmission> =
        jdbc
            .sql("$SELECT WHERE s.status = ANY (:statuses) ORDER BY s.created_at, s.id LIMIT :limit")
            .param("statuses", statuses.map(SubmissionStatus::name).toTypedArray())
            .param("limit", limit)
            .query { rs, _ -> map(rs) }
            .list()

    fun countByStatuses(statuses: Set<SubmissionStatus>): Int =
        jdbc
            .sql("SELECT count(*) FROM menu_submission WHERE status = ANY (:statuses)")
            .param("statuses", statuses.map(SubmissionStatus::name).toTypedArray())
            .query(Int::class.java)
            .single()

    fun recordOcr(
        id: Long,
        status: SubmissionStatus,
        text: String?,
    ): Boolean =
        jdbc
            .sql("UPDATE menu_submission SET status = :status, ocr_text = :text WHERE id = :id AND status = 'NEW'")
            .param("id", id)
            .param("status", status.name)
            .param("text", text)
            .update() > 0

    fun moderate(
        id: Long,
        status: SubmissionStatus,
        at: Instant,
    ): Boolean =
        jdbc
            .sql(
                """
                UPDATE menu_submission SET status = :status, moderated_at = :at
                WHERE id = :id AND status = ANY (:open)
                """,
            ).param("id", id)
            .param("status", status.name)
            .param("at", Timestamp.from(at))
            .param("open", SubmissionStatus.OPEN.map(SubmissionStatus::name).toTypedArray())
            .update() > 0

    private fun map(rs: ResultSet): MenuSubmission =
        MenuSubmission(
            id = rs.getLong("id"),
            venueId = rs.getLong("venue_id"),
            venueName = rs.getString("venue_name"),
            venueAddress = rs.getString("venue_address"),
            photoKey = rs.getString("photo_key"),
            contentType = rs.getString("content_type"),
            ocrText = rs.getString("ocr_text"),
            status = SubmissionStatus.valueOf(rs.getString("status")),
            createdAt = rs.getObject("created_at", OffsetDateTime::class.java).toInstant(),
        )

    private companion object {
        const val SELECT = """
            SELECT s.id, s.venue_id, v.name AS venue_name, v.address AS venue_address, s.photo_key,
                   s.content_type, s.ocr_text, s.status, s.created_at
            FROM menu_submission s JOIN venue v ON v.id = s.venue_id
        """
    }
}
