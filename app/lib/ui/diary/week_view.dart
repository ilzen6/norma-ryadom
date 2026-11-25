import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../domain/nutrition/week_summary.dart';
import '../core/formatting.dart';
import '../core/l10n_extensions.dart';
import '../core/layout.dart';
import '../core/session.dart';
import '../core/theme.dart';
import '../core/widgets/state_views.dart';
import '../core/widgets/visuals.dart';

class WeekView extends ConsumerWidget {
  const WeekView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final norm = ref.watch(normProvider);
    final entries = ref.watch(recentDiaryProvider).value;
    if (norm == null || entries == null) return const LoadingView();
    final week = WeekSummary.of(entries, today: ref.watch(currentDayProvider), norm: norm);
    if (week.isEmpty) {
      return Panel(
        key: const Key('week-empty'),
        child: MessageView(message: l10n.weekEmpty, icon: Icons.bar_chart_rounded),
      );
    }
    final textTheme = Theme.of(context).textTheme;
    final favorite = week.favorite;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Panel(
          key: const Key('week-chart'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Eyebrow(l10n.weekChartTitle(norm.kcal)),
              const SizedBox(height: 16),
              _WeekBars(week: week),
            ],
          ),
        ),
        const SizedBox(height: Layout.gap),
        Panel(
          key: const Key('week-stats'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.weekAverage(Formatting.integer(week.averageKcal)), style: textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(l10n.weekDaysInNorm(week.daysInNorm, week.recorded.length), style: textTheme.bodyMedium),
              const SizedBox(height: 4),
              Text(
                l10n.weekProtein(Formatting.integer(week.averageProtein), norm.protein),
                style: textTheme.bodyMedium,
              ),
              if (favorite != null) ...[
                const SizedBox(height: 4),
                Text(
                  l10n.weekFavorite(favorite.title, favorite.times),
                  key: const Key('week-favorite'),
                  style: textTheme.bodyMedium,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _WeekBars extends StatelessWidget {
  const _WeekBars({required this.week});

  static const _height = 140.0;
  static const _headroom = 1.25;

  final WeekSummary week;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final palette = context.palette;
    final weekday = DateFormat.E('ru');
    final top = math.max(week.norm.kcal * _headroom, week.days.map((day) => day.kcal).fold<double>(0, math.max));
    double heightOf(double kcal) => top <= 0 ? 0 : _height * kcal / top;
    return Column(
      children: [
        SizedBox(
          height: _height,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (final day in week.days)
                    Expanded(
                      child: Semantics(
                        container: true,
                        label: l10n.weekBar(weekday.format(day.day), day.kcal.round()),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 5),
                          child: Container(
                            height: day.entries > 0 ? math.max(heightOf(day.kcal), 4) : 0,
                            decoration: BoxDecoration(
                              color: week.isOver(day) ? palette.warn : palette.brand,
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: heightOf(week.norm.kcal.toDouble()),
                child: CustomPaint(size: const Size.fromHeight(1.5), painter: _DashedLine(palette.inkMuted)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        ExcludeSemantics(
          child: Row(
            children: [
              for (final day in week.days)
                Expanded(
                  child: Text(
                    weekday.format(day.day),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DashedLine extends CustomPainter {
  const _DashedLine(this.color);

  static const _dash = 6.0;
  static const _gap = 4.0;

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = size.height;
    for (var x = 0.0; x < size.width; x += _dash + _gap) {
      canvas.drawLine(Offset(x, 0), Offset(math.min(x + _dash, size.width), 0), paint);
    }
  }

  @override
  bool shouldRepaint(_DashedLine oldDelegate) => oldDelegate.color != color;
}
