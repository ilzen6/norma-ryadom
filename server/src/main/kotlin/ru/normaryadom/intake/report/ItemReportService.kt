package ru.normaryadom.intake.report

import org.slf4j.LoggerFactory
import org.springframework.stereotype.Service
import org.springframework.transaction.support.TransactionOperations
import ru.normaryadom.catalog.service.MenuItemService
import ru.normaryadom.common.ratelimit.RateLimitBucket
import ru.normaryadom.common.ratelimit.RateLimiter
import ru.normaryadom.intake.config.IntakeProperties

@Service
class ItemReportService(
    private val menuItems: MenuItemService,
    private val reports: ItemReportRepository,
    private val fingerprint: ReporterFingerprint,
    private val rateLimiter: RateLimiter,
    private val transactions: TransactionOperations,
    private val properties: IntakeProperties,
) {
    fun report(
        itemId: Long,
        reason: String,
        clientKey: String,
    ) {
        rateLimiter.acquire(RateLimitBucket.ITEM_REPORT, clientKey)
        val reporter = fingerprint.of(clientKey)
        val sentToReview =
            transactions.execute {
                val record = menuItems.lockAvailable(itemId)
                val added = reports.insertIfAbsent(itemId, reason.trim(), reporter)
                added && reports.countOpen(itemId) >= properties.reports.reviewThreshold && menuItems.sendToReview(record)
            }
        if (sentToReview) log.info("Menu item sent to review after reports: itemId={}", itemId)
    }

    private companion object {
        val log = LoggerFactory.getLogger(ItemReportService::class.java)
    }
}
