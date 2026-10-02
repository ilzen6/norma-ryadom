package ru.normaryadom.common

import org.assertj.core.api.Assertions.assertThat
import org.assertj.core.api.Assertions.assertThatThrownBy
import org.junit.jupiter.api.Test
import ru.normaryadom.common.ratelimit.RateLimitBucket
import ru.normaryadom.common.ratelimit.RateLimitExceededException
import ru.normaryadom.common.ratelimit.RateLimitProperties
import ru.normaryadom.common.ratelimit.RateLimiter
import ru.normaryadom.support.MutableClock
import java.time.Duration

class RateLimiterTest {
    private val clock = MutableClock()
    private val limiter =
        RateLimiter(
            RateLimitProperties(mapOf(RateLimitBucket.MENU_PHOTO to RateLimitProperties.Limit(2, Duration.ofMinutes(10)))),
            clock,
        )

    @Test
    fun `пропускает запросы в пределах лимита и отказывает сверх него`() {
        limiter.acquire(RateLimitBucket.MENU_PHOTO, "10.0.0.1")
        limiter.acquire(RateLimitBucket.MENU_PHOTO, "10.0.0.1")
        clock.advance(Duration.ofMinutes(4))

        assertThatThrownBy { limiter.acquire(RateLimitBucket.MENU_PHOTO, "10.0.0.1") }
            .isInstanceOfSatisfying(RateLimitExceededException::class.java) {
                assertThat(it.retryAfter).isEqualTo(Duration.ofMinutes(6))
            }
    }

    @Test
    fun `считает лимит отдельно для каждого клиента`() {
        limiter.acquire(RateLimitBucket.MENU_PHOTO, "10.0.0.1")
        limiter.acquire(RateLimitBucket.MENU_PHOTO, "10.0.0.1")

        limiter.acquire(RateLimitBucket.MENU_PHOTO, "10.0.0.2")
    }

    @Test
    fun `открывает новое окно после окончания периода`() {
        repeat(2) { limiter.acquire(RateLimitBucket.MENU_PHOTO, "10.0.0.1") }
        clock.advance(Duration.ofMinutes(10))

        limiter.acquire(RateLimitBucket.MENU_PHOTO, "10.0.0.1")
    }

    @Test
    fun `не работает с ненастроенным лимитом`() {
        assertThatThrownBy { limiter.acquire(RateLimitBucket.ITEM_REPORT, "10.0.0.1") }
            .isInstanceOf(IllegalArgumentException::class.java)
    }
}
