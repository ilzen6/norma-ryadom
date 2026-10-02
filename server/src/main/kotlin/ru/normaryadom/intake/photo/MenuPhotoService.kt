package ru.normaryadom.intake.photo

import org.slf4j.LoggerFactory
import org.springframework.stereotype.Service
import ru.normaryadom.catalog.service.VenueMenuService
import ru.normaryadom.common.ratelimit.RateLimitBucket
import ru.normaryadom.common.ratelimit.RateLimiter
import ru.normaryadom.intake.storage.PhotoStorage
import java.util.UUID

@Service
class MenuPhotoService(
    private val venues: VenueMenuService,
    private val storage: PhotoStorage,
    private val submissions: MenuSubmissionRepository,
    private val rateLimiter: RateLimiter,
    private val sanitizer: PhotoSanitizer,
) {
    fun submit(
        venueId: Long,
        photo: ByteArray,
        clientKey: String,
    ): SubmissionReceipt {
        rateLimiter.acquire(RateLimitBucket.MENU_PHOTO, clientKey)
        val sanitized = sanitizer.sanitize(photo)
        val venue = venues.venue(venueId)
        val format = sanitized.format
        val key = "menu-photos/${venue.id}/${UUID.randomUUID()}.${format.extension}"
        storage.put(key, sanitized.content, format.contentType)
        val submissionId = submissions.insert(venue.id, key, format.contentType)
        log.info("Menu photo submitted: submissionId={}, venueId={}", submissionId, venue.id)
        return SubmissionReceipt(submissionId = submissionId, status = SubmissionStatus.NEW)
    }

    private companion object {
        val log = LoggerFactory.getLogger(MenuPhotoService::class.java)
    }
}
