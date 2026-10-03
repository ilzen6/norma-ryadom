package ru.normaryadom.catalog.persistence

import ru.normaryadom.catalog.domain.GeoPoint
import java.time.LocalDate

data class VenueDraft(
    val name: String,
    val address: String,
    val location: GeoPoint,
    val externalId: String,
    val confirmedOn: LocalDate? = null,
)
