import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/providers.dart';
import '../../domain/models/district.dart';
import '../../routing/routes.dart';
import '../core/formatting.dart';
import '../core/l10n_extensions.dart';
import '../core/messages.dart';
import '../core/layout.dart';
import '../core/session.dart';
import '../core/theme.dart';
import '../core/widgets/visuals.dart';
import '../core/widgets/state_views.dart';
import 'server_dialog.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final profile = ref.watch(profileProvider).value;
    final norm = ref.watch(normProvider);
    if (profile == null || norm == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.profileTitle)),
        body: const LoadingView(),
      );
    }
    final controller = ref.read(profileProvider.notifier);
    final demoServer = ref.watch(appConfigProvider).demoServer;
    final palette = context.palette;
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: Layout.page(context),
          children: [
            ScreenHeader(title: l10n.profileTitle),
            Panel(
              padding: EdgeInsets.zero,
              onTap: () => context.push(Routes.profileEdit),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 18, 14, 18),
                child: Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(color: palette.brandSoft, shape: BoxShape.circle),
                      child: Icon(Icons.person_rounded, color: palette.brand, size: 28),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.profileParams(profile.age, profile.heightCm, Formatting.decimal(profile.weightKg)),
                            style: textTheme.titleSmall,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${l10n.activity(profile.activity)} · ${l10n.goal(profile.goal)}',
                            style: textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.edit_rounded, color: palette.inkMuted),
                  ],
                ),
              ),
            ),
            const SizedBox(height: Layout.gap),
            Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Eyebrow(l10n.normTitle)),
                      if (profile.manualNorm != null) StatusPill(label: l10n.normManualHint, tone: Tone.brand),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    l10n.kcalValue(norm.kcal),
                    style: textTheme.headlineMedium?.copyWith(fontFeatures: AppFonts.tabular),
                  ),
                  const SizedBox(height: 12),
                  MacroSplitBar(
                    protein: norm.protein.toDouble(),
                    fat: norm.fat.toDouble(),
                    carbs: norm.carbs.toDouble(),
                    height: 8,
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 14,
                    runSpacing: 6,
                    children: [
                      MacroLegendValue(
                        label: l10n.proteinShort,
                        value: l10n.gramsValue(norm.protein),
                        color: palette.protein,
                      ),
                      MacroLegendValue(label: l10n.fatShort, value: l10n.gramsValue(norm.fat), color: palette.fat),
                      MacroLegendValue(
                        label: l10n.carbsShort,
                        value: l10n.gramsValue(norm.carbs),
                        color: palette.carbs,
                      ),
                    ],
                  ),
                  if (profile.preferences.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final preference in profile.preferences)
                          StatusPill(label: l10n.preference(preference), tone: Tone.neutral, icon: Icons.block_rounded),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: Layout.section),
            SectionTitle(title: l10n.profileSettings),
            Panel(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                children: [
                  SwitchListTile(
                    key: const Key('location-consent'),
                    secondary: Icon(Icons.near_me_rounded, color: palette.brand),
                    title: Text(l10n.profileLocationConsent),
                    value: profile.locationConsent,
                    onChanged: (consent) async {
                      final failure = await controller.setLocationConsent(consent: consent);
                      if (failure != null && context.mounted) showMessage(context, l10n.failure(failure));
                    },
                  ),
                  const Divider(indent: 72, endIndent: 16),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                    child: DropdownButtonFormField<District>(
                      isExpanded: true,
                      initialValue: profile.district ?? District.moscowCity,
                      decoration: InputDecoration(
                        labelText: l10n.locationDistrictLabel,
                        prefixIcon: const Icon(Icons.location_city_rounded),
                      ),
                      items: [
                        for (final district in District.values)
                          DropdownMenuItem(value: district, child: Text(l10n.district(district))),
                      ],
                      onChanged: (district) async {
                        if (district == null) return;
                        await controller.save(profile.copyWith(district: district));
                      },
                    ),
                  ),
                  const Divider(indent: 72, endIndent: 16),
                  ListTile(
                    key: const Key('server-settings'),
                    leading: Icon(Icons.dns_rounded, color: palette.brand),
                    title: Text(l10n.serverTitle),
                    subtitle: Text(demoServer ? l10n.serverBuiltIn : ref.watch(serverAddressProvider)),
                    trailing: demoServer ? null : Icon(Icons.chevron_right_rounded, color: palette.inkSubtle),
                    onTap: demoServer
                        ? null
                        : () async {
                            final saved = await showDialog<String>(
                              context: context,
                              builder: (_) => const ServerDialog(),
                            );
                            if (saved != null && context.mounted) showMessage(context, l10n.serverSaved);
                          },
                  ),
                ],
              ),
            ),
            const SizedBox(height: Layout.section),
            Panel(
              color: palette.surfaceMuted,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.lock_rounded, color: palette.brand),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l10n.profilePrivacy, style: textTheme.bodyMedium),
                        const SizedBox(height: 8),
                        Text(l10n.disclaimer, style: textTheme.bodySmall),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: Layout.gap),
            OutlinedButton.icon(
              key: const Key('delete-all'),
              style: OutlinedButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
              icon: const Icon(Icons.delete_forever_rounded),
              label: Text(l10n.profileDeleteAll),
              onPressed: () => _confirmDelete(context, ref),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.profileDeleteConfirmTitle),
        content: Text(l10n.profileDeleteConfirmText),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: Text(l10n.cancel)),
          FilledButton(
            key: const Key('delete-confirm'),
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if (confirmed ?? false) await ref.read(profileProvider.notifier).deleteAllData();
  }
}
