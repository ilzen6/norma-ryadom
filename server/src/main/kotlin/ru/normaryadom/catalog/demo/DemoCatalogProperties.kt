package ru.normaryadom.catalog.demo

import jakarta.validation.Valid
import jakarta.validation.constraints.NotBlank
import jakarta.validation.constraints.Pattern
import org.springframework.boot.context.properties.ConfigurationProperties
import org.springframework.core.io.Resource
import org.springframework.validation.annotation.Validated
import java.time.LocalDate

@Validated
@ConfigurationProperties("demo")
data class DemoCatalogProperties(
    val templates: List<@Valid DemoTemplate> = emptyList(),
    val chains: List<@Valid DemoChain> = emptyList(),
    val places: Resource? = null,
) {
    data class DemoTemplate(
        @field:Pattern(regexp = "[a-z][a-z0-9-]{0,63}")
        val code: String,
        @field:NotBlank
        val name: String,
        @field:NotBlank
        val sourceUrl: String,
        val sourceDate: LocalDate? = null,
        val menu: Resource,
    )

    data class DemoChain(
        @field:NotBlank
        val name: String,
        @field:NotBlank
        val sourceUrl: String,
        val menu: Resource? = null,
        val sourceDate: LocalDate? = null,
        val venues: Resource,
    )
}
