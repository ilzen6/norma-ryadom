package ru.normaryadom.catalog.persistence

import ru.normaryadom.catalog.domain.DietTag
import ru.normaryadom.catalog.domain.DishCategory
import ru.normaryadom.catalog.domain.Nutrients

data class MenuItemDraft(
    val name: String,
    val category: DishCategory,
    val portionGrams: Double?,
    val nutrients: Nutrients,
    val priceMinor: Int?,
    val tags: Set<DietTag>,
)
