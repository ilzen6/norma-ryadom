package ru.normaryadom.support

import ru.normaryadom.catalog.domain.DataSource
import ru.normaryadom.catalog.domain.DietTag
import ru.normaryadom.catalog.domain.DishCategory
import ru.normaryadom.catalog.domain.KcalRange
import ru.normaryadom.catalog.domain.MenuItem
import ru.normaryadom.catalog.domain.Nutrients
import ru.normaryadom.catalog.domain.SourceKind
import ru.normaryadom.optimizer.ComboOptimizer
import ru.normaryadom.optimizer.ComboScorer
import ru.normaryadom.optimizer.MealTarget
import ru.normaryadom.optimizer.OptimizerSettings
import ru.normaryadom.optimizer.PricePreference
import ru.normaryadom.optimizer.ScoreWeights
import ru.normaryadom.optimizer.SearchCriteria
import java.time.Instant

object MenuTestData {
    val WEIGHTS =
        ScoreWeights(
            kcal = 1.0,
            protein = 0.6,
            fat = 0.3,
            carbs = 0.1,
            trustB = 0.15,
            trustC = 0.6,
            price = 0.5,
            priceScaleMinor = 100_000.0,
        )

    val SETTINGS = OptimizerSettings(maxItems = 3, heapFactor = 4)

    fun scorer(): ComboScorer = ComboScorer(WEIGHTS)

    fun optimizer(): ComboOptimizer = ComboOptimizer(scorer(), SETTINGS)

    fun dish(
        id: Long,
        category: DishCategory = DishCategory.MAIN,
        kcal: Double = 400.0,
        protein: Double = 25.0,
        fat: Double = 10.0,
        carbs: Double = 40.0,
        priceMinor: Int? = 30_000,
        tags: Set<DietTag> = emptySet(),
        source: SourceKind = SourceKind.A,
        name: String = "Блюдо $id",
    ): MenuItem =
        MenuItem(
            id = id,
            name = name,
            category = category,
            portionGrams = 200.0,
            nutrients = Nutrients(kcal = kcal, protein = protein, fat = fat, carbs = carbs),
            priceMinor = priceMinor,
            tags = tags,
            source =
                DataSource(
                    kind = source,
                    url = null,
                    verifiedAt = Instant.parse("2026-09-01T00:00:00Z"),
                    kcalRange = if (source == SourceKind.C) KcalRange(kcal * 0.7, kcal * 1.3) else null,
                ),
        )

    fun target(
        kcal: Double = 600.0,
        tolerance: Double = 60.0,
        minProtein: Double = 30.0,
        maxFat: Double = 25.0,
        maxCarbs: Double = 90.0,
        excluded: Set<DietTag> = emptySet(),
    ): MealTarget = MealTarget(kcal, tolerance, minProtein, maxFat, maxCarbs, excluded)

    fun criteria(
        target: MealTarget = target(),
        price: PricePreference = PricePreference.IGNORE,
    ): SearchCriteria = SearchCriteria(target, price)
}
