package ru.normaryadom.contract

import org.assertj.core.api.Assertions.assertThat
import org.assertj.core.api.Assertions.within
import org.junit.jupiter.api.Test
import tools.jackson.databind.JsonNode
import tools.jackson.databind.json.JsonMapper
import java.nio.file.Path
import kotlin.math.floor
import kotlin.math.max

class NormCalculationContractTest {
    @Test
    fun `эталонная формула нормы совпадает с общими контрольными примерами клиента`() {
        val cases = JsonMapper.builder().build().readTree(Path.of(System.getProperty("contract.dir"), "norm-cases.json").toFile())

        assertThat(cases["cases"].size()).isGreaterThanOrEqualTo(8)
        cases["cases"].forEach { case ->
            val input = case["input"]
            val expected = case["expected"]
            val actual = ReferenceNorm.calculate(input)

            assertThat(actual.bmr).`as`(input.toString()).isCloseTo(expected["bmr"].asDouble(), within(0.01))
            assertThat(actual.tdee).`as`(input.toString()).isCloseTo(expected["tdee"].asDouble(), within(0.01))
            assertThat(listOf(actual.kcal, actual.protein, actual.fat, actual.carbs)).`as`(input.toString()).containsExactly(
                expected["kcal"].asInt(),
                expected["protein"].asInt(),
                expected["fat"].asInt(),
                expected["carbs"].asInt(),
            )
        }
    }

    private object ReferenceNorm {
        private val activity = mapOf("sedentary" to 1.2, "light" to 1.375, "moderate" to 1.55, "high" to 1.725, "very_high" to 1.9)
        private val goal = mapOf("lose" to 0.85, "maintain" to 1.0, "gain" to 1.10)
        private val safeMinimum = mapOf("female" to 1200, "male" to 1500)

        fun calculate(input: JsonNode): Norm {
            val sex = input["sex"].asString()
            val weight = input["weightKg"].asDouble()
            val bmr = 10 * weight + 6.25 * input["heightCm"].asDouble() - 5 * input["age"].asDouble() + if (sex == "male") 5 else -161
            val tdee = bmr * activity.getValue(input["activity"].asString())
            val goalName = input["goal"].asString()
            val kcal = max(round(tdee * goal.getValue(goalName) / 10) * 10, safeMinimum.getValue(sex))
            val protein = round((if (goalName == "maintain") 1.2 else 1.6) * weight)
            val fat = round(max(0.9 * weight, kcal * 0.2 / 9))
            val carbs = max(0, round((kcal - 4.0 * protein - 9.0 * fat) / 4))
            return Norm(bmr, tdee, kcal, protein, fat, carbs)
        }

        private fun round(value: Double): Int = floor(value + 0.5).toInt()
    }

    private data class Norm(
        val bmr: Double,
        val tdee: Double,
        val kcal: Int,
        val protein: Int,
        val fat: Int,
        val carbs: Int,
    )
}
