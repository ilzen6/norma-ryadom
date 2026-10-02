package ru.normaryadom.intake.storage

interface PhotoStorage {
    fun put(
        key: String,
        content: ByteArray,
        contentType: String,
    )

    fun get(key: String): ByteArray
}

class StorageUnavailableException(
    cause: Throwable,
) : RuntimeException("Photo storage is unavailable", cause)

class PhotoNotFoundException(
    val key: String,
) : RuntimeException("Photo is missing in storage")
