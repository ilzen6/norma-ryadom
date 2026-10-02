package ru.normaryadom.intake.config

import jakarta.validation.Valid
import jakarta.validation.constraints.Min
import jakarta.validation.constraints.NotBlank
import org.springframework.boot.context.properties.ConfigurationProperties
import org.springframework.util.unit.DataSize
import org.springframework.validation.annotation.Validated
import java.time.Duration

@Validated
@ConfigurationProperties("intake")
data class IntakeProperties(
    @field:Valid
    val photo: Photo,
    @field:Valid
    val ocr: Ocr,
    @field:Valid
    val reports: Reports,
) {
    data class Photo(
        val maxSize: DataSize,
    )

    data class Ocr(
        val workerEnabled: Boolean,
        val pollInterval: Duration,
        @field:Min(1)
        val batchSize: Int,
        @field:NotBlank
        val dataPath: String,
        @field:NotBlank
        val language: String,
    )

    data class Reports(
        @field:Min(1)
        val reviewThreshold: Int,
    )
}
