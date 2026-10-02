import 'package:flutter/material.dart';

import '../../../domain/models/combo.dart';
import '../formatting.dart';
import '../l10n_extensions.dart';
import '../theme.dart';
import 'trust_badge.dart';
import 'visuals.dart';

class ComboCard extends StatelessWidget {
  const ComboCard({super.key, required this.option, required this.onTap, this.showVenue = true});

  final ComboOption option;
  final VoidCallback onTap;
  final bool showVenue;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final palette = context.palette;
    final textTheme = Theme.of(context).textTheme;
    final combo = option.combo;
    final totals = combo.totals;
    final onTarget = combo.checks.every((check) => check.status == MetricStatus.ok);
    return Panel(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showVenue) ...[
            Row(
              children: [
                Icon(Icons.storefront_rounded, size: 18, color: palette.inkMuted),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    option.venue.name,
                    style: textTheme.labelLarge?.copyWith(color: palette.inkMuted),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (option.distanceMeters case final meters?)
                  StatusPill(
                    label: l10n.distanceMeters(meters),
                    tone: Tone.neutral,
                    icon: Icons.directions_walk_rounded,
                  ),
              ],
            ),
            const SizedBox(height: 12),
          ],
          DishLines(dishes: combo.dishes),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: Formatting.integer(totals.kcal),
                        style: textTheme.headlineMedium?.copyWith(fontFeatures: AppFonts.tabular),
                      ),
                      TextSpan(
                        text: ' ${l10n.kcalUnit}',
                        style: textTheme.labelLarge?.copyWith(color: palette.inkMuted),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                l10n.priceOf(combo.priceMinor),
                style: textTheme.titleMedium?.copyWith(fontFeatures: AppFonts.tabular),
              ),
            ],
          ),
          const SizedBox(height: 12),
          MacroSplitBar(protein: totals.protein, fat: totals.fat, carbs: totals.carbs),
          const SizedBox(height: 10),
          Semantics(
            label: l10n.comboTotalsSpoken(
              totals.kcal.round(),
              totals.protein.round(),
              totals.fat.round(),
              totals.carbs.round(),
            ),
            child: ExcludeSemantics(
              child: Wrap(
                spacing: 14,
                runSpacing: 6,
                children: [
                  MacroLegendValue(
                    label: l10n.proteinShort,
                    value: l10n.gramsValue(totals.protein.round()),
                    color: palette.protein,
                  ),
                  MacroLegendValue(
                    label: l10n.fatShort,
                    value: l10n.gramsValue(totals.fat.round()),
                    color: palette.fat,
                  ),
                  MacroLegendValue(
                    label: l10n.carbsShort,
                    value: l10n.gramsValue(totals.carbs.round()),
                    color: palette.carbs,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              StatusPill(
                label: onTarget ? l10n.fitOnTarget : l10n.fitCompromise,
                tone: onTarget ? Tone.good : Tone.warn,
                icon: onTarget ? Icons.check_circle_rounded : Icons.balance_rounded,
              ),
              TrustBadge(kind: combo.sourceKind),
            ],
          ),
        ],
      ),
    );
  }
}

class DishLines extends StatelessWidget {
  const DishLines({super.key, required this.dishes, this.maxLines = 4});

  final List<Dish> dishes;
  final int maxLines;

  static List<(Dish, int)> group(List<Dish> dishes) {
    final groups = <(Dish, int)>[];
    for (final dish in dishes) {
      final index = groups.indexWhere((entry) => entry.$1.id == dish.id);
      if (index < 0) {
        groups.add((dish, 1));
      } else {
        groups[index] = (groups[index].$1, groups[index].$2 + 1);
      }
    }
    return groups;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final palette = context.palette;
    final textTheme = Theme.of(context).textTheme;
    final groups = group(dishes);
    final visible = groups.take(maxLines).toList();
    final hidden = groups.length - visible.length;
    return Semantics(
      label: dishes.map((dish) => dish.name).join(' + '),
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final (index, (dish, count)) in visible.indexed) ...[
              if (index > 0) const SizedBox(height: 8),
              Row(
                children: [
                  DishAvatar(category: dish.category, name: dish.name, size: 32),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      dish.name,
                      style: textTheme.titleSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (count > 1) ...[
                    const SizedBox(width: 8),
                    Text(
                      l10n.dishTimes(count),
                      style: textTheme.labelLarge?.copyWith(color: palette.brand, fontFeatures: AppFonts.tabular),
                    ),
                  ],
                  const SizedBox(width: 12),
                  Text(
                    Formatting.integer(dish.nutrients.kcal * count),
                    style: textTheme.bodySmall?.copyWith(color: palette.inkSubtle, fontFeatures: AppFonts.tabular),
                  ),
                ],
              ),
            ],
            if (hidden > 0) ...[
              const SizedBox(height: 8),
              Text(l10n.moreDishes(hidden), style: textTheme.bodySmall?.copyWith(color: palette.inkMuted)),
            ],
          ],
        ),
      ),
    );
  }
}
