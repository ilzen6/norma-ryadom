package ru.normaryadom.intake.photo

enum class PhotoFormat(
    val contentType: String,
    val extension: String,
    val imageIoName: String,
    private val signature: ByteArray,
) {
    JPEG("image/jpeg", "jpg", "jpeg", byteArrayOf(0xFF.toByte(), 0xD8.toByte(), 0xFF.toByte())),
    PNG("image/png", "png", "png", byteArrayOf(0x89.toByte(), 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A)),
    ;

    private fun matches(bytes: ByteArray): Boolean = bytes.size >= signature.size && signature.indices.all { bytes[it] == signature[it] }

    companion object {
        fun detect(bytes: ByteArray): PhotoFormat? = entries.firstOrNull { it.matches(bytes) }
    }
}
