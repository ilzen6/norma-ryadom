import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/diary.dart';
import '../../domain/models/meal.dart';
import '../../utils/result.dart';
import '../core/formatting.dart';
import '../core/l10n_extensions.dart';
import '../core/layout.dart';
import '../core/messages.dart';
import '../core/session.dart';
import '../core/theme.dart';
import '../core/widgets/busy_action.dart';
import '../core/widgets/nutrient_progress.dart';
import '../core/widgets/nutrients_text.dart';
import '../core/widgets/state_views.dart';
import '../core/widgets/visuals.dart';
import 'diary_view_model.dart';

class DiaryScreen extends ConsumerWidget {
  const DiaryScreen({super.key});

  static IconData mealIcon(MealType meal) => switch (meal) {
    MealType.breakfast => Icons.wb_twilight_rounded,
    MealType.lunch => Icons.wb_sunny_rounded,
    MealType.dinner => Icons.nights_stay_rounded,
    MealType.snack => Icons.cookie_rounded,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final palette = context.palette;
    final summary = ref.watch(daySummaryProvider);
    final quickAdd = ref.watch(quickAddProvider).value ?? const <DiaryEntry>[];
    final day = ref.watch(currentDayProvider);
    if (summary == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.navDiary)),
        body: const LoadingView(),
      );
    }
    final eaten = summary.eaten;
    final norm = summary.norm;
    double share(double value, int goal) => goal <= 0 ? 0 : value / goal;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: Layout.page(context),
          children: [
            ScreenHeader(eyebrow: Formatting.longDate(day), title: l10n.diaryTitle),
            Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Eyebrow(l10n.diaryEaten),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      ProgressRings(
                        size: 116,
                        stroke: 10,
                        gap: 3,
                        rings: [
                          RingSpec(value: share(eaten.kcal, norm.kcal), color: palette.brand),
                          RingSpec(value: share(eaten.protein, norm.protein), color: palette.protein),
                          RingSpec(value: share(eaten.fat, norm.fat), color: palette.fat),
                          RingSpec(value: share(eaten.carbs, norm.carbs), color: palette.carbs),
                        ],
                      ),
                      const SizedBox(width: 18),
                      Expanded(
                        child: Column(
                          children: [
                            NutrientProgress(
                              label: l10n.kcalLabel,
                              eaten: eaten.kcal,
                              norm: norm.kcal,
                              color: palette.brand,
                            ),
                            NutrientProgress(
                              label: l10n.proteinLabel,
                              eaten: eaten.protein,
                              norm: norm.protein,
                              color: palette.protein,
                            ),
                            NutrientProgress(
                              label: l10n.fatLabel,
                              eaten: eaten.fat,
                              norm: norm.fat,
                              color: palette.fat,
                            ),
                            NutrientProgress(
                              label: l10n.carbsLabel,
                              eaten: eaten.carbs,
                              norm: norm.carbs,
                              color: palette.carbs,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: Layout.section),
            if (summary.entries.isEmpty)
              Panel(
                child: MessageView(message: l10n.diaryEmpty, icon: Icons.menu_book_rounded),
              ),
            for (final meal in MealType.values) ..._mealSection(context, ref, meal, summary.entries),
            if (quickAdd.isNotEmpty) ...[
              const SizedBox(height: Layout.section - Layout.gap),
              SectionTitle(title: l10n.diaryQuickAdd),
              Panel(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  children: [
                    for (final (index, entry) in quickAdd.indexed) ...[
                      if (index > 0) const Divider(indent: 68, endIndent: 16),
                      ListTile(
                        contentPadding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: entry.favorite ? palette.warnSoft : palette.surfaceMuted,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(
                            entry.favorite ? Icons.star_rounded : Icons.history_rounded,
                            color: entry.favorite ? palette.warn : palette.inkMuted,
                          ),
                        ),
                        title: Text(entry.title, style: Theme.of(context).textTheme.titleSmall),
                        subtitle: Text(l10n.kcalValue(entry.intake.kcal.round())),
                        trailing: BusyAction<void>(
                          run: (_) async {
                            final meal = ref.read(mealSelectionProvider).meal;
                            final result = await ref.read(diaryActionsProvider).addAgain(entry, meal);
                            if (result case Err(:final failure) when context.mounted) {
                              showMessage(context, l10n.failure(failure));
                            }
                          },
                          builder: (context, onPressed, busy) => IconButton.filledTonal(
                            tooltip: l10n.diaryAddAgain(entry.title),
                            icon: BusyAction.icon(Icons.add_rounded, busy: busy),
                            onPressed: onPressed,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  List<Widget> _mealSection(BuildContext context, WidgetRef ref, MealType meal, List<DiaryEntry> entries) {
    final l10n = context.l10n;
    final palette = context.palette;
    final textTheme = Theme.of(context).textTheme;
    final mealEntries = entries.where((entry) => entry.meal == meal).toList();
    if (mealEntries.isEmpty) return const [];
    final actions = ref.read(diaryActionsProvider);
    final mealKcal = mealEntries.fold<double>(0, (sum, entry) => sum + entry.intake.kcal);
    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
        child: Row(
          children: [
            Icon(mealIcon(meal), size: 20, color: palette.brand),
            const SizedBox(width: 8),
            Expanded(
              child: Semantics(header: true, child: Text(l10n.meal(meal), style: textTheme.titleLarge)),
            ),
            Text(
              l10n.kcalValue(mealKcal.round()),
              style: textTheme.labelLarge?.copyWith(color: palette.inkMuted, fontFeatures: AppFonts.tabular),
            ),
          ],
        ),
      ),
      for (final entry in mealEntries) ...[
        Panel(
          key: Key('diary-entry-${entry.id}'),
          padding: const EdgeInsets.fromLTRB(18, 16, 8, 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(entry.title, style: textTheme.titleSmall),
                    const SizedBox(height: 4),
                    NutrientsText(
                      prefix: entry.venueName,
                      kcal: entry.intake.kcal,
                      protein: entry.intake.protein,
                      fat: entry.intake.fat,
                      carbs: entry.intake.carbs,
                      style: textTheme.bodySmall,
                    ),
                    const SizedBox(height: 10),
                    MacroSplitBar(
                      protein: entry.intake.protein,
                      fat: entry.intake.fat,
                      carbs: entry.intake.carbs,
                      height: 6,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                tooltip: entry.favorite ? l10n.diaryUnfavorite : l10n.diaryFavorite,
                icon: Icon(entry.favorite ? Icons.star_rounded : Icons.star_outline_rounded),
                color: entry.favorite ? palette.warn : palette.inkMuted,
                onPressed: () => actions.toggleFavorite(entry),
              ),
              IconButton(
                tooltip: l10n.diaryRemove(entry.title),
                icon: const Icon(Icons.delete_outline_rounded),
                color: palette.inkMuted,
                onPressed: () => actions.remove(entry),
              ),
            ],
          ),
        ),
        const SizedBox(height: Layout.gap),
      ],
      const SizedBox(height: Layout.gap),
    ];
  }
}
