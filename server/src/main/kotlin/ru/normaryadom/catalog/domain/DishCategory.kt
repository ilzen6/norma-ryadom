package ru.normaryadom.catalog.domain

import com.fasterxml.jackson.annotation.JsonProperty

enum class DishCategory(
    val code: String,
) {
    @JsonProperty("main")
    MAIN("main"),

    @JsonProperty("side")
    SIDE("side"),

    @JsonProperty("salad")
    SALAD("salad"),

    @JsonProperty("drink")
    DRINK("drink"),

    @JsonProperty("dessert")
    DESSERT("dessert"),

    @JsonProperty("sauce")
    SAUCE("sauce"),
    ;

    companion object {
        private val byCode = entries.associateBy(DishCategory::code)

        fun fromCode(code: String): DishCategory? = byCode[code.trim().lowercase()]
    }
}
