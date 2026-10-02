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
import org.springframework.web.bind.annotation.RequestParam
import org.springframework.web.multipart.MultipartFile
import org.springframework.web.servlet.mvc.support.RedirectAttributes
import ru.normaryadom.catalog.service.CatalogImportService
import ru.normaryadom.catalog.service.ChainNameTakenException
import ru.normaryadom.catalog.service.ChainService
import ru.normaryadom.catalog.service.ImportOutcome

@Controller
@RequestMapping("/admin/chains")
class AdminChainController(
    private val chains: ChainService,
    private val imports: CatalogImportService,
) {
    @GetMapping
    fun list(model: Model): String {
        model.addAttribute("chains", chains.list())
        if (!model.containsAttribute("chainForm")) model.addAttribute("chainForm", ChainForm())
        return "admin/chains"
    }

    @PostMapping
    fun create(
        @Valid @ModelAttribute("chainForm") form: ChainForm,
        binding: BindingResult,
        model: Model,
    ): String {
        if (binding.hasErrors()) return list(model)
        return try {
            "redirect:/admin/chains/${chains.create(form.name, form.sourceUrl)}"
        } catch (e: ChainNameTakenException) {
            binding.rejectValue("name", "chain.name.taken")
            list(model)
        }
    }

    @GetMapping("/{chainId}")
    fun details(
        @PathVariable chainId: Long,
        model: Model,
    ): String {
        model.addAttribute("chain", chains.get(chainId))
        model.addAttribute("items", chains.items(chainId))
        model.addAttribute("venues", chains.venues(chainId))
        return "admin/chain"
    }

    @PostMapping("/{chainId}/menu")
    fun importMenu(
        @PathVariable chainId: Long,
        @RequestParam("file") file: MultipartFile,
        @RequestParam("sourceUrl") sourceUrl: String,
        redirect: RedirectAttributes,
    ): String {
        if (!sourceUrl.matches(HTTP_URL)) {
            redirect.addFlashAttribute("importError", "import.sourceUrl.invalid")
        } else {
            report(imports.importChainMenu(chainId, file.bytes, sourceUrl.trim()), ImportKind.MENU, redirect)
        }
        return "redirect:/admin/chains/$chainId"
    }

    @PostMapping("/{chainId}/venues")
    fun importVenues(
        @PathVariable chainId: Long,
        @RequestParam("file") file: MultipartFile,
        redirect: RedirectAttributes,
    ): String {
        report(imports.importChainVenues(chainId, file.bytes), ImportKind.VENUES, redirect)
        return "redirect:/admin/chains/$chainId"
    }

    private fun report(
        outcome: ImportOutcome,
        kind: ImportKind,
        redirect: RedirectAttributes,
    ) {
        when (outcome) {
            is ImportOutcome.Imported -> redirect.addFlashAttribute("imported", outcome).addFlashAttribute("importKind", kind)
            is ImportOutcome.Rejected -> redirect.addFlashAttribute("csvErrors", outcome.errors)
        }
    }

    private companion object {
        val HTTP_URL = Regex("^\\s*https?://\\S+\\s*$")
    }
}

enum class ImportKind {
    MENU,
    VENUES,
}
