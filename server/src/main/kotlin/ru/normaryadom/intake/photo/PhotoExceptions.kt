package ru.normaryadom.intake.photo

import ru.normaryadom.common.error.NotFoundException

class UnsupportedPhotoException : RuntimeException("Photo format is not supported")

class PhotoTooLargeException : RuntimeException("Photo exceeds the size limit")

class StorageUnavailableException(
    cause: Throwable,
) : RuntimeException("Photo storage is unavailable", cause)

class SubmissionNotFoundException(
    submissionId: Long,
) : NotFoundException("menu-submission", submissionId)

class SubmissionAlreadyModeratedException(
    val submissionId: Long,
) : RuntimeException("Submission is already moderated")
