package ru.normaryadom.optimizer

import ru.normaryadom.catalog.domain.MenuItem
import ru.normaryadom.catalog.domain.Nutrients
import ru.normaryadom.catalog.domain.SourceKind

data class Combo(
    val dishes: List<MenuItem>,
    val totals: Nutrients,
    val priceMinor: Int?,
    val sourceKind: SourceKind,
    val score: Double,
) {
    val dishIds: List<Long> get() = dishes.map(MenuItem::id)

    companion object {
        val ORDER: Comparator<Combo> =
            Comparator
                .comparingDouble(Combo::score)
                .thenComparing(Combo::dishIds, LexicographicOrder)
    }
}

private object LexicographicOrder : Comparator<List<Long>> {
    override fun compare(
        left: List<Long>,
        right: List<Long>,
    ): Int =
        left
            .zip(right)
            .map { (a, b) -> a.compareTo(b) }
            .firstOrNull { it != 0 }
            ?: left.size.compareTo(right.size)
}
