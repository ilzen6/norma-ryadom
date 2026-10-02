import 'package:flutter/material.dart';

import '../l10n_extensions.dart';

class NutrientProgress extends StatelessWidget {
  const NutrientProgress({super.key, required this.label, required this.eaten, required this.norm});

  final String label;
  final double eaten;
  final int norm;

  @override
  Widget build(BuildContext context) {
    final ratio = norm <= 0 ? 0.0 : (eaten / norm).clamp(0.0, 1.0);
    final over = norm > 0 && eaten > norm;
    final valueText = context.l10n.progressValue(eaten.round(), norm);
    return Semantics(
      label: '$label: $valueText',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(child: Text(label)),
                Text(valueText),
              ],
            ),
            const SizedBox(height: 4),
            LinearProgressIndicator(
              value: ratio,
              minHeight: 8,
              borderRadius: BorderRadius.circular(4),
              color: over ? Theme.of(context).colorScheme.error : null,
            ),
          ],
        ),
      ),
    );
  }
}
