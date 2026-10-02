package ru.normaryadom.geo

import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test
import org.springframework.beans.factory.annotation.Autowired
import ru.normaryadom.catalog.domain.GeoPoint
import ru.normaryadom.support.CatalogFixtures.Companion.BOWL_MENU
import ru.normaryadom.support.CatalogFixtures.Companion.BOWL_VENUES
import ru.normaryadom.support.CatalogFixtures.Companion.CITY_LAT
import ru.normaryadom.support.CatalogFixtures.Companion.CITY_LON
import ru.normaryadom.support.CatalogFixtures.Companion.GRILL_MENU
import ru.normaryadom.support.CatalogFixtures.Companion.GRILL_VENUES
import ru.normaryadom.support.IntegrationTest
import java.nio.file.Files
import java.nio.file.Path

class NearbyVenueRepositoryIT : IntegrationTest() {
    @Autowired
    private lateinit var repository: NearbyVenueRepository

    private val city = GeoPoint(CITY_LAT, CITY_LON)

    @Test
    fun `находит точки в радиусе, ближайшие первыми`() {
        catalog.chain("Гриль", GRILL_MENU, GRILL_VENUES)
        catalog.chain("Боулы", BOWL_MENU, BOWL_VENUES)

        val nearby = repository.findNearby(NearbyQuery(city, 1000, MenuCoverage.WITH_MENU_ONLY, 50))

        assertThat(nearby.map { it.venue.name }).containsExactly("Гриль, Сити", "Боулы, Сити")
        assertThat(nearby.map { it.distanceMeters }).allSatisfy { assertThat(it).isBetween(0.0, 1000.0) }
        assertThat(nearby.map { it.distanceMeters }).satisfiesExactly(
            { assertThat(it).isBetween(140.0, 150.0) },
            { assertThat(it).isBetween(160.0, 175.0) },
        )
    }

    @Test
    fun `расширяет поиск при большем радиусе и ограничивает число результатов`() {
        catalog.chain("Гриль", GRILL_MENU, GRILL_VENUES)
        catalog.chain("Боулы", BOWL_MENU, BOWL_VENUES)

        assertThat(repository.findNearby(NearbyQuery(city, 5000, MenuCoverage.WITH_MENU_ONLY, 50))).hasSize(3)
        assertThat(repository.findNearby(NearbyQuery(city, 5000, MenuCoverage.WITH_MENU_ONLY, 2))).hasSize(2)
    }

    @Test
    fun `не путает широту и долготу`() {
        catalog.chain("Гриль", GRILL_MENU, GRILL_VENUES)

        assertThat(repository.findNearby(NearbyQuery(GeoPoint(CITY_LON, CITY_LAT), 5000, MenuCoverage.ALL, 50))).isEmpty()
    }

    @Test
    fun `по умолчанию скрывает точки без меню и неактивные точки`() {
        catalog.chain("Гриль", GRILL_MENU, GRILL_VENUES)
        catalog.chain("Без меню", listOf("Временное;main;100;100;1;1;1;;"), listOf("Пусто;адрес;55.7490;37.5380;empty-01"))
        jdbc.sql("UPDATE menu_item SET is_available = FALSE WHERE name = 'Временное'").update()
        jdbc.sql("UPDATE venue SET is_active = FALSE WHERE external_id = 'grill-02'").update()

        val withMenu = repository.findNearby(NearbyQuery(city, 5000, MenuCoverage.WITH_MENU_ONLY, 50))
        val all = repository.findNearby(NearbyQuery(city, 5000, MenuCoverage.ALL, 50))

        assertThat(withMenu.map { it.venue.name }).containsExactly("Гриль, Сити")
        assertThat(all.map { it.venue.name to it.venue.hasMenu }).containsExactly("Пусто" to false, "Гриль, Сити" to true)
    }

    @Test
    fun `геозапрос использует пространственный индекс на 10 тысячах точек`() {
        jdbc
            .sql(
                """
                INSERT INTO venue (name, address, location, external_id)
                SELECT 'Точка ' || g, 'Адрес ' || g,
                       ST_SetSRID(ST_MakePoint(37.3 + random() * 0.6, 55.55 + random() * 0.35), 4326)::geography, 'p-' || g
                FROM generate_series(1, 10000) g
                """,
            ).update()
        jdbc.sql("ANALYZE venue").update()

        val plan =
            jdbc
                .sql(
                    """
                    EXPLAIN (ANALYZE, BUFFERS)
                    SELECT v.id, ST_Distance(v.location, ST_SetSRID(ST_MakePoint(:lon, :lat), 4326)::geography) AS distance_m
                    FROM venue v
                    WHERE v.is_active AND ST_DWithin(v.location, ST_SetSRID(ST_MakePoint(:lon, :lat), 4326)::geography, :radius)
                    ORDER BY distance_m
                    LIMIT 50
                    """,
                ).param("lat", CITY_LAT)
                .param("lon", CITY_LON)
                .param("radius", 1000)
                .query(String::class.java)
                .list()
                .joinToString("\n")
        val report = Path.of("build", "reports", "explain", "nearby-venues.txt")
        Files.createDirectories(report.parent)
        Files.writeString(report, plan)

        assertThat(plan).contains("venue_location_gix").doesNotContain("Seq Scan on venue")
    }
}
