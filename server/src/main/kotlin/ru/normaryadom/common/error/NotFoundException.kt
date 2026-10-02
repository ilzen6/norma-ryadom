package ru.normaryadom.common.error

open class NotFoundException(
    val resource: String,
    val resourceId: Long,
) : RuntimeException("Resource not found")
