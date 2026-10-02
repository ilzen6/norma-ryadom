package ru.normaryadom.catalog.domain

import com.fasterxml.jackson.annotation.JsonProperty

enum class DietTag(
    val code: String,
) {
    @JsonProperty("meat")
    MEAT("meat"),

    @JsonProperty("pork")
    PORK("pork"),

    @JsonProperty("beef")
    BEEF("beef"),

    @JsonProperty("chicken")
    CHICKEN("chicken"),

    @JsonProperty("fish")
    FISH("fish"),

    @JsonProperty("seafood")
    SEAFOOD("seafood"),

    @JsonProperty("nuts")
    NUTS("nuts"),

    @JsonProperty("milk")
    MILK("milk"),

    @JsonProperty("gluten")
    GLUTEN("gluten"),

    @JsonProperty("egg")
    EGG("egg"),

    @JsonProperty("soy")
    SOY("soy"),
    ;

    companion object {
        private val byCode = entries.associateBy(DietTag::code)
        private val meatKinds = setOf(PORK, BEEF, CHICKEN)

        fun fromCode(code: String): DietTag? = byCode[code.trim().lowercase()]

        fun withImplied(tags: Set<DietTag>): Set<DietTag> = if (tags.any(meatKinds::contains)) tags + MEAT else tags
    }
}
