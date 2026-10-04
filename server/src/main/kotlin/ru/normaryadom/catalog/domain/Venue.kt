package ru.normaryadom.catalog.domain

import java.time.LocalDate

data class Venue(
    val id: Long,
    val chainId: Long?,
    val chainName: String?,
    val name: String,
    val address: String,
    val location: GeoPoint,
    val isActive: Boolean,
    val currency: String,
    val menuScope: MenuScope,
    val hasMenu: Boolean,
    val confirmedOn: LocalDate? = null,
    val underReview: Boolean = false,
    val dataQuality: SourceKind? = null,
)
