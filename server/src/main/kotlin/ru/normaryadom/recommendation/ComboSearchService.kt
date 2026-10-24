package ru.normaryadom.recommendation

import org.springframework.stereotype.Service
import ru.normaryadom.catalog.domain.GeoPoint
import ru.normaryadom.catalog.domain.MenuItem
import ru.normaryadom.catalog.domain.Venue
import ru.normaryadom.catalog.service.VenueMenuService
import ru.normaryadom.geo.MenuCoverage
import ru.normaryadom.geo.NearbyQuery
import ru.normaryadom.geo.NearbyVenue
import ru.normaryadom.geo.NearbyVenueRepository
import ru.normaryadom.optimizer.Combo
import ru.normaryadom.optimizer.ComboOptimizer
import ru.normaryadom.optimizer.SearchCriteria
import ru.normaryadom.optimizer.TargetRelaxation
import ru.normaryadom.recommendation.config.NearbyProperties

@Service
class ComboSearchService(
    private val menus: VenueMenuService,
    private val nearbyVenues: NearbyVenueRepository,
    private val optimizer: ComboOptimizer,
    private val comboCache: MenuComboCache,
    private val nearby: NearbyProperties,
    private val relaxation: TargetRelaxation,
) {
    fun searchAtVenue(
        venueId: Long,
        criteria: SearchCriteria,
        limit: Int,
    ): ComboSearchResult {
        val venue = menus.venue(venueId)
        val menu = menus.menu(venue.menuScope)
        val combos = firstNonEmpty(criteria) { tier -> optimizer.bestCombos(menu, tier, limit) }
        return ComboSearchResult(
            appliedCriteria = criteria,
            options = combos.map { ComboOption(venue = venue, distanceMeters = null, combo = it) },
        )
    }

    fun searchNearby(
        center: GeoPoint,
        radiusMeters: Int,
        criteria: SearchCriteria,
        limit: Int,
    ): ComboSearchResult {
        val applied = criteria.copy(target = TargetRounding.round(criteria.target))
        val query = NearbyQuery(center, radiusMeters, MenuCoverage.WITH_MENU_ONLY, nearby.maxResults, limitEachMenuKind = true)
        val options =
            nearbyVenues
                .findNearby(query)
                .groupBy(::menuGroup)
                .values
                .map { venuesWithSameMenu -> venuesWithSameMenu.minBy(NearbyVenue::distanceMeters) }
                .flatMap { closest -> optionsFor(closest, applied) }
                .sortedWith(compareBy<RankedOption> { it.rank }.thenComparing({ it.option.combo }, Combo.ORDER))
                .let(::limitRepeatedTemplates)
                .take(limit)
                .map(RankedOption::option)
        return ComboSearchResult(appliedCriteria = applied, options = options)
    }

    fun replace(
        venueId: Long,
        criteria: SearchCriteria,
        dishIds: List<Long>,
        replaceIndex: Int,
        limit: Int,
    ): ComboSearchResult {
        if (replaceIndex !in dishIds.indices) throw ReplaceIndexOutOfRangeException(replaceIndex, dishIds.size)
        val venue = menus.venue(venueId)
        val menu = menus.menu(venue.menuScope)
        val dishes = dishesFrom(menu, dishIds)
        val excluded = dishes.filterIndexed { index, dish -> index != replaceIndex && !criteria.target.allows(dish) }
        if (excluded.isNotEmpty()) throw DishExcludedException(excluded.map { it.id }.distinct())
        val combos = firstNonEmpty(criteria) { tier -> optimizer.replacements(menu, tier, dishes, replaceIndex, limit) }
        return ComboSearchResult(
            appliedCriteria = criteria,
            options = combos.map { ComboOption(venue = venue, distanceMeters = null, combo = it) },
        )
    }

    private fun dishesFrom(
        menu: List<MenuItem>,
        dishIds: List<Long>,
    ): List<MenuItem> {
        val byId = menu.associateBy { it.id }
        val missing = dishIds.filterNot(byId::containsKey)
        if (missing.isNotEmpty()) throw DishNotInMenuException(missing.distinct())
        return dishIds.map(byId::getValue)
    }

    private fun tiers(criteria: SearchCriteria): List<SearchCriteria> =
        generateSequence(criteria) { it.copy(target = it.target.relaxed(relaxation)) }.take(COMPROMISE_STEPS + 1).toList()

    private fun firstNonEmpty(
        criteria: SearchCriteria,
        search: (SearchCriteria) -> List<Combo>,
    ): List<Combo> =
        tiers(criteria)
            .asSequence()
            .map(search)
            .firstOrNull { it.isNotEmpty() }
            .orEmpty()

    private fun limitRepeatedTemplates(options: List<RankedOption>): List<RankedOption> {
        val shown = mutableMapOf<List<String>, Int>()
        return options.filter { ranked ->
            val option = ranked.option
            !option.venue.usesTemplateMenu ||
                shown.merge(option.combo.dishes.map { it.name }, 1, Int::plus)!! <= nearby.venuesPerTemplate
        }
    }

    private fun menuGroup(nearbyVenue: NearbyVenue): Any =
        if (nearbyVenue.venue.usesTemplateMenu) nearbyVenue.venue.id else nearbyVenue.venue.menuScope

    private fun optionsFor(
        nearbyVenue: NearbyVenue,
        criteria: SearchCriteria,
    ): List<RankedOption> {
        val distancePenalty = nearby.distanceWeightPerKm * nearbyVenue.distanceMeters / METERS_PER_KILOMETER
        val perVenue = if (nearbyVenue.venue.usesTemplateMenu) nearby.combosPerTemplateVenue else nearby.combosPerVenue
        return tiers(criteria)
            .asSequence()
            .mapIndexed { step, tier -> step to comboCache.bestCombos(nearbyVenue.venue.menuScope, tier) }
            .firstOrNull { (_, combos) -> combos.isNotEmpty() }
            ?.let { (step, combos) ->
                combos.take(perVenue).map { combo ->
                    RankedOption(
                        option = ComboOption(nearbyVenue.venue, nearbyVenue.distanceMeters, combo),
                        rank = combo.score + distancePenalty + step * nearby.compromisePenalty,
                    )
                }
            }.orEmpty()
    }

    private data class RankedOption(
        val option: ComboOption,
        val rank: Double,
    )

    private companion object {
        const val METERS_PER_KILOMETER = 1000.0
        const val COMPROMISE_STEPS = 2
    }
}

data class ComboSearchResult(
    val appliedCriteria: SearchCriteria,
    val options: List<ComboOption>,
)

data class ComboOption(
    val venue: Venue,
    val distanceMeters: Double?,
    val combo: Combo,
)
