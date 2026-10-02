import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';

class LayoutIssue {
  const LayoutIssue(this.kind, this.description);

  final String kind;
  final String description;

  @override
  String toString() => '$kind: $description';
}

class _Label {
  const _Label(this.text, this.rect, this.object);

  final String text;
  final Rect rect;
  final RenderObject object;

  bool contains(_Label other) {
    var parent = other.object.parent;
    while (parent != null) {
      if (identical(parent, object)) return true;
      parent = parent.parent;
    }
    return false;
  }
}

abstract final class LayoutAudit {
  static const edgeGutter = 12.0;
  static const minInlineGap = 4.0;

  static bool _painted(RenderObject object) {
    var child = object;
    var parent = object.parent;
    while (parent != null) {
      if (!parent.paintsChild(child)) return false;
      if (parent is RenderIndexedStack && parent.getChildrenAsList().indexOf(child as RenderBox) != parent.index) {
        return false;
      }
      if (parent is RenderOpacity && parent.opacity == 0) return false;
      child = parent;
      parent = parent.parent;
    }
    return true;
  }

  static Rect _globalRect(RenderBox box) => MatrixUtils.transformRect(box.getTransformTo(null), Offset.zero & box.size);

  static Rect _contentArea(WidgetTester tester) {
    final size = tester.view.physicalSize / tester.view.devicePixelRatio;
    var top = tester.view.padding.top / tester.view.devicePixelRatio;
    var bottom = size.height;
    for (final element in find.byType(AppBar).hitTestable().evaluate()) {
      final box = element.renderObject! as RenderBox;
      top = top < _globalRect(box).bottom ? _globalRect(box).bottom : top;
    }
    for (final finder in [find.byType(NavigationBar), find.byKey(const Key('eat-combo'))]) {
      for (final element in finder.evaluate()) {
        final rect = _globalRect(element.renderObject! as RenderBox).inflate(12);
        if (rect.top < bottom) bottom = rect.top;
      }
    }
    return Rect.fromLTRB(0, top, size.width, bottom);
  }

  static Rect? _visibleRect(RenderParagraph paragraph) {
    final plain = paragraph.text.toPlainText();
    Rect local;
    if (plain.contains('\uFFFC')) {
      final boxes = paragraph.getBoxesForSelection(
        TextSelection(baseOffset: 0, extentOffset: plain.trimRight().length),
      );
      if (boxes.isEmpty) return null;
      local = boxes.map((box) => box.toRect()).reduce((a, b) => a.expandToInclude(b));
    } else {
      final painter = TextPainter(
        text: paragraph.text,
        textAlign: paragraph.textAlign,
        textDirection: paragraph.textDirection,
        textScaler: paragraph.textScaler,
        maxLines: paragraph.maxLines,
        ellipsis: paragraph.overflow == TextOverflow.ellipsis ? '\u2026' : null,
        locale: paragraph.locale,
        strutStyle: paragraph.strutStyle,
        textWidthBasis: paragraph.textWidthBasis,
        textHeightBehavior: paragraph.textHeightBehavior,
      )..layout(minWidth: paragraph.size.width, maxWidth: paragraph.size.width);
      final lines = painter.computeLineMetrics().where((line) => line.width > 0).toList();
      painter.dispose();
      if (lines.isEmpty) return null;
      Rect lineRect(LineMetrics line) =>
          Rect.fromLTWH(line.left, line.baseline - line.ascent, line.width, line.ascent + line.descent);
      local = lines.map(lineRect).reduce((a, b) => a.expandToInclude(b));
    }
    final rect = MatrixUtils.transformRect(paragraph.getTransformTo(null), local);
    RenderObject child = paragraph;
    var parent = paragraph.parent;
    while (parent != null) {
      final clip = parent.describeApproximatePaintClip(child);
      if (clip != null) {
        final globalClip = MatrixUtils.transformRect(parent.getTransformTo(null), clip);
        if (!globalClip.contains(rect.topLeft + const Offset(0.5, 0.5)) ||
            !globalClip.contains(rect.bottomRight - const Offset(0.5, 0.5))) {
          return null;
        }
      }
      child = parent;
      parent = parent.parent;
    }
    return rect;
  }

  static bool _onTop(BuildContext context) {
    var route = ModalRoute.of(context);
    while (route != null) {
      if (!route.isCurrent) return false;
      final navigator = route.navigator?.context;
      if (navigator == null) return true;
      route = ModalRoute.of(navigator);
    }
    return true;
  }

  static bool _isIcon(String text) => text.runes.every((rune) => rune >= 0xE000 && rune <= 0xF8FF);

  static List<_Label> _labels(WidgetTester tester, Rect area) {
    final map = find.byType(FlutterMap).evaluate().toSet();
    final seen = <RenderParagraph>{};
    final labels = <_Label>[];
    for (final element in tester.allElements) {
      if (element is! RenderObjectElement) continue;
      final object = element.renderObject;
      if (object is! RenderParagraph || !object.attached || !object.hasSize || !seen.add(object)) continue;
      final text = object.text.toPlainText().replaceAll('\uFFFC', '').trim();
      if (text.isEmpty) continue;
      if (!_onTop(element)) continue;
      if (map.isNotEmpty && element.findAncestorWidgetOfExactType<FlutterMap>() != null) continue;
      if (!_painted(object)) continue;
      final rect = _visibleRect(object);
      if (rect == null || rect.width < 1 || rect.height < 1) continue;
      if (rect.top < area.top || rect.bottom > area.bottom) continue;
      labels.add(_Label(_isIcon(text) ? '' : text, rect, object));
    }
    return labels;
  }

  static List<LayoutIssue> inspect(WidgetTester tester) {
    final area = _contentArea(tester);
    final labels = _labels(tester, area);
    final issues = <LayoutIssue>[];
    for (final label in labels.where((label) => label.text.isNotEmpty)) {
      if (label.rect.left < edgeGutter - 0.5 || label.rect.right > area.right - edgeGutter + 0.5) {
        issues.add(LayoutIssue('у края экрана', '«${label.text}» ${_fmt(label.rect)}'));
      }
    }
    for (var i = 0; i < labels.length; i++) {
      for (var j = i + 1; j < labels.length; j++) {
        if (labels[i].contains(labels[j]) || labels[j].contains(labels[i])) continue;
        final a = labels[i].rect;
        final b = labels[j].rect;
        final overlap = a.intersect(b);
        if (overlap.width > 1 && overlap.height > 1) {
          issues.add(LayoutIssue('наложение', '«${_name(labels[i])}» ${_fmt(a)} и «${_name(labels[j])}» ${_fmt(b)}'));
          continue;
        }
        final sameLine =
            a.top < b.bottom && b.top < a.bottom && overlap.height > (a.height < b.height ? a.height : b.height) * 0.5;
        if (!sameLine) continue;
        final gap = a.left < b.left ? b.left - a.right : a.left - b.right;
        if (gap >= 0 && gap < minInlineGap) {
          issues.add(
            LayoutIssue('слиплись', '«${labels[i].text}» и «${labels[j].text}», зазор ${gap.toStringAsFixed(1)}'),
          );
        }
      }
    }
    return issues;
  }

  static Future<List<String>> inspectScrolling(WidgetTester tester, String screen) async {
    final issues = <String>{};
    void collect() {
      for (final issue in inspect(tester)) {
        issues.add('$screen → $issue');
      }
      final error = tester.takeException();
      if (error != null) issues.add('$screen → ошибка вёрстки: $error');
    }

    collect();
    final scrollables = find.byType(Scrollable).hitTestable();
    if (scrollables.evaluate().isNotEmpty) {
      final position = tester.state<ScrollableState>(scrollables.first).position;
      if (position.axis == Axis.vertical) {
        while (position.pixels < position.maxScrollExtent - 1) {
          position.jumpTo((position.pixels + position.viewportDimension * 0.6).clamp(0, position.maxScrollExtent));
          await tester.pumpAndSettle();
          collect();
        }
        position.jumpTo(0);
        await tester.pumpAndSettle();
      }
    }
    return issues.toList();
  }

  static String _name(_Label label) => label.text.isEmpty ? 'значок' : label.text;

  static String _fmt(Rect rect) =>
      '(${rect.left.toStringAsFixed(0)}, ${rect.top.toStringAsFixed(0)}, ${rect.right.toStringAsFixed(0)}, ${rect.bottom.toStringAsFixed(0)})';
}
