package ru.normaryadom.catalog.domain

data class Chain(
    val id: Long,
    val name: String,
    val currency: String,
    val sourceUrl: String?,
    val menuVersion: Long,
    val templateCode: String? = null,
) {
    val isTemplate: Boolean get() = templateCode != null
}
