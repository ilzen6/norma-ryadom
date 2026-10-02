package ru.normaryadom.catalog.persistence

import org.springframework.jdbc.core.namedparam.MapSqlParameterSource
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcOperations
import org.springframework.jdbc.core.simple.JdbcClient
import org.springframework.stereotype.Repository
import ru.normaryadom.catalog.domain.Venue

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
            INSERT INTO venue (chain_id, name, address, location, external_id)
            VALUES (:chainId, :name, :address, ST_SetSRID(ST_MakePoint(:lon, :lat), 4326)::geography, :externalId)
            ON CONFLICT (chain_id, external_id) WHERE external_id IS NOT NULL DO UPDATE SET
                name = EXCLUDED.name, address = EXCLUDED.address, location = EXCLUDED.location, is_active = TRUE
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
                }.toTypedArray(),
        )
    }

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

    fun bumpMenuVersion(id: Long) {
        jdbc
            .sql("UPDATE venue SET menu_version = menu_version + 1 WHERE id = :id")
            .param("id", id)
            .update()
    }
}
