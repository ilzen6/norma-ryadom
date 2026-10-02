import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../domain/models/catalog.dart';
import '../formatting.dart';
import '../theme.dart';

class GlassSurface extends StatelessWidget {
  const GlassSurface({super.key, required this.child, this.radius = 32, this.padding = EdgeInsets.zero});

  final Widget child;
  final double radius;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: palette.glass,
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: palette.hairline.withValues(alpha: 0.8)),
          ),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

class Panel extends StatelessWidget {
  const Panel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.color,
    this.gradient,
    this.onTap,
  });

  final Widget child;
  final EdgeInsets padding;
  final Color? color;
  final Gradient? gradient;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Padding(padding: padding, child: child);
    final gradient = this.gradient;
    return Material(
      color: gradient == null ? color ?? context.palette.surface : Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadii.card),
      clipBehavior: Clip.antiAlias,
      child: Ink(
        decoration: gradient == null ? null : BoxDecoration(gradient: gradient),
        child: onTap == null ? content : InkWell(onTap: onTap, child: content),
      ),
    );
  }
}

class Eyebrow extends StatelessWidget {
  const Eyebrow(this.text, {super.key, this.color});

  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) => Text(
    text.toUpperCase(),
    semanticsLabel: text,
    style: Theme.of(context).textTheme.labelSmall?.copyWith(
      color: color ?? context.palette.inkMuted,
      letterSpacing: 1.1,
      fontWeight: FontWeight.w700,
    ),
  );
}

enum Tone { good, warn, neutral, brand }

class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.label, required this.tone, this.icon});

  final String label;
  final Tone tone;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final (background, foreground) = switch (tone) {
      Tone.good => (palette.goodSoft, palette.good),
      Tone.warn => (palette.warnSoft, palette.warn),
      Tone.neutral => (palette.neutralSoft, palette.neutral),
      Tone.brand => (palette.brandSoft, palette.brand),
    };
    return DecoratedBox(
      decoration: ShapeDecoration(color: background, shape: const StadiumBorder()),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[Icon(icon, size: 15, color: foreground), const SizedBox(width: 4)],
            Flexible(
              child: Text(
                label,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(color: foreground),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class DishAvatar extends StatelessWidget {
  const DishAvatar({super.key, required this.category, this.name = '', this.size = 44});

  final DishCategory category;
  final String name;
  final double size;

  static const _keywords = <(List<String>, IconData)>[
    (['пицц', 'кальцоне'], Icons.local_pizza_rounded),
    (['бургер'], Icons.lunch_dining_rounded),
    (['суп', 'борщ', 'солянк'], Icons.soup_kitchen_rounded),
    (['паста', 'пельмен', 'варени'], Icons.dinner_dining_rounded),
    (['ролл', 'фалафел'], Icons.kebab_dining_rounded),
    (['сэндвич', 'киш', 'круассан'], Icons.bakery_dining_rounded),
    (['блин', 'сырник', 'омлет'], Icons.breakfast_dining_rounded),
    (['лосос', 'сёмг', 'тунц', 'креветк'], Icons.set_meal_rounded),
    (['стейк', 'колбаск', 'рёбрышк', 'крыл', 'грудка', 'курица'], Icons.outdoor_grill_rounded),
    (['картоф'], Icons.fastfood_rounded),
    (['коктейл', 'смузи'], Icons.blender_rounded),
    (['кофе', 'американо', 'капучино', 'латте', 'флэт'], Icons.coffee_rounded),
    (['чай'], Icons.emoji_food_beverage_rounded),
    (['вода', 'морс', 'лимонад', 'компот', 'квас', 'кола', 'комбуча', 'кефир'], Icons.local_drink_rounded),
    (['морожен'], Icons.icecream_rounded),
    (['печенье', 'батончик'], Icons.cookie_rounded),
    (['чизкейк', 'тирамису', 'пирог', 'брауни', 'пудинг'], Icons.cake_rounded),
    (['боул', 'плов', 'рис', 'гречк', 'булгур', 'киноа', 'овсянк', 'гранол'], Icons.rice_bowl_rounded),
    (['салат', 'брокколи', 'овощ', 'кукуруз'], Icons.eco_rounded),
  ];

  static IconData iconOf(DishCategory category, [String name = '']) {
    if (category == DishCategory.salad || category == DishCategory.sauce) {
      return category == DishCategory.salad ? Icons.eco_rounded : Icons.water_drop_rounded;
    }
    final lower = name.toLowerCase();
    for (final (words, icon) in _keywords) {
      if (words.any(lower.contains)) {
        return icon;
      }
    }
    return switch (category) {
      DishCategory.main => Icons.restaurant_rounded,
      DishCategory.side => Icons.rice_bowl_rounded,
      DishCategory.salad => Icons.eco_rounded,
      DishCategory.drink => Icons.local_cafe_rounded,
      DishCategory.dessert => Icons.icecream_rounded,
      DishCategory.sauce => Icons.water_drop_rounded,
      DishCategory.unknown => Icons.restaurant_rounded,
    };
  }

  static Color colorOf(Palette palette, DishCategory category) => switch (category) {
    DishCategory.main => palette.brand,
    DishCategory.side => palette.fat,
    DishCategory.salad => palette.good,
    DishCategory.drink => palette.carbs,
    DishCategory.dessert => palette.protein,
    DishCategory.sauce || DishCategory.unknown => palette.neutral,
  };

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final color = colorOf(palette, category);
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Color.alphaBlend(color.withValues(alpha: 0.14), palette.surface),
          borderRadius: BorderRadius.circular(size * 0.36),
        ),
        child: Icon(iconOf(category, name), color: color, size: size * 0.52),
      ),
    );
  }
}

class MacroSplitBar extends StatelessWidget {
  const MacroSplitBar({super.key, required this.protein, required this.fat, required this.carbs, this.height = 8});

  final double protein;
  final double fat;
  final double carbs;
  final double height;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final parts = [(protein * 4, palette.protein), (fat * 9, palette.fat), (carbs * 4, palette.carbs)];
    final total = parts.fold<double>(0, (sum, part) => sum + part.$1);
    return ExcludeSemantics(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(height),
        child: SizedBox(
          height: height,
          child: total <= 0
              ? ColoredBox(color: palette.surfaceMuted)
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final (index, (energy, color)) in parts.indexed)
                      if (energy > 0)
                        Expanded(
                          flex: math.max(1, (energy / total * 1000).round()),
                          child: Padding(
                            padding: EdgeInsets.only(left: index == 0 ? 0 : 2),
                            child: ColoredBox(color: color),
                          ),
                        ),
                  ],
                ),
        ),
      ),
    );
  }
}

class MacroLegendValue extends StatelessWidget {
  const MacroLegendValue({super.key, required this.label, required this.value, required this.color});

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: textTheme.labelMedium?.copyWith(color: context.palette.inkMuted)),
        const SizedBox(width: 4),
        Text(value, style: textTheme.labelLarge?.copyWith(fontFeatures: AppFonts.tabular)),
      ],
    );
  }
}

class RingSpec {
  const RingSpec({required this.value, required this.color});

  final double value;
  final Color color;
}

class ProgressRings extends StatefulWidget {
  const ProgressRings({super.key, required this.rings, this.size = 120, this.stroke = 11, this.gap = 4, this.center});

  final List<RingSpec> rings;
  final double size;
  final double stroke;
  final double gap;
  final Widget? center;

  @override
  State<ProgressRings> createState() => _ProgressRingsState();
}

class _ProgressRingsState extends State<ProgressRings> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );
  late final Animation<double> _curve = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
  List<double> _from = const [];

  @override
  void initState() {
    super.initState();
    _from = [for (final _ in widget.rings) 0];
    _controller.forward();
  }

  @override
  void didUpdateWidget(ProgressRings oldWidget) {
    super.didUpdateWidget(oldWidget);
    final changed =
        oldWidget.rings.length != widget.rings.length ||
        [for (final (index, ring) in widget.rings.indexed) ring.value != oldWidget.rings[index].value].any((it) => it);
    if (changed) {
      _from = _current(oldWidget.rings);
      _controller.forward(from: 0);
    }
  }

  List<double> _current(List<RingSpec> target) => [
    for (final (index, ring) in target.indexed)
      lerpDouble(index < _from.length ? _from[index] : 0, ring.value, _curve.value) ?? ring.value,
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: widget.size,
    child: AnimatedBuilder(
      animation: _curve,
      builder: (context, child) {
        final values = _current(widget.rings);
        return CustomPaint(
          painter: _RingsPainter(
            [for (final (index, ring) in widget.rings.indexed) RingSpec(value: values[index], color: ring.color)],
            widget.stroke,
            widget.gap,
            context.palette.surfaceMuted,
          ),
          child: child,
        );
      },
      child: widget.center == null ? null : Center(child: widget.center),
    ),
  );
}

class _RingsPainter extends CustomPainter {
  const _RingsPainter(this.rings, this.stroke, this.gap, this.track);

  final List<RingSpec> rings;
  final double stroke;
  final double gap;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    for (final (index, ring) in rings.indexed) {
      final radius = size.shortestSide / 2 - stroke / 2 - index * (stroke + gap);
      if (radius <= stroke / 2) break;
      final rect = Rect.fromCircle(center: center, radius: radius);
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(rect, 0, math.pi * 2, false, paint..color = ring.color.withValues(alpha: 0.16));
      final sweep = ring.value.clamp(0.0, 1.0) * math.pi * 2;
      if (sweep > 0.001) canvas.drawArc(rect, -math.pi / 2, sweep, false, paint..color = ring.color);
    }
  }

  @override
  bool shouldRepaint(_RingsPainter old) => old.rings != rings || old.track != track;
}

enum GaugeKind { window, atLeast, atMost }

class TargetGauge extends StatelessWidget {
  const TargetGauge({
    super.key,
    required this.value,
    required this.goal,
    required this.kind,
    required this.color,
    this.tolerance = 0,
  });

  final double value;
  final double goal;
  final double tolerance;
  final GaugeKind kind;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return ExcludeSemantics(
      child: SizedBox(
        height: 22,
        child: CustomPaint(
          size: const Size.fromHeight(22),
          painter: _GaugePainter(this, palette.surfaceMuted, palette.ink, palette.surface),
        ),
      ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  const _GaugePainter(this.gauge, this.track, this.marker, this.halo);

  final TargetGauge gauge;
  final Color track;
  final Color marker;
  final Color halo;

  @override
  void paint(Canvas canvas, Size size) {
    final maxValue = math.max(gauge.goal + gauge.tolerance, gauge.value) * 1.25;
    double x(double value) => (value / (maxValue <= 0 ? 1 : maxValue)).clamp(0.0, 1.0) * size.width;
    final barTop = size.height / 2 - 4;
    final bar = RRect.fromLTRBR(0, barTop, size.width, barTop + 8, const Radius.circular(4));
    canvas.drawRRect(bar, Paint()..color = track);
    final (start, end) = switch (gauge.kind) {
      GaugeKind.window => (x(gauge.goal - gauge.tolerance), x(gauge.goal + gauge.tolerance)),
      GaugeKind.atLeast => (x(gauge.goal), size.width),
      GaugeKind.atMost => (0.0, x(gauge.goal)),
    };
    canvas.drawRRect(
      RRect.fromLTRBR(start, barTop, end, barTop + 8, const Radius.circular(4)),
      Paint()..color = gauge.color.withValues(alpha: 0.35),
    );
    final markerX = x(gauge.value).clamp(7.0, size.width - 7);
    canvas.drawCircle(Offset(markerX, size.height / 2), 8, Paint()..color = halo);
    canvas.drawCircle(Offset(markerX, size.height / 2), 6, Paint()..color = gauge.color);
  }

  @override
  bool shouldRepaint(_GaugePainter old) =>
      old.gauge.value != gauge.value || old.gauge.goal != gauge.goal || old.track != track;
}

class ChoiceCard extends StatelessWidget {
  const ChoiceCard({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
    this.subtitle,
    this.horizontal = false,
  });

  final String label;
  final String? subtitle;
  final IconData? icon;
  final bool selected;
  final VoidCallback onTap;
  final bool horizontal;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final textTheme = Theme.of(context).textTheme;
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? palette.brandSoft : palette.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.tile),
          side: BorderSide(color: selected ? palette.brand : palette.hairline, width: selected ? 2 : 1),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: horizontal
              ? Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 16, 12),
                  child: Row(
                    children: [
                      if (icon != null) ...[
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: selected ? palette.brand : palette.surfaceMuted,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(icon, size: 22, color: selected ? palette.onBrand : palette.inkMuted),
                        ),
                        const SizedBox(width: 14),
                      ],
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(label, style: textTheme.titleSmall),
                            if (subtitle case final subtitle?) ...[
                              const SizedBox(height: 2),
                              Text(subtitle, style: textTheme.bodySmall?.copyWith(color: palette.inkMuted)),
                            ],
                          ],
                        ),
                      ),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: Icon(
                          selected ? Icons.check_circle_rounded : Icons.circle_outlined,
                          key: ValueKey(selected),
                          color: selected ? palette.brand : palette.hairline,
                        ),
                      ),
                    ],
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (icon != null) ...[
                        Icon(icon, color: selected ? palette.brand : palette.inkMuted),
                        const SizedBox(height: 6),
                      ],
                      Text(label, textAlign: TextAlign.center, style: textTheme.labelLarge),
                      if (subtitle case final subtitle?) ...[
                        const SizedBox(height: 2),
                        Text(subtitle, textAlign: TextAlign.center, style: textTheme.bodySmall),
                      ],
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}

class StepProgress extends StatelessWidget {
  const StepProgress({super.key, required this.current, required this.total});

  final int current;
  final int total;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return ExcludeSemantics(
      child: Row(
        children: [
          for (var step = 0; step < total; step++) ...[
            if (step > 0) const SizedBox(width: 6),
            Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                height: 6,
                decoration: BoxDecoration(
                  color: step <= current ? palette.brand : palette.surfaceMuted,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class NearbyIllustration extends StatelessWidget {
  const NearbyIllustration({super.key, this.height = 150});

  final double height;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return ExcludeSemantics(
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: CustomPaint(painter: _NearbyPainter(palette)),
      ),
    );
  }
}

class _NearbyPainter extends CustomPainter {
  const _NearbyPainter(this.palette);

  final Palette palette;

  static const _venues = [(0.5, -0.6, 0), (0.42, 0.95, 1), (0.72, 2.4, 0), (0.82, -2.1, 2), (0.9, 1.6, 0)];

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.height / 2;
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = palette.brand.withValues(alpha: 0.18);
    canvas.drawCircle(center, radius, Paint()..color = palette.brandSoft.withValues(alpha: 0.6));
    for (final fraction in [0.34, 0.67, 1.0]) {
      canvas.drawCircle(center, radius * fraction, ring);
    }
    final street = Paint()
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round
      ..color = palette.surface.withValues(alpha: 0.9);
    canvas
      ..save()
      ..clipPath(Path()..addOval(Rect.fromCircle(center: center, radius: radius)))
      ..drawLine(center + Offset(-radius, radius * 0.3), center + Offset(radius, -radius * 0.2), street)
      ..drawLine(center + Offset(-radius * 0.2, -radius), center + Offset(radius * 0.25, radius), street)
      ..restore();
    for (final (distance, angle, kind) in _venues) {
      final position = center + Offset(math.cos(angle), math.sin(angle)) * radius * distance;
      final color = switch (kind) {
        0 => palette.good,
        1 => palette.warn,
        _ => palette.neutral,
      };
      canvas
        ..drawCircle(position, 9, Paint()..color = palette.surface)
        ..drawCircle(position, 6.5, Paint()..color = color);
    }
    canvas
      ..drawCircle(center, 22, Paint()..color = palette.brand.withValues(alpha: 0.18))
      ..drawCircle(center, 11, Paint()..color = palette.surface)
      ..drawCircle(center, 8, Paint()..color = palette.brand);
  }

  @override
  bool shouldRepaint(_NearbyPainter oldDelegate) => oldDelegate.palette != palette;
}

LinearGradient heroGradient(Palette palette) => LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [
    Color.lerp(palette.brand, Colors.white, 0.1) ?? palette.brand,
    palette.brand,
    Color.lerp(palette.brand, Colors.black, 0.22) ?? palette.brand,
  ],
  stops: const [0, 0.45, 1],
);

class AnimatedNumber extends StatelessWidget {
  const AnimatedNumber({super.key, required this.value, this.style});

  final double value;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: value, end: value),
    duration: const Duration(milliseconds: 700),
    curve: Curves.easeOutCubic,
    builder: (context, current, _) => Text(Formatting.integer(current), style: style),
  );
}

class SkeletonCards extends StatefulWidget {
  const SkeletonCards({super.key, this.count = 3, this.label});

  final int count;
  final String? label;

  @override
  State<SkeletonCards> createState() => _SkeletonCardsState();
}

class _SkeletonCardsState extends State<SkeletonCards> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    Widget bar(double width, double height) => Container(
      width: width,
      height: height,
      decoration: BoxDecoration(color: palette.surfaceMuted, borderRadius: BorderRadius.circular(height / 2)),
    );
    return Semantics(
      label: widget.label,
      liveRegion: true,
      child: ExcludeSemantics(
        child: FadeTransition(
          opacity: Tween<double>(begin: 0.45, end: 1).animate(_controller),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var index = 0; index < widget.count; index++) ...[
                if (index > 0) const SizedBox(height: 12),
                Panel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      bar(140, 12),
                      const SizedBox(height: 16),
                      for (final width in [210.0, 170.0]) ...[
                        Row(
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: palette.surfaceMuted,
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            const SizedBox(width: 12),
                            bar(width, 12),
                          ],
                        ),
                        const SizedBox(height: 10),
                      ],
                      const SizedBox(height: 8),
                      bar(90, 26),
                      const SizedBox(height: 14),
                      bar(double.infinity, 8),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class Appear extends StatelessWidget {
  const Appear({super.key, required this.child, this.index = 0});

  final Widget child;
  final int index;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: 1),
    duration: Duration(milliseconds: 380 + 70 * index.clamp(0, 6)),
    curve: Curves.easeOutCubic,
    builder: (context, progress, child) => Opacity(
      opacity: progress,
      child: Transform.translate(offset: Offset(0, 18 * (1 - progress)), child: child),
    ),
    child: child,
  );
}

class RevealOnAppear extends StatefulWidget {
  const RevealOnAppear({super.key, required this.child});

  final Widget child;

  @override
  State<RevealOnAppear> createState() => _RevealOnAppearState();
}

class _RevealOnAppearState extends State<RevealOnAppear> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Scrollable.ensureVisible(
        context,
        alignment: 0.15,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
