package ru.normaryadom.recommendation

sealed class RejectedDishesException(
    val dishIds: List<Long>,
    message: String,
) : RuntimeException(message)

class DishNotInMenuException(
    dishIds: List<Long>,
) : RejectedDishesException(dishIds, "Dishes are not available in the venue menu")

class DishExcludedException(
    dishIds: List<Long>,
) : RejectedDishesException(dishIds, "Dishes contain excluded diet tags")

class ReplaceIndexOutOfRangeException(
    val index: Int,
    val size: Int,
) : RuntimeException("Replace index is out of range")
