import dev.detekt.gradle.plugin.getSupportedKotlinVersion
import kotlinx.kover.gradle.plugin.dsl.CoverageUnit
import org.gradle.api.tasks.testing.logging.TestExceptionFormat
import org.jetbrains.kotlin.gradle.dsl.JvmTarget

plugins {
    id("org.springframework.boot") version "4.1.1"
    id("io.spring.dependency-management") version "1.1.7"
    kotlin("jvm") version "2.3.21"
    kotlin("plugin.spring") version "2.3.21"
    id("org.jlleitschuh.gradle.ktlint") version "14.2.0"
    id("dev.detekt") version "2.0.0-alpha.6"
    id("org.jetbrains.kotlinx.kover") version "0.9.9"
}

group = "ru.normaryadom"
version = "0.1.0"

java {
    toolchain {
        languageVersion = JavaLanguageVersion.of(21)
    }
}

repositories {
    mavenCentral()
}

dependencies {
    implementation("org.springframework.boot:spring-boot-starter-webmvc")
    implementation("org.springframework.boot:spring-boot-starter-validation")
    implementation("org.springframework.boot:spring-boot-starter-jdbc")
    implementation("org.springframework.boot:spring-boot-starter-flyway")
    implementation("org.springframework.boot:spring-boot-starter-actuator")
    implementation("org.springframework.boot:spring-boot-starter-security")
    implementation("org.springframework.boot:spring-boot-starter-thymeleaf")
    implementation("org.springframework.boot:spring-boot-starter-cache")
    implementation("com.github.ben-manes.caffeine:caffeine")
    implementation("org.flywaydb:flyway-database-postgresql")
    implementation("tools.jackson.module:jackson-module-kotlin")
    runtimeOnly("com.fasterxml.jackson.module:jackson-module-kotlin")
    implementation("org.jetbrains.kotlin:kotlin-reflect")
    implementation("org.springdoc:springdoc-openapi-starter-webmvc-ui:3.1.1")
    implementation("org.apache.commons:commons-csv:1.14.1")
    implementation(platform("software.amazon.awssdk:bom:2.55.9"))
    implementation("software.amazon.awssdk:s3")
    implementation("software.amazon.awssdk:url-connection-client")
    implementation("net.sourceforge.tess4j:tess4j:5.4.0") {
        exclude(group = "org.slf4j")
        exclude(group = "commons-logging")
    }
    runtimeOnly("org.postgresql:postgresql")

    testImplementation("org.springframework.boot:spring-boot-starter-test")
    testImplementation("org.springframework.boot:spring-boot-starter-webmvc-test")
    testImplementation("org.springframework.boot:spring-boot-starter-security-test")
    testImplementation("org.springframework.boot:spring-boot-testcontainers")
    testImplementation("org.testcontainers:testcontainers-junit-jupiter")
    testImplementation("org.testcontainers:testcontainers-postgresql")
    testImplementation("org.testcontainers:testcontainers-minio")
    testImplementation("net.jqwik:jqwik:1.10.1")
    testImplementation("io.mockk:mockk:1.14.11")
    testImplementation("com.tngtech.archunit:archunit-junit5:1.5.1")
    testRuntimeOnly("org.junit.platform:junit-platform-launcher")
}

kotlin {
    compilerOptions {
        jvmTarget = JvmTarget.JVM_21
        freeCompilerArgs.addAll("-Xjsr305=strict", "-Xannotation-default-target=param-property")
        allWarningsAsErrors = true
    }
}

tasks.withType<Test> {
    useJUnitPlatform {
        includeEngines("junit-jupiter", "jqwik")
    }
    val contractDir = layout.projectDirectory.dir("../contract")
    systemProperty("contract.dir", contractDir.asFile.absolutePath)
    systemProperty("contract.update", providers.gradleProperty("updateContract").getOrElse("false"))
    testLogging {
        events("failed")
        exceptionFormat = TestExceptionFormat.FULL
    }
}

configurations.matching { it.name == "detekt" }.configureEach {
    resolutionStrategy.eachDependency {
        if (requested.group == "org.jetbrains.kotlin") {
            useVersion(getSupportedKotlinVersion())
        }
    }
}

detekt {
    buildUponDefaultConfig = true
    config.setFrom(files("config/detekt/detekt.yml"))
}

kover {
    reports {
        filters {
            excludes {
                classes("ru.normaryadom.NormaRyadomApplicationKt")
            }
        }
        verify {
            rule("line coverage") {
                minBound(90)
            }
            rule("branch coverage") {
                bound {
                    minValue = 80
                    coverageUnits = CoverageUnit.BRANCH
                }
            }
        }
    }
}

tasks.named("check") {
    dependsOn("koverVerify")
}
