package ru.normaryadom.intake.ocr

import net.sourceforge.tess4j.Tesseract
import net.sourceforge.tess4j.TesseractException
import org.slf4j.LoggerFactory
import org.springframework.stereotype.Component
import ru.normaryadom.intake.config.IntakeProperties
import java.awt.image.BufferedImage
import java.io.ByteArrayInputStream
import java.io.IOException
import javax.imageio.ImageIO

@Component
class TesseractTextRecognizer(
    private val properties: IntakeProperties,
) : MenuTextRecognizer {
    override fun recognize(image: ByteArray): RecognitionResult =
        when (val decoded = decode(image)) {
            null -> RecognitionResult.Failed("image cannot be decoded")
            else -> readText(decoded)
        }

    private fun decode(image: ByteArray): BufferedImage? =
        try {
            ImageIO.read(ByteArrayInputStream(image))
        } catch (e: IOException) {
            log.warn("Menu photo cannot be decoded: {}", e.javaClass.simpleName)
            null
        }

    private fun readText(image: BufferedImage): RecognitionResult =
        try {
            val tesseract =
                Tesseract().apply {
                    setDatapath(properties.ocr.dataPath)
                    setLanguage(properties.ocr.language)
                }
            RecognitionResult.Recognized(tesseract.doOCR(image).trim())
        } catch (e: TesseractException) {
            RecognitionResult.Failed("recognition failed: ${e.javaClass.simpleName}")
        }

    private companion object {
        val log = LoggerFactory.getLogger(TesseractTextRecognizer::class.java)
    }
}
