package ru.normaryadom.intake.ocr

import org.slf4j.LoggerFactory
import org.springframework.stereotype.Component
import ru.normaryadom.intake.config.IntakeProperties
import ru.normaryadom.intake.photo.MenuSubmissionRepository
import ru.normaryadom.intake.photo.MenuTextRecognizer
import ru.normaryadom.intake.photo.PhotoStorage
import ru.normaryadom.intake.photo.RecognitionResult
import ru.normaryadom.intake.photo.StorageUnavailableException
import ru.normaryadom.intake.photo.SubmissionStatus

@Component
class MenuOcrProcessor(
    private val submissions: MenuSubmissionRepository,
    private val storage: PhotoStorage,
    private val recognizer: MenuTextRecognizer,
    private val properties: IntakeProperties,
) {
    fun processPending(): Int =
        submissions
            .findByStatuses(setOf(SubmissionStatus.NEW), properties.ocr.batchSize)
            .count { submission ->
                try {
                    val result = recognizer.recognize(storage.get(submission.photoKey))
                    record(submission.id, result)
                } catch (e: StorageUnavailableException) {
                    log.error("Menu photo is unavailable for OCR: submissionId={}", submission.id, e)
                    false
                }
            }

    private fun record(
        submissionId: Long,
        result: RecognitionResult,
    ): Boolean =
        when (result) {
            is RecognitionResult.Recognized -> {
                log.info("Menu photo recognized: submissionId={}, characters={}", submissionId, result.text.length)
                submissions.recordOcr(submissionId, SubmissionStatus.OCR_DONE, result.text)
            }
            is RecognitionResult.Failed -> {
                log.warn("Menu photo recognition failed: submissionId={}, reason={}", submissionId, result.reason)
                submissions.recordOcr(submissionId, SubmissionStatus.OCR_FAILED, null)
            }
        }

    private companion object {
        val log = LoggerFactory.getLogger(MenuOcrProcessor::class.java)
    }
}
