package ru.normaryadom.intake.config

import jakarta.validation.constraints.NotBlank
import org.springframework.boot.context.properties.ConfigurationProperties
import org.springframework.validation.annotation.Validated
import java.net.URI
import java.time.Duration

@Validated
@ConfigurationProperties("storage")
data class StorageProperties(
    val endpoint: URI,
    @field:NotBlank
    val region: String,
    @field:NotBlank
    val bucket: String,
    @field:NotBlank
    val accessKey: String,
    @field:NotBlank
    val secretKey: String,
    val connectTimeout: Duration,
    val callTimeout: Duration,
)
