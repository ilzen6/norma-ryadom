import 'package:flutter/material.dart';

import '../../../domain/models/district.dart';
import '../l10n_extensions.dart';
import '../theme.dart';

class DistrictField extends StatelessWidget {
  const DistrictField({super.key, required this.value, required this.onChanged, this.inset = false});

  final District value;
  final ValueChanged<District> onChanged;
  final bool inset;

  Future<void> _choose(BuildContext context) async {
    final district = await showModalBottomSheet<District>(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _DistrictSheet(selected: value),
    );
    if (district != null && district != value) onChanged(district);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final palette = context.palette;
    final textTheme = Theme.of(context).textTheme;
    final label = l10n.locationDistrictLabel;
    final row = Padding(
      padding: EdgeInsets.symmetric(horizontal: inset ? 16 : 18, vertical: 12),
      child: Row(
        children: [
          Icon(Icons.location_city_rounded, color: palette.brand),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: textTheme.labelMedium?.copyWith(color: palette.inkMuted)),
                const SizedBox(height: 2),
                Text(l10n.districtName(value), style: textTheme.titleMedium),
                Text(l10n.region(value.region), style: textTheme.bodySmall?.copyWith(color: palette.inkMuted)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Icon(Icons.unfold_more_rounded, color: palette.inkSubtle),
        ],
      ),
    );
    return Semantics(
      button: true,
      onTap: () => _choose(context),
      label: l10n.districtChange(label, l10n.district(value)),
      excludeSemantics: true,
      child: inset
          ? InkWell(onTap: () => _choose(context), child: row)
          : Material(
              color: palette.surface,
              borderRadius: BorderRadius.circular(AppRadii.tile),
              clipBehavior: Clip.antiAlias,
              child: InkWell(onTap: () => _choose(context), child: row),
            ),
    );
  }
}

class _DistrictSheet extends StatefulWidget {
  const _DistrictSheet({required this.selected});

  final District selected;

  @override
  State<_DistrictSheet> createState() => _DistrictSheetState();
}

class _DistrictSheetState extends State<_DistrictSheet> {
  var _query = '';

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final palette = context.palette;
    final textTheme = Theme.of(context).textTheme;
    final query = _query.trim().toLowerCase();
    bool matches(District district) =>
        query.isEmpty ||
        l10n.districtName(district).toLowerCase().contains(query) ||
        l10n.region(district.region).toLowerCase().contains(query);
    final groups = [
      for (final region in DistrictRegion.values)
        (region, District.values.where((district) => district.region == region && matches(district)).toList()),
    ].where((group) => group.$2.isNotEmpty).toList();
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 1,
      builder: (context, controller) => CustomScrollView(
        controller: controller,
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Semantics(header: true, child: Text(l10n.districtPickerTitle, style: textTheme.titleLarge)),
                  const SizedBox(height: 12),
                  TextField(
                    key: const Key('district-search'),
                    onChanged: (value) => setState(() => _query = value),
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText: l10n.districtSearch,
                      prefixIcon: const Icon(Icons.search_rounded),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (groups.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  l10n.districtSearchEmpty,
                  style: textTheme.bodyMedium?.copyWith(color: palette.inkMuted),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          for (final (region, districts) in groups) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 4),
                child: Semantics(
                  header: true,
                  child: Text(
                    l10n.region(region).toUpperCase(),
                    style: textTheme.labelMedium?.copyWith(color: palette.brand, letterSpacing: 0.8),
                  ),
                ),
              ),
            ),
            SliverList.list(
              children: [
                for (final district in districts)
                  ListTile(
                    key: Key('district-${district.name}'),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 24),
                    selected: district == widget.selected,
                    title: Text(l10n.districtName(district)),
                    trailing: district == widget.selected ? Icon(Icons.check_rounded, color: palette.brand) : null,
                    onTap: () => Navigator.of(context).pop(district),
                  ),
              ],
            ),
          ],
          SliverToBoxAdapter(child: SizedBox(height: 16 + MediaQuery.paddingOf(context).bottom)),
        ],
      ),
    );
  }
}
