import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/meal.dart';
import '../core/l10n_extensions.dart';
import '../core/session.dart';

class TargetSheet extends ConsumerStatefulWidget {
  const TargetSheet({super.key, required this.initial});

  final MealTarget initial;

  @override
  ConsumerState<TargetSheet> createState() => _TargetSheetState();
}

class _TargetSheetState extends ConsumerState<TargetSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _kcal = TextEditingController(text: widget.initial.kcal.round().toString());
  late final _tolerance = TextEditingController(text: widget.initial.kcalTolerance.round().toString());
  late final _protein = TextEditingController(text: widget.initial.minProtein.round().toString());
  late final _fat = TextEditingController(text: widget.initial.maxFat.round().toString());
  late final _carbs = TextEditingController(text: widget.initial.maxCarbs.round().toString());

  @override
  void dispose() {
    for (final controller in [_kcal, _tolerance, _protein, _fat, _carbs]) {
      controller.dispose();
    }
    super.dispose();
  }

  void _save() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    ref
        .read(mealSelectionProvider.notifier)
        .setCustomTarget(
          widget.initial.copyWith(
            kcal: double.parse(_kcal.text),
            kcalTolerance: double.parse(_tolerance.text),
            minProtein: double.parse(_protein.text),
            maxFat: double.parse(_fat.text),
            maxCarbs: double.parse(_carbs.text),
          ),
        );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: EdgeInsets.only(left: 16, right: 16, top: 16, bottom: MediaQuery.viewInsetsOf(context).bottom + 16),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l10n.targetSheetTitle, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              _field(const Key('target-kcal'), _kcal, l10n.kcalLabel, 100, 2000),
              _field(const Key('target-tolerance'), _tolerance, l10n.toleranceLabel, 10, 500),
              _field(const Key('target-protein'), _protein, l10n.proteinLabel, 0, 300),
              _field(const Key('target-fat'), _fat, l10n.fatLabel, 0, 300),
              _field(const Key('target-carbs'), _carbs, l10n.carbsLabel, 0, 500),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () {
                      ref.read(mealSelectionProvider.notifier).setCustomTarget(null);
                      Navigator.of(context).pop();
                    },
                    child: Text(l10n.resetTarget),
                  ),
                  FilledButton(key: const Key('target-save'), onPressed: _save, child: Text(l10n.save)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(Key key, TextEditingController controller, String label, int min, int max) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextFormField(
      key: key,
      controller: controller,
      decoration: InputDecoration(labelText: label),
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      validator: (text) {
        final value = int.tryParse(text ?? '');
        return value == null || value < min || value > max ? context.l10n.fieldOutOfRange(min, max) : null;
      },
    ),
  );
}
