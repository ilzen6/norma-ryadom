package ru.normaryadom.intake.report

import org.slf4j.LoggerFactory
import org.springframework.stereotype.Service
import org.springframework.transaction.support.TransactionOperations
import ru.normaryadom.catalog.persistence.MenuItemRepository
import ru.normaryadom.catalog.service.MenuItemNotFoundException
import ru.normaryadom.catalog.service.MenuVersions
import ru.normaryadom.common.ratelimit.RateLimitBucket
import ru.normaryadom.common.ratelimit.RateLimiter
import ru.normaryadom.intake.config.IntakeProperties

@Service
class ItemReportService(
    private val items: MenuItemRepository,
    private val reports: ItemReportRepository,
    private val menuVersions: MenuVersions,
    private val rateLimiter: RateLimiter,
    private val transactions: TransactionOperations,
    private val properties: IntakeProperties,
) {
    fun report(
        itemId: Long,
        reason: String,
        clientKey: String,
    ) {
        val record = items.findById(itemId)?.takeIf { it.isAvailable } ?: throw MenuItemNotFoundException(itemId)
        rateLimiter.acquire(RateLimitBucket.ITEM_REPORT, clientKey)
        val sentToReview =
            transactions.execute {
                reports.insert(itemId, reason.trim())
                val thresholdReached = reports.countOpen(itemId) >= properties.reports.reviewThreshold
                val marked = thresholdReached && items.markUnderReview(itemId)
                if (marked) menuVersions.bumpOwnerOf(record)
                marked
            }
        if (sentToReview) log.info("Menu item sent to review after reports: itemId={}", itemId)
    }

    private companion object {
        val log = LoggerFactory.getLogger(ItemReportService::class.java)
    }
}
