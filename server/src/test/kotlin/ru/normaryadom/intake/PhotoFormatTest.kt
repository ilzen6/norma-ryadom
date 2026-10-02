package ru.normaryadom.intake

import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test
import ru.normaryadom.intake.photo.PhotoFormat

class PhotoFormatTest {
    @Test
    fun `определяет JPEG и PNG по сигнатуре, а не по имени файла`() {
        assertThat(PhotoFormat.detect(byteArrayOf(0xFF.toByte(), 0xD8.toByte(), 0xFF.toByte(), 0x00))).isEqualTo(PhotoFormat.JPEG)
        val png = byteArrayOf(0x89.toByte(), 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00)
        assertThat(PhotoFormat.detect(png)).isEqualTo(PhotoFormat.PNG)
    }

    @Test
    fun `не принимает другие и слишком короткие файлы`() {
        assertThat(PhotoFormat.detect("GIF89a".toByteArray())).isNull()
        assertThat(PhotoFormat.detect(byteArrayOf(0xFF.toByte()))).isNull()
        assertThat(PhotoFormat.detect(ByteArray(0))).isNull()
    }
}
