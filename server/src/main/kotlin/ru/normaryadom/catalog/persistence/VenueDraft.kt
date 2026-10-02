package ru.normaryadom.catalog.persistence

import ru.normaryadom.catalog.domain.GeoPoint

data class VenueDraft(
    val name: String,
    val address: String,
    val location: GeoPoint,
    val externalId: String,
)
