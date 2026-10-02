package ru.normaryadom.intake.photo

import org.slf4j.LoggerFactory
import org.springframework.stereotype.Service
import org.springframework.transaction.support.TransactionOperations
import ru.normaryadom.catalog.domain.SourceKind
import ru.normaryadom.catalog.importing.CsvError
import ru.normaryadom.catalog.importing.CsvParseResult
import ru.normaryadom.catalog.importing.MenuCsvParser
import ru.normaryadom.catalog.persistence.MenuItemRepository
import ru.normaryadom.catalog.persistence.Provenance
import ru.normaryadom.catalog.service.MenuVersions
import java.time.Clock

@Service
class ModerationService(
    private val submissions: MenuSubmissionRepository,
    private val storage: PhotoStorage,
    private val items: MenuItemRepository,
    private val menuVersions: MenuVersions,
    private val parser: MenuCsvParser,
    private val transactions: TransactionOperations,
    private val clock: Clock,
) {
    fun queue(): List<MenuSubmission> = submissions.findByStatuses(SubmissionStatus.OPEN, QUEUE_PAGE_SIZE)

    fun openCount(): Int = submissions.countByStatuses(SubmissionStatus.OPEN)

    fun get(submissionId: Long): MenuSubmission = submissions.findById(submissionId) ?: throw SubmissionNotFoundException(submissionId)

    fun photo(submissionId: Long): StoredPhoto {
        val submission = get(submissionId)
        return StoredPhoto(content = storage.get(submission.photoKey), contentType = submission.contentType)
    }

    fun approve(
        submissionId: Long,
        menuCsv: String,
    ): ModerationOutcome {
        val submission = get(submissionId)
        if (submission.status !in SubmissionStatus.OPEN) throw SubmissionAlreadyModeratedException(submissionId)
        return when (val parsed = parser.parse(menuCsv)) {
            is CsvParseResult.Invalid -> ModerationOutcome.Rejected(parsed.errors)
            is CsvParseResult.Parsed -> {
                val now = clock.instant()
                transactions.executeWithoutResult {
                    if (!submissions.moderate(submissionId, SubmissionStatus.APPROVED, now)) {
                        throw SubmissionAlreadyModeratedException(submissionId)
                    }
                    items.upsertForVenue(submission.venueId, parsed.rows, Provenance(SourceKind.B, null, now))
                    menuVersions.bumpVenue(submission.venueId)
                }
                log.info("Menu submission approved: submissionId={}, items={}", submissionId, parsed.rows.size)
                ModerationOutcome.Approved(parsed.rows.size)
            }
        }
    }

    fun reject(submissionId: Long) {
        get(submissionId)
        if (!submissions.moderate(submissionId, SubmissionStatus.REJECTED, clock.instant())) {
            throw SubmissionAlreadyModeratedException(submissionId)
        }
        log.info("Menu submission rejected: submissionId={}", submissionId)
    }

    private companion object {
        const val QUEUE_PAGE_SIZE = 100
        val log = LoggerFactory.getLogger(ModerationService::class.java)
    }
}

sealed interface ModerationOutcome {
    data class Approved(
        val items: Int,
    ) : ModerationOutcome

    data class Rejected(
        val errors: List<CsvError>,
    ) : ModerationOutcome
}

class StoredPhoto(
    val content: ByteArray,
    val contentType: String,
)
