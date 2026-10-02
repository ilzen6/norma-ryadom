import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/diary.dart';
import '../../domain/models/meal.dart';
import '../../utils/result.dart';
import '../core/formatting.dart';
import '../core/l10n_extensions.dart';
import '../core/session.dart';
import '../core/messages.dart';
import '../core/widgets/busy_action.dart';
import '../core/widgets/nutrients_text.dart';
import '../core/widgets/nutrient_progress.dart';
import '../core/widgets/state_views.dart';
import 'diary_view_model.dart';

class DiaryScreen extends ConsumerWidget {
  const DiaryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final summary = ref.watch(daySummaryProvider);
    final quickAdd = ref.watch(quickAddProvider).value ?? const <DiaryEntry>[];
    if (summary == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.navDiary)),
        body: const LoadingView(),
      );
    }
    final eaten = summary.eaten;
    final norm = summary.norm;
    return Scaffold(
      appBar: AppBar(title: Text('${l10n.diaryTitle}, ${Formatting.date(ref.watch(currentDayProvider))}')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(l10n.diaryEaten, style: Theme.of(context).textTheme.titleMedium),
            NutrientProgress(label: l10n.kcalLabel, eaten: eaten.kcal, norm: norm.kcal),
            NutrientProgress(label: l10n.proteinLabel, eaten: eaten.protein, norm: norm.protein),
            NutrientProgress(label: l10n.fatLabel, eaten: eaten.fat, norm: norm.fat),
            NutrientProgress(label: l10n.carbsLabel, eaten: eaten.carbs, norm: norm.carbs),
            const SizedBox(height: 16),
            if (summary.entries.isEmpty) MessageView(message: l10n.diaryEmpty, icon: Icons.menu_book),
            for (final meal in MealType.values) ..._mealSection(context, ref, meal, summary.entries),
            if (quickAdd.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(l10n.diaryQuickAdd, style: Theme.of(context).textTheme.titleMedium),
              for (final entry in quickAdd)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(entry.favorite ? Icons.star : Icons.history),
                  title: Text(entry.title),
                  subtitle: Text(l10n.kcalValue(entry.intake.kcal.round())),
                  trailing: BusyAction<void>(
                    run: (_) async {
                      final meal = ref.read(mealSelectionProvider).meal;
                      final result = await ref.read(diaryActionsProvider).addAgain(entry, meal);
                      if (result case Err(:final failure) when context.mounted) {
                        showMessage(context, l10n.failure(failure));
                      }
                    },
                    builder: (context, onPressed, busy) => IconButton(
                      tooltip: l10n.diaryAddAgain(entry.title),
                      icon: BusyAction.icon(Icons.add_circle_outline, busy: busy),
                      onPressed: onPressed,
                    ),
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
    final mealEntries = entries.where((entry) => entry.meal == meal).toList();
    if (mealEntries.isEmpty) return const [];
    final actions = ref.read(diaryActionsProvider);
    return [
      Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text(l10n.meal(meal), style: Theme.of(context).textTheme.titleSmall),
      ),
      for (final entry in mealEntries)
        Card(
          key: Key('diary-entry-${entry.id}'),
          child: ListTile(
            title: Text(entry.title),
            subtitle: NutrientsText(
              prefix: entry.venueName,
              kcal: entry.intake.kcal,
              protein: entry.intake.protein,
              fat: entry.intake.fat,
              carbs: entry.intake.carbs,
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: entry.favorite ? l10n.diaryUnfavorite : l10n.diaryFavorite,
                  icon: Icon(entry.favorite ? Icons.star : Icons.star_border),
                  onPressed: () => actions.toggleFavorite(entry),
                ),
                IconButton(
                  tooltip: l10n.diaryRemove(entry.title),
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => actions.remove(entry),
                ),
              ],
            ),
          ),
        ),
    ];
  }
}
