package ru.normaryadom.catalog.persistence

import org.springframework.jdbc.core.namedparam.MapSqlParameterSource
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcOperations
import org.springframework.jdbc.core.simple.JdbcClient
import org.springframework.stereotype.Repository
import ru.normaryadom.catalog.domain.Venue
import java.sql.Types
import java.time.LocalDate

@Repository
class VenueRepository(
    private val jdbc: JdbcClient,
    private val batchJdbc: NamedParameterJdbcOperations,
) {
    fun findActiveById(id: Long): Venue? =
        jdbc
            .sql("SELECT ${VenueRows.SELECT_COLUMNS} ${VenueRows.FROM} WHERE v.id = :id AND v.is_active")
            .param("id", id)
            .query { rs, _ -> VenueRows.map(rs) }
            .optional()
            .orElse(null)

    fun findByChain(chainId: Long): List<Venue> =
        jdbc
            .sql("SELECT ${VenueRows.SELECT_COLUMNS} ${VenueRows.FROM} WHERE v.chain_id = :chainId ORDER BY v.name, v.id")
            .param("chainId", chainId)
            .query { rs, _ -> VenueRows.map(rs) }
            .list()

    fun upsertForChain(
        chainId: Long,
        drafts: List<VenueDraft>,
    ) {
        batchJdbc.batchUpdate(
            """
            INSERT INTO venue (chain_id, name, address, location, external_id, confirmed_on)
            VALUES (:chainId, :name, :address, ST_SetSRID(ST_MakePoint(:lon, :lat), 4326)::geography, :externalId,
                    :confirmedOn)
            ON CONFLICT (chain_id, external_id) WHERE external_id IS NOT NULL DO UPDATE SET
                name = EXCLUDED.name, address = EXCLUDED.address, location = EXCLUDED.location,
                is_active = venue.closed_on IS NULL OR coalesce(EXCLUDED.confirmed_on > venue.closed_on, FALSE),
                closed_on = CASE WHEN EXCLUDED.confirmed_on > venue.closed_on THEN NULL ELSE venue.closed_on END,
                confirmed_on = coalesce(EXCLUDED.confirmed_on, venue.confirmed_on)
            """,
            drafts
                .map { draft ->
                    MapSqlParameterSource()
                        .addValue("chainId", chainId)
                        .addValue("name", draft.name)
                        .addValue("address", draft.address)
                        .addValue("lat", draft.location.lat)
                        .addValue("lon", draft.location.lon)
                        .addValue("externalId", draft.externalId)
                        .addValue("confirmedOn", draft.confirmedOn, Types.DATE)
                }.toTypedArray(),
        )
    }

    fun upsertStandalone(drafts: List<VenueDraft>) {
        batchJdbc.batchUpdate(
            """
            INSERT INTO venue (chain_id, name, address, location, external_id, confirmed_on)
            VALUES (NULL, :name, :address, ST_SetSRID(ST_MakePoint(:lon, :lat), 4326)::geography, :externalId,
                    :confirmedOn)
            ON CONFLICT (external_id) WHERE chain_id IS NULL AND external_id IS NOT NULL DO UPDATE SET
                name = EXCLUDED.name, address = EXCLUDED.address, location = EXCLUDED.location,
                is_active = venue.closed_on IS NULL OR coalesce(EXCLUDED.confirmed_on > venue.closed_on, FALSE),
                closed_on = CASE WHEN EXCLUDED.confirmed_on > venue.closed_on THEN NULL ELSE venue.closed_on END,
                confirmed_on = coalesce(EXCLUDED.confirmed_on, venue.confirmed_on)
            """,
            drafts
                .map { draft ->
                    MapSqlParameterSource()
                        .addValue("name", draft.name)
                        .addValue("address", draft.address)
                        .addValue("lat", draft.location.lat)
                        .addValue("lon", draft.location.lon)
                        .addValue("externalId", draft.externalId)
                        .addValue("confirmedOn", draft.confirmedOn, Types.DATE)
                }.toTypedArray(),
        )
    }

    fun deactivateStandaloneExcept(keptExternalIds: Collection<String>): Int =
        jdbc
            .sql(
                """
                UPDATE venue SET is_active = FALSE
                WHERE chain_id IS NULL AND is_active AND external_id IS NOT NULL
                  AND NOT (external_id = ANY (:externalIds))
                """,
            ).param("externalIds", keptExternalIds.toTypedArray())
            .update()

    fun countStandalone(): Int =
        jdbc
            .sql("SELECT count(*) FROM venue WHERE chain_id IS NULL AND is_active")
            .query(Int::class.java)
            .single()

    fun deactivateChainVenuesExcept(
        chainId: Long,
        keptExternalIds: Collection<String>,
    ): Int =
        jdbc
            .sql(
                """
                UPDATE venue SET is_active = FALSE
                WHERE chain_id = :chainId AND is_active
                  AND (external_id IS NULL OR NOT (external_id = ANY (:externalIds)))
                """,
            ).param("chainId", chainId)
            .param("externalIds", keptExternalIds.toTypedArray())
            .update()

    fun lockActive(id: Long): Boolean =
        jdbc
            .sql("SELECT id FROM venue WHERE id = :id AND is_active FOR UPDATE")
            .param("id", id)
            .query(Long::class.java)
            .optional()
            .isPresent

    fun sendToReview(id: Long): Boolean =
        jdbc
            .sql("UPDATE venue SET under_review = TRUE WHERE id = :id AND is_active AND NOT under_review")
            .param("id", id)
            .update() > 0

    fun findUnderReview(): List<Venue> =
        jdbc
            .sql("SELECT ${VenueRows.SELECT_COLUMNS} ${VenueRows.FROM} WHERE v.is_active AND v.under_review ORDER BY v.id")
            .query { rs, _ -> VenueRows.map(rs) }
            .list()

    fun restore(
        id: Long,
        confirmedOn: LocalDate,
    ): Boolean =
        jdbc
            .sql("UPDATE venue SET under_review = FALSE, confirmed_on = :confirmedOn WHERE id = :id AND under_review")
            .param("id", id)
            .param("confirmedOn", confirmedOn)
            .update() > 0

    fun close(
        id: Long,
        closedOn: LocalDate,
    ): Boolean =
        jdbc
            .sql("UPDATE venue SET under_review = FALSE, is_active = FALSE, closed_on = :closedOn WHERE id = :id AND under_review")
            .param("id", id)
            .param("closedOn", closedOn)
            .update() > 0

    fun bumpMenuVersion(id: Long) {
        jdbc
            .sql("UPDATE venue SET menu_version = menu_version + 1 WHERE id = :id")
            .param("id", id)
            .update()
    }
}
