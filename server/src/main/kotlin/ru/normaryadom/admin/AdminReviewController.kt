package ru.normaryadom.admin

import jakarta.validation.Valid
import org.springframework.stereotype.Controller
import org.springframework.ui.Model
import org.springframework.validation.BindingResult
import org.springframework.web.bind.annotation.GetMapping
import org.springframework.web.bind.annotation.ModelAttribute
import org.springframework.web.bind.annotation.PathVariable
import org.springframework.web.bind.annotation.PostMapping
import org.springframework.web.bind.annotation.RequestMapping
import org.springframework.web.servlet.mvc.support.RedirectAttributes
import ru.normaryadom.intake.report.ReviewService

@Controller
@RequestMapping("/admin/reviews")
class AdminReviewController(
    private val reviews: ReviewService,
) {
    @GetMapping
    fun cases(model: Model): String {
        model.addAttribute("cases", reviews.cases())
        return "admin/reviews"
    }

    @PostMapping("/{itemId}/confirm")
    fun confirm(
        @PathVariable itemId: Long,
        redirect: RedirectAttributes,
    ): String {
        reviews.confirm(itemId)
        redirect.addFlashAttribute("resolved", "confirmed")
        return "redirect:/admin/reviews"
    }

    @PostMapping("/{itemId}/correct")
    fun correct(
        @PathVariable itemId: Long,
        @Valid @ModelAttribute form: NutrientsForm,
        binding: BindingResult,
        redirect: RedirectAttributes,
    ): String {
        if (binding.hasErrors()) {
            redirect.addFlashAttribute("correctionError", itemId)
        } else {
            reviews.correct(itemId, form.toNutrients())
            redirect.addFlashAttribute("resolved", "corrected")
        }
        return "redirect:/admin/reviews"
    }

    @PostMapping("/{itemId}/withdraw")
    fun withdraw(
        @PathVariable itemId: Long,
        redirect: RedirectAttributes,
    ): String {
        reviews.withdraw(itemId)
        redirect.addFlashAttribute("resolved", "withdrawn")
        return "redirect:/admin/reviews"
    }
}
