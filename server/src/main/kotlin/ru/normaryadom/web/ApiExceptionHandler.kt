package ru.normaryadom.web

import org.slf4j.LoggerFactory
import org.springframework.beans.TypeMismatchException
import org.springframework.context.MessageSourceResolvable
import org.springframework.http.HttpHeaders
import org.springframework.http.HttpStatus
import org.springframework.http.HttpStatusCode
import org.springframework.http.ProblemDetail
import org.springframework.http.ResponseEntity
import org.springframework.http.converter.HttpMessageNotReadableException
import org.springframework.validation.Errors
import org.springframework.web.bind.MethodArgumentNotValidException
import org.springframework.web.bind.MissingServletRequestParameterException
import org.springframework.web.bind.annotation.ExceptionHandler
import org.springframework.web.bind.annotation.RestController
import org.springframework.web.bind.annotation.RestControllerAdvice
import org.springframework.web.context.request.WebRequest
import org.springframework.web.method.annotation.HandlerMethodValidationException
import org.springframework.web.multipart.MaxUploadSizeExceededException
import org.springframework.web.servlet.mvc.method.annotation.ResponseEntityExceptionHandler
import ru.normaryadom.common.error.NotFoundException
import ru.normaryadom.common.ratelimit.RateLimitExceededException
import ru.normaryadom.intake.photo.PhotoTooLargeException
import ru.normaryadom.intake.photo.StorageUnavailableException
import ru.normaryadom.intake.photo.UnsupportedPhotoException
import ru.normaryadom.recommendation.DishNotInMenuException
import ru.normaryadom.recommendation.ReplaceIndexOutOfRangeException
import ru.normaryadom.recommendation.api.IncompleteTargetException
import tools.jackson.core.JacksonException
import java.net.URI

@RestControllerAdvice(annotations = [RestController::class])
class ApiExceptionHandler : ResponseEntityExceptionHandler() {
    @ExceptionHandler(NotFoundException::class)
    fun notFound(ex: NotFoundException): ProblemDetail =
        problem(HttpStatus.NOT_FOUND, ProblemTypes.NOT_FOUND, "Объект не найден").apply {
            setProperty("resource", ex.resource)
            setProperty("resourceId", ex.resourceId)
        }

    @ExceptionHandler(IncompleteTargetException::class)
    fun incompleteTarget(ex: IncompleteTargetException): ProblemDetail =
        validationProblem(ex.missingParameters.map { FieldError(it, "обязателен, если задана цель") })

    @ExceptionHandler(ReplaceIndexOutOfRangeException::class)
    fun replaceIndex(ex: ReplaceIndexOutOfRangeException): ProblemDetail =
        validationProblem(listOf(FieldError("replaceIndex", "должно быть меньше ${ex.size}")))

    @ExceptionHandler(DishNotInMenuException::class)
    fun dishNotInMenu(ex: DishNotInMenuException): ProblemDetail =
        problem(HttpStatus.UNPROCESSABLE_CONTENT, ProblemTypes.DISH_NOT_IN_MENU, "Блюда недоступны в этом заведении").apply {
            setProperty("dishIds", ex.dishIds)
        }

    @ExceptionHandler(RateLimitExceededException::class)
    fun rateLimited(ex: RateLimitExceededException): ResponseEntity<ProblemDetail> =
        ResponseEntity
            .status(HttpStatus.TOO_MANY_REQUESTS)
            .header(
                HttpHeaders.RETRY_AFTER,
                ex.retryAfter
                    .toSeconds()
                    .coerceAtLeast(1)
                    .toString(),
            ).body(problem(HttpStatus.TOO_MANY_REQUESTS, ProblemTypes.RATE_LIMIT, "Слишком много запросов, попробуйте позже"))

    @ExceptionHandler(UnsupportedPhotoException::class)
    fun unsupportedPhoto(): ProblemDetail =
        problem(HttpStatus.UNSUPPORTED_MEDIA_TYPE, ProblemTypes.UNSUPPORTED_PHOTO, "Принимаются только фото JPEG и PNG")

    @ExceptionHandler(PhotoTooLargeException::class)
    fun photoTooLarge(): ProblemDetail = photoTooLargeProblem()

    @ExceptionHandler(StorageUnavailableException::class)
    fun storageUnavailable(ex: StorageUnavailableException): ProblemDetail {
        log.error("Photo storage is unavailable", ex)
        return problem(HttpStatus.SERVICE_UNAVAILABLE, ProblemTypes.STORAGE_UNAVAILABLE, "Загрузка фото временно недоступна")
    }

    @ExceptionHandler(Exception::class)
    fun unexpected(ex: Exception): ProblemDetail {
        log.error("Unexpected error while handling API request", ex)
        return problem(HttpStatus.INTERNAL_SERVER_ERROR, ProblemTypes.INTERNAL, "Непредвиденная ошибка")
    }

    override fun handleMethodArgumentNotValid(
        ex: MethodArgumentNotValidException,
        headers: HttpHeaders,
        status: HttpStatusCode,
        request: WebRequest,
    ): ResponseEntity<Any> = ResponseEntity.badRequest().body(validationProblem(bindingErrors(ex.bindingResult)))

    override fun handleHandlerMethodValidationException(
        ex: HandlerMethodValidationException,
        headers: HttpHeaders,
        status: HttpStatusCode,
        request: WebRequest,
    ): ResponseEntity<Any> {
        val errors =
            ex.parameterValidationResults.flatMap { result ->
                val parameterName = result.methodParameter.parameterName ?: "parameter"
                val beanErrors = (result as? Errors)?.let(::bindingErrors)
                beanErrors ?: result.resolvableErrors.map { FieldError(parameterName, messageOf(it)) }
            }
        return ResponseEntity.badRequest().body(validationProblem(errors))
    }

    override fun handleHttpMessageNotReadable(
        ex: HttpMessageNotReadableException,
        headers: HttpHeaders,
        status: HttpStatusCode,
        request: WebRequest,
    ): ResponseEntity<Any> {
        val path = (ex.cause as? JacksonException)?.path.orEmpty()
        val field =
            path
                .joinToString(".") { reference -> reference.propertyName ?: "[${reference.index}]" }
                .replace(".[", "[")
                .ifEmpty { "body" }
        return ResponseEntity.badRequest().body(validationProblem(listOf(FieldError(field, "отсутствует или имеет неверный формат"))))
    }

    override fun handleMissingServletRequestParameter(
        ex: MissingServletRequestParameterException,
        headers: HttpHeaders,
        status: HttpStatusCode,
        request: WebRequest,
    ): ResponseEntity<Any> =
        ResponseEntity.badRequest().body(validationProblem(listOf(FieldError(ex.parameterName, "обязательный параметр"))))

    override fun handleMaxUploadSizeExceededException(
        ex: MaxUploadSizeExceededException,
        headers: HttpHeaders,
        status: HttpStatusCode,
        request: WebRequest,
    ): ResponseEntity<Any> = ResponseEntity.status(HttpStatus.CONTENT_TOO_LARGE).body(photoTooLargeProblem())

    override fun handleTypeMismatch(
        ex: TypeMismatchException,
        headers: HttpHeaders,
        status: HttpStatusCode,
        request: WebRequest,
    ): ResponseEntity<Any> =
        ResponseEntity.badRequest().body(validationProblem(listOf(FieldError(ex.propertyName ?: "parameter", INVALID_VALUE))))

    private fun bindingErrors(result: Errors): List<FieldError> =
        result.fieldErrors.map { FieldError(it.field, if (it.isBindingFailure) INVALID_VALUE else messageOf(it)) } +
            result.globalErrors.map { FieldError(it.objectName, messageOf(it)) }

    private fun messageOf(error: MessageSourceResolvable): String = error.defaultMessage ?: INVALID_VALUE

    private fun validationProblem(errors: List<FieldError>): ProblemDetail =
        problem(HttpStatus.BAD_REQUEST, ProblemTypes.VALIDATION, "Запрос не прошёл проверку").apply {
            setProperty("errors", errors.sortedWith(compareBy(FieldError::field, FieldError::message)))
        }

    private fun photoTooLargeProblem(): ProblemDetail =
        problem(HttpStatus.CONTENT_TOO_LARGE, ProblemTypes.PHOTO_TOO_LARGE, "Фото больше допустимого размера")

    private fun problem(
        status: HttpStatus,
        type: URI,
        detail: String,
    ): ProblemDetail =
        ProblemDetail.forStatusAndDetail(status, detail).apply {
            this.type = type
        }

    private companion object {
        const val INVALID_VALUE = "имеет неверное значение"
        val log = LoggerFactory.getLogger(ApiExceptionHandler::class.java)
    }
}
