import 'package:flutter/material.dart';

import '../../../domain/models/combo.dart';
import '../l10n_extensions.dart';
import 'nutrients_text.dart';
import 'trust_badge.dart';

class ComboCard extends StatelessWidget {
  const ComboCard({super.key, required this.option, required this.onTap, this.showVenue = true});

  final ComboOption option;
  final VoidCallback onTap;
  final bool showVenue;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final combo = option.combo;
    final totals = combo.totals;
    final textTheme = Theme.of(context).textTheme;
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (showVenue)
                Row(
                  children: [
                    Expanded(child: Text(option.venue.name, style: textTheme.titleMedium)),
                    if (option.distanceMeters case final meters?) Text(l10n.distanceMeters(meters)),
                  ],
                ),
              const SizedBox(height: 4),
              Text(combo.dishes.map((dish) => dish.name).join(' + '), style: textTheme.bodyLarge),
              const SizedBox(height: 8),
              NutrientsText(
                kcal: totals.kcal,
                protein: totals.protein,
                fat: totals.fat,
                carbs: totals.carbs,
                style: textTheme.titleSmall,
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 12,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(l10n.priceOf(combo.priceMinor)),
                  TrustBadge(kind: combo.sourceKind),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
