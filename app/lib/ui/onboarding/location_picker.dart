import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/l10n_extensions.dart';
import '../core/widgets/district_field.dart';
import '../core/widgets/visuals.dart';
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
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const NearbyIllustration(),
              const SizedBox(height: 18),
              Text(l10n.locationHint, style: Theme.of(context).textTheme.bodyLarge),
              const SizedBox(height: 18),
              if (state.locationConsent)
                StatusPill(label: l10n.locationAllowed, tone: Tone.good, icon: Icons.check_circle_rounded)
              else
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    key: const Key('allow-location'),
                    onPressed: state.requestingLocation ? null : controller.requestLocation,
                    icon: const Icon(Icons.my_location_rounded),
                    label: Text(l10n.locationAllow),
                  ),
                ),
            ],
          ),
        ),
        if (state.locationFailure case final failure?)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(l10n.failure(failure), style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ),
        const SizedBox(height: 24),
        DistrictField(
          key: const Key('district-field'),
          value: state.district,
          onChanged: controller.setDistrict,
        ),
      ],
    );
  }
}
