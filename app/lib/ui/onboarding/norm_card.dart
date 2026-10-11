import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/nutrition_norm.dart';
import '../../domain/nutrition/norm_calculator.dart';
import '../core/l10n_extensions.dart';
import '../core/theme.dart';
import '../core/widgets/visuals.dart';
import 'onboarding_view_model.dart';

class NormCard extends ConsumerStatefulWidget {
  const NormCard({super.key});

  @override
  ConsumerState<NormCard> createState() => _NormCardState();
}

class _NormCardState extends ConsumerState<NormCard> {
  bool _editing = false;
  final _formKey = GlobalKey<FormState>();
  final _kcal = TextEditingController();
  final _protein = TextEditingController();
  final _fat = TextEditingController();
  final _carbs = TextEditingController();

  @override
  void dispose() {
    _kcal.dispose();
    _protein.dispose();
    _fat.dispose();
    _carbs.dispose();
    super.dispose();
  }

  void _startEditing(NutritionNorm norm) {
    final split = norm.split;
    _kcal.text = '${norm.kcal}';
    _protein.text = '${split.protein}';
    _fat.text = '${split.fat}';
    _carbs.text = '${100 - split.protein - split.fat}';
    setState(() => _editing = true);
  }

  int? _value(TextEditingController controller) => int.tryParse(controller.text);

  MacroSplit get _split =>
      MacroSplit(protein: _value(_protein) ?? 0, fat: _value(_fat) ?? 0, carbs: _value(_carbs) ?? 0);

  void _applyManual() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final applied = ref.read(onboardingProvider.notifier).setManualNorm(_split.normFor(int.parse(_kcal.text)));
    if (applied) setState(() => _editing = false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final calculation = ref.watch(normPreviewProvider);
    final state = ref.watch(onboardingProvider);
    if (calculation == null) return const SizedBox.shrink();
    final norm = state.manualNorm ?? calculation.norm;
    final textTheme = Theme.of(context).textTheme;
    final palette = context.palette;
    return Panel(
      key: const Key('norm-card'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Eyebrow(l10n.normTitle),
          const SizedBox(height: 10),
          Text(
            l10n.kcalValue(norm.kcal),
            key: const Key('norm-kcal'),
            style: textTheme.displaySmall?.copyWith(fontFeatures: AppFonts.tabular),
          ),
          const SizedBox(height: 14),
          MacroSplitBar(
            protein: norm.protein.toDouble(),
            fat: norm.fat.toDouble(),
            carbs: norm.carbs.toDouble(),
            height: 10,
          ),
          const SizedBox(height: 10),
          Text(l10n.normMacros(norm.protein, norm.fat, norm.carbs), style: textTheme.titleSmall),
          const SizedBox(height: 4),
          Text(
            l10n.normShares(norm.split.protein, norm.split.fat, norm.split.carbs),
            key: const Key('norm-shares'),
            style: textTheme.bodySmall?.copyWith(color: palette.inkMuted),
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: palette.surfaceMuted,
              borderRadius: BorderRadius.circular(AppRadii.control),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (state.manualNorm == null)
                  Text(
                    l10n.normExplanation(calculation.bmr.round(), calculation.tdee.round(), calculation.norm.kcal),
                    style: textTheme.bodySmall,
                  )
                else
                  Text(l10n.normManualHint, style: textTheme.bodySmall),
                if (calculation.limitedBySafeMinimum && state.manualNorm == null)
                  Text(l10n.normSafeMinimum(NormCalculator.safeMinimumKcal(state.sex)), style: textTheme.bodySmall),
              ],
            ),
          ),
          const SizedBox(height: 8),
          if (_editing) _manualForm(context) else _actions(context, norm),
          const SizedBox(height: 4),
          Text(l10n.disclaimer, style: textTheme.bodySmall),
        ],
      ),
    );
  }

  Widget _actions(BuildContext context, NutritionNorm norm) {
    final l10n = context.l10n;
    final manual = ref.watch(onboardingProvider.select((state) => state.manualNorm != null));
    return Wrap(
      spacing: 8,
      children: [
        TextButton(onPressed: () => _startEditing(norm), child: Text(l10n.normEditManually)),
        if (manual)
          TextButton(
            onPressed: () => ref.read(onboardingProvider.notifier).setManualNorm(null),
            child: Text(l10n.normUseCalculated),
          ),
      ],
    );
  }

  Widget _manualForm(BuildContext context) {
    final l10n = context.l10n;
    final safeMinimum = NormCalculator.safeMinimumKcal(ref.watch(onboardingProvider).sex);
    return Form(
      key: _formKey,
      child: ListenableBuilder(
        listenable: Listenable.merge([_kcal, _protein, _fat, _carbs]),
        builder: (context, _) => Column(
          children: [
            const SizedBox(height: 12),
            _field(
              _kcal,
              l10n.kcalLabel,
              (value) => value < safeMinimum ? l10n.normBelowSafeMinimum(safeMinimum) : null,
              key: const Key('norm-manual-kcal'),
            ),
            _shareField(_protein, l10n.proteinShareLabel, (norm) => norm.protein, const Key('norm-manual-protein')),
            _shareField(_fat, l10n.fatShareLabel, (norm) => norm.fat, const Key('norm-manual-fat')),
            _shareField(
              _carbs,
              l10n.carbsShareLabel,
              (norm) => norm.carbs,
              const Key('norm-manual-carbs'),
              check: (_) => _split.total == 100 ? null : l10n.normSharesTotal(_split.total),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(onPressed: () => setState(() => _editing = false), child: Text(l10n.cancel)),
                FilledButton(onPressed: _applyManual, child: Text(l10n.save)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _shareField(
    TextEditingController controller,
    String label,
    int Function(NutritionNorm norm) grams,
    Key key, {
    String? Function(int value)? check,
  }) {
    final kcal = _value(_kcal);
    return _field(
      controller,
      label,
      (value) => value > 100 ? context.l10n.fieldOutOfRange(0, 100) : check?.call(value),
      key: key,
      helper: kcal == null || _value(controller) == null
          ? null
          : context.l10n.normShareGrams(grams(_split.normFor(kcal))),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label,
    String? Function(int value) check, {
    Key? key,
    String? helper,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: TextFormField(
      key: key,
      controller: controller,
      decoration: InputDecoration(labelText: label, helperText: helper),
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      validator: (text) {
        final value = int.tryParse(text ?? '');
        if (value == null) return context.l10n.fieldOutOfRange(0, 9999);
        return check(value);
      },
    ),
  );
}
