package ru.normaryadom.intake.photo

import org.springframework.stereotype.Component
import ru.normaryadom.intake.config.IntakeProperties
import java.awt.image.BufferedImage
import java.io.ByteArrayInputStream
import java.io.ByteArrayOutputStream
import java.io.IOException
import javax.imageio.ImageIO

@Component
class PhotoSanitizer(
    private val properties: IntakeProperties,
) {
    fun sanitize(photo: ByteArray): SanitizedPhoto {
        requireWithin(photo.size.toLong(), properties.photo.maxSize.toBytes())
        val format = PhotoFormat.detect(photo) ?: throw UnsupportedPhotoException()
        requireWithin(pixelCount(photo), properties.photo.maxPixels)
        return SanitizedPhoto(content = reencode(decode(photo), format), format = format)
    }

    private fun requireWithin(
        value: Long,
        limit: Long,
    ) {
        if (value > limit) throw PhotoTooLargeException()
    }

    private fun pixelCount(photo: ByteArray): Long =
        unreadableAsUnsupported {
            ImageIO.createImageInputStream(ByteArrayInputStream(photo)).use { stream ->
                val reader = ImageIO.getImageReaders(stream).asSequence().firstOrNull() ?: throw UnsupportedPhotoException()
                try {
                    reader.input = stream
                    reader.getWidth(0).toLong() * reader.getHeight(0)
                } finally {
                    reader.dispose()
                }
            }
        }

    private fun decode(photo: ByteArray): BufferedImage =
        unreadableAsUnsupported { ImageIO.read(ByteArrayInputStream(photo)) } ?: throw UnsupportedPhotoException()

    private fun reencode(
        image: BufferedImage,
        format: PhotoFormat,
    ): ByteArray {
        val output = ByteArrayOutputStream()
        if (!ImageIO.write(image, format.imageIoName, output)) throw UnsupportedPhotoException()
        return output.toByteArray()
    }

    private fun <T> unreadableAsUnsupported(read: () -> T): T =
        try {
            read()
        } catch (e: IOException) {
            throw UnsupportedPhotoException(e)
        }
}

class SanitizedPhoto(
    val content: ByteArray,
    val format: PhotoFormat,
)
