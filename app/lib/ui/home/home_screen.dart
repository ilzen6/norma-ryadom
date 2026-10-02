import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/services/norma_api.dart';
import '../../domain/models/geo_location.dart';
import '../../domain/models/meal.dart';
import '../../routing/routes.dart';
import '../core/l10n_extensions.dart';
import '../core/session.dart';
import '../core/widgets/combo_card.dart';
import '../core/widgets/state_views.dart';
import 'home_view_model.dart';
import 'target_sheet.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.navHome)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const _RemainingCard(),
            const SizedBox(height: 16),
            const _MealSelector(),
            const SizedBox(height: 16),
            const _SearchControls(),
            const SizedBox(height: 8),
            const _SearchResults(),
            const SizedBox(height: 16),
            Text(l10n.disclaimer, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _RemainingCard extends ConsumerWidget {
  const _RemainingCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final summary = ref.watch(daySummaryProvider);
    if (summary == null) return const LoadingView();
    final remaining = summary.remaining;
    return Card(
      key: const Key('remaining-card'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.remainingTitle, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              remaining.kcal > 0
                  ? l10n.remainingSummary(remaining.kcal, remaining.protein < 0 ? 0 : remaining.protein)
                  : l10n.overNorm,
              key: const Key('remaining-summary'),
              style: Theme.of(context).textTheme.headlineSmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _MealSelector extends ConsumerWidget {
  const _MealSelector();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final selection = ref.watch(mealSelectionProvider);
    final target = ref.watch(currentTargetProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SegmentedButton<MealType>(
          showSelectedIcon: false,
          segments: [
            for (final meal in MealType.values)
              ButtonSegment(
                value: meal,
                label: Text(l10n.meal(meal), key: Key('meal-${meal.name}')),
              ),
          ],
          selected: {selection.meal},
          onSelectionChanged: (meals) => ref.read(mealSelectionProvider.notifier).selectMeal(meals.first),
        ),
        if (target != null)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              l10n.targetSummary(
                target.kcal.round(),
                target.kcalTolerance.round(),
                target.minProtein.round(),
                target.maxFat.round(),
                target.maxCarbs.round(),
              ),
              key: const Key('target-summary'),
            ),
            trailing: IconButton(
              key: const Key('edit-target'),
              tooltip: l10n.editTarget,
              icon: const Icon(Icons.tune),
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                builder: (_) => TargetSheet(initial: target),
              ),
            ),
          ),
      ],
    );
  }
}

class _SearchControls extends ConsumerWidget {
  const _SearchControls();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final selection = ref.watch(mealSelectionProvider);
    final location = ref.watch(locationProvider).value;
    final profile = ref.watch(profileProvider).value;
    final running = ref.watch(nearbySearchProvider) is SearchRunning;
    final locationLabel = switch ((location?.location.source, profile?.district)) {
      (LocationSource.device, _) => l10n.locationFromDevice,
      (_, final district?) => l10n.locationFromDistrict(l10n.district(district)),
      _ => null,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SwitchListTile(
          key: const Key('prefer-cheaper'),
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.preferCheaper),
          value: selection.price == PricePreference.cheaper,
          onChanged: (cheaper) => ref
              .read(mealSelectionProvider.notifier)
              .setPrice(cheaper ? PricePreference.cheaper : PricePreference.any),
        ),
        if (locationLabel != null) Text(locationLabel, style: Theme.of(context).textTheme.bodySmall),
        if (location?.notice case final notice?)
          Text(l10n.failure(notice), style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 8),
        FilledButton.icon(
          key: const Key('find-nearby'),
          onPressed: running ? null : () => ref.read(nearbySearchProvider.notifier).search(),
          icon: const Icon(Icons.search),
          label: Text(l10n.findNearby),
        ),
      ],
    );
  }
}

class _SearchResults extends ConsumerWidget {
  const _SearchResults();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return switch (ref.watch(nearbySearchProvider)) {
      SearchIdle() => MessageView(message: l10n.searchPrompt, icon: Icons.restaurant),
      SearchRunning() => const LoadingView(),
      SearchFailed(:final failure) => FailureView(
        failure: failure,
        onRetry: () => ref.read(nearbySearchProvider.notifier).search(),
      ),
      SearchDone(:final result) when result.options.isEmpty => MessageView(
        message: l10n.noCombosNearby,
        icon: Icons.search_off,
      ),
      SearchDone(:final result) => Column(
        key: const Key('search-results'),
        children: [
          for (final option in result.options)
            ComboCard(
              option: option,
              onTap: () {
                ref.read(nearbySearchProvider.notifier).open(option);
                context.push(Routes.combo);
              },
            ),
        ],
      ),
    };
  }
}
