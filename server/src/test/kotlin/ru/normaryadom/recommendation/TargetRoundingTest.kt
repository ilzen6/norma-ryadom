package ru.normaryadom.recommendation

import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test
import ru.normaryadom.support.MenuTestData.target

class TargetRoundingTest {
    @Test
    fun `округляет калории до 50, а граммы до 5`() {
        val rounded = TargetRounding.round(target(kcal = 630.0, tolerance = 63.0, minProtein = 28.0, maxFat = 22.4, maxCarbs = 93.0))

        assertThat(rounded.kcal).isEqualTo(650.0)
        assertThat(rounded.kcalTolerance).isEqualTo(50.0)
        assertThat(rounded.minProtein).isEqualTo(30.0)
        assertThat(rounded.maxFat).isEqualTo(20.0)
        assertThat(rounded.maxCarbs).isEqualTo(95.0)
    }

    @Test
    fun `не превращает маленькие калории и допуск в ноль`() {
        val rounded = TargetRounding.round(target(kcal = 110.0, tolerance = 12.0))

        assertThat(rounded.kcal).isEqualTo(100.0)
        assertThat(rounded.kcalTolerance).isEqualTo(50.0)
    }

    @Test
    fun `сводит похожие цели к одному ключу кэша`() {
        assertThat(TargetRounding.round(target(kcal = 640.0, minProtein = 31.0)))
            .isEqualTo(TargetRounding.round(target(kcal = 655.0, minProtein = 29.0)))
    }
}
