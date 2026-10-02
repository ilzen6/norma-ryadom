package ru.normaryadom.recommendation

class DishNotInMenuException(
    val dishIds: List<Long>,
) : RuntimeException("Dishes are not available in the venue menu")

class ReplaceIndexOutOfRangeException(
    val index: Int,
    val size: Int,
) : RuntimeException("Replace index is out of range")
