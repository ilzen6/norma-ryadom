import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/services/photo_picker_service.dart';
import '../../domain/models/catalog.dart';
import '../../routing/routes.dart';
import '../../utils/result.dart';
import '../core/l10n_extensions.dart';
import '../core/messages.dart';
import '../core/session.dart';
import '../core/layout.dart';
import '../core/theme.dart';
import '../core/widgets/busy_action.dart';
import '../core/widgets/combo_card.dart';
import '../core/widgets/nutrients_text.dart';
import '../core/widgets/state_views.dart';
import '../core/widgets/trust_badge.dart';
import '../core/widgets/visuals.dart';
import '../home/home_view_model.dart';
import 'venue_view_model.dart';

class VenueScreen extends ConsumerWidget {
  const VenueScreen({super.key, required this.venueId});

  final int venueId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final menu = ref.watch(venueMenuProvider(venueId));
    final title = switch (menu.value) {
      Ok() => '',
      _ => l10n.venueMenu,
    };
    return Scaffold(
      appBar: AppBar(
        title: Text(title, overflow: TextOverflow.ellipsis),
        actions: [
          BusyAction<PhotoSource>(
            prepare: () => _choosePhotoSource(context),
            run: (source) => _uploadPhoto(context, ref, source),
            builder: (context, onPressed, busy) => IconButton(
              key: const Key('upload-photo'),
              tooltip: l10n.uploadMenuPhoto,
              icon: BusyAction.icon(Icons.add_a_photo_rounded, busy: busy),
              onPressed: onPressed,
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        top: false,
        child: switch (menu) {
          AsyncData(value: Ok(:final value)) => _VenueBody(menu: value),
          AsyncData(value: Err(:final failure)) => FailureView(
            failure: failure,
            onRetry: () => ref.invalidate(venueMenuProvider(venueId)),
          ),
          AsyncError() => FailureView(
            failure: AppFailure.unexpected,
            onRetry: () => ref.invalidate(venueMenuProvider(venueId)),
          ),
          _ => const LoadingView(),
        },
      ),
    );
  }

  Future<PhotoSource?> _choosePhotoSource(BuildContext context) {
    final l10n = context.l10n;
    return showModalBottomSheet<PhotoSource>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera),
              title: Text(l10n.uploadFromCamera),
              onTap: () => Navigator.of(sheetContext).pop(PhotoSource.camera),
            ),
            ListTile(
              key: const Key('upload-from-gallery'),
              leading: const Icon(Icons.photo_library),
              title: Text(l10n.uploadFromGallery),
              onTap: () => Navigator.of(sheetContext).pop(PhotoSource.gallery),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _uploadPhoto(BuildContext context, WidgetRef ref, PhotoSource? source) async {
    if (source == null) return;
    final l10n = context.l10n;
    final result = await ref.read(feedbackActionsProvider).sendMenuPhoto(venueId, source);
    if (!context.mounted) return;
    final message = switch (result) {
      Ok(value: FeedbackOutcome.sent) => l10n.photoSent,
      Ok(value: FeedbackOutcome.cancelled) => null,
      Err(:final failure) => l10n.failure(failure),
    };
    if (message != null) showMessage(context, message);
  }
}

class _VenueBody extends ConsumerWidget {
  const _VenueBody({required this.menu});

  final VenueMenu menu;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final palette = context.palette;
    final textTheme = Theme.of(context).textTheme;
    final venue = menu.venue;
    final meal = ref.watch(mealSelectionProvider).meal;
    final comboState = ref.watch(venueComboProvider(venue.id));
    final comboController = ref.read(venueComboProvider(venue.id).notifier);
    return ListView(
      padding: Layout.page(context, top: 0),
      children: [
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (venue.chainName case final chain?) ...[
                Eyebrow(l10n.venueChainLabel(chain)),
                const SizedBox(height: 8),
              ],
              Text(venue.name, style: textTheme.headlineSmall),
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(Icons.place_rounded, size: 18, color: palette.inkMuted),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(venue.address, style: textTheme.bodyMedium?.copyWith(color: palette.inkMuted)),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  key: const Key('build-here'),
                  onPressed: comboState is SearchRunning ? null : comboController.search,
                  icon: const Icon(Icons.auto_awesome_rounded),
                  label: Text(l10n.venueBuildHere(l10n.meal(meal).toLowerCase())),
                ),
              ),
            ],
          ),
        ),
        switch (comboState) {
          SearchIdle() => const SizedBox.shrink(),
          SearchRunning() => Padding(
            padding: const EdgeInsets.only(top: Layout.section),
            child: SkeletonCards(count: 2, label: l10n.searchLoading),
          ),
          SearchFailed(:final failure) => FailureView(failure: failure, onRetry: comboController.search),
          SearchDone(:final result) when result.options.isEmpty => MessageView(message: l10n.noCombosNearby),
          SearchDone(:final result) => Column(
            key: const Key('venue-combos'),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: Layout.section),
              SectionTitle(title: l10n.venueCombosTitle, trailing: '${result.options.length}'),
              for (final (index, option) in result.options.indexed) ...[
                Appear(
                  index: index,
                  child: ComboCard(
                    option: option,
                    showVenue: false,
                    onTap: () {
                      comboController.open(option);
                      context.push(Routes.combo);
                    },
                  ),
                ),
                const SizedBox(height: Layout.gap),
              ],
            ],
          ),
        },
        const SizedBox(height: Layout.section),
        SectionTitle(title: l10n.venueMenu, trailing: menu.items.isEmpty ? null : l10n.menuCount(menu.items.length)),
        if (menu.items.isEmpty) MessageView(message: l10n.venueMenuEmpty),
        for (final item in menu.items) ...[_MenuItemCard(item: item), const SizedBox(height: Layout.gap)],
      ],
    );
  }
}

class _MenuItemCard extends ConsumerWidget {
  const _MenuItemCard({required this.item});

  final MenuItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final palette = context.palette;
    final textTheme = Theme.of(context).textTheme;
    final nutrients = item.nutrients;
    final assessment = item.assessment;
    final reasons = assessment?.reasons.map((reason) => _reasonText(context, reason)).where((text) => text.isNotEmpty);
    return Panel(
      key: Key('menu-item-${item.id}'),
      padding: const EdgeInsets.fromLTRB(16, 16, 8, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DishAvatar(category: item.category, name: item.name),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.name, style: textTheme.titleSmall),
                    const SizedBox(height: 2),
                    NutrientsText(
                      kcal: nutrients.kcal,
                      protein: nutrients.protein,
                      fat: nutrients.fat,
                      carbs: nutrients.carbs,
                      style: textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                l10n.priceOf(item.priceMinor),
                style: (item.priceMinor == null ? textTheme.labelMedium : textTheme.titleSmall)?.copyWith(
                  color: item.priceMinor == null ? palette.inkMuted : palette.ink,
                  fontFeatures: AppFonts.tabular,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: MacroSplitBar(protein: nutrients.protein, fat: nutrients.fat, carbs: nutrients.carbs, height: 6),
          ),
          if (reasons != null && reasons.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(reasons.join(', '), style: textTheme.bodySmall),
          ],
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: Wrap(
                  spacing: 10,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (assessment != null) _VerdictChip(verdict: assessment.verdict),
                    TrustBadge(kind: item.source.kind, source: item.source),
                  ],
                ),
              ),
              BusyAction<String>(
                prepare: () => showDialog<String>(
                  context: context,
                  builder: (_) => _ReportDialog(dishName: item.name),
                ),
                run: (reason) => _report(context, ref, reason),
                builder: (context, onPressed, busy) => IconButton(
                  key: Key('report-${item.id}'),
                  tooltip: l10n.reportNumbers,
                  onPressed: onPressed,
                  icon: BusyAction.icon(Icons.outlined_flag_rounded, busy: busy),
                  color: palette.inkMuted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _reasonText(BuildContext context, AssessmentReason reason) {
    final l10n = context.l10n;
    final amount = (reason.amount ?? 0).round();
    return switch (reason.code) {
      ReasonCode.excludedTag => l10n.reasonExcludedTag(l10n.tag(reason.tag ?? '')),
      ReasonCode.kcalAbove => l10n.reasonKcalAbove(amount),
      ReasonCode.fatAbove => l10n.reasonFatAbove(amount),
      ReasonCode.carbsAbove => l10n.reasonCarbsAbove(amount),
      ReasonCode.lowProtein => l10n.reasonLowProtein,
      ReasonCode.estimatedData => l10n.reasonEstimated,
      ReasonCode.unknown => '',
    };
  }

  Future<void> _report(BuildContext context, WidgetRef ref, String? reason) async {
    if (reason == null) return;
    final l10n = context.l10n;
    final result = await ref.read(feedbackActionsProvider).reportItem(item.id, reason);
    if (!context.mounted) return;
    final message = switch (result) {
      Ok() => l10n.reportSent,
      Err(:final failure) => l10n.failure(failure),
    };
    showMessage(context, message);
  }
}

class _VerdictChip extends StatelessWidget {
  const _VerdictChip({required this.verdict});

  final Verdict verdict;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final (label, tone, icon) = switch (verdict) {
      Verdict.fits => (l10n.verdictFits, Tone.good, Icons.check_circle_rounded),
      Verdict.partial => (l10n.verdictPartial, Tone.warn, Icons.error_outline_rounded),
      Verdict.notFits => (l10n.verdictNotFits, Tone.neutral, Icons.block_rounded),
      Verdict.unknown => ('', Tone.neutral, null),
    };
    if (label.isEmpty) return const SizedBox.shrink();
    return StatusPill(label: label, tone: tone, icon: icon);
  }
}

class _ReportDialog extends StatefulWidget {
  const _ReportDialog({required this.dishName});

  final String dishName;

  @override
  State<_ReportDialog> createState() => _ReportDialogState();
}

class _ReportDialogState extends State<_ReportDialog> {
  final _controller = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.reportTitle(widget.dishName)),
      content: Form(
        key: _formKey,
        child: TextFormField(
          key: const Key('report-reason'),
          controller: _controller,
          maxLength: 500,
          decoration: InputDecoration(labelText: l10n.reportReasonLabel),
          validator: (text) => (text ?? '').trim().isEmpty ? l10n.reportReasonRequired : null,
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(l10n.cancel)),
        FilledButton(
          key: const Key('report-send'),
          onPressed: () {
            if (_formKey.currentState?.validate() ?? false) Navigator.of(context).pop(_controller.text);
          },
          child: Text(l10n.send),
        ),
      ],
    );
  }
}
