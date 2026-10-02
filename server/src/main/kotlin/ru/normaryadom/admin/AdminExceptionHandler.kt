package ru.normaryadom.admin

import org.springframework.http.HttpStatus
import org.springframework.web.bind.annotation.ControllerAdvice
import org.springframework.web.bind.annotation.ExceptionHandler
import org.springframework.web.bind.annotation.ResponseStatus
import ru.normaryadom.common.error.NotFoundException

@ControllerAdvice(basePackageClasses = [AdminController::class])
class AdminExceptionHandler {
    @ExceptionHandler(NotFoundException::class)
    @ResponseStatus(HttpStatus.NOT_FOUND)
    fun notFound(): String = "admin/not-found"
}
