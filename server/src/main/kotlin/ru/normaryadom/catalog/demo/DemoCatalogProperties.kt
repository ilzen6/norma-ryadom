package ru.normaryadom.catalog.demo

import jakarta.validation.Valid
import jakarta.validation.constraints.NotBlank
import org.springframework.boot.context.properties.ConfigurationProperties
import org.springframework.core.io.Resource
import org.springframework.validation.annotation.Validated

@Validated
@ConfigurationProperties("demo")
data class DemoCatalogProperties(
    val chains: List<@Valid DemoChain> = emptyList(),
) {
    data class DemoChain(
        @field:NotBlank
        val name: String,
        @field:NotBlank
        val sourceUrl: String,
        val menu: Resource,
        val venues: Resource,
    )
}
