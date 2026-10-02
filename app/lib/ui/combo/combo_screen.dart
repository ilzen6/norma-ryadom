import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/models/combo.dart';
import '../../routing/routes.dart';
import '../core/l10n_extensions.dart';
import '../core/messages.dart';
import '../core/theme.dart';
import '../core/widgets/state_views.dart';
import '../core/widgets/trust_badge.dart';
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
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.comboTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(option.venue.name, style: textTheme.titleLarge),
            Text(option.venue.address),
            if (option.distanceMeters case final meters?) Text(l10n.distanceMeters(meters)),
            TextButton.icon(
              key: const Key('open-venue'),
              onPressed: () => context.push(Routes.venue(option.venue.id)),
              icon: const Icon(Icons.storefront),
              label: Text(l10n.openVenue),
            ),
            const SizedBox(height: 8),
            for (final (index, dish) in combo.dishes.indexed) _DishTile(index: index, dish: dish),
            const _Replacements(),
            const SizedBox(height: 16),
            Text(l10n.comboChecks, style: textTheme.titleMedium),
            for (final check in combo.checks) _CheckRow(check: check),
            const SizedBox(height: 8),
            Text(l10n.priceOf(combo.priceMinor), style: textTheme.titleSmall),
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(l10n.comboTrustLabel),
                TrustBadge(kind: combo.sourceKind),
              ],
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton.icon(
            key: const Key('eat-combo'),
            icon: const Icon(Icons.check),
            label: Text(l10n.eatCombo),
            onPressed: () async {
              await ref.read(diaryActionsProvider).addCombo(selected);
              if (!context.mounted) return;
              showMessage(context, l10n.addedToDiary);
              context.go(Routes.diary);
            },
          ),
        ),
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
    final nutrients = dish.nutrients;
    return Card(
      child: ListTile(
        title: Text(dish.name),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.comboTotals(
                nutrients.kcal.round(),
                nutrients.protein.round(),
                nutrients.fat.round(),
                nutrients.carbs.round(),
              ),
            ),
            TrustBadge(kind: dish.sourceKind),
          ],
        ),
        trailing: TextButton(
          key: Key('replace-$index'),
          onPressed: () => ref.read(replacementProvider.notifier).load(index),
          child: Text(l10n.replaceDish, semanticsLabel: l10n.replaceDishTooltip(dish.name)),
        ),
      ),
    );
  }
}

class _Replacements extends ConsumerWidget {
  const _Replacements();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final controller = ref.read(replacementProvider.notifier);
    return switch (ref.watch(replacementProvider)) {
      ReplacementIdle() => const SizedBox.shrink(),
      ReplacementLoading() => const LoadingView(),
      ReplacementFailed(:final index, :final failure) => FailureView(
        failure: failure,
        onRetry: () => controller.load(index),
      ),
      ReplacementOptions(:final options) when options.isEmpty => MessageView(message: l10n.noReplacements),
      ReplacementOptions(:final options) => Card(
        key: const Key('replacements'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListTile(
              title: Text(l10n.replacementsTitle),
              trailing: IconButton(tooltip: l10n.close, icon: const Icon(Icons.close), onPressed: controller.dismiss),
            ),
            for (final option in options)
              ListTile(
                title: Text(_newDishName(ref, option)),
                subtitle: Text(
                  l10n.comboTotals(
                    option.combo.totals.kcal.round(),
                    option.combo.totals.protein.round(),
                    option.combo.totals.fat.round(),
                    option.combo.totals.carbs.round(),
                  ),
                ),
                onTap: () => controller.choose(option),
              ),
          ],
        ),
      ),
    };
  }
}

String _newDishName(WidgetRef ref, ComboOption option) {
  final current = {for (final dish in ref.read(selectedComboProvider)?.option.combo.dishes ?? const <Dish>[]) dish.id};
  final added = option.combo.dishes.where((dish) => !current.contains(dish.id));
  return (added.isEmpty ? option.combo.dishes : added).map((dish) => dish.name).join(' + ');
}

class _CheckRow extends StatelessWidget {
  const _CheckRow({required this.check});

  final MetricCheck check;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final value = check.value.round();
    final goal = check.goal.round();
    final label = switch (check.metric) {
      Metric.kcal => l10n.checkKcal(value, goal),
      Metric.protein => l10n.checkProtein(value, goal),
      Metric.fat => l10n.checkFat(value, goal),
      Metric.carbs => l10n.checkCarbs(value, goal),
      Metric.unknown => '',
    };
    final amount = check.delta.abs().round();
    final (status, color, icon) = switch (check.status) {
      MetricStatus.ok => (l10n.checkOk, AppColors.good, Icons.check_circle),
      MetricStatus.above => (l10n.checkAbove(amount), AppColors.compromise, Icons.arrow_upward),
      MetricStatus.below => (l10n.checkBelow(amount), AppColors.compromise, Icons.arrow_downward),
      MetricStatus.unknown => ('', AppColors.none, Icons.help_outline),
    };
    if (label.isEmpty) return const SizedBox.shrink();
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: color),
      title: Text(label),
      trailing: Text(status, style: TextStyle(color: color)),
    );
  }
}
