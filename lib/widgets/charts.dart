import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 여러 조각으로 나뉜 도넛 그래프. 가운데에 글자를 넣을 수 있어요.
class Donut extends StatelessWidget {
  const Donut({super.key, required this.parts, this.size = 120, this.stroke = 16, this.center});
  final List<(double value, Color color)> parts;
  final double size;
  final double stroke;
  final Widget? center;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _DonutPainter(parts, stroke, Theme.of(context).colorScheme.surfaceContainerHighest),
        child: Center(child: center),
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  _DonutPainter(this.parts, this.stroke, this.track);
  final List<(double, Color)> parts;
  final double stroke;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromCircle(center: size.center(Offset.zero), radius: (size.shortestSide - stroke) / 2);
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    canvas.drawArc(rect, 0, math.pi * 2, false, p..color = track);
    final total = parts.fold<double>(0, (a, e) => a + math.max(0, e.$1));
    if (total <= 0) return;
    var start = -math.pi / 2;
    const gap = 0.03;
    for (final (v, c) in parts) {
      if (v <= 0) continue;
      final sweep = v / total * math.pi * 2;
      canvas.drawArc(rect, start + gap / 2, math.max(0.001, sweep - gap), false, p..color = c);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(_DonutPainter old) => true;
}

/// 0~1 진행률 고리
class Ring extends StatelessWidget {
  const Ring({super.key, required this.value, required this.color, this.size = 120, this.stroke = 12, this.label});
  final double value;
  final Color color;
  final double size;
  final double stroke;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final v = value.clamp(0.0, 1.0);
    return Donut(
      size: size,
      stroke: stroke,
      parts: [(v, color), (1 - v, Colors.transparent)],
      center: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('${(v * 100).round()}%', style: TextStyle(fontSize: size * .2, fontWeight: FontWeight.w800, color: color)),
        if (label != null) Text(label!, style: TextStyle(fontSize: 11, color: Theme.of(context).hintColor)),
      ]),
    );
  }
}

/// 세로 막대 그래프 (값은 0~1, null이면 빈 칸)
class MiniBars extends StatelessWidget {
  const MiniBars({super.key, required this.values, required this.labels, required this.color, this.height = 110, this.highlight});
  final List<double?> values;
  final List<String> labels;
  final Color color;
  final double height;
  final int? highlight;

  @override
  Widget build(BuildContext context) {
    final hint = Theme.of(context).hintColor;
    return SizedBox(
      height: height + 36,
      child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        for (var i = 0; i < values.length; i++)
          Expanded(
            child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
              Text(values[i] == null ? '' : '${(values[i]! * 100).round()}', style: TextStyle(fontSize: 11, color: hint)),
              const SizedBox(height: 2),
              Container(
                height: math.max(3, height * (values[i] ?? 0)),
                margin: const EdgeInsets.symmetric(horizontal: 5),
                decoration: BoxDecoration(
                  color: values[i] == null ? hint.withValues(alpha: .15) : color.withValues(alpha: i == highlight ? 1 : .55),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 4),
              Text(labels[i], style: TextStyle(fontSize: 12, fontWeight: i == highlight ? FontWeight.w700 : null)),
            ]),
          ),
      ]),
    );
  }
}

/// 숫자 하나를 크게 보여주는 칸
class StatTile extends StatelessWidget {
  const StatTile({super.key, required this.value, required this.label, this.color});
  final String value;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: color)),
      Text(label, style: TextStyle(fontSize: 12, color: Theme.of(context).hintColor)),
    ]);
  }
}

/// 가로 진행 막대 + 이름
class ProgressRow extends StatelessWidget {
  const ProgressRow({super.key, required this.label, required this.value, required this.color, this.trailing});
  final String label;
  final double value;
  final Color color;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        SizedBox(width: 90, child: Text(label, overflow: TextOverflow.ellipsis)),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(value: value.clamp(0, 1), minHeight: 10, color: color, backgroundColor: color.withValues(alpha: .12)),
          ),
        ),
        SizedBox(width: 48, child: Text(trailing ?? '${(value * 100).round()}%', textAlign: TextAlign.right, style: const TextStyle(fontSize: 13))),
      ]),
    );
  }
}
