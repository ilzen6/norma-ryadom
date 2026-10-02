package ru.normaryadom

import org.springframework.boot.autoconfigure.SpringBootApplication
import org.springframework.boot.context.properties.ConfigurationPropertiesScan
import org.springframework.boot.runApplication

@SpringBootApplication
@ConfigurationPropertiesScan
class NormaRyadomApplication

fun main(args: Array<String>) {
    runApplication<NormaRyadomApplication>(*args)
}
