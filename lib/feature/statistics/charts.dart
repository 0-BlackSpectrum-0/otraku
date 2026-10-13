import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/physics.dart';
import 'package:material_ui/material_ui.dart';
import 'package:otraku/extension/card_extension.dart';
import 'package:otraku/util/theming.dart';

class BarChart extends StatelessWidget {
  const BarChart({required this.title, required this.categories, this.toolbar});

  final String title;
  final List<(String key, num val)> categories;
  final Widget? toolbar;

  @override
  Widget build(BuildContext context) {
    final colorScheme = ColorScheme.of(context);
    final textTheme = TextTheme.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxBarWidth = constraints.maxWidth;
        double scale(num value) => value > 0 ? math.log(value + 0.1) : 0;

        final maxValue = categories.fold<num>(0.0, (prev, elem) => elem.$2 > prev ? elem.$2 : prev);
        final scaledMaxValue = scale(maxValue);

        final totalValue = categories.fold(0.0, (sum, elem) => sum + elem.$2);

        return Column(
          crossAxisAlignment: .start,
          children: [
            Padding(
              padding: const .symmetric(vertical: 5),
              child: Text(title, style: textTheme.titleSmall),
            ),
            if (toolbar != null) ...[
              SizedBox(width: .infinity, child: toolbar!),
              const SizedBox(height: Theming.offset),
            ],
            for (int i = 0; i < categories.length; i++)
              Padding(
                padding: const .symmetric(vertical: 3),
                child: Column(
                  crossAxisAlignment: .start,
                  spacing: 1,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            categories[i].$1,
                            style: textTheme.labelMedium,
                            textAlign: .left,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            "${(categories[i].$2 / totalValue * 100).toStringAsFixed(1)}%",
                            style: textTheme.labelMedium,
                            textAlign: .center,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            "${categories[i].$2}",
                            style: textTheme.labelMedium,
                            textAlign: .right,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      height: 10,
                      width: maxBarWidth,
                      decoration: BoxDecoration(
                        borderRadius: Theming.borderRadiusSmall,
                        color: colorScheme.surfaceContainerLowest,
                        border: .all(color: colorScheme.outlineVariant, width: 1),
                      ),
                      alignment: .centerLeft,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: (scale(categories[i].$2) / scaledMaxValue) * maxBarWidth,
                        decoration: BoxDecoration(
                          borderRadius: Theming.borderRadiusSmall,
                          gradient: LinearGradient(
                            begin: .centerLeft,
                            end: .centerRight,
                            colors: [colorScheme.primaryContainer, colorScheme.primary],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

class PieChart extends StatefulWidget {
  const PieChart({required this.title, required this.categories, required this.highContrast});

  final String title;
  final List<(String key, int val)> categories;
  final bool highContrast;

  @override
  State<PieChart> createState() => _PieChartState();
}

class _PieChartState extends State<PieChart> with TickerProviderStateMixin {
  static const _spring = SpringDescription(mass: 1, stiffness: 260, damping: 15);

  late final _intro = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))
    ..forward();
  late final _spin = AnimationController.unbounded(vsync: this);
  late List<AnimationController> _pops = _makePops();

  int _selected = -1;
  int _hovered = -1;
  double _lastAngle = 0;
  Offset _lastPos = Offset.zero;

  List<AnimationController> _makePops() => [
    for (int i = 0; i < widget.categories.length; i++) AnimationController.unbounded(vsync: this),
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) _intro.value = 1;
  }

  @override
  void didUpdateWidget(PieChart old) {
    super.didUpdateWidget(old);
    if (listEquals(old.categories, widget.categories)) return;

    if (old.categories.length != widget.categories.length) {
      for (final c in _pops) {
        c.dispose();
      }
      _pops = _makePops();
      _selected = -1;
      _hovered = -1;
    }
    _intro.forward(from: 0);
  }

  @override
  void dispose() {
    _intro.dispose();
    _spin.dispose();
    for (final c in _pops) {
      c.dispose();
    }
    super.dispose();
  }

  void _retarget() {
    for (int i = 0; i < _pops.length; i++) {
      final target = i == _selected ? 1.0 : (i == _hovered ? 0.35 : 0.0);
      final c = _pops[i];
      c.animateWith(SpringSimulation(_spring, c.value, target, c.velocity));
    }
  }

  void _select(int i) {
    setState(() => _selected = (i < 0 || i == _selected) ? -1 : i);
    _retarget();
  }

  void _hover(int i) {
    if (i == _hovered) return;
    _hovered = i;
    _retarget();
  }

  double _angleAt(Offset pos, Size size) {
    final d = pos - size.center(Offset.zero);
    return math.atan2(d.dy, d.dx);
  }

  int _hit(Offset pos, Size size) {
    final g = _geometry(size);
    final dist = (pos - size.center(Offset.zero)).distance;
    if (dist < g.inner - 6 || dist > g.outer + g.pop) return -1;

    final total = widget.categories.fold<int>(0, (s, c) => s + c.$2);
    if (total <= 0) return -1;

    final ease = Curves.easeOutCubic.transform(_intro.value);
    final a = (_angleAt(pos, size) - _baseAngle(_spin.value, ease)) % (math.pi * 2);

    double start = 0;
    for (int i = 0; i < widget.categories.length; i++) {
      final len = widget.categories[i].$2 / total * math.pi * 2;
      if (a >= start && a < start + len) return i;
      start += len;
    }
    return -1;
  }

  void _fling(Offset velocity, Size size) {
    final r = _lastPos - size.center(Offset.zero);
    final len2 = r.dx * r.dx + r.dy * r.dy;
    if (len2 < 1) return;

    final omega = ((r.dx * velocity.dy - r.dy * velocity.dx) / len2).clamp(-18.0, 18.0).toDouble();
    _spin.animateWith(FrictionSimulation(0.08, _spin.value, omega));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.of(context);
    final text = TextTheme.of(context);
    final cats = widget.categories;
    final total = cats.fold<int>(0, (s, c) => s + c.$2);
    final colors = [for (int i = 0; i < cats.length; i++) _sliceColor(scheme, i)];

    final donut = AspectRatio(
      aspectRatio: 1,
      child: LayoutBuilder(
        builder: (context, box) {
          final size = box.biggest;
          final g = _geometry(size);

          return MouseRegion(
            onHover: (e) => _hover(_hit(e.localPosition, size)),
            onExit: (_) => _hover(-1),
            child: GestureDetector(
              onTapUp: (d) => _select(_hit(d.localPosition, size)),
              onPanStart: (d) {
                _spin.stop();
                _lastPos = d.localPosition;
                _lastAngle = _angleAt(d.localPosition, size);
              },
              onPanUpdate: (d) {
                final a = _angleAt(d.localPosition, size);
                var delta = a - _lastAngle;
                if (delta > math.pi) delta -= math.pi * 2;
                if (delta < -math.pi) delta += math.pi * 2;
                _spin.value += delta;
                _lastAngle = a;
                _lastPos = d.localPosition;
              },
              onPanEnd: (d) => _fling(d.velocity.pixelsPerSecond, size),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CustomPaint(
                    painter: _DonutPainter(
                      values: [for (final c in cats) c.$2],
                      colors: colors,
                      track: scheme.surfaceContainerHighest,
                      intro: _intro,
                      spin: _spin,
                      pops: _pops,
                    ),
                  ),
                  Center(
                    child: IgnorePointer(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: g.inner * 1.5),
                        child: _selected >= 0 && _selected < cats.length
                            ? _DonutCenter(
                                label: cats[_selected].$1,
                                value: cats[_selected].$2,
                                percent: _percent(cats[_selected].$2, total),
                              )
                            : _DonutCenter(value: total),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );

    final container = CardExtension.highContrast(widget.highContrast)(
      child: Row(
        mainAxisSize: MediaQuery.sizeOf(context).width > 420 ? .min : .max,
        mainAxisAlignment: .spaceBetween,
        spacing: Theming.offset,
        children: [
          Expanded(
            child: Padding(padding: const .all(Theming.offset), child: donut),
          ),
          Expanded(
            child: ListView.builder(
              padding: const .only(top: 5, bottom: 5, right: Theming.offset),
              itemCount: cats.length,
              itemBuilder: (context, i) => GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _select(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const .symmetric(vertical: 2),
                  padding: const .symmetric(horizontal: 6, vertical: 4),
                  decoration: BoxDecoration(
                    color: i == _selected ? colors[i].withAlpha(40) : Colors.transparent,
                    borderRadius: Theming.borderRadiusSmall,
                  ),
                  child: Column(
                    spacing: 4,
                    children: [
                      Row(
                        spacing: 8,
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: colors[i],
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                          Expanded(
                            child: Text(cats[i].$1, maxLines: 1, overflow: TextOverflow.ellipsis),
                          ),
                          Text(cats[i].$2.toString(), style: text.labelMedium),
                          Text(
                            _percent(cats[i].$2, total),
                            style: text.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: ColoredBox(
                          color: scheme.surfaceContainerHighest,
                          child: SizedBox(
                            height: 3,
                            child: AnimatedBuilder(
                              animation: _intro,
                              builder: (context, _) => FractionallySizedBox(
                                alignment: Alignment.centerLeft,
                                widthFactor:
                                    (total > 0 ? cats[i].$2 / total : 0.0) *
                                    Curves.easeOutCubic.transform(_intro.value),
                                child: ColoredBox(color: colors[i]),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );

    return Column(
      mainAxisSize: .min,
      crossAxisAlignment: .start,
      spacing: 5,
      children: [
        Text(widget.title, style: text.titleSmall),
        Expanded(child: container),
      ],
    );
  }
}

String _percent(int value, int total) =>
    '${(total > 0 ? value / total * 100 : 0.0).toStringAsFixed(1)}%';

/// Slice colors come only from the current theme, so the chart follows
/// the app's colors and light/dark mode.
Color _sliceColor(ColorScheme s, int i) {
  final base = switch (i % 3) {
    0 => s.primary,
    1 => s.tertiary,
    _ => s.secondary,
  };
  final tier = i ~/ 3;
  if (tier == 0) return base;
  return Color.lerp(base, tier.isOdd ? s.surface : s.onSurface, 0.35 + 0.1 * (tier ~/ 2))!;
}

({double outer, double inner, double pop}) _geometry(Size size) {
  final r = math.min(size.width, size.height) / 2;
  final pop = r * 0.07;
  final outer = r - pop;
  return (outer: outer, inner: outer * 0.62, pop: pop);
}

double _baseAngle(double spin, double ease) => -math.pi / 2 + spin + (1 - ease) * -1.75;

Path _sector(Offset c, double inner, double outer, double from, double sweep) {
  return Path()
    ..arcTo(Rect.fromCircle(center: c, radius: outer), from, sweep, true)
    ..arcTo(Rect.fromCircle(center: c, radius: inner), from + sweep, -sweep, false)
    ..close();
}

class _DonutPainter extends CustomPainter {
  _DonutPainter({
    required this.values,
    required this.colors,
    required this.track,
    required this.intro,
    required this.spin,
    required this.pops,
  }) : super(repaint: Listenable.merge([intro, spin, ...pops]));

  final List<int> values;
  final List<Color> colors;
  final Color track;
  final AnimationController intro;
  final AnimationController spin;
  final List<AnimationController> pops;

  /// How far a slice's end tucks under the next slice, in radians.
  /// Hides the anti-aliasing hairline between touching slices.
  static const _seam = 0.006;
  static const _full = math.pi * 2;

  @override
  void paint(Canvas canvas, Size size) {
    final g = _geometry(size);
    final center = size.center(Offset.zero);

    canvas.drawCircle(
      center,
      (g.outer + g.inner) / 2,
      Paint()
        ..color = track
        ..style = PaintingStyle.stroke
        ..strokeWidth = g.outer - g.inner,
    );

    final total = values.fold<int>(0, (s, v) => s + v);
    if (total <= 0) return;

    final ease = Curves.easeOutCubic.transform(intro.value);
    final base = _baseAngle(spin.value, ease);
    final revealed = ease * _full;
    final first = values.indexWhere((v) => v > 0);
    final last = values.lastIndexWhere((v) => v > 0);

    double start = 0;
    for (int i = 0; i < values.length; i++) {
      final len = values[i] / total * _full;
      final from = start;
      start += len;

      final shown = math.min(len, revealed - from);
      if (values[i] <= 0 || shown <= 0) continue;

      final lead = (i == first && first != last && ease >= 1) ? _seam : 0.0;
      final tail = (i < last && shown >= len - 1e-9) ? _seam : 0.0;
      final sweep = math.min(shown + lead + tail, _full - 1e-4);

      final pop = math.max(-0.15, math.min(1.3, pops[i].value));
      final mid = base + from + shown / 2;
      final shift = pop * g.pop;
      final c = center + Offset(math.cos(mid), math.sin(mid)) * shift;

      canvas.drawPath(
        _sector(c, g.inner, g.outer + shift * 0.35, base + from - lead, sweep),
        Paint()
          ..color = colors[i]
          ..isAntiAlias = true,
      );
    }
  }

  @override
  bool shouldRepaint(_DonutPainter old) =>
      !listEquals(old.values, values) || !listEquals(old.colors, colors) || old.track != track;
}

class _DonutCenter extends StatelessWidget {
  const _DonutCenter({required this.value, this.label, this.percent});

  final int value;
  final String? label;
  final String? percent;

  @override
  Widget build(BuildContext context) {
    final text = TextTheme.of(context);
    final muted = ColorScheme.of(context).onSurfaceVariant;

    return Column(
      mainAxisSize: .min,
      children: [
        if (label != null)
          Text(
            label!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: text.labelSmall?.copyWith(color: muted),
          ),
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: value.toDouble()),
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeOutCubic,
          builder: (context, v, _) => Text(v.round().toString(), style: text.titleLarge),
        ),
        if (percent != null) Text(percent!, style: text.labelSmall?.copyWith(color: muted)),
      ],
    );
  }
}
