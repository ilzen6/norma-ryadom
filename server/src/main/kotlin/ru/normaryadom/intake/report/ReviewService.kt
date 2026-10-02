package ru.normaryadom.intake.report

import org.springframework.stereotype.Service
import org.springframework.transaction.support.TransactionOperations
import ru.normaryadom.catalog.domain.Nutrients
import ru.normaryadom.catalog.persistence.MenuItemRecord
import ru.normaryadom.catalog.persistence.MenuItemRepository
import ru.normaryadom.catalog.service.MenuItemNotFoundException
import ru.normaryadom.catalog.service.MenuVersions
import java.time.Clock

@Service
class ReviewService(
    private val items: MenuItemRepository,
    private val reports: ItemReportRepository,
    private val menuVersions: MenuVersions,
    private val transactions: TransactionOperations,
    private val clock: Clock,
) {
    fun cases(): List<ReviewCase> {
        val underReview = items.findUnderReview()
        val reasons = reports.openReasons(underReview.map { it.item.id })
        return underReview.map { ReviewCase(it, reasons[it.item.id].orEmpty()) }
    }

    fun confirm(itemId: Long) =
        resolve(itemId) { record ->
            items.confirm(record.item.id)
        }

    fun correct(
        itemId: Long,
        nutrients: Nutrients,
    ) = resolve(itemId) { record ->
        items.correctNutrients(record.item.id, nutrients, clock.instant())
    }

    fun withdraw(itemId: Long) =
        resolve(itemId) { record ->
            items.withdraw(record.item.id)
        }

    private fun resolve(
        itemId: Long,
        change: (MenuItemRecord) -> Unit,
    ) {
        val record = items.findById(itemId) ?: throw MenuItemNotFoundException(itemId)
        transactions.executeWithoutResult {
            change(record)
            reports.resolveOpen(itemId, clock.instant())
            menuVersions.bumpOwnerOf(record)
        }
    }
}

data class ReviewCase(
    val record: MenuItemRecord,
    val reasons: List<String>,
)
