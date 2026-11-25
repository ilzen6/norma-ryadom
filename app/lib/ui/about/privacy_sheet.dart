import 'package:flutter/material.dart';

import '../core/l10n_extensions.dart';
import '../core/theme.dart';

class PrivacySheet extends StatelessWidget {
  const PrivacySheet({super.key});

  static Future<void> show(BuildContext context) => showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => const PrivacySheet(),
  );

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final textTheme = Theme.of(context).textTheme;
    final sections = [
      (l10n.privacyOnPhoneTitle, l10n.privacyOnPhoneText),
      (l10n.privacyServerTitle, l10n.privacyServerText),
      (l10n.privacyReportsTitle, l10n.privacyReportsText),
      (l10n.privacyPermissionsTitle, l10n.privacyPermissionsText),
      (l10n.privacyChildrenTitle, l10n.privacyChildrenText),
    ];
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      builder: (context, controller) => ListView(
        key: const Key('privacy-sheet'),
        controller: controller,
        padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.paddingOf(context).bottom + 24),
        children: [
          Semantics(header: true, child: Text(l10n.privacyTitle, style: textTheme.headlineSmall)),
          const SizedBox(height: 10),
          Text(l10n.privacyIntro, style: textTheme.bodyLarge),
          for (final (title, text) in sections) ...[
            const SizedBox(height: 18),
            Semantics(
              header: true,
              child: Text(title, style: textTheme.titleMedium?.copyWith(color: context.palette.brand)),
            ),
            const SizedBox(height: 6),
            Text(text, style: textTheme.bodyMedium),
          ],
        ],
      ),
    );
  }
}
