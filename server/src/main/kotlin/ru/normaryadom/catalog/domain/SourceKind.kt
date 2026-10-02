package ru.normaryadom.catalog.domain

enum class SourceKind {
    A,
    B,
    C,
    ;

    val code: String get() = name

    companion object {
        fun fromCode(code: String): SourceKind = valueOf(code.trim())
    }
}
