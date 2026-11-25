import 'package:flutter/material.dart';

import '../../domain/models/taste.dart';
import '../core/l10n_extensions.dart';

class TastesPicker extends StatelessWidget {
  const TastesPicker({super.key, required this.selected, required this.onToggle});

  final Set<TasteTag> selected;
  final ValueChanged<TasteTag> onToggle;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      for (final taste in TasteTag.values)
        FilterChip(
          key: Key('taste-${taste.code}'),
          label: Text(context.l10n.taste(taste)),
          selected: selected.contains(taste),
          onSelected: (_) => onToggle(taste),
        ),
    ],
  );
}
