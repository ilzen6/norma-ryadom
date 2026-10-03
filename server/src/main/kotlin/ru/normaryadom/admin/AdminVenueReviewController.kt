package ru.normaryadom.admin

import org.springframework.stereotype.Controller
import org.springframework.ui.Model
import org.springframework.web.bind.annotation.GetMapping
import org.springframework.web.bind.annotation.PathVariable
import org.springframework.web.bind.annotation.PostMapping
import org.springframework.web.bind.annotation.RequestMapping
import org.springframework.web.servlet.mvc.support.RedirectAttributes
import ru.normaryadom.intake.report.VenueReviewService

@Controller
@RequestMapping("/admin/venue-reviews")
class AdminVenueReviewController(
    private val reviews: VenueReviewService,
) {
    @GetMapping
    fun cases(model: Model): String {
        model.addAttribute("cases", reviews.cases())
        return "admin/venue-reviews"
    }

    @PostMapping("/{venueId}/restore")
    fun restore(
        @PathVariable venueId: Long,
        redirect: RedirectAttributes,
    ): String {
        reviews.restore(venueId)
        redirect.addFlashAttribute("resolved", "restored")
        return "redirect:/admin/venue-reviews"
    }

    @PostMapping("/{venueId}/close")
    fun close(
        @PathVariable venueId: Long,
        redirect: RedirectAttributes,
    ): String {
        reviews.close(venueId)
        redirect.addFlashAttribute("resolved", "closed")
        return "redirect:/admin/venue-reviews"
    }
}
