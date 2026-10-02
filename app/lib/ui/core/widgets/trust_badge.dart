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
    final (icon, color) = switch (kind) {
      SourceKind.verified => (Icons.verified, AppColors.good),
      SourceKind.fromMenu => (Icons.menu_book, AppColors.brand),
      SourceKind.estimate || SourceKind.unknown => (Icons.help_outline, AppColors.none),
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
          child: Text(details.join(' · '), style: Theme.of(context).textTheme.bodySmall?.copyWith(color: color)),
        ),
      ],
    );
  }
}
