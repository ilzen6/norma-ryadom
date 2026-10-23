package ru.normaryadom.catalog.persistence

import org.springframework.jdbc.core.simple.JdbcClient
import org.springframework.stereotype.Repository
import ru.normaryadom.catalog.domain.Chain
import java.sql.ResultSet

@Repository
class ChainRepository(
    private val jdbc: JdbcClient,
) {
    fun findAll(): List<ChainSummary> =
        jdbc
            .sql(
                """
                SELECT c.id, c.name, c.currency, c.source_url, c.menu_version, c.template_code,
                       (SELECT count(*) FROM menu_item m WHERE m.chain_id = c.id AND m.is_available) AS item_count,
                       (SELECT count(*) FROM venue v WHERE (v.chain_id = c.id OR v.template_id = c.id) AND v.is_active) AS venue_count
                FROM chain c
                ORDER BY c.name
                """,
            ).query { rs, _ ->
                ChainSummary(
                    chain = mapChain(rs),
                    itemCount = rs.getInt("item_count"),
                    venueCount = rs.getInt("venue_count"),
                )
            }.list()

    fun findById(id: Long): Chain? =
        jdbc
            .sql("SELECT c.id, c.name, c.currency, c.source_url, c.menu_version, c.template_code FROM chain c WHERE c.id = :id")
            .param("id", id)
            .query { rs, _ -> mapChain(rs) }
            .optional()
            .orElse(null)

    fun findByName(name: String): Chain? =
        jdbc
            .sql("SELECT c.id, c.name, c.currency, c.source_url, c.menu_version, c.template_code FROM chain c WHERE c.name = :name")
            .param("name", name)
            .query { rs, _ -> mapChain(rs) }
            .optional()
            .orElse(null)

    fun create(
        name: String,
        sourceUrl: String?,
        templateCode: String? = null,
    ): Long =
        jdbc
            .sql("INSERT INTO chain (name, source_url, template_code) VALUES (:name, :sourceUrl, :templateCode) RETURNING id")
            .param("name", name)
            .param("sourceUrl", sourceUrl)
            .param("templateCode", templateCode)
            .query(Long::class.java)
            .single()

    fun findTemplateIds(): Map<String, Long> =
        jdbc
            .sql("SELECT template_code, id FROM chain WHERE template_code IS NOT NULL")
            .query { rs, _ -> rs.getString("template_code") to rs.getLong("id") }
            .list()
            .toMap()

    fun updateSourceUrl(
        id: Long,
        sourceUrl: String,
    ) {
        jdbc
            .sql("UPDATE chain SET source_url = :sourceUrl WHERE id = :id")
            .param("id", id)
            .param("sourceUrl", sourceUrl)
            .update()
    }

    fun bumpMenuVersion(id: Long) {
        jdbc
            .sql("UPDATE chain SET menu_version = menu_version + 1 WHERE id = :id")
            .param("id", id)
            .update()
    }

    private fun mapChain(rs: ResultSet): Chain =
        Chain(
            id = rs.getLong("id"),
            name = rs.getString("name"),
            currency = rs.getString("currency"),
            sourceUrl = rs.getString("source_url"),
            menuVersion = rs.getLong("menu_version"),
            templateCode = rs.getString("template_code"),
        )
}

data class ChainSummary(
    val chain: Chain,
    val itemCount: Int,
    val venueCount: Int,
)
