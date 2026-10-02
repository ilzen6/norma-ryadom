package ru.normaryadom.intake.photo

interface PhotoStorage {
    fun put(
        key: String,
        content: ByteArray,
        contentType: String,
    )

    fun get(key: String): ByteArray
}
