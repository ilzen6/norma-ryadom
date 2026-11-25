package ru.normaryadom.intake.report

data class WeeklySummary(
    val itemReports: Int,
    val venueReports: Int,
    val closedReports: Int,
    val photos: Int,
    val topPlaces: List<PlaceComplaints>,
)

data class PlaceComplaints(
    val name: String,
    val complaints: Int,
)
