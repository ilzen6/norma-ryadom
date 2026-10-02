package ru.normaryadom.recommendation.config

import org.springframework.context.annotation.Bean
import org.springframework.context.annotation.Configuration
import ru.normaryadom.optimizer.ComboOptimizer
import ru.normaryadom.optimizer.ComboScorer
import ru.normaryadom.optimizer.OptimizerSettings
import ru.normaryadom.optimizer.ScoreWeights
import ru.normaryadom.optimizer.TargetRelaxation

@Configuration(proxyBeanMethods = false)
class OptimizerConfiguration {
    @Bean
    fun comboScorer(properties: OptimizerProperties): ComboScorer =
        ComboScorer(
            ScoreWeights(
                kcal = properties.weights.kcal,
                protein = properties.weights.protein,
                fat = properties.weights.fat,
                carbs = properties.weights.carbs,
                trustB = properties.weights.trustB,
                trustC = properties.weights.trustC,
                price = properties.weights.price,
                priceScaleMinor = properties.weights.priceScaleMinor,
            ),
        )

    @Bean
    fun comboOptimizer(
        scorer: ComboScorer,
        properties: OptimizerProperties,
    ): ComboOptimizer = ComboOptimizer(scorer, OptimizerSettings(maxItems = properties.maxItems, heapFactor = properties.heapFactor))

    @Bean
    fun targetRelaxation(properties: OptimizerProperties): TargetRelaxation =
        TargetRelaxation(
            kcalToleranceFactor = properties.relaxation.kcalToleranceFactor,
            proteinFactor = properties.relaxation.proteinFactor,
            limitFactor = properties.relaxation.limitFactor,
        )
}
