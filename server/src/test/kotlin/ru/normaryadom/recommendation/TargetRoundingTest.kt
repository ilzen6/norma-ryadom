package ru.normaryadom.recommendation

import net.jqwik.api.ForAll
import net.jqwik.api.Property
import net.jqwik.api.constraints.DoubleRange
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test
import ru.normaryadom.support.MenuTestData.target

class TargetRoundingTest {
    @Test
    fun `округляет калории до 10, а граммы внутрь исходного окна`() {
        val rounded = TargetRounding.round(target(kcal = 634.0, tolerance = 63.0, minProtein = 28.0, maxFat = 22.4, maxCarbs = 93.0))

        assertThat(rounded.kcal).isEqualTo(630.0)
        assertThat(rounded.kcalTolerance).isEqualTo(55.0)
        assertThat(rounded.minProtein).isEqualTo(30.0)
        assertThat(rounded.maxFat).isEqualTo(20.0)
        assertThat(rounded.maxCarbs).isEqualTo(90.0)
    }

    @Test
    fun `оставляет минимальный допуск при самой узкой цели`() {
        val rounded = TargetRounding.round(target(kcal = 105.0, tolerance = 10.0))

        assertThat(rounded.kcal).isEqualTo(110.0)
        assertThat(rounded.kcalTolerance).isEqualTo(5.0)
    }

    @Test
    fun `сводит похожие цели к одному ключу кэша`() {
        assertThat(TargetRounding.round(target(kcal = 641.0, tolerance = 60.0, minProtein = 26.0)))
            .isEqualTo(TargetRounding.round(target(kcal = 638.0, tolerance = 61.0, minProtein = 29.0)))
    }

    @Property(tries = 500)
    fun `округлённая цель не шире исходной`(
        @ForAll @DoubleRange(min = 100.0, max = 2000.0) kcal: Double,
        @ForAll @DoubleRange(min = 10.0, max = 500.0) tolerance: Double,
        @ForAll @DoubleRange(min = 0.0, max = 300.0) minProtein: Double,
        @ForAll @DoubleRange(min = 0.0, max = 300.0) maxFat: Double,
        @ForAll @DoubleRange(min = 0.0, max = 500.0) maxCarbs: Double,
    ) {
        val original = target(kcal = kcal, tolerance = tolerance, minProtein = minProtein, maxFat = maxFat, maxCarbs = maxCarbs)

        val rounded = TargetRounding.round(original)

        assertThat(rounded.minKcal).isGreaterThanOrEqualTo(original.minKcal - PRECISION)
        assertThat(rounded.maxKcal).isLessThanOrEqualTo(original.maxKcal + PRECISION)
        assertThat(rounded.minProtein).isGreaterThanOrEqualTo(original.minProtein - PRECISION)
        assertThat(rounded.maxFat).isLessThanOrEqualTo(original.maxFat + PRECISION)
        assertThat(rounded.maxCarbs).isLessThanOrEqualTo(original.maxCarbs + PRECISION)
    }

    private companion object {
        const val PRECISION = 1e-6
    }
}
