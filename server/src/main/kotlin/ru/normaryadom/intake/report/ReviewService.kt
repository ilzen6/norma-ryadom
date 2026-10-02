package ru.normaryadom.intake.report

import org.springframework.stereotype.Service
import org.springframework.transaction.support.TransactionOperations
import ru.normaryadom.catalog.domain.Nutrients
import ru.normaryadom.catalog.persistence.MenuItemRecord
import ru.normaryadom.catalog.persistence.MenuItemRepository
import ru.normaryadom.catalog.service.MenuItemService
import java.time.Clock

@Service
class ReviewService(
    private val items: MenuItemRepository,
    private val menuItems: MenuItemService,
    private val reports: ItemReportRepository,
    private val transactions: TransactionOperations,
    private val clock: Clock,
) {
    fun cases(): List<ReviewCase> {
        val underReview = items.findUnderReview()
        val reasons = reports.openReasons(underReview.map { it.item.id })
        return underReview.map { ReviewCase(it, reasons[it.item.id].orEmpty()) }
    }

    fun confirm(itemId: Long) = resolve(itemId) { menuItems.confirm(itemId) }

    fun correct(
        itemId: Long,
        nutrients: Nutrients,
    ) = resolve(itemId) { menuItems.correct(itemId, nutrients) }

    fun withdraw(itemId: Long) = resolve(itemId) { menuItems.withdraw(itemId) }

    private fun resolve(
        itemId: Long,
        change: () -> Unit,
    ) {
        transactions.executeWithoutResult {
            change()
            reports.resolveOpen(itemId, clock.instant())
        }
    }
}

data class ReviewCase(
    val record: MenuItemRecord,
    val reasons: List<String>,
)
