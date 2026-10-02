import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/diet_preference.dart';
import '../core/l10n_extensions.dart';
import '../core/theme.dart';
import 'onboarding_view_model.dart';

class PreferencesPicker extends ConsumerWidget {
  const PreferencesPicker({super.key});

  static IconData iconOf(DietPreference preference) => switch (preference) {
    DietPreference.noPork => Icons.no_food_rounded,
    DietPreference.vegetarian => Icons.eco_rounded,
    DietPreference.noNuts => Icons.spa_rounded,
    DietPreference.noMilk => Icons.water_drop_rounded,
    DietPreference.noGluten => Icons.grain_rounded,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final selected = ref.watch(onboardingProvider.select((state) => state.preferences));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (index, preference) in DietPreference.values.indexed) ...[
          if (index > 0) const SizedBox(height: 8),
          _PreferenceTile(
            key: Key('preference-${preference.name}'),
            icon: iconOf(preference),
            label: l10n.preference(preference),
            hint: l10n.preferenceHint(preference),
            selected: selected.contains(preference),
            onTap: () {
              HapticFeedback.selectionClick();
              ref.read(onboardingProvider.notifier).togglePreference(preference);
            },
          ),
        ],
      ],
    );
  }
}

class _PreferenceTile extends StatelessWidget {
  const _PreferenceTile({
    super.key,
    required this.icon,
    required this.label,
    required this.hint,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String hint;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final textTheme = Theme.of(context).textTheme;
    return Semantics(
      checked: selected,
      label: label,
      hint: hint,
      excludeSemantics: true,
      onTap: onTap,
      child: Material(
        color: selected ? palette.brandSoft : palette.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.tile),
          side: BorderSide(color: selected ? palette.brand : palette.hairline, width: selected ? 2 : 1),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 16, 12),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: selected ? palette.brand : palette.surfaceMuted,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, size: 22, color: selected ? palette.onBrand : palette.inkMuted),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label, style: textTheme.titleSmall),
                      const SizedBox(height: 2),
                      Text(hint, style: textTheme.bodySmall?.copyWith(color: palette.inkMuted)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    selected ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
                    key: ValueKey(selected),
                    color: selected ? palette.brand : palette.inkSubtle,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
