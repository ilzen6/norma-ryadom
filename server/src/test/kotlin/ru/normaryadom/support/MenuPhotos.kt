package ru.normaryadom.support

import java.awt.Color
import java.awt.Font
import java.awt.RenderingHints
import java.awt.image.BufferedImage
import java.io.ByteArrayOutputStream
import javax.imageio.ImageIO

object MenuPhotos {
    fun withText(
        lines: List<String>,
        format: String = "png",
    ): ByteArray {
        val image = BufferedImage(WIDTH, LINE_HEIGHT * (lines.size + 1), BufferedImage.TYPE_INT_RGB)
        image.createGraphics().apply {
            color = Color.WHITE
            fillRect(0, 0, image.width, image.height)
            color = Color.BLACK
            font = Font(Font.SANS_SERIF, Font.PLAIN, FONT_SIZE)
            setRenderingHint(RenderingHints.KEY_TEXT_ANTIALIASING, RenderingHints.VALUE_TEXT_ANTIALIAS_ON)
            lines.forEachIndexed { index, line -> drawString(line, MARGIN, LINE_HEIGHT * (index + 1)) }
            dispose()
        }
        return ByteArrayOutputStream().also { ImageIO.write(image, format, it) }.toByteArray()
    }

    private const val WIDTH = 900
    private const val LINE_HEIGHT = 70
    private const val FONT_SIZE = 44
    private const val MARGIN = 30
}
