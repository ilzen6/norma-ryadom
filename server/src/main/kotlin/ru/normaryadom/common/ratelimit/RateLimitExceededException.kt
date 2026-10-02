package ru.normaryadom.common.ratelimit

import java.time.Duration

class RateLimitExceededException(
    val bucket: RateLimitBucket,
    val retryAfter: Duration,
) : RuntimeException("Rate limit exceeded")
