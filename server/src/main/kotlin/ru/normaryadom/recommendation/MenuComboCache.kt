package ru.normaryadom.recommendation

import org.springframework.cache.annotation.Cacheable
import org.springframework.stereotype.Component
import ru.normaryadom.catalog.domain.MenuScope
import ru.normaryadom.catalog.service.VenueMenuService
import ru.normaryadom.optimizer.Combo
import ru.normaryadom.optimizer.ComboOptimizer
import ru.normaryadom.optimizer.SearchCriteria

@Component
class MenuComboCache(
    private val menus: VenueMenuService,
    private val optimizer: ComboOptimizer,
) {
    @Cacheable(cacheNames = [CACHE_NAME], sync = true)
    fun bestCombos(
        scope: MenuScope,
        criteria: SearchCriteria,
    ): List<Combo> = optimizer.bestCombos(menus.menu(scope), criteria, CACHED_COMBOS)

    companion object {
        const val CACHE_NAME = "bestCombos"
        const val CACHED_COMBOS = 5
    }
}
