package ru.normaryadom.common.ratelimit

import jakarta.validation.Valid
import jakarta.validation.constraints.Min
import jakarta.validation.constraints.NotEmpty
import org.springframework.boot.context.properties.ConfigurationProperties
import org.springframework.validation.annotation.Validated
import java.time.Duration

@Validated
@ConfigurationProperties("rate-limit")
data class RateLimitProperties(
    @field:NotEmpty
    val buckets: Map<RateLimitBucket, @Valid Limit>,
) {
    data class Limit(
        @field:Min(1)
        val capacity: Int,
        val refillPeriod: Duration,
    )
}
