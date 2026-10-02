package ru.normaryadom.optimizer

import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test
import ru.normaryadom.catalog.domain.DishCategory
import ru.normaryadom.catalog.domain.MenuItem
import ru.normaryadom.catalog.domain.SourceKind
import ru.normaryadom.support.MenuTestData
import java.nio.file.Files
import java.nio.file.Path
import kotlin.random.Random
import kotlin.time.Duration
import kotlin.time.Duration.Companion.milliseconds
import kotlin.time.measureTime

class ComboOptimizerPerformanceTest {
    private val optimizer = MenuTestData.optimizer()

    @Test
    fun `подбирает наборы из меню на 250 позиций быстрее бюджета времени`() {
        val menu = randomMenu(size = 250, seed = 42)
        val criteria = MenuTestData.criteria(MenuTestData.target(kcal = 650.0, tolerance = 65.0, minProtein = 30.0))
        repeat(WARMUP_RUNS) { optimizer.bestCombos(menu, criteria, 5) }

        val median = medianOf(MEASURED_RUNS) { optimizer.bestCombos(menu, criteria, 5) }

        assertThat(median).isLessThan(BUDGET)
    }

    @Test
    fun `записывает время подбора в зависимости от размера меню для отчёта`() {
        val criteria = MenuTestData.criteria(MenuTestData.target(kcal = 650.0, tolerance = 65.0, minProtein = 30.0))
        val rows =
            listOf(25, 50, 100, 150, 200, 250).map { size ->
                val menu = randomMenu(size, seed = size.toLong())
                repeat(WARMUP_RUNS) { optimizer.bestCombos(menu, criteria, 5) }
                size to medianOf(MEASURED_RUNS) { optimizer.bestCombos(menu, criteria, 5) }
            }
        val report = Path.of("build", "reports", "performance", "optimizer-timing.csv")
        Files.createDirectories(report.parent)
        val lines = rows.joinToString("\n") { (size, time) -> "$size;${time.inWholeMicroseconds / 1000.0}" }
        Files.writeString(report, "menu_size;median_ms\n$lines")

        assertThat(rows.map { it.second }).allSatisfy { assertThat(it).isLessThan(BUDGET) }
    }

    private fun medianOf(
        runs: Int,
        block: () -> Unit,
    ): Duration = List(runs) { measureTime(block) }.sorted()[runs / 2]

    private fun randomMenu(
        size: Int,
        seed: Long,
    ): List<MenuItem> {
        val random = Random(seed)
        return (1..size).map { id ->
            val category = DishCategory.entries[random.nextInt(DishCategory.entries.size)]
            val protein = random.nextInt(0, 45).toDouble()
            val fat = random.nextInt(0, 35).toDouble()
            val carbs = random.nextInt(0, 80).toDouble()
            MenuTestData.dish(
                id = id.toLong(),
                category = category,
                kcal = protein * 4 + fat * 9 + carbs * 4,
                protein = protein,
                fat = fat,
                carbs = carbs,
                source = SourceKind.entries[random.nextInt(SourceKind.entries.size)],
            )
        }
    }

    private companion object {
        const val WARMUP_RUNS = 5
        const val MEASURED_RUNS = 9
        val BUDGET = 100.milliseconds
    }
}
