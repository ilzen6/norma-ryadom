import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/services/norma_api.dart';
import '../../domain/models/geo_location.dart';
import '../../domain/models/meal.dart';
import '../../routing/routes.dart';
import '../core/formatting.dart';
import '../core/l10n_extensions.dart';
import '../core/layout.dart';
import '../core/session.dart';
import '../core/theme.dart';
import '../core/widgets/combo_card.dart';
import '../core/widgets/state_views.dart';
import '../core/widgets/visuals.dart';
import 'home_view_model.dart';
import 'target_sheet.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final today = ref.watch(currentDayProvider);
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: Layout.page(context),
          children: [
            ScreenHeader(eyebrow: Formatting.longDate(today), title: l10n.navHome),
            const _RemainingHero(),
            const SizedBox(height: Layout.gap),
            const _MealSelector(),
            const SizedBox(height: Layout.gap),
            const _TargetPanel(),
            const SizedBox(height: Layout.gap),
            const _SearchControls(),
            const SizedBox(height: Layout.section),
            const _SearchResults(),
            const SizedBox(height: Layout.section),
            Text(l10n.disclaimer, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _RemainingHero extends ConsumerWidget {
  const _RemainingHero();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final palette = context.palette;
    final textTheme = Theme.of(context).textTheme;
    final summary = ref.watch(daySummaryProvider);
    if (summary == null) return const LoadingView();
    final remaining = summary.remaining;
    final norm = summary.norm;
    final eaten = summary.eaten;
    final label = remaining.kcal > 0
        ? l10n.remainingSummary(remaining.kcal, remaining.protein < 0 ? 0 : remaining.protein)
        : l10n.overNorm;
    double share(double value, int goal) => goal <= 0 ? 0 : value / goal;
    final onHero = palette.onBrand;
    return Semantics(
      key: const Key('remaining-card'),
      container: true,
      label: '${l10n.remainingTitle}: $label',
      child: ExcludeSemantics(
        child: Panel(
          gradient: heroGradient(palette),
          padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Eyebrow(l10n.remainingTitle, color: onHero.withValues(alpha: 0.8)),
                        const SizedBox(height: 10),
                        if (remaining.kcal > 0) ...[
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: AnimatedNumber(
                              value: remaining.kcal.toDouble(),
                              key: const Key('remaining-summary'),
                              style: textTheme.displayMedium?.copyWith(color: onHero, fontFeatures: AppFonts.tabular),
                            ),
                          ),
                          Text(
                            l10n.kcalUnit,
                            style: textTheme.titleMedium?.copyWith(color: onHero.withValues(alpha: 0.85)),
                          ),
                        ] else
                          Text(
                            l10n.overNorm,
                            key: const Key('remaining-summary'),
                            style: textTheme.headlineSmall?.copyWith(color: onHero),
                          ),
                        const SizedBox(height: 8),
                        Text(
                          l10n.eatenOfNorm(eaten.kcal.round(), norm.kcal),
                          style: textTheme.bodySmall?.copyWith(color: onHero.withValues(alpha: 0.8)),
                        ),
                      ],
                    ),
                  ),
                  ProgressRings(
                    size: 104,
                    stroke: 12,
                    rings: [RingSpec(value: share(eaten.kcal, norm.kcal), color: onHero)],
                    center: Text(
                      '${(share(eaten.kcal, norm.kcal) * 100).clamp(0, 999).round()}%',
                      style: textTheme.titleMedium?.copyWith(
                        color: onHero,
                        fontFamily: AppFonts.display,
                        fontFeatures: AppFonts.tabular,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 22,
                runSpacing: 8,
                children: [
                  for (final (short, value, color) in [
                    (l10n.proteinShort, remaining.protein, palette.protein),
                    (l10n.fatShort, remaining.fat, palette.fat),
                    (l10n.carbsShort, remaining.carbs, palette.carbs),
                  ])
                    _HeroMacro(
                      short: short,
                      value: l10n.gramsValue(value < 0 ? 0 : value),
                      dot: _onBrandTint(color, onHero),
                      textColor: onHero,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Color _onBrandTint(Color color, Color onHero) => Color.lerp(color, onHero, 0.45) ?? color;
}

class _HeroMacro extends StatelessWidget {
  const _HeroMacro({required this.short, required this.value, required this.dot, required this.textColor});

  final String short;
  final String value;
  final Color dot;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(short, style: textTheme.labelMedium?.copyWith(color: textColor.withValues(alpha: 0.75))),
        const SizedBox(width: 6),
        Text(
          value,
          style: textTheme.titleSmall?.copyWith(color: textColor, fontFeatures: AppFonts.tabular),
        ),
      ],
    );
  }
}

class _MealSelector extends ConsumerWidget {
  const _MealSelector();

  static IconData iconOf(MealType meal) => switch (meal) {
    MealType.breakfast => Icons.wb_twilight_rounded,
    MealType.lunch => Icons.wb_sunny_rounded,
    MealType.dinner => Icons.nights_stay_rounded,
    MealType.snack => Icons.cookie_rounded,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final palette = context.palette;
    final selected = ref.watch(mealSelectionProvider).meal;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: ShapeDecoration(color: palette.surfaceMuted, shape: const StadiumBorder()),
      child: Row(
        children: [
          for (final meal in MealType.values)
            Expanded(
              child: Semantics(
                selected: meal == selected,
                button: true,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    ref.read(mealSelectionProvider.notifier).selectMeal(meal);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    constraints: const BoxConstraints(minHeight: 56),
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                    decoration: ShapeDecoration(
                      color: meal == selected ? palette.surface : Colors.transparent,
                      shape: const StadiumBorder(),
                      shadows: meal == selected
                          ? [
                              BoxShadow(
                                color: palette.ink.withValues(alpha: 0.08),
                                blurRadius: 12,
                                offset: const Offset(0, 3),
                              ),
                            ]
                          : const [],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(iconOf(meal), size: 18, color: meal == selected ? palette.brand : palette.inkMuted),
                        const SizedBox(height: 2),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            l10n.meal(meal),
                            key: Key('meal-${meal.name}'),
                            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                              color: meal == selected ? palette.ink : palette.inkMuted,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _TargetPanel extends ConsumerWidget {
  const _TargetPanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final palette = context.palette;
    final textTheme = Theme.of(context).textTheme;
    final target = ref.watch(currentTargetProvider);
    final meal = ref.watch(mealSelectionProvider).meal;
    if (target == null) return const SizedBox.shrink();
    final summary = l10n.targetSummary(
      target.kcal.round(),
      target.kcalTolerance.round(),
      target.minProtein.round(),
      target.maxFat.round(),
      target.maxCarbs.round(),
    );
    return Panel(
      padding: const EdgeInsets.fromLTRB(20, 18, 12, 18),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              key: const Key('target-summary'),
              label: summary,
              child: ExcludeSemantics(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Eyebrow(l10n.targetFor(l10n.meal(meal).toLowerCase())),
                    const SizedBox(height: 6),
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: '≈ ${Formatting.integer(target.kcal)} ',
                            style: textTheme.headlineSmall?.copyWith(fontFeatures: AppFonts.tabular),
                          ),
                          TextSpan(
                            text: l10n.targetTolerance(target.kcalTolerance.round()),
                            style: textTheme.titleSmall?.copyWith(color: palette.inkMuted),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _LimitChip(text: l10n.targetProteinMin(target.minProtein.round()), color: palette.protein),
                        _LimitChip(text: l10n.targetFatMax(target.maxFat.round()), color: palette.fat),
                        _LimitChip(text: l10n.targetCarbsMax(target.maxCarbs.round()), color: palette.carbs),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          IconButton.filledTonal(
            key: const Key('edit-target'),
            tooltip: l10n.editTarget,
            icon: const Icon(Icons.tune_rounded),
            onPressed: () => showModalBottomSheet<void>(
              context: context,
              useRootNavigator: true,
              isScrollControlled: true,
              builder: (_) => TargetSheet(initial: target),
            ),
          ),
        ],
      ),
    );
  }
}

class _LimitChip extends StatelessWidget {
  const _LimitChip({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: ShapeDecoration(color: color.withValues(alpha: 0.12), shape: const StadiumBorder()),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      child: Text(text, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: context.palette.ink)),
    ),
  );
}

class _SearchControls extends ConsumerWidget {
  const _SearchControls();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final palette = context.palette;
    final textTheme = Theme.of(context).textTheme;
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
        Row(
          children: [
            if (locationLabel != null)
              Expanded(
                child: Row(
                  children: [
                    Icon(Icons.near_me_rounded, size: 18, color: palette.brand),
                    const SizedBox(width: 6),
                    Flexible(child: Text(locationLabel, style: textTheme.labelLarge)),
                  ],
                ),
              )
            else
              const Spacer(),
            MergeSemantics(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(l10n.preferCheaper, style: textTheme.labelLarge),
                  const SizedBox(width: 4),
                  Switch(
                    key: const Key('prefer-cheaper'),
                    value: selection.price == PricePreference.cheaper,
                    onChanged: (cheaper) => ref
                        .read(mealSelectionProvider.notifier)
                        .setPrice(cheaper ? PricePreference.cheaper : PricePreference.any),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (location?.notice case final notice?)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(l10n.failure(notice), style: textTheme.bodySmall),
          ),
        const SizedBox(height: 8),
        FilledButton.icon(
          key: const Key('find-nearby'),
          onPressed: running ? null : () => ref.read(nearbySearchProvider.notifier).search(),
          icon: running
              ? SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2.5, color: palette.onBrand),
                )
              : const Icon(Icons.auto_awesome_rounded),
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
      SearchIdle() => const _HowItWorks(),
      SearchRunning() => SkeletonCards(label: l10n.searchLoading),
      SearchFailed(:final failure) => FailureView(
        failure: failure,
        onRetry: () => ref.read(nearbySearchProvider.notifier).search(),
      ),
      SearchDone(:final result) when result.options.isEmpty => MessageView(
        message: l10n.noCombosNearby,
        icon: Icons.search_off_rounded,
      ),
      SearchDone(:final result) => Column(
        key: const Key('search-results'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionTitle(title: l10n.resultsTitle, trailing: '${result.options.length}'),
          for (final (index, option) in result.options.indexed) ...[
            Appear(
              index: index,
              child: ComboCard(
                option: option,
                onTap: () {
                  ref.read(nearbySearchProvider.notifier).open(option);
                  context.push(Routes.combo);
                },
              ),
            ),
            const SizedBox(height: Layout.gap),
          ],
        ],
      ),
    };
  }
}

class _HowItWorks extends StatelessWidget {
  const _HowItWorks();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final palette = context.palette;
    final textTheme = Theme.of(context).textTheme;
    final steps = [
      (Icons.wb_sunny_rounded, l10n.howStepMeal),
      (Icons.auto_awesome_rounded, l10n.howStepSearch),
      (Icons.menu_book_rounded, l10n.howStepDiary),
    ];
    return Panel(
      key: const Key('how-it-works'),
      color: palette.surface.withValues(alpha: 0.72),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Eyebrow(l10n.howTitle),
          const SizedBox(height: 16),
          for (final (index, (icon, text)) in steps.indexed) ...[
            if (index > 0) const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(color: palette.brandSoft, borderRadius: BorderRadius.circular(14)),
                  child: Icon(icon, size: 20, color: palette.brand),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: '${index + 1}. ',
                            style: textTheme.titleSmall?.copyWith(color: palette.brand),
                          ),
                          TextSpan(text: text),
                        ],
                      ),
                      style: textTheme.bodyMedium,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
