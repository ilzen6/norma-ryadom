package ru.normaryadom.catalog.domain

import java.time.Instant

data class MenuItem(
    val id: Long,
    val name: String,
    val category: DishCategory,
    val portionGrams: Double?,
    val nutrients: Nutrients,
    val priceMinor: Int?,
    val tags: Set<DietTag>,
    val source: DataSource,
)

data class DataSource(
    val kind: SourceKind,
    val url: String?,
    val verifiedAt: Instant?,
    val kcalRange: KcalRange?,
)

data class KcalRange(
    val low: Double,
    val high: Double,
)
