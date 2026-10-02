package ru.normaryadom.web

import org.springframework.core.convert.converter.Converter
import org.springframework.stereotype.Component
import ru.normaryadom.catalog.domain.DietTag

@Component
class DietTagConverter : Converter<String, DietTag> {
    override fun convert(source: String): DietTag = DietTag.fromCode(source) ?: throw IllegalArgumentException("Unknown diet tag")
}
