package ru.normaryadom.common.security

import jakarta.validation.constraints.NotBlank
import jakarta.validation.constraints.Pattern
import org.springframework.boot.context.properties.ConfigurationProperties
import org.springframework.validation.annotation.Validated

@Validated
@ConfigurationProperties("admin")
data class AdminProperties(
    @field:NotBlank
    val username: String,
    @field:Pattern(regexp = "^\\$2[aby]\\$\\d{2}\\$.{53}$", message = "must be a bcrypt hash")
    val passwordHash: String,
)
