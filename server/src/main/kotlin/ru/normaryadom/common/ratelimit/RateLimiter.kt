package ru.normaryadom.common.ratelimit

import com.github.benmanes.caffeine.cache.Cache
import com.github.benmanes.caffeine.cache.Caffeine
import org.springframework.stereotype.Component
import java.time.Clock
import java.time.Duration
import java.time.Instant

@Component
class RateLimiter(
    private val properties: RateLimitProperties,
    private val clock: Clock,
) {
    private val windows: Cache<Pair<RateLimitBucket, String>, Window> =
        Caffeine
            .newBuilder()
            .maximumSize(MAX_TRACKED_CLIENTS)
            .expireAfterAccess(properties.buckets.values.maxOf { it.refillPeriod })
            .build()

    fun acquire(
        bucket: RateLimitBucket,
        clientKey: String,
    ) {
        val limit = requireNotNull(properties.buckets[bucket]) { "Rate limit for $bucket is not configured" }
        val now = clock.instant()
        val window =
            checkNotNull(
                windows.asMap().compute(bucket to clientKey) { _, current ->
                    val active = current?.takeIf { now.isBefore(it.startedAt.plus(limit.refillPeriod)) }
                    active?.copy(used = active.used + 1) ?: Window(startedAt = now, used = 1)
                },
            )
        if (window.used > limit.capacity) {
            throw RateLimitExceededException(bucket, Duration.between(now, window.startedAt.plus(limit.refillPeriod)))
        }
    }

    private data class Window(
        val startedAt: Instant,
        val used: Int,
    )

    private companion object {
        const val MAX_TRACKED_CLIENTS = 100_000L
    }
}
