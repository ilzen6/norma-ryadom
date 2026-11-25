import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/taste.dart';
import '../core/l10n_extensions.dart';
import '../core/layout.dart';
import '../core/session.dart';
import '../core/theme.dart';
import '../core/widgets/state_views.dart';
import '../core/widgets/visuals.dart';
import 'tastes_picker.dart';

class TastesScreen extends ConsumerWidget {
  const TastesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final palette = context.palette;
    final textTheme = Theme.of(context).textTheme;
    final profile = ref.watch(profileProvider).value;
    if (profile == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.tastesTitle)),
        body: const LoadingView(),
      );
    }
    final controller = ref.read(profileProvider.notifier);
    final learned = ref.watch(learnedTastesProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.tastesTitle)),
      body: ListView(
        padding: Layout.page(context, top: 0),
        children: [
          Text(l10n.tastesHint, style: textTheme.bodyMedium?.copyWith(color: palette.inkMuted)),
          const SizedBox(height: Layout.gap),
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Eyebrow(l10n.tastesLikedTitle),
                const SizedBox(height: 12),
                TastesPicker(
                  selected: profile.likedTastes,
                  onToggle: (taste) => controller.setTastes(
                    profile.likedTastes.contains(taste)
                        ? ({...profile.likedTastes}..remove(taste))
                        : {...profile.likedTastes, taste},
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: Layout.gap),
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SwitchListTile(
                  key: const Key('learn-tastes'),
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.tastesLearnTitle),
                  subtitle: Text(l10n.tastesLearnHint),
                  value: profile.learnTastes,
                  onChanged: (learn) => controller.setLearnTastes(learn: learn),
                ),
                const SizedBox(height: 8),
                if (learned.isEmpty)
                  Text(
                    l10n.tastesLearnedEmpty,
                    key: const Key('learned-empty'),
                    style: textTheme.bodyMedium?.copyWith(color: palette.inkMuted),
                  )
                else ...[
                  Eyebrow(l10n.tastesLearnedTitle),
                  const SizedBox(height: 6),
                  for (final MapEntry(key: taste, value: times) in learned.entries)
                    _LearnedRow(
                      taste: taste,
                      times: times,
                      used: profile.learnTastes && times >= TasteLearning.minTimes,
                    ),
                  const SizedBox(height: 6),
                  Text(l10n.tastesLearnedRule(TasteLearning.minTimes), style: textTheme.bodySmall),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LearnedRow extends StatelessWidget {
  const _LearnedRow({required this.taste, required this.times, required this.used});

  final TasteTag taste;
  final int times;
  final bool used;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final palette = context.palette;
    final textTheme = Theme.of(context).textTheme;
    return ConstrainedBox(
      key: Key('learned-${taste.code}'),
      constraints: const BoxConstraints(minHeight: 40),
      child: Row(
        children: [
          Icon(
            used ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
            size: 18,
            color: used ? palette.brand : palette.inkSubtle,
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(l10n.taste(taste), style: textTheme.bodyLarge)),
          Text(l10n.tastesLearnedTimes(times), style: textTheme.bodyMedium?.copyWith(color: palette.inkMuted)),
        ],
      ),
    );
  }
}
