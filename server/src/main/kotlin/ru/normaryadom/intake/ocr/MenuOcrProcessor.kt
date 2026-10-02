package ru.normaryadom.intake.ocr

import io.micrometer.core.instrument.MeterRegistry
import org.slf4j.LoggerFactory
import org.springframework.stereotype.Component
import ru.normaryadom.intake.config.IntakeProperties
import ru.normaryadom.intake.photo.MenuSubmission
import ru.normaryadom.intake.photo.MenuSubmissionRepository
import ru.normaryadom.intake.photo.SubmissionStatus
import ru.normaryadom.intake.storage.PhotoNotFoundException
import ru.normaryadom.intake.storage.PhotoStorage
import ru.normaryadom.intake.storage.StorageUnavailableException

@Component
class MenuOcrProcessor(
    private val submissions: MenuSubmissionRepository,
    private val storage: PhotoStorage,
    private val recognizer: MenuTextRecognizer,
    private val properties: IntakeProperties,
    private val meters: MeterRegistry,
) {
    fun processPending(): Int {
        var processed = 0
        for (submission in submissions.findByStatuses(setOf(SubmissionStatus.NEW), properties.ocr.batchSize)) {
            val outcome = process(submission)
            if (outcome == Outcome.STORAGE_UNAVAILABLE) break
            if (outcome != Outcome.SKIPPED) processed++
        }
        return processed
    }

    @Suppress("TooGenericExceptionCaught")
    private fun process(submission: MenuSubmission): Outcome {
        val result =
            try {
                recognizer.recognize(storage.get(submission.photoKey))
            } catch (e: StorageUnavailableException) {
                log.error("Menu photo storage is unavailable for OCR: submissionId={}", submission.id, e)
                return record(Outcome.STORAGE_UNAVAILABLE)
            } catch (e: PhotoNotFoundException) {
                log.error("Menu photo is missing in storage: submissionId={}", submission.id, e)
                RecognitionResult.Failed("photo is missing")
            } catch (e: RuntimeException) {
                log.error("Menu photo recognition crashed: submissionId={}", submission.id, e)
                RecognitionResult.Failed("recognition crashed: ${e.javaClass.simpleName}")
            }
        val recorded =
            when (result) {
                is RecognitionResult.Recognized -> submissions.recordOcr(submission.id, SubmissionStatus.OCR_DONE, result.text)
                is RecognitionResult.Failed -> {
                    log.warn("Menu photo recognition failed: submissionId={}, reason={}", submission.id, result.reason)
                    submissions.recordOcr(submission.id, SubmissionStatus.OCR_FAILED, null)
                }
            }
        val outcome =
            when {
                !recorded -> Outcome.SKIPPED
                result is RecognitionResult.Recognized -> Outcome.RECOGNIZED
                else -> Outcome.FAILED
            }
        return record(outcome)
    }

    private fun record(outcome: Outcome): Outcome {
        meters.counter(METRIC, "outcome", outcome.name.lowercase()).increment()
        return outcome
    }

    private enum class Outcome { RECOGNIZED, FAILED, SKIPPED, STORAGE_UNAVAILABLE }

    private companion object {
        const val METRIC = "norma.ocr.results"
        val log = LoggerFactory.getLogger(MenuOcrProcessor::class.java)
    }
}
