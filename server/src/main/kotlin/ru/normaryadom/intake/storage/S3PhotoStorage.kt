package ru.normaryadom.intake.storage

import org.springframework.stereotype.Component
import ru.normaryadom.intake.config.StorageProperties
import ru.normaryadom.intake.photo.PhotoStorage
import ru.normaryadom.intake.photo.StorageUnavailableException
import software.amazon.awssdk.core.exception.SdkException
import software.amazon.awssdk.core.sync.RequestBody
import software.amazon.awssdk.services.s3.S3Client

@Component
class S3PhotoStorage(
    private val s3: S3Client,
    private val properties: StorageProperties,
) : PhotoStorage {
    override fun put(
        key: String,
        content: ByteArray,
        contentType: String,
    ) {
        try {
            s3.putObject({ it.bucket(properties.bucket).key(key).contentType(contentType) }, RequestBody.fromBytes(content))
        } catch (e: SdkException) {
            throw StorageUnavailableException(e)
        }
    }

    override fun get(key: String): ByteArray =
        try {
            s3.getObjectAsBytes { it.bucket(properties.bucket).key(key) }.asByteArray()
        } catch (e: SdkException) {
            throw StorageUnavailableException(e)
        }
}
