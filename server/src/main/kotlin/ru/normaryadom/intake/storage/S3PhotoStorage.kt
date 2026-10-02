package ru.normaryadom.intake.storage

import io.micrometer.core.instrument.MeterRegistry
import org.springframework.stereotype.Component
import ru.normaryadom.intake.config.StorageProperties
import software.amazon.awssdk.core.exception.SdkException
import software.amazon.awssdk.core.sync.RequestBody
import software.amazon.awssdk.services.s3.S3Client
import software.amazon.awssdk.services.s3.model.NoSuchKeyException

@Component
class S3PhotoStorage(
    private val s3: S3Client,
    private val properties: StorageProperties,
    private val meters: MeterRegistry,
) : PhotoStorage {
    override fun put(
        key: String,
        content: ByteArray,
        contentType: String,
    ) = call(OPERATION_PUT) {
        s3.putObject({ it.bucket(properties.bucket).key(key).contentType(contentType) }, RequestBody.fromBytes(content))
        Unit
    }

    override fun get(key: String): ByteArray =
        try {
            call(OPERATION_GET) { s3.getObjectAsBytes { it.bucket(properties.bucket).key(key) }.asByteArray() }
        } catch (e: StorageUnavailableException) {
            if (e.cause is NoSuchKeyException) throw PhotoNotFoundException(key)
            throw e
        }

    private fun <T> call(
        operation: String,
        action: () -> T,
    ): T =
        try {
            action().also { record(operation, OUTCOME_SUCCESS) }
        } catch (e: SdkException) {
            record(operation, if (e is NoSuchKeyException) OUTCOME_NOT_FOUND else OUTCOME_ERROR)
            throw StorageUnavailableException(e)
        }

    private fun record(
        operation: String,
        outcome: String,
    ) = meters.counter(METRIC, "operation", operation, "outcome", outcome).increment()

    private companion object {
        const val METRIC = "norma.storage.calls"
        const val OPERATION_PUT = "put"
        const val OPERATION_GET = "get"
        const val OUTCOME_SUCCESS = "success"
        const val OUTCOME_NOT_FOUND = "not_found"
        const val OUTCOME_ERROR = "error"
    }
}
