package ru.normaryadom.catalog.service

import ru.normaryadom.catalog.importing.CsvError

sealed interface ImportOutcome {
    data class Imported(
        val upserted: Int,
        val withdrawn: Int,
    ) : ImportOutcome

    data class Rejected(
        val errors: List<CsvError>,
    ) : ImportOutcome
}
