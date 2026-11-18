package ru.normaryadom.catalog.persistence

import ru.normaryadom.catalog.domain.GeoPoint
import ru.normaryadom.catalog.domain.VenueKind
import java.time.LocalDate

data class VenueDraft(
    val name: String,
    val address: String,
    val location: GeoPoint,
    val externalId: String,
    val confirmedOn: LocalDate? = null,
    val templateId: Long? = null,
    val kind: VenueKind? = null,
)
