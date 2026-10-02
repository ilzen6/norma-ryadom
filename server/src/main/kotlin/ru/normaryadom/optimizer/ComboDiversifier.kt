package ru.normaryadom.optimizer

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
        val firstCounts = first.dishIds.groupingBy { it }.eachCount()
        val secondCounts = second.dishIds.groupingBy { it }.eachCount()
        return firstCounts.entries.sumOf { (id, count) -> minOf(count, secondCounts[id] ?: 0) }
    }
}
