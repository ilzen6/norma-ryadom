package ru.normaryadom.web

import jakarta.servlet.http.HttpServletRequest
import org.springframework.boot.web.servlet.FilterRegistrationBean
import org.springframework.context.annotation.Bean
import org.springframework.context.annotation.Configuration
import org.springframework.web.filter.ShallowEtagHeaderFilter

class MenuEtagFilter : ShallowEtagHeaderFilter() {
    override fun shouldNotFilter(request: HttpServletRequest): Boolean = !MENU_PATH.matches(request.requestURI)

    private companion object {
        val MENU_PATH = Regex("^/api/v1/venues/\\d+/menu$")
    }
}

@Configuration(proxyBeanMethods = false)
class HttpCachingConfiguration {
    @Bean
    fun menuEtagFilter(): FilterRegistrationBean<MenuEtagFilter> =
        FilterRegistrationBean(MenuEtagFilter()).apply { addUrlPatterns("/api/v1/venues/*") }
}
