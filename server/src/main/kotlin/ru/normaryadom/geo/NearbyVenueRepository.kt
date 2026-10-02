package ru.normaryadom.geo

import org.springframework.jdbc.core.simple.JdbcClient
import org.springframework.stereotype.Repository
import ru.normaryadom.catalog.persistence.VenueRows

@Repository
class NearbyVenueRepository(
    private val jdbc: JdbcClient,
) {
    fun findNearby(query: NearbyQuery): List<NearbyVenue> =
        jdbc
            .sql(
                """
                WITH nearby AS (
                    SELECT ${VenueRows.SELECT_COLUMNS},
                           ST_Distance(v.location, ST_SetSRID(ST_MakePoint(:lon, :lat), 4326)::geography) AS distance_m
                    ${VenueRows.FROM}
                    WHERE v.is_active
                      AND ST_DWithin(v.location, ST_SetSRID(ST_MakePoint(:lon, :lat), 4326)::geography, :radius)
                )
                SELECT * FROM nearby
                WHERE :includeWithoutMenu OR has_own_items OR has_chain_items
                ORDER BY distance_m, id
                LIMIT :limit
                """,
            ).param("lat", query.center.lat)
            .param("lon", query.center.lon)
            .param("radius", query.radiusMeters)
            .param("includeWithoutMenu", query.coverage == MenuCoverage.ALL)
            .param("limit", query.limit)
            .query { rs, _ -> NearbyVenue(venue = VenueRows.map(rs), distanceMeters = rs.getDouble("distance_m")) }
            .list()
}
