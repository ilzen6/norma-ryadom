package ru.normaryadom.site

import jakarta.servlet.http.HttpServletResponse
import org.springframework.boot.context.properties.EnableConfigurationProperties
import org.springframework.http.CacheControl
import org.springframework.stereotype.Controller
import org.springframework.ui.Model
import org.springframework.web.bind.annotation.GetMapping
import java.time.Duration

@Controller
@EnableConfigurationProperties(PrivacyProperties::class)
class PrivacyController(
    private val properties: PrivacyProperties,
) {
    @GetMapping("/privacy")
    fun privacy(
        model: Model,
        response: HttpServletResponse,
    ): String {
        response.setHeader("Cache-Control", CacheControl.maxAge(Duration.ofHours(1)).cachePublic().headerValue)
        model.addAttribute("publishedOn", properties.publishedOn)
        model.addAttribute("contactEmail", properties.contactEmail)
        return "privacy"
    }
}
