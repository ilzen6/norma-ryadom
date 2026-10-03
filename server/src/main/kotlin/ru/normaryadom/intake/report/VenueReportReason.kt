package ru.normaryadom.intake.report

import com.fasterxml.jackson.annotation.JsonValue

enum class VenueReportReason(
    @get:JsonValue val code: String,
) {
    CLOSED("closed"),
    MOVED("moved"),
    NOT_FOUND("not_found"),
    ;

    companion object {
        fun of(code: String): VenueReportReason? = entries.firstOrNull { it.code == code }
    }
}
