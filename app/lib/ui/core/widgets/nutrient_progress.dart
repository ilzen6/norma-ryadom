import 'package:flutter/material.dart';

import '../l10n_extensions.dart';
import '../theme.dart';

class NutrientProgress extends StatelessWidget {
  const NutrientProgress({super.key, required this.label, required this.eaten, required this.norm, this.color});

  final String label;
  final double eaten;
  final int norm;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final textTheme = Theme.of(context).textTheme;
    final ratio = norm <= 0 ? 0.0 : (eaten / norm).clamp(0.0, 1.0);
    final over = norm > 0 && eaten > norm;
    final valueText = context.l10n.progressValue(eaten.round(), norm);
    final barColor = over ? palette.warn : (color ?? palette.brand);
    return Semantics(
      label: '$label: $valueText',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              spacing: 8,
              children: [
                Text(label, style: textTheme.labelMedium?.copyWith(color: palette.inkMuted)),
                Text(valueText, style: textTheme.labelMedium?.copyWith(fontFeatures: AppFonts.tabular)),
              ],
            ),
            const SizedBox(height: 5),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: ratio,
                minHeight: 6,
                color: barColor,
                backgroundColor: barColor.withValues(alpha: 0.14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
