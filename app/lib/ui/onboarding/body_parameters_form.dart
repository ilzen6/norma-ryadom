import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/profile.dart';
import '../core/formatting.dart';
import '../core/l10n_extensions.dart';
import '../core/widgets/visuals.dart';
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
        _Label(l10n.sexLabel),
        Row(
          children: [
            for (final (index, (sex, label, icon)) in [
              (Sex.female, l10n.sexFemale, Icons.female_rounded),
              (Sex.male, l10n.sexMale, Icons.male_rounded),
            ].indexed) ...[
              if (index > 0) const SizedBox(width: 10),
              Expanded(
                child: ChoiceCard(
                  label: label,
                  icon: icon,
                  selected: state.sex == sex,
                  onTap: () => controller.setSex(sex),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 20),
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
        _Label(l10n.activityLabel),
        RadioGroup<ActivityLevel>(
          groupValue: state.activity,
          onChanged: (value) {
            if (value != null) controller.setActivity(value);
          },
          child: Panel(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: [
                for (final (index, level) in ActivityLevel.values.indexed) ...[
                  if (index > 0) const Divider(indent: 56, endIndent: 16),
                  RadioListTile<ActivityLevel>(
                    key: Key('activity-${level.name}'),
                    value: level,
                    title: Text(l10n.activity(level)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        _Label(l10n.goalLabel),
        for (final (index, goal) in Goal.values.indexed) ...[
          if (index > 0) const SizedBox(height: 8),
          ChoiceCard(
            horizontal: true,
            label: l10n.goal(goal),
            subtitle: switch (goal) {
              Goal.lose => l10n.goalHintLose,
              Goal.maintain => l10n.goalHintMaintain,
              Goal.gain => l10n.goalHintGain,
            },
            icon: switch (goal) {
              Goal.lose => Icons.trending_down_rounded,
              Goal.maintain => Icons.trending_flat_rounded,
              Goal.gain => Icons.trending_up_rounded,
            },
            selected: state.goal == goal,
            onTap: () => controller.setGoal(goal),
          ),
        ],
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

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 4, bottom: 10),
    child: Text(text, style: Theme.of(context).textTheme.titleMedium),
  );
}
