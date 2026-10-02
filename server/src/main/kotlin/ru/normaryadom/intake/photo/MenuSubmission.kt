package ru.normaryadom.intake.photo

import java.time.Instant

data class MenuSubmission(
    val id: Long,
    val venueId: Long,
    val venueName: String,
    val venueAddress: String,
    val photoKey: String,
    val contentType: String,
    val ocrText: String?,
    val status: SubmissionStatus,
    val createdAt: Instant,
)

data class SubmissionReceipt(
    val submissionId: Long,
    val status: SubmissionStatus,
)
