package ru.normaryadom.optimizer

import ru.normaryadom.catalog.domain.MenuItem
import ru.normaryadom.catalog.domain.Nutrients
import java.util.PriorityQueue

class ComboOptimizer(
    private val scorer: ComboScorer,
    private val settings: OptimizerSettings,
) {
    fun bestCombos(
        menu: List<MenuItem>,
        criteria: SearchCriteria,
        limit: Int,
    ): List<Combo> {
        val allowed =
            menu
                .filter { criteria.target.allows(it) && criteria.affordable(it) }
                .sortedWith(compareBy<MenuItem>({ it.nutrients.kcal }, { it.id }))
        val best = BoundedBest(limit * settings.heapFactor)
        Enumeration(allowed, criteria, best).run()
        return ComboDiversifier.diversify(best.ranked(), limit)
    }

    fun replacements(
        menu: List<MenuItem>,
        criteria: SearchCriteria,
        dishes: List<MenuItem>,
        replacedIndex: Int,
        limit: Int,
    ): List<Combo> {
        val replaced = dishes[replacedIndex]
        return menu
            .asSequence()
            .filter { it.id != replaced.id && criteria.target.allows(it) }
            .map { candidate -> dishes.toMutableList().apply { set(replacedIndex, candidate) }.toList() }
            .filter(MealStructure::isValid)
            .map { scorer.combo(it, criteria) }
            .filter { criteria.target.isSatisfiedBy(it.totals) && criteria.withinBudget(it.priceMinor) }
            .sortedWith(Combo.ORDER)
            .take(limit)
            .toList()
    }

    private inner class Enumeration(
        private val allowed: List<MenuItem>,
        private val criteria: SearchCriteria,
        private val best: BoundedBest,
    ) {
        private val picked = ArrayList<MenuItem>(settings.maxItems)
        private val upperKcal = criteria.target.maxKcal + MealTarget.EPSILON

        fun run() = visit(start = 0, totals = Nutrients.ZERO, priceMinor = 0)

        private fun visit(
            start: Int,
            totals: Nutrients,
            priceMinor: Int,
        ) {
            if (picked.isNotEmpty() && criteria.target.isSatisfiedBy(totals) && MealStructure.isComplete(picked)) {
                best.offer(scorer.combo(picked.toList(), criteria))
            }
            if (picked.size == settings.maxItems) return
            var index = start
            while (index < allowed.size && totals.kcal + allowed[index].nutrients.kcal <= upperKcal) {
                val dish = allowed[index]
                val nextPrice = priceMinor + (dish.priceMinor ?: 0)
                if (MealStructure.canAdd(picked, dish) && criteria.withinBudget(nextPrice)) {
                    picked += dish
                    visit(index, totals + dish.nutrients, nextPrice)
                    picked.removeLast()
                }
                index++
            }
        }
    }

    private class BoundedBest(
        private val capacity: Int,
    ) {
        private val heap = PriorityQueue(capacity + 1, Combo.ORDER.reversed())

        fun offer(combo: Combo) {
            if (heap.size < capacity) {
                heap += combo
            } else if (Combo.ORDER.compare(combo, heap.peek()) < 0) {
                heap.poll()
                heap += combo
            }
        }

        fun ranked(): List<Combo> = heap.sortedWith(Combo.ORDER)
    }
}
