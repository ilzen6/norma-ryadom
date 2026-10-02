package ru.normaryadom.admin

import org.springframework.http.MediaType
import org.springframework.http.ResponseEntity
import org.springframework.stereotype.Controller
import org.springframework.ui.Model
import org.springframework.web.bind.annotation.GetMapping
import org.springframework.web.bind.annotation.PathVariable
import org.springframework.web.bind.annotation.PostMapping
import org.springframework.web.bind.annotation.RequestMapping
import org.springframework.web.bind.annotation.RequestParam
import org.springframework.web.servlet.mvc.support.RedirectAttributes
import ru.normaryadom.catalog.importing.MenuCsvParser
import ru.normaryadom.intake.photo.ModerationOutcome
import ru.normaryadom.intake.photo.ModerationService
import ru.normaryadom.intake.photo.SubmissionAlreadyModeratedException

@Controller
@RequestMapping("/admin/moderation")
class AdminModerationController(
    private val moderation: ModerationService,
) {
    @GetMapping
    fun queue(model: Model): String {
        model.addAttribute("submissions", moderation.queue())
        return "admin/moderation"
    }

    @GetMapping("/{submissionId}")
    fun details(
        @PathVariable submissionId: Long,
        model: Model,
    ): String {
        model.addAttribute("submission", moderation.get(submissionId))
        if (!model.containsAttribute("menuCsv")) model.addAttribute("menuCsv", MenuCsvParser.HEADER.joinToString(";") + "\n")
        return "admin/submission"
    }

    @GetMapping("/{submissionId}/photo")
    fun photo(
        @PathVariable submissionId: Long,
    ): ResponseEntity<ByteArray> {
        val photo = moderation.photo(submissionId)
        return ResponseEntity
            .ok()
            .contentType(MediaType.parseMediaType(photo.contentType))
            .header("X-Content-Type-Options", "nosniff")
            .body(photo.content)
    }

    @PostMapping("/{submissionId}/approve")
    fun approve(
        @PathVariable submissionId: Long,
        @RequestParam("menuCsv") menuCsv: String,
        redirect: RedirectAttributes,
    ): String =
        try {
            when (val outcome = moderation.approve(submissionId, menuCsv)) {
                is ModerationOutcome.Approved -> {
                    redirect.addFlashAttribute("approvedItems", outcome.items)
                    "redirect:/admin/moderation"
                }
                is ModerationOutcome.Rejected -> {
                    redirect.addFlashAttribute("csvErrors", outcome.errors)
                    redirect.addFlashAttribute("menuCsv", menuCsv)
                    "redirect:/admin/moderation/$submissionId"
                }
            }
        } catch (e: SubmissionAlreadyModeratedException) {
            redirect.addFlashAttribute("alreadyModerated", true)
            "redirect:/admin/moderation"
        }

    @PostMapping("/{submissionId}/reject")
    fun reject(
        @PathVariable submissionId: Long,
        redirect: RedirectAttributes,
    ): String {
        try {
            moderation.reject(submissionId)
            redirect.addFlashAttribute("rejected", true)
        } catch (e: SubmissionAlreadyModeratedException) {
            redirect.addFlashAttribute("alreadyModerated", true)
        }
        return "redirect:/admin/moderation"
    }
}
