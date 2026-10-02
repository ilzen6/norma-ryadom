package ru.normaryadom.optimizer

data class OptimizerSettings(
    val maxItems: Int,
    val heapFactor: Int,
) {
    init {
        require(maxItems > 0) { "Max items must be positive" }
        require(heapFactor > 0) { "Heap factor must be positive" }
    }
}
