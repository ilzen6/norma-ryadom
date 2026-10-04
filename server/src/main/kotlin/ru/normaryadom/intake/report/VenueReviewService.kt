package ru.normaryadom.intake.report

import org.springframework.stereotype.Service
import org.springframework.transaction.support.TransactionOperations
import ru.normaryadom.catalog.domain.Venue
import ru.normaryadom.catalog.persistence.VenueRepository
import java.time.Clock
import java.time.LocalDate

@Service
class VenueReviewService(
    private val venues: VenueRepository,
    private val reports: VenueReportRepository,
    private val transactions: TransactionOperations,
    private val clock: Clock,
) {
    fun cases(): List<VenueReviewCase> {
        val underReview = venues.findUnderReview()
        val reasons = reports.openReasons(underReview.map(Venue::id))
        return underReview.map { VenueReviewCase(it, reasons[it.id].orEmpty()) }
    }

    fun restore(venueId: Long) = resolve(venueId) { venues.restore(venueId, LocalDate.now(clock)) }

    fun close(venueId: Long) = resolve(venueId) { venues.close(venueId, LocalDate.now(clock)) }

    private fun resolve(
        venueId: Long,
        change: () -> Boolean,
    ) {
        transactions.executeWithoutResult {
            if (change()) reports.resolveOpen(venueId, clock.instant())
        }
    }
}

data class VenueReviewCase(
    val venue: Venue,
    val reasons: Map<VenueReportReason, Int>,
)
