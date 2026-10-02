package ru.normaryadom.catalog.domain

data class MenuScope(
    val chainId: Long?,
    val chainMenuVersion: Long,
    val venueId: Long?,
    val venueMenuVersion: Long,
) {
    init {
        require(chainId != null || venueId != null) { "Menu scope must reference a chain or a venue" }
    }
}
