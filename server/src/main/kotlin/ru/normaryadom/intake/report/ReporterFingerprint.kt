package ru.normaryadom.intake.report

import org.springframework.stereotype.Component
import ru.normaryadom.intake.config.IntakeProperties
import java.util.HexFormat
import javax.crypto.Mac
import javax.crypto.spec.SecretKeySpec

@Component
class ReporterFingerprint(
    properties: IntakeProperties,
) {
    private val key = SecretKeySpec(properties.reports.reporterKey.toByteArray(Charsets.UTF_8), ALGORITHM)

    fun of(clientKey: String): String {
        val mac = Mac.getInstance(ALGORITHM)
        mac.init(key)
        return HexFormat.of().formatHex(mac.doFinal(clientKey.toByteArray(Charsets.UTF_8)))
    }

    private companion object {
        const val ALGORITHM = "HmacSHA256"
    }
}
