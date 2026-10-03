package ru.normaryadom.catalog.demo

import jakarta.validation.Valid
import jakarta.validation.constraints.NotBlank
import org.springframework.boot.context.properties.ConfigurationProperties
import org.springframework.core.io.Resource
import org.springframework.validation.annotation.Validated
import java.time.LocalDate

@Validated
@ConfigurationProperties("demo")
data class DemoCatalogProperties(
    val chains: List<@Valid DemoChain> = emptyList(),
    val places: Resource? = null,
) {
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
