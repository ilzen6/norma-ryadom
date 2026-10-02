package ru.normaryadom.optimizer

import ru.normaryadom.catalog.domain.DishCategory
import ru.normaryadom.catalog.domain.MenuItem

object MealStructure {
    const val MAX_SAME_DISH = 2

    private val categoryLimits =
        mapOf(
            DishCategory.MAIN to 1,
            DishCategory.DRINK to 1,
            DishCategory.SAUCE to 1,
        )

    private val sauceCarriers = setOf(DishCategory.MAIN, DishCategory.SIDE, DishCategory.SALAD)

    fun canAdd(
        picked: List<MenuItem>,
        candidate: MenuItem,
    ): Boolean {
        val categoryLimit = categoryLimits[candidate.category] ?: Int.MAX_VALUE
        return picked.count { it.category == candidate.category } < categoryLimit &&
            picked.count { it.id == candidate.id } < MAX_SAME_DISH
    }

    fun isComplete(dishes: List<MenuItem>): Boolean =
        dishes.none { it.category == DishCategory.SAUCE } || dishes.any { it.category in sauceCarriers }

    fun isValid(dishes: List<MenuItem>): Boolean =
        dishes.isNotEmpty() &&
            dishes.indices.all { index -> canAdd(dishes.subList(0, index), dishes[index]) } &&
            isComplete(dishes)
}
