import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/district.dart';
import '../core/l10n_extensions.dart';
import 'onboarding_view_model.dart';

class LocationPicker extends ConsumerWidget {
  const LocationPicker({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final state = ref.watch(onboardingProvider);
    final controller = ref.read(onboardingProvider.notifier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.locationHint),
        const SizedBox(height: 16),
        if (state.locationConsent)
          ListTile(
            leading: const Icon(Icons.my_location),
            title: Text(l10n.locationAllowed),
            contentPadding: EdgeInsets.zero,
          )
        else
          FilledButton.tonalIcon(
            key: const Key('allow-location'),
            onPressed: state.requestingLocation ? null : controller.requestLocation,
            icon: const Icon(Icons.my_location),
            label: Text(l10n.locationAllow),
          ),
        if (state.locationFailure case final failure?)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(l10n.failure(failure), style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
        const SizedBox(height: 24),
        DropdownButtonFormField<District>(
          key: const Key('district-field'),
          initialValue: state.district,
          decoration: InputDecoration(labelText: l10n.locationDistrictLabel),
          items: [
            for (final district in District.values)
              DropdownMenuItem(value: district, child: Text(l10n.district(district))),
          ],
          onChanged: (district) {
            if (district != null) controller.setDistrict(district);
          },
        ),
      ],
    );
  }
}
