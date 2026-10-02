package ru.normaryadom.intake.ocr

import org.slf4j.LoggerFactory
import org.springframework.boot.autoconfigure.condition.ConditionalOnBooleanProperty
import org.springframework.context.SmartLifecycle
import org.springframework.stereotype.Component
import ru.normaryadom.intake.config.IntakeProperties
import java.util.concurrent.Executors
import java.util.concurrent.ScheduledExecutorService
import java.util.concurrent.TimeUnit

@Component
@ConditionalOnBooleanProperty("intake.ocr.worker-enabled")
class OcrWorker(
    private val processor: MenuOcrProcessor,
    private val properties: IntakeProperties,
) : SmartLifecycle {
    private var executor: ScheduledExecutorService? = null

    override fun start() {
        val pollMillis = properties.ocr.pollInterval.toMillis()
        executor =
            Executors.newSingleThreadScheduledExecutor { task -> Thread(task, THREAD_NAME).apply { isDaemon = true } }.apply {
                scheduleWithFixedDelay(::runSafely, pollMillis, pollMillis, TimeUnit.MILLISECONDS)
            }
    }

    override fun stop() {
        executor?.shutdownNow()
        executor = null
    }

    override fun isRunning(): Boolean = executor != null

    @Suppress("TooGenericExceptionCaught")
    private fun runSafely() {
        try {
            processor.processPending()
        } catch (e: RuntimeException) {
            log.error("Menu OCR worker iteration failed", e)
        }
    }

    private companion object {
        const val THREAD_NAME = "menu-ocr"
        val log = LoggerFactory.getLogger(OcrWorker::class.java)
    }
}
