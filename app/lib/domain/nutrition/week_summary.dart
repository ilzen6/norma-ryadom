import '../models/diary.dart';
import '../models/nutrition_norm.dart';

class DayTotal {
  const DayTotal({required this.day, required this.kcal, required this.protein, required this.entries});

  final DateTime day;
  final double kcal;
  final double protein;
  final int entries;
}

class WeekSummary {
  const WeekSummary._(this.days, this.norm, this.favorite);

  factory WeekSummary.of(Iterable<DiaryEntry> entries, {required DateTime today, required NutritionNorm norm}) {
    final days = [
      for (var shift = length - 1; shift >= 0; shift--) DateTime(today.year, today.month, today.day - shift),
    ];
    bool sameDay(DateTime left, DateTime right) =>
        left.year == right.year && left.month == right.month && left.day == right.day;
    final inWeek = entries.where((entry) => days.any((day) => sameDay(day, entry.day))).toList();
    final titles = <String, int>{};
    for (final entry in inWeek) {
      titles[entry.title] = (titles[entry.title] ?? 0) + 1;
    }
    final favorite = titles.entries
        .where((entry) => entry.value >= minRepeats)
        .fold<MapEntry<String, int>?>(
          null,
          (best, entry) => best == null || entry.value > best.value ? entry : best,
        );
    return WeekSummary._(
      [
        for (final day in days)
          DayTotal(
            day: day,
            kcal: inWeek.where((entry) => sameDay(entry.day, day)).fold(0, (sum, entry) => sum + entry.intake.kcal),
            protein: inWeek
                .where((entry) => sameDay(entry.day, day))
                .fold(0, (sum, entry) => sum + entry.intake.protein),
            entries: inWeek.where((entry) => sameDay(entry.day, day)).length,
          ),
      ],
      norm,
      favorite == null ? null : (title: favorite.key, times: favorite.value),
    );
  }

  static const length = 7;
  static const overShare = 1.05;
  static const underShare = 0.85;
  static const minRepeats = 2;

  final List<DayTotal> days;
  final NutritionNorm norm;
  final ({String title, int times})? favorite;

  List<DayTotal> get recorded => days.where((day) => day.entries > 0).toList();

  bool get isEmpty => recorded.isEmpty;

  double get averageKcal => _average((day) => day.kcal);

  double get averageProtein => _average((day) => day.protein);

  int get daysInNorm =>
      recorded.where((day) => day.kcal >= norm.kcal * underShare && day.kcal <= norm.kcal * overShare).length;

  bool isOver(DayTotal day) => day.kcal > norm.kcal * overShare;

  double _average(double Function(DayTotal day) value) {
    final days = recorded;
    return days.isEmpty ? 0 : days.fold<double>(0, (sum, day) => sum + value(day)) / days.length;
  }
}
