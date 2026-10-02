import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/models/combo.dart';
import '../../routing/routes.dart';
import '../../utils/result.dart';
import '../core/formatting.dart';
import '../core/l10n_extensions.dart';
import '../core/layout.dart';
import '../core/messages.dart';
import '../core/theme.dart';
import '../core/widgets/busy_action.dart';
import '../core/widgets/nutrients_text.dart';
import '../core/widgets/state_views.dart';
import '../core/widgets/trust_badge.dart';
import '../core/widgets/visuals.dart';
import '../diary/diary_view_model.dart';
import 'combo_view_model.dart';
import 'selected_combo.dart';

class ComboScreen extends ConsumerWidget {
  const ComboScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final selected = ref.watch(selectedComboProvider);
    if (selected == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.comboTitle)),
        body: MessageView(message: l10n.searchPrompt),
      );
    }
    final option = selected.option;
    final combo = option.combo;
    return Scaffold(
      extendBody: true,
      appBar: AppBar(title: Text(l10n.comboTitle)),
      body: ListView(
        padding: Layout.page(context, top: 0).copyWith(bottom: 120 + MediaQuery.paddingOf(context).bottom),
        children: [
          _VenueHeader(option: option),
          const SizedBox(height: Layout.gap),
          _Summary(combo: combo, target: selected),
          const SizedBox(height: Layout.section),
          SectionTitle(title: l10n.comboDishes, trailing: '${combo.dishes.length}'),
          Panel(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              children: [
                for (final (index, dish) in combo.dishes.indexed) ...[
                  if (index > 0) const Divider(indent: 76, endIndent: 20),
                  _DishTile(index: index, dish: dish),
                ],
              ],
            ),
          ),
          const _Replacements(),
          const SizedBox(height: Layout.section),
          SectionTitle(title: l10n.comboChecks),
          Panel(
            child: Column(
              children: [
                for (final (index, check) in combo.checks.indexed) ...[
                  if (index > 0) const SizedBox(height: 18),
                  _CheckRow(check: check, tolerance: selected.target.kcalTolerance),
                ],
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: GlassSurface(
          padding: const EdgeInsets.all(8),
          child: BusyAction<void>(
            run: (_) async {
              final result = await ref.read(diaryActionsProvider).addCombo(selected);
              if (!context.mounted) return;
              switch (result) {
                case Ok():
                  showMessage(context, l10n.addedToDiary);
                  context.go(Routes.diary);
                case Err(:final failure):
                  showMessage(context, l10n.failure(failure));
              }
            },
            builder: (context, onPressed, busy) => FilledButton.icon(
              key: const Key('eat-combo'),
              icon: BusyAction.icon(Icons.check_rounded, busy: busy),
              label: Text(l10n.eatCombo),
              onPressed: onPressed,
            ),
          ),
        ),
      ),
    );
  }
}

class _VenueHeader extends StatelessWidget {
  const _VenueHeader({required this.option});

  final ComboOption option;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final palette = context.palette;
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(option.venue.name, style: textTheme.headlineSmall),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(option.venue.address, style: textTheme.bodyMedium?.copyWith(color: palette.inkMuted)),
              if (option.distanceMeters case final meters?)
                StatusPill(label: l10n.distanceMeters(meters), tone: Tone.neutral, icon: Icons.directions_walk_rounded),
            ],
          ),
          const SizedBox(height: 4),
          TextButton.icon(
            key: const Key('open-venue'),
            style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 4)),
            onPressed: () => context.push(Routes.venue(option.venue.id)),
            icon: const Icon(Icons.storefront_rounded, size: 18),
            label: Text(l10n.openVenue),
          ),
        ],
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.combo, required this.target});

  final Combo combo;
  final SelectedCombo target;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final palette = context.palette;
    final textTheme = Theme.of(context).textTheme;
    final totals = combo.totals;
    final onTarget = combo.checks.every((check) => check.status == MetricStatus.ok);
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Eyebrow(l10n.comboTotalLabel),
                    const SizedBox(height: 8),
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: Formatting.integer(totals.kcal),
                            style: textTheme.displaySmall?.copyWith(fontFeatures: AppFonts.tabular),
                          ),
                          TextSpan(
                            text: ' ${l10n.kcalUnit}',
                            style: textTheme.titleMedium?.copyWith(color: palette.inkMuted),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              StatusPill(
                label: onTarget ? l10n.fitOnTarget : l10n.fitCompromise,
                tone: onTarget ? Tone.good : Tone.warn,
                icon: onTarget ? Icons.check_circle_rounded : Icons.balance_rounded,
              ),
            ],
          ),
          const SizedBox(height: 16),
          MacroSplitBar(protein: totals.protein, fat: totals.fat, carbs: totals.carbs, height: 10),
          const SizedBox(height: 10),
          Semantics(
            label: l10n.comboTotalsSpoken(
              totals.kcal.round(),
              totals.protein.round(),
              totals.fat.round(),
              totals.carbs.round(),
            ),
            child: ExcludeSemantics(
              child: Wrap(
                spacing: 16,
                runSpacing: 6,
                children: [
                  MacroLegendValue(
                    label: l10n.proteinShort,
                    value: l10n.gramsValue(totals.protein.round()),
                    color: palette.protein,
                  ),
                  MacroLegendValue(
                    label: l10n.fatShort,
                    value: l10n.gramsValue(totals.fat.round()),
                    color: palette.fat,
                  ),
                  MacroLegendValue(
                    label: l10n.carbsShort,
                    value: l10n.gramsValue(totals.carbs.round()),
                    color: palette.carbs,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Wrap(
                  spacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(l10n.comboTrustLabel, style: textTheme.labelMedium?.copyWith(color: palette.inkMuted)),
                    TrustBadge(kind: combo.sourceKind),
                  ],
                ),
              ),
              Text(
                l10n.priceOf(combo.priceMinor),
                style: textTheme.titleLarge?.copyWith(fontFeatures: AppFonts.tabular),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DishTile extends ConsumerWidget {
  const _DishTile({required this.index, required this.dish});

  final int index;
  final Dish dish;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final textTheme = Theme.of(context).textTheme;
    final nutrients = dish.nutrients;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DishAvatar(category: dish.category, name: dish.name),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(dish.name, style: textTheme.titleSmall),
                const SizedBox(height: 2),
                NutrientsText(
                  kcal: nutrients.kcal,
                  protein: nutrients.protein,
                  fat: nutrients.fat,
                  carbs: nutrients.carbs,
                  style: textTheme.bodySmall,
                ),
                const SizedBox(height: 6),
                TrustBadge(kind: dish.sourceKind),
              ],
            ),
          ),
          TextButton(
            key: Key('replace-$index'),
            onPressed: () => ref.read(replacementProvider.notifier).load(index),
            child: Text(l10n.replaceDish, semanticsLabel: l10n.replaceDishTooltip(dish.name)),
          ),
        ],
      ),
    );
  }
}

class _Replacements extends ConsumerWidget {
  const _Replacements();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final palette = context.palette;
    final textTheme = Theme.of(context).textTheme;
    final controller = ref.read(replacementProvider.notifier);
    final content = switch (ref.watch(replacementProvider)) {
      ReplacementIdle() => null,
      ReplacementLoading() => const LoadingView(),
      ReplacementFailed(:final index, :final failure) => FailureView(
        failure: failure,
        onRetry: () => controller.load(index),
      ),
      ReplacementOptions(:final options) when options.isEmpty => MessageView(message: l10n.noReplacements),
      ReplacementOptions(:final options) => RevealOnAppear(
        child: Panel(
          key: const Key('replacements'),
          color: palette.brandSoft,
          padding: const EdgeInsets.fromLTRB(20, 12, 8, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(child: Text(l10n.replacementsTitle, style: textTheme.titleMedium)),
                  IconButton(tooltip: l10n.close, icon: const Icon(Icons.close_rounded), onPressed: controller.dismiss),
                ],
              ),
              for (final option in options)
                ListTile(
                  contentPadding: const EdgeInsets.only(right: 12),
                  leading: DishAvatar(
                    category: _newDish(ref, option).category,
                    name: _newDishName(ref, option),
                    size: 40,
                  ),
                  title: Text(_newDishName(ref, option), style: textTheme.titleSmall),
                  subtitle: NutrientsText(
                    prefix: l10n.replacementTotalPrefix,
                    kcal: option.combo.totals.kcal,
                    protein: option.combo.totals.protein,
                    fat: option.combo.totals.fat,
                    carbs: option.combo.totals.carbs,
                    style: textTheme.bodySmall,
                  ),
                  trailing: Icon(Icons.swap_horiz_rounded, color: palette.brand),
                  onTap: () => controller.choose(option),
                ),
            ],
          ),
        ),
      ),
    };
    if (content == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: Layout.gap),
      child: content,
    );
  }
}

List<Dish> _addedDishes(WidgetRef ref, ComboOption option) {
  final current = {for (final dish in ref.read(selectedComboProvider)?.option.combo.dishes ?? const <Dish>[]) dish.id};
  final added = option.combo.dishes.where((dish) => !current.contains(dish.id)).toList();
  return added.isEmpty ? option.combo.dishes : added;
}

Dish _newDish(WidgetRef ref, ComboOption option) => _addedDishes(ref, option).first;

String _newDishName(WidgetRef ref, ComboOption option) =>
    _addedDishes(ref, option).map((dish) => dish.name).join(' + ');

class _CheckRow extends StatelessWidget {
  const _CheckRow({required this.check, required this.tolerance});

  final MetricCheck check;
  final double tolerance;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final palette = context.palette;
    final textTheme = Theme.of(context).textTheme;
    final value = check.value.round();
    final goal = check.goal.round();
    final (label, color, kind) = switch (check.metric) {
      Metric.kcal => (l10n.checkKcal(value, goal), palette.brand, GaugeKind.window),
      Metric.protein => (l10n.checkProtein(value, goal), palette.protein, GaugeKind.atLeast),
      Metric.fat => (l10n.checkFat(value, goal), palette.fat, GaugeKind.atMost),
      Metric.carbs => (l10n.checkCarbs(value, goal), palette.carbs, GaugeKind.atMost),
      Metric.unknown => ('', palette.neutral, GaugeKind.atMost),
    };
    final amount = check.delta.abs().round();
    final (status, tone) = switch (check.status) {
      MetricStatus.ok => (l10n.checkOk, Tone.good),
      MetricStatus.above => (l10n.checkAbove(amount), Tone.warn),
      MetricStatus.below => (l10n.checkBelow(amount), Tone.warn),
      MetricStatus.unknown => ('', Tone.neutral),
    };
    if (label.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: Text(label, style: textTheme.titleSmall)),
            const SizedBox(width: 8),
            StatusPill(label: status, tone: tone),
          ],
        ),
        const SizedBox(height: 8),
        TargetGauge(
          value: check.value,
          goal: check.goal,
          tolerance: check.metric == Metric.kcal ? tolerance : 0,
          kind: kind,
          color: color,
        ),
      ],
    );
  }
}
