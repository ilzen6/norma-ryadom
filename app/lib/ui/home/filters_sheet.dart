import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../domain/models/search_filters.dart';
import '../core/l10n_extensions.dart';
import '../core/theme.dart';
import 'home_view_model.dart';

class SortSelector extends StatelessWidget {
  const SortSelector({super.key, required this.value, required this.onChanged, this.keyPrefix = 'sort'});

  final ComboSort value;
  final ValueChanged<ComboSort> onChanged;
  final String keyPrefix;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final palette = context.palette;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: ShapeDecoration(color: palette.surfaceMuted, shape: const StadiumBorder()),
      child: Row(
        children: [
          for (final sort in ComboSort.values)
            Expanded(
              child: Semantics(
                selected: sort == value,
                button: true,
                child: GestureDetector(
                  key: Key('$keyPrefix-${sort.name}'),
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    if (sort == value) return;
                    HapticFeedback.selectionClick();
                    onChanged(sort);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    constraints: const BoxConstraints(minHeight: 48),
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                    decoration: ShapeDecoration(
                      color: sort == value ? palette.surface : Colors.transparent,
                      shape: const StadiumBorder(),
                      shadows: sort == value
                          ? [
                              BoxShadow(
                                color: palette.ink.withValues(alpha: 0.08),
                                blurRadius: 12,
                                offset: const Offset(0, 3),
                              ),
                            ]
                          : const [],
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        l10n.comboSort(sort),
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: palette.ink,
                          fontWeight: sort == value ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
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

class FiltersSheet extends ConsumerStatefulWidget {
  const FiltersSheet({super.key});

  static const countDelay = Duration(milliseconds: 350);

  @override
  ConsumerState<FiltersSheet> createState() => _FiltersSheetState();
}

class _FiltersSheetState extends ConsumerState<FiltersSheet> {
  late SearchFilters _draft = ref.read(searchFiltersProvider);
  late SearchFilters _counted = _draft;
  Timer? _countTimer;

  @override
  void dispose() {
    _countTimer?.cancel();
    super.dispose();
  }

  void _update(SearchFilters next) {
    setState(() => _draft = next);
    _countTimer?.cancel();
    _countTimer = Timer(FiltersSheet.countDelay, () {
      if (mounted) setState(() => _counted = next);
    });
  }

  void _show() {
    final filters = _draft;
    Navigator.of(context).pop();
    unawaited(ref.read(nearbySearchProvider.notifier).applyFilters(filters, show: true));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final palette = context.palette;
    final textTheme = Theme.of(context).textTheme;
    final preview = ref.watch(filterPreviewProvider(_counted));
    final count = _counted == _draft && preview.hasValue && !preview.isLoading ? preview.value : null;
    final price = _draft.maxPriceRub;
    Widget caption(String text) => Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: Text(text, style: textTheme.labelMedium?.copyWith(color: palette.inkMuted)),
    );
    return Padding(
      key: const Key('filters-sheet'),
      padding: EdgeInsets.only(left: 20, right: 20, bottom: MediaQuery.paddingOf(context).bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(l10n.filtersTitle, style: textTheme.headlineSmall),
                  caption(l10n.sortTitle),
                  SortSelector(
                    keyPrefix: 'sheet-sort',
                    value: _draft.sort,
                    onChanged: (sort) => _update(_draft.copyWith(sort: sort)),
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    key: const Key('sheet-hide-fast-food'),
                    contentPadding: EdgeInsets.zero,
                    title: Text(l10n.hideFastFood),
                    subtitle: Text(l10n.hideFastFoodHint),
                    value: _draft.hideFastFood,
                    onChanged: (hidden) => _update(_draft.withHiddenFastFood(hidden: hidden)),
                  ),
                  caption(l10n.venueKindTitle),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final kind in VenueKind.values)
                        FilterChip(
                          key: Key('sheet-kind-${kind.code}'),
                          label: Text(l10n.venueKind(kind)),
                          selected: _draft.kinds.contains(kind),
                          onSelected: (_) => _update(_draft.toggleKind(kind)),
                        ),
                    ],
                  ),
                  caption(price == null ? l10n.priceLimitAny : l10n.priceLimitTitle(price)),
                  Slider(
                    key: const Key('sheet-price'),
                    min: SearchFilters.minPriceRub.toDouble(),
                    max: SearchFilters.maxPriceRubLimit.toDouble(),
                    divisions:
                        (SearchFilters.maxPriceRubLimit - SearchFilters.minPriceRub) ~/ SearchFilters.priceStepRub,
                    value: (price ?? SearchFilters.maxPriceRubLimit).toDouble(),
                    label: price == null ? l10n.priceLimitAny : l10n.priceChip(price),
                    onChanged: (rubles) => _update(_draft.withMaxPrice(rubles)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  key: const Key('reset-filters'),
                  onPressed: _draft.isDefault ? null : () => _update(const SearchFilters()),
                  child: Text(l10n.resetFilters),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: FilledButton(
                  key: const Key('apply-filters'),
                  onPressed: _show,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(count == null ? l10n.showOptionsUnknown : l10n.showOptions(count)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
