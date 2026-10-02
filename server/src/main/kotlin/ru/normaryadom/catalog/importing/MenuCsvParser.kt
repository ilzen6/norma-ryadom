package ru.normaryadom.catalog.importing

import org.springframework.stereotype.Component
import ru.normaryadom.catalog.domain.DietTag
import ru.normaryadom.catalog.domain.DishCategory
import ru.normaryadom.catalog.domain.Nutrients
import ru.normaryadom.catalog.persistence.MenuItemDraft
import java.math.BigDecimal
import java.math.RoundingMode

@Component
class MenuCsvParser {
    private val document = CsvDocument(HEADER, NAME, MenuItemDraft::name, ::parseRow)

    fun parse(text: String): CsvParseResult<MenuItemDraft> = document.parse(text)

    fun parse(content: ByteArray): CsvParseResult<MenuItemDraft> = document.parse(content)

    private fun parseRow(row: CsvRowReader): MenuItemDraft? {
        val draft =
            MenuItemDraft(
                name = row.requiredText(NAME, MAX_NAME_LENGTH),
                category = row.requiredCode(CATEGORY, DishCategory.MAIN, CsvErrorCode.UNKNOWN_CATEGORY, DishCategory::fromCode),
                portionGrams = row.optionalNumber(PORTION, POSITIVE_PORTION)?.toDouble(),
                nutrients =
                    Nutrients(
                        kcal = row.requiredNumber(KCAL, KCAL_RANGE).toDouble(),
                        protein = row.requiredNumber(PROTEIN, MACRO_RANGE).toDouble(),
                        fat = row.requiredNumber(FAT, MACRO_RANGE).toDouble(),
                        carbs = row.requiredNumber(CARBS, MACRO_RANGE).toDouble(),
                    ),
                priceMinor = row.optionalNumber(PRICE, PRICE_RANGE)?.let(::toMinorUnits),
                tags = DietTag.withImplied(row.codes(TAGS, CsvErrorCode.UNKNOWN_TAG, DietTag::fromCode)),
            )
        return draft.takeIf { row.isValid }
    }

    private fun toMinorUnits(rubles: BigDecimal): Int = rubles.movePointRight(2).setScale(0, RoundingMode.HALF_UP).toInt()

    companion object {
        const val NAME = "name"
        const val CATEGORY = "category"
        const val PORTION = "portion_g"
        const val KCAL = "kcal"
        const val PROTEIN = "protein_g"
        const val FAT = "fat_g"
        const val CARBS = "carbs_g"
        const val PRICE = "price_rub"
        const val TAGS = "tags"
        val HEADER = listOf(NAME, CATEGORY, PORTION, KCAL, PROTEIN, FAT, CARBS, PRICE, TAGS)

        private const val MAX_NAME_LENGTH = 200
        private val POSITIVE_PORTION = BigDecimal("0.1")..BigDecimal("5000")
        private val KCAL_RANGE = BigDecimal.ZERO..BigDecimal("5000")
        private val MACRO_RANGE = BigDecimal.ZERO..BigDecimal("1000")
        private val PRICE_RANGE = BigDecimal.ZERO..BigDecimal("100000")
    }
}
