package ru.normaryadom.admin

import jakarta.validation.constraints.DecimalMax
import jakarta.validation.constraints.DecimalMin
import jakarta.validation.constraints.NotBlank
import jakarta.validation.constraints.NotNull
import jakarta.validation.constraints.Pattern
import jakarta.validation.constraints.Size
import ru.normaryadom.catalog.domain.Nutrients

data class ChainForm(
    @field:NotBlank
    @field:Size(max = 100)
    val name: String = "",
    @field:Size(max = 500)
    @field:Pattern(regexp = "^$|^https?://.+", message = "должна начинаться с http:// или https://")
    val sourceUrl: String = "",
)

data class NutrientsForm(
    @field:NotNull
    @field:DecimalMin("0")
    @field:DecimalMax("5000")
    val kcal: Double? = null,
    @field:NotNull
    @field:DecimalMin("0")
    @field:DecimalMax("1000")
    val protein: Double? = null,
    @field:NotNull
    @field:DecimalMin("0")
    @field:DecimalMax("1000")
    val fat: Double? = null,
    @field:NotNull
    @field:DecimalMin("0")
    @field:DecimalMax("1000")
    val carbs: Double? = null,
) {
    fun toNutrients(): Nutrients =
        Nutrients(
            kcal = checkNotNull(kcal),
            protein = checkNotNull(protein),
            fat = checkNotNull(fat),
            carbs = checkNotNull(carbs),
        )
}
