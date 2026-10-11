package ru.normaryadom.optimizer

import ru.normaryadom.catalog.domain.DishCategory
import ru.normaryadom.catalog.domain.MenuItem
import ru.normaryadom.catalog.domain.Nutrients

object ComboDiversifier {
    const val MAX_SHARED_DISHES = 1

    fun diversify(
        ranked: List<Combo>,
        limit: Int,
    ): List<Combo> =
        ranked.fold(emptyList()) { chosen, candidate ->
            if (chosen.size < limit && chosen.all { sharedDishes(it, candidate) <= MAX_SHARED_DISHES }) {
                chosen + candidate
            } else {
                chosen
            }
        }

    fun sharedDishes(
        first: Combo,
        second: Combo,
    ): Int {
        val firstCounts = first.dishes.groupingBy(::sameDish).eachCount()
        val secondCounts = second.dishes.groupingBy(::sameDish).eachCount()
        return firstCounts.entries.sumOf { (dish, count) -> minOf(count, secondCounts[dish] ?: 0) }
    }

    private fun sameDish(item: MenuItem): Pair<DishCategory, Nutrients> = item.category to item.nutrients
}
