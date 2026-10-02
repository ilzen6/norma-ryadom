package ru.normaryadom.intake.api

import io.swagger.v3.oas.annotations.Operation
import io.swagger.v3.oas.annotations.tags.Tag
import jakarta.servlet.http.HttpServletRequest
import jakarta.validation.constraints.Min
import org.springframework.http.HttpStatus
import org.springframework.http.MediaType
import org.springframework.web.bind.annotation.PathVariable
import org.springframework.web.bind.annotation.PostMapping
import org.springframework.web.bind.annotation.RequestMapping
import org.springframework.web.bind.annotation.RequestPart
import org.springframework.web.bind.annotation.ResponseStatus
import org.springframework.web.bind.annotation.RestController
import org.springframework.web.multipart.MultipartFile
import ru.normaryadom.common.ratelimit.ClientKey
import ru.normaryadom.intake.photo.MenuPhotoService

@Tag(name = "intake")
@RestController
@RequestMapping("/api/v1/venues/{venueId}/menu-photos")
class MenuPhotoController(
    private val photos: MenuPhotoService,
) {
    @Operation(summary = "Загрузка фото меню или стенда заведения в очередь распознавания и модерации")
    @PostMapping(consumes = [MediaType.MULTIPART_FORM_DATA_VALUE])
    @ResponseStatus(HttpStatus.ACCEPTED)
    fun upload(
        @PathVariable @Min(1) venueId: Long,
        @RequestPart("photo") photo: MultipartFile,
        request: HttpServletRequest,
    ): MenuPhotoResponse {
        val receipt = photos.submit(venueId, photo.bytes, ClientKey.of(request.remoteAddr))
        return MenuPhotoResponse(submissionId = receipt.submissionId, status = receipt.status)
    }
}
