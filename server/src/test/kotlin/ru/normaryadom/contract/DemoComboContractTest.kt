package ru.normaryadom.contract

import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test
import ru.normaryadom.catalog.domain.DataSource
import ru.normaryadom.catalog.domain.DietTag
import ru.normaryadom.catalog.domain.MenuItem
import ru.normaryadom.catalog.domain.SourceKind
import ru.normaryadom.catalog.importing.CsvParseResult
import ru.normaryadom.catalog.importing.MenuCsvParser
import ru.normaryadom.optimizer.Combo
import ru.normaryadom.optimizer.MealTarget
import ru.normaryadom.optimizer.PricePreference
import ru.normaryadom.optimizer.SearchCriteria
import ru.normaryadom.optimizer.TargetRelaxation
import ru.normaryadom.recommendation.DishAssessor
import ru.normaryadom.recommendation.TargetRounding
import ru.normaryadom.support.MenuTestData
import tools.jackson.databind.SerializationFeature
import tools.jackson.databind.json.JsonMapper
import java.nio.file.Files
import java.nio.file.Path

class DemoComboContractTest {
    private val optimizer = MenuTestData.optimizer()
    private val assessor = DishAssessor(MenuTestData.scorer())
    private val relaxation = TargetRelaxation(kcalToleranceFactor = 2.0, proteinFactor = 0.8, limitFactor = 1.2)
    private val mapper = JsonMapper.builder().enable(SerializationFeature.INDENT_OUTPUT).build()

    @Test
    fun `подбор на демо-каталоге совпадает с эталоном, по которому проверяется демо-режим клиента`() {
        val generated = mapper.writeValueAsString(mapOf("cases" to CASES.map(::caseOf))) + "\n"
        val file = Path.of(System.getProperty("contract.dir"), "combo-cases.json")
        if (System.getProperty("contract.update").toBoolean()) Files.writeString(file, generated)

        assertThat(Files.readString(file)).isEqualTo(generated)
    }

    private fun caseOf(case: ContractCase): Map<String, Any> {
        val exact = SearchCriteria(case.target, case.price)
        val rounded = exact.copy(target = TargetRounding.round(case.target))
        val relaxed = rounded.copy(target = rounded.target.relaxed(relaxation))
        return mapOf(
            "name" to case.name,
            "target" to targetOf(case.target),
            "preferCheaper" to (case.price == PricePreference.PREFER_CHEAPER),
            "roundedTarget" to targetOf(rounded.target),
            "chains" to
                demoMenus().map { (chain, menu) ->
                    val nearby = optimizer.bestCombos(menu, rounded, COMBOS)
                    val fit =
                        when {
                            nearby.isNotEmpty() -> "GOOD"
                            optimizer.bestCombos(menu, relaxed, COMBOS).isNotEmpty() -> "COMPROMISE"
                            else -> "NONE"
                        }
                    mapOf(
                        "chain" to chain,
                        "fit" to fit,
                        "nearby" to nearby.map(::comboOf),
                        "atVenue" to optimizer.bestCombos(menu, exact, COMBOS).map(::comboOf),
                        "replaceFirst" to
                            nearby
                                .firstOrNull()
                                ?.let { best ->
                                    optimizer.replacements(menu, rounded, best.dishes, 0, REPLACEMENTS).map(::comboOf)
                                }.orEmpty(),
                        "assessment" to
                            assessor.assessMenu(menu, exact).map { assessment ->
                                mapOf(
                                    "dish" to assessment.item.name,
                                    "verdict" to assessment.verdict.name,
                                    "reasons" to assessment.reasons.map { it.code.name },
                                )
                            },
                    )
                },
        )
    }

    private fun comboOf(combo: Combo): Map<String, Any> =
        mapOf("dishes" to combo.dishes.map(MenuItem::name), "score" to Math.round(combo.score * SCORE_SCALE) / SCORE_SCALE)

    private fun targetOf(target: MealTarget): Map<String, Any> =
        mapOf(
            "kcal" to target.kcal,
            "kcalTolerance" to target.kcalTolerance,
            "minProtein" to target.minProtein,
            "maxFat" to target.maxFat,
            "maxCarbs" to target.maxCarbs,
            "excludeTags" to target.excludedTags.map(DietTag::code).sorted(),
        )

    private fun demoMenus(): List<Pair<String, List<MenuItem>>> {
        var nextId = 1L
        return DEMO_CHAINS.map { (chain, file) ->
            val csv = requireNotNull(javaClass.getResource("/demo/$file-menu.csv")).readBytes()
            val drafts = (MenuCsvParser().parse(csv) as CsvParseResult.Parsed).rows
            chain to
                drafts.map { draft ->
                    MenuItem(
                        id = nextId++,
                        name = draft.name,
                        category = draft.category,
                        portionGrams = draft.portionGrams,
                        nutrients = draft.nutrients,
                        priceMinor = draft.priceMinor,
                        tags = draft.tags,
                        source = DataSource(SourceKind.A, null, null, null),
                    )
                }
        }
    }

    private data class ContractCase(
        val name: String,
        val target: MealTarget,
        val price: PricePreference = PricePreference.IGNORE,
    )

    private companion object {
        const val COMBOS = 5
        const val REPLACEMENTS = 3
        const val SCORE_SCALE = 1_000_000.0

        val DEMO_CHAINS =
            listOf(
                "Гриль Хаус" to "grill-house",
                "Тёплая плошка" to "warm-bowl",
                "Блинная Масленица" to "blinnaya",
                "Кофейня Зерно" to "zerno",
                "Пицца Квадрат" to "pizza-square",
                "Зелёный бар" to "green-bar",
            )

        val CASES =
            listOf(
                ContractCase("обед без свинины", MealTarget(630.0, 63.0, 27.7, 23.5, 94.5, setOf(DietTag.PORK))),
                ContractCase(
                    "обед без свинины подешевле",
                    MealTarget(630.0, 63.0, 27.7, 23.5, 94.5, setOf(DietTag.PORK)),
                    PricePreference.PREFER_CHEAPER,
                ),
                ContractCase("завтрак", MealTarget(450.0, 45.0, 19.8, 16.8, 67.5, emptySet())),
                ContractCase(
                    "вегетарианский ужин",
                    MealTarget(540.0, 54.0, 23.8, 20.2, 81.0, setOf(DietTag.MEAT, DietTag.FISH, DietTag.SEAFOOD)),
                ),
                ContractCase("перекус", MealTarget(180.0, 30.0, 5.0, 10.0, 30.0, emptySet())),
            )
    }
}
