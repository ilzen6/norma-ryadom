package ru.normaryadom.intake.api

import jakarta.validation.constraints.NotBlank
import jakarta.validation.constraints.Size
import ru.normaryadom.intake.photo.SubmissionStatus

data class MenuPhotoResponse(
    val submissionId: Long,
    val status: SubmissionStatus,
)

data class ItemReportRequest(
    @field:NotBlank
    @field:Size(max = 500)
    val reason: String,
)
