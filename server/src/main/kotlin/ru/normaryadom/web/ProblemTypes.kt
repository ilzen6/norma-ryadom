package ru.normaryadom.web

import java.net.URI

object ProblemTypes {
    private const val PREFIX = "urn:norma-ryadom:problem:"

    val VALIDATION: URI = URI.create("${PREFIX}validation")
    val NOT_FOUND: URI = URI.create("${PREFIX}not-found")
    val DISH_NOT_IN_MENU: URI = URI.create("${PREFIX}dish-not-in-menu")
    val DISH_EXCLUDED: URI = URI.create("${PREFIX}dish-excluded")
    val RATE_LIMIT: URI = URI.create("${PREFIX}rate-limit")
    val UNSUPPORTED_PHOTO: URI = URI.create("${PREFIX}unsupported-photo")
    val PHOTO_TOO_LARGE: URI = URI.create("${PREFIX}photo-too-large")
    val STORAGE_UNAVAILABLE: URI = URI.create("${PREFIX}storage-unavailable")
    val INTERNAL: URI = URI.create("${PREFIX}internal")
}
