package ru.normaryadom.optimizer

import ru.normaryadom.catalog.domain.MenuItem
import ru.normaryadom.catalog.domain.Nutrients
import ru.normaryadom.catalog.domain.SourceKind
import kotlin.math.abs

class ComboScorer(
    private val weights: ScoreWeights,
) {
    fun combo(
        dishes: List<MenuItem>,
        criteria: SearchCriteria,
    ): Combo {
        val totals = dishes.fold(Nutrients.ZERO) { sum, dish -> sum + dish.nutrients }
        val priceMinor = totalPrice(dishes)
        val sourceKind = dishes.maxOf { it.source.kind }
        return Combo(
            dishes = dishes,
            totals = totals,
            priceMinor = priceMinor,
            sourceKind = sourceKind,
            score = score(totals, priceMinor, sourceKind, criteria),
        )
    }

    fun score(
        totals: Nutrients,
        priceMinor: Int?,
        sourceKind: SourceKind,
        criteria: SearchCriteria,
    ): Double {
        val target = criteria.target
        val kcalTerm = abs(totals.kcal - target.kcal) / target.kcalTolerance
        val proteinTerm = shortfall(totals.protein, target.minProtein)
        val fatTerm = usage(totals.fat, target.maxFat)
        val carbsTerm = usage(totals.carbs, target.maxCarbs)
        return weights.kcal * kcalTerm +
            weights.protein * proteinTerm +
            weights.fat * fatTerm +
            weights.carbs * carbsTerm +
            weights.trustPenalty(sourceKind) +
            criteria.pricePreference.penalty(priceMinor, weights)
    }

    private fun shortfall(
        value: Double,
        minimum: Double,
    ): Double = if (minimum <= 0.0) 0.0 else minimum / (minimum + value)

    private fun usage(
        value: Double,
        limit: Double,
    ): Double = if (limit <= 0.0) 0.0 else value / limit

    private fun totalPrice(dishes: List<MenuItem>): Int? =
        dishes
            .map(MenuItem::priceMinor)
            .takeIf { prices -> prices.all { it != null } }
            ?.sumOf { it ?: 0 }
}
