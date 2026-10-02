import 'package:flutter/material.dart';

import '../l10n_extensions.dart';

class NutrientsText extends StatelessWidget {
  const NutrientsText({
    super.key,
    required this.kcal,
    required this.protein,
    required this.fat,
    required this.carbs,
    this.prefix,
    this.style,
  });

  final double kcal;
  final double protein;
  final double fat;
  final double carbs;
  final String? prefix;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final shown = l10n.comboTotals(kcal.round(), protein.round(), fat.round(), carbs.round());
    final spoken = l10n.comboTotalsSpoken(kcal.round(), protein.round(), fat.round(), carbs.round());
    final prefix = this.prefix;
    return Text(
      prefix == null ? shown : '$prefix · $shown',
      semanticsLabel: prefix == null ? spoken : '$prefix, $spoken',
      style: style,
    );
  }
}
