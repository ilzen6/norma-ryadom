package ru.normaryadom.catalog

import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test
import org.junit.jupiter.params.ParameterizedTest
import org.junit.jupiter.params.provider.CsvSource
import ru.normaryadom.catalog.domain.DietTag
import ru.normaryadom.catalog.domain.DishCategory
import ru.normaryadom.catalog.importing.CsvError
import ru.normaryadom.catalog.importing.CsvErrorCode
import ru.normaryadom.catalog.importing.CsvParseResult
import ru.normaryadom.catalog.importing.MenuCsvParser
import ru.normaryadom.catalog.persistence.MenuItemDraft

class MenuCsvParserTest {
    private val parser = MenuCsvParser()

    @Test
    fun `разбирает строку меню со всеми полями`() {
        val result = parser.parse("$HEADER\nБлин с ветчиной;main;220;446;21,5;22;41;249.90;pork, milk\n")

        val draft = (result as CsvParseResult.Parsed<MenuItemDraft>).rows.single()
        assertThat(draft.name).isEqualTo("Блин с ветчиной")
        assertThat(draft.category).isEqualTo(DishCategory.MAIN)
        assertThat(draft.portionGrams).isEqualTo(220.0)
        assertThat(draft.nutrients.protein).isEqualTo(21.5)
        assertThat(draft.priceMinor).isEqualTo(24_990)
        assertThat(draft.tags).containsExactlyInAnyOrder(DietTag.PORK, DietTag.MILK, DietTag.MEAT)
    }

    @Test
    fun `принимает файл с BOM и необязательными пустыми полями`() {
        val result = parser.parse("﻿$HEADER\r\nЧай;drink;;0;0;0;0;;\r\n")

        val draft = (result as CsvParseResult.Parsed<MenuItemDraft>).rows.single()
        assertThat(draft.portionGrams).isNull()
        assertThat(draft.priceMinor).isNull()
        assertThat(draft.tags).isEmpty()
    }

    @ParameterizedTest(name = "{0} -> {1} в колонке {2}")
    @CsvSource(
        delimiter = '|',
        value = [
            ";main;200;400;20;10;40;100;|REQUIRED|name",
            "Блюдо;soup;200;400;20;10;40;100;|UNKNOWN_CATEGORY|category",
            "Блюдо;;200;400;20;10;40;100;|REQUIRED|category",
            "Блюдо;main;200;много;20;10;40;100;|NOT_A_NUMBER|kcal",
            "Блюдо;main;200;;20;10;40;100;|REQUIRED|kcal",
            "Блюдо;main;200;6000;20;10;40;100;|OUT_OF_RANGE|kcal",
            "Блюдо;main;0;400;20;10;40;100;|OUT_OF_RANGE|portion_g",
            "Блюдо;main;200;400;-1;10;40;100;|OUT_OF_RANGE|protein_g",
            "Блюдо;main;200;400;20;10;40;-5;|OUT_OF_RANGE|price_rub",
            "Блюдо;main;200;400;20;10;40;100;bacon|UNKNOWN_TAG|tags",
        ],
    )
    fun `отклоняет строку с ошибкой и называет колонку`(
        row: String,
        code: CsvErrorCode,
        column: String,
    ) {
        val result = parser.parse("$HEADER\n$row\n")

        assertThat((result as CsvParseResult.Invalid).errors).containsExactly(CsvError(2, code, column))
    }

    @Test
    fun `отклоняет слишком длинное название`() {
        val result = parser.parse("$HEADER\n${"а".repeat(201)};main;200;400;20;10;40;100;\n")

        assertThat((result as CsvParseResult.Invalid).errors.single().code).isEqualTo(CsvErrorCode.TOO_LONG)
    }

    @Test
    fun `находит повтор названия блюда без учёта регистра`() {
        val result = parser.parse("$HEADER\nЧай;drink;;0;0;0;0;;\nчай;drink;;0;0;0;0;;\n")

        assertThat((result as CsvParseResult.Invalid).errors).containsExactly(CsvError(3, CsvErrorCode.DUPLICATE, "name"))
    }

    @Test
    fun `отклоняет файл с чужим заголовком, пустой файл и битый CSV`() {
        assertThat((parser.parse("name;kcal\nЧай;0\n") as CsvParseResult.Invalid).errors.single().code)
            .isEqualTo(CsvErrorCode.HEADER_MISMATCH)
        assertThat((parser.parse("$HEADER\n") as CsvParseResult.Invalid).errors.single().code).isEqualTo(CsvErrorCode.EMPTY_FILE)
        assertThat((parser.parse("$HEADER\n\"Чай;drink;;0;0;0;0;;\n") as CsvParseResult.Invalid).errors.single().code)
            .isEqualTo(CsvErrorCode.MALFORMED)
    }

    @Test
    fun `собирает ошибки всех строк, а не только первой`() {
        val result = parser.parse("$HEADER\nЧай;drink;;x;0;0;0;;\nКофе;drink;;0;y;0;0;;\n")

        assertThat((result as CsvParseResult.Invalid).errors.map { it.line }).containsExactly(2L, 3L)
    }

    private companion object {
        val HEADER = MenuCsvParser.HEADER.joinToString(";")
    }
}
