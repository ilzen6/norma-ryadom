package ru.normaryadom.contract

import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test
import org.springframework.boot.autoconfigure.AutoConfigurations
import org.springframework.boot.context.properties.EnableConfigurationProperties
import org.springframework.boot.test.context.runner.ApplicationContextRunner
import org.springframework.boot.validation.autoconfigure.ValidationAutoConfiguration
import ru.normaryadom.common.ratelimit.RateLimitProperties
import ru.normaryadom.common.security.AdminProperties
import ru.normaryadom.intake.config.IntakeProperties
import ru.normaryadom.intake.config.StorageProperties
import ru.normaryadom.recommendation.config.NearbyProperties

class ConfigurationValidationTest {
    private val runner =
        ApplicationContextRunner()
            .withConfiguration(AutoConfigurations.of(ValidationAutoConfiguration::class.java))
            .withUserConfiguration(PropertiesConfiguration::class.java)
            .withPropertyValues(
                "admin.username=admin",
                "admin.password-hash=\$2a\$10\$ceaRfGnVAAigyn5nns6LVOLZOtNzDooisRCeW7qSzaZuVIFjdos0m",
                "storage.endpoint=http://localhost:8333",
                "storage.region=us-east-1",
                "storage.bucket=photos",
                "storage.access-key=key",
                "storage.secret-key=secret",
                "storage.connect-timeout=1s",
                "storage.call-timeout=5s",
                "nearby.max-results=50",
                "nearby.distance-weight-per-km=0.5",
                "nearby.combos-per-venue=2",
                "rate-limit.buckets.menu-photo.capacity=5",
                "rate-limit.buckets.menu-photo.refill-period=10m",
                "intake.photo.max-size=8MB",
                "intake.photo.max-pixels=24000000",
                "intake.ocr.poll-interval=5s",
                "intake.ocr.batch-size=5",
                "intake.ocr.data-path=/usr/share/tesseract-ocr/5/tessdata",
                "intake.ocr.language=rus",
                "intake.reports.review-threshold=3",
                "intake.reports.reporter-key=secret",
            )

    @Test
    fun `поднимается с корректной конфигурацией`() {
        runner.run { context -> assertThat(context).hasNotFailed() }
    }

    @Test
    fun `не стартует без хеша пароля администратора`() {
        runner.withPropertyValues("admin.password-hash=").run { context ->
            assertThat(context).hasFailed()
            assertThat(context.startupFailure).rootCause().hasMessageContaining("passwordHash")
        }
    }

    @Test
    fun `не стартует с открытым паролем вместо bcrypt-хеша`() {
        runner.withPropertyValues("admin.password-hash=qwerty").run { context ->
            assertThat(context.startupFailure).rootCause().hasMessageContaining("bcrypt")
        }
    }

    @Test
    fun `не стартует без ключей хранилища`() {
        runner.withPropertyValues("storage.secret-key=").run { context ->
            assertThat(context.startupFailure).rootCause().hasMessageContaining("secretKey")
        }
    }

    @Test
    fun `не стартует с недопустимым лимитом выдачи заведений`() {
        runner.withPropertyValues("nearby.max-results=0").run { context ->
            assertThat(context.startupFailure).rootCause().hasMessageContaining("maxResults")
        }
    }

    @Test
    fun `проверяет вложенные лимиты частоты запросов`() {
        runner.withPropertyValues("rate-limit.buckets.menu-photo.capacity=0").run { context ->
            assertThat(context.startupFailure).rootCause().hasMessageContaining("capacity")
        }
    }

    @Test
    fun `не стартует без ключа обезличивания жалоб`() {
        runner.withPropertyValues("intake.reports.reporter-key=").run { context ->
            assertThat(context.startupFailure).rootCause().hasMessageContaining("reporterKey")
        }
    }

    @Test
    fun `не берёт из кэша больше наборов на заведение, чем в нём хранится`() {
        runner.withPropertyValues("nearby.combos-per-venue=6").run { context ->
            assertThat(context.startupFailure).rootCause().hasMessageContaining("combosPerVenue")
        }
    }

    @EnableConfigurationProperties(
        AdminProperties::class,
        StorageProperties::class,
        NearbyProperties::class,
        RateLimitProperties::class,
        IntakeProperties::class,
    )
    class PropertiesConfiguration
}
