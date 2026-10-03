package ru.normaryadom.intake.api

import jakarta.validation.constraints.NotBlank
import jakarta.validation.constraints.NotNull
import jakarta.validation.constraints.Size
import ru.normaryadom.intake.photo.SubmissionStatus
import ru.normaryadom.intake.report.VenueReportReason

data class MenuPhotoResponse(
    val submissionId: Long,
    val status: SubmissionStatus,
)

data class ItemReportRequest(
    @field:NotBlank
    @field:Size(max = 500)
    val reason: String,
)

data class VenueReportRequest(
    @field:NotNull
    val reason: VenueReportReason,
)
