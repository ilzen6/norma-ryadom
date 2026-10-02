import 'package:flutter/material.dart';

import '../../../domain/models/catalog.dart';
import '../formatting.dart';
import '../l10n_extensions.dart';
import '../theme.dart';

class TrustBadge extends StatelessWidget {
  const TrustBadge({super.key, required this.kind, this.source});

  final SourceKind kind;
  final DataSource? source;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final palette = context.palette;
    final (icon, color) = switch (kind) {
      SourceKind.verified => (Icons.verified_rounded, palette.good),
      SourceKind.fromMenu => (Icons.menu_book_rounded, palette.brand),
      SourceKind.estimate || SourceKind.unknown => (Icons.help_outline_rounded, palette.neutral),
    };
    final details = <String>[
      l10n.trust(kind),
      if (source?.verifiedAt case final verifiedAt?) l10n.trustVerifiedAt(Formatting.date(verifiedAt)),
      if ((source?.kcalLow, source?.kcalHigh) case (final low?, final high?))
        l10n.trustEstimateRange(low.round(), high.round()),
    ];
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 4),
        Flexible(
          child: Text(details.join(' · '), style: Theme.of(context).textTheme.labelMedium?.copyWith(color: color)),
        ),
      ],
    );
  }
}
