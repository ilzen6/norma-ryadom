import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../core/l10n_extensions.dart';
import '../core/layout.dart';
import '../core/messages.dart';
import '../core/theme.dart';
import '../core/widgets/visuals.dart';
import 'privacy_sheet.dart';

class AboutScreen extends ConsumerWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final palette = context.palette;
    final textTheme = Theme.of(context).textTheme;
    final version = ref.watch(appVersionProvider).value;
    final email = ref.watch(appConfigProvider).supportEmail;
    final rows = [
      (
        const Key('about-sources'),
        l10n.aboutSources,
        () => _explain(context, l10n.aboutSources, l10n.aboutSourcesText),
      ),
      (const Key('about-norm'), l10n.aboutNorm, () => _explain(context, l10n.aboutNorm, l10n.aboutNormText)),
      (const Key('about-privacy'), l10n.aboutPrivacy, () => PrivacySheet.show(context)),
      (
        const Key('about-licenses'),
        l10n.aboutLicenses,
        () => showLicensePage(context: context, applicationName: l10n.appTitle, applicationVersion: version),
      ),
      if (email.isNotEmpty)
        (
          const Key('about-write'),
          l10n.aboutWrite,
          () async {
            await Clipboard.setData(ClipboardData(text: email));
            if (context.mounted) showMessage(context, l10n.aboutEmailCopied(email));
          },
        ),
    ];
    return Scaffold(
      appBar: AppBar(title: Text(l10n.aboutTitle)),
      body: ListView(
        padding: Layout.page(context, top: 0),
        children: [
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const BrandMark(size: 56),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(l10n.appTitle, style: textTheme.titleMedium),
                          if (version != null)
                            Text(
                              l10n.aboutVersion(version),
                              key: const Key('about-version'),
                              style: textTheme.bodySmall?.copyWith(color: palette.inkMuted),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                for (final (key, title, onTap) in rows) ...[
                  const Divider(height: 1),
                  ListTile(
                    key: key,
                    minTileHeight: 52,
                    contentPadding: EdgeInsets.zero,
                    title: Text(title, style: textTheme.bodyLarge),
                    trailing: Icon(Icons.chevron_right_rounded, color: palette.inkSubtle),
                    onTap: onTap,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: Layout.gap),
          Panel(
            key: const Key('about-sync-soon'),
            child: Row(
              children: [
                Icon(Icons.cloud_sync_rounded, color: palette.inkSubtle),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l10n.aboutSyncTitle, style: textTheme.titleSmall?.copyWith(color: palette.inkMuted)),
                      Text(l10n.aboutSyncText, style: textTheme.bodySmall),
                    ],
                  ),
                ),
                StatusPill(label: l10n.soon, tone: Tone.neutral),
              ],
            ),
          ),
          const SizedBox(height: Layout.gap),
          Text(l10n.aboutMapCredit, style: textTheme.bodySmall),
        ],
      ),
    );
  }

  static Future<void> _explain(BuildContext context, String title, String text) => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: SingleChildScrollView(child: Text(text)),
      actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(context.l10n.close))],
    ),
  );
}
