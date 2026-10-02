package ru.normaryadom.intake.api

import io.swagger.v3.oas.annotations.Operation
import io.swagger.v3.oas.annotations.tags.Tag
import jakarta.servlet.http.HttpServletRequest
import jakarta.validation.Valid
import jakarta.validation.constraints.Min
import org.springframework.http.HttpStatus
import org.springframework.web.bind.annotation.PathVariable
import org.springframework.web.bind.annotation.PostMapping
import org.springframework.web.bind.annotation.RequestBody
import org.springframework.web.bind.annotation.RequestMapping
import org.springframework.web.bind.annotation.ResponseStatus
import org.springframework.web.bind.annotation.RestController
import ru.normaryadom.common.ratelimit.ClientKey
import ru.normaryadom.intake.report.ItemReportService

@Tag(name = "intake")
@RestController
@RequestMapping("/api/v1/items/{itemId}/reports")
class ItemReportController(
    private val reports: ItemReportService,
) {
    @Operation(summary = "Жалоба «цифры не совпадают» на блюдо")
    @PostMapping
    @ResponseStatus(HttpStatus.NO_CONTENT)
    fun report(
        @PathVariable @Min(1) itemId: Long,
        @Valid @RequestBody body: ItemReportRequest,
        request: HttpServletRequest,
    ) {
        reports.report(itemId, body.reason, ClientKey.of(request.remoteAddr))
    }
}
