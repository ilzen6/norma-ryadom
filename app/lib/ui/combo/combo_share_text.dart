import '../../domain/models/catalog.dart' show SourceKind;
import '../../l10n/generated/app_localizations.dart';
import '../core/formatting.dart';
import '../core/l10n_extensions.dart';
import 'selected_combo.dart';

abstract final class ComboShareText {
  static String of(AppLocalizations l10n, SelectedCombo selected) {
    final option = selected.option;
    final combo = option.combo;
    final totals = combo.totals;
    final venue = option.venue;
    final heading = l10n.shareHeading(l10n.meal(selected.meal), venue.name, venue.address);
    final distance = option.distanceMeters;
    final walk = distance != null && distance <= MealLabels.walkingLimitMeters
        ? ', ${l10n.shareWalk(l10n.walkMinutesOf(distance))}'
        : '';
    final estimated =
        combo.sourceKind == SourceKind.estimate || combo.dishes.any((dish) => dish.sourceKind == SourceKind.estimate);
    return [
      '$heading$walk',
      for (final dish in combo.dishes) l10n.shareDish(dish.name, Formatting.integer(dish.nutrients.kcal)),
      [
        l10n.shareTotals(
          Formatting.integer(totals.kcal),
          Formatting.integer(totals.protein),
          Formatting.integer(totals.fat),
          Formatting.integer(totals.carbs),
        ),
        if (combo.priceMinor case final price?) l10n.sharePrice(Formatting.rubles(price)),
      ].join(' · '),
      if (estimated) l10n.shareFooterEstimate else l10n.shareFooter,
    ].join('\n');
  }
}
