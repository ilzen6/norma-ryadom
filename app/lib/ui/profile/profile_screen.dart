import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/providers.dart';
import '../../domain/models/district.dart';
import '../../routing/routes.dart';
import '../core/formatting.dart';
import '../core/l10n_extensions.dart';
import '../core/messages.dart';
import '../core/session.dart';
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
    return Scaffold(
      appBar: AppBar(title: Text(l10n.profileTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: ListTile(
                title: Text(l10n.profileParams(profile.age, profile.heightCm, Formatting.decimal(profile.weightKg))),
                subtitle: Text('${l10n.activity(profile.activity)} · ${l10n.goal(profile.goal)}'),
                trailing: const Icon(Icons.edit),
                onTap: () => context.push(Routes.profileEdit),
              ),
            ),
            Card(
              child: ListTile(
                title: Text(l10n.normTitle),
                subtitle: Text(
                  '${l10n.kcalValue(norm.kcal)} · ${l10n.normMacros(norm.protein, norm.fat, norm.carbs)}'
                  '${profile.manualNorm != null ? ' · ${l10n.normManualHint}' : ''}',
                ),
              ),
            ),
            if (profile.preferences.isNotEmpty)
              Wrap(
                spacing: 8,
                children: [
                  for (final preference in profile.preferences) Chip(label: Text(l10n.preference(preference))),
                ],
              ),
            SwitchListTile(
              key: const Key('location-consent'),
              title: Text(l10n.profileLocationConsent),
              value: profile.locationConsent,
              onChanged: (consent) async {
                final failure = await controller.setLocationConsent(consent: consent);
                if (failure != null && context.mounted) showMessage(context, l10n.failure(failure));
              },
            ),
            DropdownButtonFormField<District>(
              initialValue: profile.district ?? District.moscowCity,
              decoration: InputDecoration(labelText: l10n.locationDistrictLabel),
              items: [
                for (final district in District.values)
                  DropdownMenuItem(value: district, child: Text(l10n.district(district))),
              ],
              onChanged: (district) async {
                if (district == null) return;
                await controller.save(profile.copyWith(district: district));
              },
            ),
            Card(
              child: ListTile(
                key: const Key('server-settings'),
                leading: const Icon(Icons.dns_outlined),
                title: Text(l10n.serverTitle),
                subtitle: Text(demoServer ? l10n.serverBuiltIn : ref.watch(serverAddressProvider)),
                trailing: demoServer ? null : const Icon(Icons.edit),
                onTap: demoServer
                    ? null
                    : () async {
                        final saved = await showDialog<String>(context: context, builder: (_) => const ServerDialog());
                        if (saved != null && context.mounted) showMessage(context, l10n.serverSaved);
                      },
              ),
            ),
            const SizedBox(height: 16),
            Text(l10n.profilePrivacy, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 8),
            Text(l10n.disclaimer, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              key: const Key('delete-all'),
              style: OutlinedButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
              icon: const Icon(Icons.delete_forever),
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
