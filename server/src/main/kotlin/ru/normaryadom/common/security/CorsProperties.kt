package ru.normaryadom.common.security

import org.springframework.boot.context.properties.ConfigurationProperties

@ConfigurationProperties("cors")
data class CorsProperties(
    val allowedOrigins: List<String> = emptyList(),
)
