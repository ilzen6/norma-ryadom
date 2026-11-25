package ru.normaryadom.intake.report

import org.springframework.stereotype.Service
import java.time.Clock
import java.time.Duration

@Service
class WeeklySummaryService(
    private val summaries: WeeklySummaryRepository,
    private val clock: Clock,
) {
    fun lastWeek(): WeeklySummary = summaries.summary(clock.instant().minus(WINDOW), TOP_PLACES)

    private companion object {
        val WINDOW: Duration = Duration.ofDays(7)
        const val TOP_PLACES = 5
    }
}
