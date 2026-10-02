package ru.normaryadom.intake.photo

enum class SubmissionStatus {
    NEW,
    OCR_DONE,
    OCR_FAILED,
    APPROVED,
    REJECTED,
    ;

    companion object {
        val OPEN: Set<SubmissionStatus> = setOf(NEW, OCR_DONE, OCR_FAILED)
    }
}
