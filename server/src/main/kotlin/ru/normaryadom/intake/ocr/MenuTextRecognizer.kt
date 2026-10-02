package ru.normaryadom.intake.ocr

interface MenuTextRecognizer {
    fun recognize(image: ByteArray): RecognitionResult
}

sealed interface RecognitionResult {
    data class Recognized(
        val text: String,
    ) : RecognitionResult

    data class Failed(
        val reason: String,
    ) : RecognitionResult
}
