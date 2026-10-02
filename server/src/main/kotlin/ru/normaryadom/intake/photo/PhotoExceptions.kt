package ru.normaryadom.intake.photo

import ru.normaryadom.common.error.NotFoundException

class UnsupportedPhotoException(
    cause: Throwable? = null,
) : RuntimeException("Photo format is not supported", cause)

class PhotoTooLargeException : RuntimeException("Photo exceeds the size limit")

class SubmissionNotFoundException(
    submissionId: Long,
) : NotFoundException("menu-submission", submissionId)

class SubmissionAlreadyModeratedException(
    val submissionId: Long,
) : RuntimeException("Submission is already moderated")
