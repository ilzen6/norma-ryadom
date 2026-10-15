import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/diary.dart';
import '../../domain/models/meal.dart';
import '../../domain/models/nutrition_norm.dart';
import '../../utils/result.dart';
import '../core/l10n_extensions.dart';
import '../core/messages.dart';
import '../core/session.dart';
import 'diary_view_model.dart';

class ManualEntrySheet extends ConsumerStatefulWidget {
  const ManualEntrySheet({super.key});

  static const maxKcal = 5000;
  static const maxGrams = 1000;

  static Future<void> show(BuildContext context) => showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => const ManualEntrySheet(),
  );

  @override
  ConsumerState<ManualEntrySheet> createState() => _ManualEntrySheetState();
}

class _ManualEntrySheetState extends ConsumerState<ManualEntrySheet> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _kcal = TextEditingController();
  final _protein = TextEditingController();
  final _fat = TextEditingController();
  final _carbs = TextEditingController();
  late MealType _meal = ref.read(mealSelectionProvider).meal;
  bool _saving = false;

  @override
  void dispose() {
    for (final controller in [_title, _kcal, _protein, _fat, _carbs]) {
      controller.dispose();
    }
    super.dispose();
  }

  double _grams(TextEditingController controller) => double.tryParse(controller.text) ?? 0;

  Future<void> _save() async {
    if (_saving || !(_formKey.currentState?.validate() ?? false)) return;
    final l10n = context.l10n;
    final title = _title.text.trim();
    setState(() => _saving = true);
    final result = await ref
        .read(diaryActionsProvider)
        .addManual(
          NewDiaryEntry(
            meal: _meal,
            title: title.isEmpty ? l10n.diaryManualDefaultName : title,
            intake: Intake(
              kcal: double.parse(_kcal.text),
              protein: _grams(_protein),
              fat: _grams(_fat),
              carbs: _grams(_carbs),
            ),
          ),
        );
    if (!mounted) return;
    setState(() => _saving = false);
    switch (result) {
      case Ok():
        Navigator.of(context).pop();
      case Err(:final failure):
        showMessage(context, l10n.failure(failure));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 0, 24, 24 + MediaQuery.viewInsetsOf(context).bottom),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l10n.diaryManualTitle, style: textTheme.titleLarge),
              const SizedBox(height: 6),
              Text(l10n.diaryManualHint, style: textTheme.bodyMedium),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final meal in MealType.values)
                    ChoiceChip(
                      key: Key('manual-meal-${meal.name}'),
                      label: Text(l10n.meal(meal)),
                      selected: meal == _meal,
                      onSelected: (_) => setState(() => _meal = meal),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              TextFormField(
                key: const Key('manual-title'),
                controller: _title,
                decoration: InputDecoration(labelText: l10n.diaryManualName),
                textCapitalization: TextCapitalization.sentences,
                maxLength: 80,
              ),
              _number(_kcal, l10n.kcalLabel, const Key('manual-kcal'), ManualEntrySheet.maxKcal, required: true),
              _number(_protein, l10n.proteinLabel, const Key('manual-protein'), ManualEntrySheet.maxGrams),
              _number(_fat, l10n.fatLabel, const Key('manual-fat'), ManualEntrySheet.maxGrams),
              _number(_carbs, l10n.carbsLabel, const Key('manual-carbs'), ManualEntrySheet.maxGrams),
              const SizedBox(height: 8),
              FilledButton(
                key: const Key('manual-save'),
                onPressed: _saving ? null : _save,
                child: Text(l10n.save),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _number(TextEditingController controller, String label, Key key, int max, {bool required = false}) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: TextFormField(
      key: key,
      controller: controller,
      decoration: InputDecoration(labelText: label),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d{0,4}([.,]\d?)?'))],
      onChanged: (text) {
        if (text.contains(',')) {
          controller.value = controller.value.copyWith(text: text.replaceAll(',', '.'));
        }
      },
      validator: (text) {
        final value = double.tryParse(text ?? '');
        if (value == null) return required ? context.l10n.fieldOutOfRange(1, max) : null;
        final min = required ? 1 : 0;
        return value < min || value > max ? context.l10n.fieldOutOfRange(min, max) : null;
      },
    ),
  );
}
