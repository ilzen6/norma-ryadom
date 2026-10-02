package ru.normaryadom.common.security

import jakarta.servlet.FilterChain
import jakarta.servlet.http.HttpServletRequest
import jakarta.servlet.http.HttpServletResponse
import org.slf4j.LoggerFactory
import org.springframework.http.HttpMethod
import org.springframework.security.web.servlet.util.matcher.PathPatternRequestMatcher
import org.springframework.web.filter.OncePerRequestFilter
import ru.normaryadom.common.ratelimit.ClientKey
import ru.normaryadom.common.ratelimit.RateLimitBucket
import ru.normaryadom.common.ratelimit.RateLimitExceededException
import ru.normaryadom.common.ratelimit.RateLimiter

class AdminLoginRateLimitFilter(
    private val rateLimiter: RateLimiter,
) : OncePerRequestFilter() {
    private val loginRequest = PathPatternRequestMatcher.withDefaults().matcher(HttpMethod.POST, LOGIN_PATH)

    override fun shouldNotFilter(request: HttpServletRequest): Boolean = !loginRequest.matches(request)

    override fun doFilterInternal(
        request: HttpServletRequest,
        response: HttpServletResponse,
        filterChain: FilterChain,
    ) {
        try {
            rateLimiter.acquire(RateLimitBucket.ADMIN_LOGIN, ClientKey.of(request.remoteAddr))
        } catch (e: RateLimitExceededException) {
            log.warn("Admin login attempts limited: retryAfterSeconds={}", e.retryAfter.toSeconds())
            response.sendRedirect(request.contextPath + "$LOGIN_PATH?locked")
            return
        }
        filterChain.doFilter(request, response)
    }

    companion object {
        const val LOGIN_PATH = "/admin/login"
        private val log = LoggerFactory.getLogger(AdminLoginRateLimitFilter::class.java)
    }
}
