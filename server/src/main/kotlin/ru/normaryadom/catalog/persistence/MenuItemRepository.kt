package ru.normaryadom.catalog.persistence

import org.springframework.jdbc.core.namedparam.MapSqlParameterSource
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcOperations
import org.springframework.jdbc.core.simple.JdbcClient
import org.springframework.stereotype.Repository
import ru.normaryadom.catalog.domain.MenuItem
import ru.normaryadom.catalog.domain.MenuScope
import ru.normaryadom.catalog.domain.Nutrients
import ru.normaryadom.catalog.domain.SourceKind
import java.sql.Timestamp
import java.time.Instant

@Repository
class MenuItemRepository(
    private val jdbc: JdbcClient,
    private val batchJdbc: NamedParameterJdbcOperations,
) {
    fun findAvailable(scope: MenuScope): List<MenuItem> =
        jdbc
            .sql(
                """
                SELECT ${MenuItemRows.SELECT_COLUMNS}
                FROM menu_item m
                WHERE m.is_available AND NOT m.under_review
                  AND (m.chain_id = :chainId OR m.venue_id = :venueId)
                ORDER BY m.category, m.name
                """,
            ).param("chainId", scope.chainId)
            .param("venueId", scope.venueId)
            .query { rs, _ -> MenuItemRows.map(rs) }
            .list()

    fun findById(id: Long): MenuItemRecord? =
        jdbc
            .sql(
                """
                SELECT ${MenuItemRows.SELECT_COLUMNS}, m.chain_id, m.venue_id, m.is_available, m.under_review
                FROM menu_item m
                WHERE m.id = :id
                """,
            ).param("id", id)
            .query { rs, _ -> MenuItemRecord.map(rs) }
            .optional()
            .orElse(null)

    fun lockAvailable(id: Long): MenuItemRecord? =
        jdbc
            .sql(
                """
                SELECT ${MenuItemRows.SELECT_COLUMNS}, m.chain_id, m.venue_id, m.is_available, m.under_review
                FROM menu_item m
                WHERE m.id = :id AND m.is_available
                FOR UPDATE
                """,
            ).param("id", id)
            .query { rs, _ -> MenuItemRecord.map(rs) }
            .optional()
            .orElse(null)

    fun findByChain(chainId: Long): List<MenuItemRecord> =
        jdbc
            .sql(
                """
                SELECT ${MenuItemRows.SELECT_COLUMNS}, m.chain_id, m.venue_id, m.is_available, m.under_review
                FROM menu_item m
                WHERE m.chain_id = :chainId
                ORDER BY m.is_available DESC, m.category, m.name
                """,
            ).param("chainId", chainId)
            .query { rs, _ -> MenuItemRecord.map(rs) }
            .list()

    fun findUnderReview(): List<MenuItemRecord> =
        jdbc
            .sql(
                """
                SELECT ${MenuItemRows.SELECT_COLUMNS}, m.chain_id, m.venue_id, m.is_available, m.under_review
                FROM menu_item m
                WHERE m.under_review
                ORDER BY m.id
                """,
            ).query { rs, _ -> MenuItemRecord.map(rs) }
            .list()

    fun upsertForChain(
        chainId: Long,
        drafts: List<MenuItemDraft>,
        provenance: Provenance,
    ) {
        batchJdbc.batchUpdate(
            """
            INSERT INTO menu_item (chain_id, name, category, portion_g, kcal, protein_g, fat_g, carbs_g,
                                   price_minor, tags, source_kind, source_url, verified_at)
            VALUES (:ownerId, :name, :category, :portion, :kcal, :protein, :fat, :carbs,
                    :price, :tags, :sourceKind, :sourceUrl, :verifiedAt)
            ON CONFLICT (chain_id, name) WHERE chain_id IS NOT NULL DO UPDATE SET
                category = EXCLUDED.category, portion_g = EXCLUDED.portion_g, kcal = EXCLUDED.kcal,
                protein_g = EXCLUDED.protein_g, fat_g = EXCLUDED.fat_g, carbs_g = EXCLUDED.carbs_g,
                price_minor = EXCLUDED.price_minor, tags = EXCLUDED.tags, source_kind = EXCLUDED.source_kind,
                source_url = EXCLUDED.source_url, verified_at = EXCLUDED.verified_at,
                kcal_low = NULL, kcal_high = NULL, is_available = TRUE
            """,
            drafts.map { draftParams(chainId, it, provenance) }.toTypedArray(),
        )
    }

    fun upsertForVenue(
        venueId: Long,
        drafts: List<MenuItemDraft>,
        provenance: Provenance,
    ) {
        batchJdbc.batchUpdate(
            """
            INSERT INTO menu_item (venue_id, name, category, portion_g, kcal, protein_g, fat_g, carbs_g,
                                   price_minor, tags, source_kind, source_url, verified_at)
            VALUES (:ownerId, :name, :category, :portion, :kcal, :protein, :fat, :carbs,
                    :price, :tags, :sourceKind, :sourceUrl, :verifiedAt)
            ON CONFLICT (venue_id, name) WHERE venue_id IS NOT NULL DO UPDATE SET
                category = EXCLUDED.category, portion_g = EXCLUDED.portion_g, kcal = EXCLUDED.kcal,
                protein_g = EXCLUDED.protein_g, fat_g = EXCLUDED.fat_g, carbs_g = EXCLUDED.carbs_g,
                price_minor = EXCLUDED.price_minor, tags = EXCLUDED.tags, source_kind = EXCLUDED.source_kind,
                source_url = EXCLUDED.source_url, verified_at = EXCLUDED.verified_at,
                kcal_low = NULL, kcal_high = NULL, is_available = TRUE
            """,
            drafts.map { draftParams(venueId, it, provenance) }.toTypedArray(),
        )
    }

    fun withdrawChainItemsExcept(
        chainId: Long,
        keptNames: Collection<String>,
    ): Int =
        jdbc
            .sql(
                """
                UPDATE menu_item SET is_available = FALSE, under_review = FALSE
                WHERE chain_id = :chainId AND is_available AND NOT (name = ANY (:names))
                """,
            ).param("chainId", chainId)
            .param("names", keptNames.toTypedArray())
            .update()

    fun markUnderReview(id: Long): Boolean =
        jdbc
            .sql("UPDATE menu_item SET under_review = TRUE WHERE id = :id AND NOT under_review")
            .param("id", id)
            .update() > 0

    fun confirm(id: Long) {
        jdbc
            .sql("UPDATE menu_item SET under_review = FALSE WHERE id = :id")
            .param("id", id)
            .update()
    }

    fun correctNutrients(
        id: Long,
        nutrients: Nutrients,
        verifiedAt: Instant,
    ) {
        jdbc
            .sql(
                """
                UPDATE menu_item
                SET kcal = :kcal, protein_g = :protein, fat_g = :fat, carbs_g = :carbs,
                    source_kind = 'B', source_url = NULL, kcal_low = NULL, kcal_high = NULL,
                    verified_at = :verifiedAt, under_review = FALSE
                WHERE id = :id
                """,
            ).param("id", id)
            .param("kcal", nutrients.kcal)
            .param("protein", nutrients.protein)
            .param("fat", nutrients.fat)
            .param("carbs", nutrients.carbs)
            .param("verifiedAt", Timestamp.from(verifiedAt))
            .update()
    }

    fun withdraw(id: Long) {
        jdbc
            .sql("UPDATE menu_item SET is_available = FALSE, under_review = FALSE WHERE id = :id")
            .param("id", id)
            .update()
    }

    private fun draftParams(
        ownerId: Long,
        draft: MenuItemDraft,
        provenance: Provenance,
    ): MapSqlParameterSource =
        MapSqlParameterSource()
            .addValue("ownerId", ownerId)
            .addValue("name", draft.name)
            .addValue("category", draft.category.code)
            .addValue("portion", draft.portionGrams)
            .addValue("kcal", draft.nutrients.kcal)
            .addValue("protein", draft.nutrients.protein)
            .addValue("fat", draft.nutrients.fat)
            .addValue("carbs", draft.nutrients.carbs)
            .addValue("price", draft.priceMinor)
            .addValue(
                "tags",
                draft.tags
                    .map { it.code }
                    .sorted()
                    .toTypedArray(),
            ).addValue("sourceKind", provenance.kind.code)
            .addValue("sourceUrl", provenance.url)
            .addValue("verifiedAt", Timestamp.from(provenance.verifiedAt))
}

data class Provenance(
    val kind: SourceKind,
    val url: String?,
    val verifiedAt: Instant,
)
