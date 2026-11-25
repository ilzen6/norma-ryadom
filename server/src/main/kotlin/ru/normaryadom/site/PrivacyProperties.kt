package ru.normaryadom.site

import org.springframework.boot.context.properties.ConfigurationProperties

@ConfigurationProperties("privacy")
data class PrivacyProperties(
    val publishedOn: String = "[ДАТА ПУБЛИКАЦИИ]",
    val contactEmail: String = "[ПОЧТА ДЛЯ СВЯЗИ]",
)
