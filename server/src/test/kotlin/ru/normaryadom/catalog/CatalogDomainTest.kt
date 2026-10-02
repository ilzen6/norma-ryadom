package ru.normaryadom.catalog

import org.assertj.core.api.Assertions.assertThat
import org.assertj.core.api.Assertions.assertThatThrownBy
import org.junit.jupiter.api.Test
import ru.normaryadom.catalog.domain.DietTag
import ru.normaryadom.catalog.domain.DishCategory
import ru.normaryadom.catalog.domain.GeoPoint
import ru.normaryadom.catalog.domain.MenuScope
import ru.normaryadom.catalog.domain.SourceKind

class CatalogDomainTest {
    @Test
    fun `добавляет тег мяса к свинине, говядине и курице`() {
        assertThat(DietTag.withImplied(setOf(DietTag.CHICKEN))).containsExactlyInAnyOrder(DietTag.CHICKEN, DietTag.MEAT)
        assertThat(DietTag.withImplied(setOf(DietTag.FISH))).containsExactly(DietTag.FISH)
    }

    @Test
    fun `распознаёт коды тегов, категорий и источников`() {
        assertThat(DietTag.fromCode(" Pork ")).isEqualTo(DietTag.PORK)
        assertThat(DietTag.fromCode("bacon")).isNull()
        assertThat(DishCategory.fromCode("SAUCE")).isEqualTo(DishCategory.SAUCE)
        assertThat(DishCategory.fromCode("soup")).isNull()
        assertThat(SourceKind.fromCode("B")).isEqualTo(SourceKind.B)
        assertThat(SourceKind.C.code).isEqualTo("C")
    }

    @Test
    fun `не допускает координаты вне земного шара`() {
        assertThatThrownBy { GeoPoint(lat = 90.1, lon = 0.0) }.isInstanceOf(IllegalArgumentException::class.java)
        assertThatThrownBy { GeoPoint(lat = 0.0, lon = -180.1) }.isInstanceOf(IllegalArgumentException::class.java)
    }

    @Test
    fun `требует у меню владельца - сеть или точку`() {
        assertThatThrownBy { MenuScope(null, 0, null, 0) }.isInstanceOf(IllegalArgumentException::class.java)
    }
}
