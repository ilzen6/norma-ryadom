package ru.normaryadom.admin

import org.slf4j.LoggerFactory
import org.springframework.http.HttpStatus
import org.springframework.web.bind.annotation.ControllerAdvice
import org.springframework.web.bind.annotation.ExceptionHandler
import org.springframework.web.bind.annotation.ResponseStatus
import ru.normaryadom.common.error.NotFoundException
import ru.normaryadom.intake.storage.StorageUnavailableException

@ControllerAdvice(basePackageClasses = [AdminController::class])
class AdminExceptionHandler {
    @ExceptionHandler(NotFoundException::class)
    @ResponseStatus(HttpStatus.NOT_FOUND)
    fun notFound(): String = "admin/not-found"

    @ExceptionHandler(StorageUnavailableException::class)
    @ResponseStatus(HttpStatus.SERVICE_UNAVAILABLE)
    fun storageUnavailable(ex: StorageUnavailableException): String {
        log.error("Photo storage is unavailable", ex)
        return "admin/unavailable"
    }

    private companion object {
        val log = LoggerFactory.getLogger(AdminExceptionHandler::class.java)
    }
}
