import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/profile.dart';
import '../core/formatting.dart';
import '../core/l10n_extensions.dart';
import 'onboarding_view_model.dart';

class BodyParametersForm extends ConsumerWidget {
  const BodyParametersForm({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final state = ref.watch(onboardingProvider);
    final controller = ref.read(onboardingProvider.notifier);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.sexLabel, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        SegmentedButton<Sex>(
          segments: [
            ButtonSegment(value: Sex.female, label: Text(l10n.sexFemale)),
            ButtonSegment(value: Sex.male, label: Text(l10n.sexMale)),
          ],
          selected: {state.sex},
          onSelectionChanged: (selection) => controller.setSex(selection.first),
        ),
        const SizedBox(height: 16),
        _NumberField(
          fieldKey: const Key('age-field'),
          label: l10n.ageLabel,
          initial: state.age?.toString(),
          range: OnboardingState.ageRange,
          onChanged: (text) => controller.setBodyField(BodyField.age, text),
        ),
        _NumberField(
          fieldKey: const Key('height-field'),
          label: l10n.heightLabel,
          initial: state.heightCm?.toString(),
          range: OnboardingState.heightRange,
          onChanged: (text) => controller.setBodyField(BodyField.height, text),
        ),
        _NumberField(
          fieldKey: const Key('weight-field'),
          label: l10n.weightLabel,
          initial: state.weightKg == null ? null : Formatting.decimal(state.weightKg ?? 0),
          range: OnboardingState.weightRange,
          decimal: true,
          onChanged: (text) => controller.setBodyField(BodyField.weight, text),
        ),
        const SizedBox(height: 8),
        Text(l10n.activityLabel, style: Theme.of(context).textTheme.titleSmall),
        RadioGroup<ActivityLevel>(
          groupValue: state.activity,
          onChanged: (value) {
            if (value != null) controller.setActivity(value);
          },
          child: Column(
            children: [
              for (final level in ActivityLevel.values)
                RadioListTile<ActivityLevel>(
                  key: Key('activity-${level.name}'),
                  value: level,
                  title: Text(l10n.activity(level)),
                  contentPadding: EdgeInsets.zero,
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(l10n.goalLabel, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        SegmentedButton<Goal>(
          segments: [
            for (final goal in Goal.values)
              ButtonSegment(
                value: goal,
                label: Text(l10n.goal(goal), textAlign: TextAlign.center),
              ),
          ],
          selected: {state.goal},
          onSelectionChanged: (selection) => controller.setGoal(selection.first),
        ),
      ],
    );
  }
}

class _NumberField extends StatelessWidget {
  const _NumberField({
    required this.fieldKey,
    required this.label,
    required this.initial,
    required this.range,
    required this.onChanged,
    this.decimal = false,
  });

  final Key fieldKey;
  final String label;
  final String? initial;
  final ({int min, int max}) range;
  final ValueChanged<String> onChanged;
  final bool decimal;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextFormField(
      key: fieldKey,
      initialValue: initial,
      decoration: InputDecoration(labelText: label),
      keyboardType: TextInputType.numberWithOptions(decimal: decimal),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(decimal ? r'[0-9.,]' : r'[0-9]'))],
      autovalidateMode: AutovalidateMode.onUserInteraction,
      validator: (text) {
        final value = num.tryParse((text ?? '').replaceAll(',', '.'));
        if (value == null || value < range.min || value > range.max) {
          return context.l10n.fieldOutOfRange(range.min, range.max);
        }
        return null;
      },
      onChanged: onChanged,
    ),
  );
}
