package ru.normaryadom.catalog.domain

import com.fasterxml.jackson.annotation.JsonProperty

enum class VenueKind(
    val code: String,
    val isFastFood: Boolean = false,
) {
    @JsonProperty("cafe")
    CAFE("cafe"),

    @JsonProperty("coffee")
    COFFEE("coffee"),

    @JsonProperty("bakery")
    BAKERY("bakery"),

    @JsonProperty("canteen")
    CANTEEN("canteen"),

    @JsonProperty("georgian")
    GEORGIAN("georgian"),

    @JsonProperty("central-asian")
    CENTRAL_ASIAN("central-asian"),

    @JsonProperty("asian")
    ASIAN("asian"),

    @JsonProperty("sushi")
    SUSHI("sushi"),

    @JsonProperty("italian")
    ITALIAN("italian"),

    @JsonProperty("blini")
    BLINI("blini"),

    @JsonProperty("bar")
    BAR("bar"),

    @JsonProperty("ready-food")
    READY_FOOD("ready-food"),

    @JsonProperty("pizza")
    PIZZA("pizza", isFastFood = true),

    @JsonProperty("burger")
    BURGER("burger", isFastFood = true),

    @JsonProperty("shawarma")
    SHAWARMA("shawarma", isFastFood = true),
    ;

    companion object {
        private val byCode = entries.associateBy(VenueKind::code)

        fun fromCode(code: String): VenueKind? = byCode[code.trim().lowercase()]
    }
}
