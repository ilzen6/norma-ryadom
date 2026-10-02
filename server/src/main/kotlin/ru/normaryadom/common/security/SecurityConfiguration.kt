package ru.normaryadom.common.security

import org.springframework.context.annotation.Bean
import org.springframework.context.annotation.Configuration
import org.springframework.core.annotation.Order
import org.springframework.security.config.Customizer
import org.springframework.security.config.annotation.web.builders.HttpSecurity
import org.springframework.security.config.http.SessionCreationPolicy
import org.springframework.security.core.userdetails.User
import org.springframework.security.core.userdetails.UserDetailsService
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder
import org.springframework.security.crypto.password.PasswordEncoder
import org.springframework.security.provisioning.InMemoryUserDetailsManager
import org.springframework.security.web.SecurityFilterChain
import org.springframework.web.cors.CorsConfiguration
import org.springframework.web.cors.CorsConfigurationSource
import org.springframework.web.cors.UrlBasedCorsConfigurationSource

@Configuration(proxyBeanMethods = false)
class SecurityConfiguration {
    @Bean
    @Order(1)
    fun apiSecurity(http: HttpSecurity): SecurityFilterChain =
        http
            .securityMatcher("/api/**")
            .authorizeHttpRequests { it.anyRequest().permitAll() }
            .csrf { it.disable() }
            .cors(Customizer.withDefaults())
            .sessionManagement { it.sessionCreationPolicy(SessionCreationPolicy.STATELESS) }
            .build()

    @Bean
    @Order(2)
    fun webSecurity(http: HttpSecurity): SecurityFilterChain =
        http
            .authorizeHttpRequests {
                it
                    .requestMatchers("/admin/login", "/admin/assets/**", "/error")
                    .permitAll()
                    .requestMatchers("/admin/**")
                    .hasRole(ADMIN_ROLE)
                    .requestMatchers("/actuator/health/**", "/actuator/info", "/v3/api-docs/**", "/swagger-ui/**", "/swagger-ui.html")
                    .permitAll()
                    .anyRequest()
                    .denyAll()
            }.formLogin {
                it
                    .loginPage("/admin/login")
                    .defaultSuccessUrl("/admin", true)
                    .failureUrl("/admin/login?error")
            }.logout {
                it
                    .logoutUrl("/admin/logout")
                    .logoutSuccessUrl("/admin/login?logout")
            }.build()

    @Bean
    fun passwordEncoder(): PasswordEncoder = BCryptPasswordEncoder()

    @Bean
    fun adminUsers(properties: AdminProperties): UserDetailsService =
        InMemoryUserDetailsManager(
            User
                .withUsername(properties.username)
                .password(properties.passwordHash)
                .roles(ADMIN_ROLE)
                .build(),
        )

    @Bean
    fun corsConfigurationSource(properties: CorsProperties): CorsConfigurationSource =
        UrlBasedCorsConfigurationSource().apply {
            registerCorsConfiguration(
                "/api/**",
                CorsConfiguration().apply {
                    allowedOrigins = properties.allowedOrigins
                    allowedMethods = listOf("GET", "POST")
                    allowedHeaders = listOf("Content-Type", "Accept")
                    maxAge = CORS_MAX_AGE_SECONDS
                },
            )
        }

    private companion object {
        const val ADMIN_ROLE = "ADMIN"
        const val CORS_MAX_AGE_SECONDS = 3600L
    }
}
