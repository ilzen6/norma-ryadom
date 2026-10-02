package ru.normaryadom.intake.config

import org.springframework.boot.autoconfigure.condition.ConditionalOnBooleanProperty
import org.springframework.context.annotation.Configuration
import org.springframework.scheduling.annotation.EnableScheduling
import org.springframework.scheduling.annotation.Scheduled
import ru.normaryadom.intake.ocr.MenuOcrProcessor

@Configuration(proxyBeanMethods = false)
@EnableScheduling
@ConditionalOnBooleanProperty("intake.ocr.worker-enabled")
class OcrWorkerConfiguration(
    private val processor: MenuOcrProcessor,
) {
    @Scheduled(fixedDelayString = "\${intake.ocr.poll-interval}")
    fun recognizePendingMenus() {
        processor.processPending()
    }
}
