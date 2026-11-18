package ru.normaryadom.optimizer

import ru.normaryadom.catalog.domain.MenuItem

data class SearchCriteria(
    val target: MealTarget,
    val pricePreference: PricePreference,
    val maxPriceMinor: Int? = null,
) {
    init {
        require(maxPriceMinor == null || maxPriceMinor > 0) { "Предел цены набора должен быть больше нуля" }
    }

    fun affordable(item: MenuItem): Boolean = withinBudget(item.priceMinor)

    fun withinBudget(priceMinor: Int?): Boolean = maxPriceMinor == null || (priceMinor != null && priceMinor <= maxPriceMinor)
}
