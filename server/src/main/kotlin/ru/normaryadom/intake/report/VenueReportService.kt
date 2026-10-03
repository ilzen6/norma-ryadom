package ru.normaryadom.intake.report

import org.slf4j.LoggerFactory
import org.springframework.stereotype.Service
import org.springframework.transaction.support.TransactionOperations
import ru.normaryadom.catalog.persistence.VenueRepository
import ru.normaryadom.catalog.service.VenueNotFoundException
import ru.normaryadom.common.ratelimit.RateLimitBucket
import ru.normaryadom.common.ratelimit.RateLimiter
import ru.normaryadom.intake.config.IntakeProperties

@Service
class VenueReportService(
    private val venues: VenueRepository,
    private val reports: VenueReportRepository,
    private val fingerprint: ReporterFingerprint,
    private val rateLimiter: RateLimiter,
    private val transactions: TransactionOperations,
    private val properties: IntakeProperties,
) {
    fun report(
        venueId: Long,
        reason: VenueReportReason,
        clientKey: String,
    ) {
        rateLimiter.acquire(RateLimitBucket.VENUE_REPORT, clientKey)
        val reporter = fingerprint.of(clientKey)
        val sentToReview =
            transactions.execute {
                if (!venues.lockActive(venueId)) throw VenueNotFoundException(venueId)
                val added = reports.insertIfAbsent(venueId, reason, reporter)
                added && reports.countOpen(venueId) >= properties.reports.reviewThreshold && venues.sendToReview(venueId)
            }
        if (sentToReview == true) log.info("Venue sent to review after reports: venueId={}", venueId)
    }

    private companion object {
        val log = LoggerFactory.getLogger(VenueReportService::class.java)
    }
}
