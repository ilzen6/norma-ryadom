import 'package:flutter/material.dart';

import 'theme.dart';
import 'widgets/visuals.dart';

abstract final class Layout {
  static const gutter = 16.0;
  static const gap = 12.0;
  static const section = 28.0;

  static EdgeInsets page(BuildContext context, {double top = 8}) =>
      EdgeInsets.fromLTRB(gutter, top, gutter, gutter + MediaQuery.paddingOf(context).bottom);
}

class ScreenHeader extends StatelessWidget {
  const ScreenHeader({super.key, required this.title, this.eyebrow, this.trailing});

  final String title;
  final String? eyebrow;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 12, 0, 20),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (eyebrow case final eyebrow?) ...[Eyebrow(eyebrow), const SizedBox(height: 6)],
              Semantics(
                header: true,
                child: Text(title, style: Theme.of(context).textTheme.headlineLarge),
              ),
            ],
          ),
        ),
        ?trailing,
      ],
    ),
  );
}

class SectionTitle extends StatelessWidget {
  const SectionTitle({super.key, required this.title, this.trailing});

  final String title;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Expanded(
            child: Semantics(header: true, child: Text(title, style: textTheme.titleLarge)),
          ),
          if (trailing case final trailing?)
            Text(trailing, style: textTheme.labelLarge?.copyWith(color: context.palette.inkMuted)),
        ],
      ),
    );
  }
}
