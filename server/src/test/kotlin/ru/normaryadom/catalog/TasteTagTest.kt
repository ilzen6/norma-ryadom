package ru.normaryadom.catalog

import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test
import ru.normaryadom.catalog.domain.DietTag
import ru.normaryadom.catalog.domain.DishCategory
import ru.normaryadom.catalog.domain.TasteTag
import ru.normaryadom.catalog.domain.VenueKind

class TasteTagTest {
    @Test
    fun `узнаёт суп по слову в названии`() {
        assertThat(TasteTag.ofDish("Крем-суп грибной", DishCategory.MAIN, emptySet())).containsExactly(TasteTag.SOUP)
    }

    @Test
    fun `узнаёт короткие названия только целым словом`() {
        assertThat(TasteTag.ofDish("Щи из свежей капусты", DishCategory.MAIN, emptySet())).containsExactly(TasteTag.SOUP)
        assertThat(TasteTag.ofDish("Фокачча с розмарином", DishCategory.SIDE, emptySet())).isEmpty()
    }

    @Test
    fun `относит к салатам по категории меню`() {
        assertThat(TasteTag.ofDish("Овощи гриль", DishCategory.SALAD, emptySet())).containsExactly(TasteTag.SALAD)
    }

    @Test
    fun `узнаёт рыбу по отметке в меню`() {
        assertThat(TasteTag.ofDish("Стейк на гриле", DishCategory.MAIN, setOf(DietTag.FISH))).containsExactly(TasteTag.FISH)
    }

    @Test
    fun `находит у блюда несколько вкусов`() {
        assertThat(TasteTag.ofDish("Рамен с креветками", DishCategory.MAIN, emptySet()))
            .containsExactly(TasteTag.SOUP, TasteTag.FISH, TasteTag.ASIAN)
    }

    @Test
    fun `узнаёт словосочетания`() {
        assertThat(TasteTag.ofDish("Хот-дог классический", DishCategory.MAIN, emptySet())).containsExactly(TasteTag.BURGER)
    }

    @Test
    fun `берёт кухню из вида заведения`() {
        assertThat(TasteTag.ofVenue(VenueKind.GEORGIAN)).containsExactly(TasteTag.GEORGIAN)
        assertThat(TasteTag.ofVenue(VenueKind.CAFE)).isEmpty()
        assertThat(TasteTag.ofVenue(null)).isEmpty()
    }
}
