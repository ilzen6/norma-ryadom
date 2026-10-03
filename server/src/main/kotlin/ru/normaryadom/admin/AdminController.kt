package ru.normaryadom.admin

import org.springframework.stereotype.Controller
import org.springframework.ui.Model
import org.springframework.web.bind.annotation.GetMapping
import org.springframework.web.bind.annotation.RequestMapping
import ru.normaryadom.catalog.service.ChainService
import ru.normaryadom.intake.photo.ModerationService
import ru.normaryadom.intake.report.ReviewService
import ru.normaryadom.intake.report.VenueReviewService

@Controller
@RequestMapping("/admin")
class AdminController(
    private val chains: ChainService,
    private val moderation: ModerationService,
    private val reviews: ReviewService,
    private val venueReviews: VenueReviewService,
) {
    @GetMapping("/login")
    fun login(): String = "admin/login"

    @GetMapping
    fun dashboard(model: Model): String {
        val summaries = chains.list()
        model.addAttribute("chainCount", summaries.size)
        model.addAttribute("itemCount", summaries.sumOf { it.itemCount })
        model.addAttribute("venueCount", summaries.sumOf { it.venueCount })
        model.addAttribute("openSubmissions", moderation.openCount())
        model.addAttribute("reviewCases", reviews.cases().size)
        model.addAttribute("venueCases", venueReviews.cases().size)
        return "admin/dashboard"
    }
}
