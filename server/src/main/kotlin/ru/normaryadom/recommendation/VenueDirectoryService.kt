package ru.normaryadom.recommendation

import org.springframework.stereotype.Service
import ru.normaryadom.geo.NearbyQuery
import ru.normaryadom.geo.NearbyVenue
import ru.normaryadom.geo.NearbyVenueRepository
import ru.normaryadom.optimizer.SearchCriteria
import ru.normaryadom.optimizer.TargetRelaxation

@Service
class VenueDirectoryService(
    private val nearbyVenues: NearbyVenueRepository,
    private val comboCache: MenuComboCache,
    private val relaxation: TargetRelaxation,
) {
    fun nearby(query: NearbyQuery): List<NearbyVenue> = nearbyVenues.findNearby(query)

    fun nearbyWithFit(
        query: NearbyQuery,
        criteria: SearchCriteria,
    ): List<VenueFit> {
        val strict = criteria.copy(target = TargetRounding.round(criteria.target))
        val relaxed = strict.copy(target = strict.target.relaxed(relaxation))
        return nearbyVenues.findNearby(query).map { nearbyVenue ->
            VenueFit(nearbyVenue, if (nearbyVenue.venue.hasMenu) fitOf(nearbyVenue, strict, relaxed) else null)
        }
    }

    private fun fitOf(
        nearbyVenue: NearbyVenue,
        strict: SearchCriteria,
        relaxed: SearchCriteria,
    ): FitLevel {
        val scope = nearbyVenue.venue.menuScope
        return when {
            comboCache.bestCombos(scope, strict).isNotEmpty() -> FitLevel.GOOD
            comboCache.bestCombos(scope, relaxed).isNotEmpty() -> FitLevel.COMPROMISE
            else -> FitLevel.NONE
        }
    }
}

data class VenueFit(
    val nearbyVenue: NearbyVenue,
    val fit: FitLevel?,
)
