import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/diet_preference.dart';
import '../core/l10n_extensions.dart';
import 'onboarding_view_model.dart';

class PreferencesPicker extends ConsumerWidget {
  const PreferencesPicker({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(onboardingProvider.select((state) => state.preferences));
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final preference in DietPreference.values)
          FilterChip(
            key: Key('preference-${preference.name}'),
            label: Text(context.l10n.preference(preference)),
            selected: selected.contains(preference),
            onSelected: (_) => ref.read(onboardingProvider.notifier).togglePreference(preference),
          ),
      ],
    );
  }
}
