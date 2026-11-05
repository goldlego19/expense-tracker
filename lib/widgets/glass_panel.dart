import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// A clipped backdrop keeps blur local to each panel instead of the whole page.
class GlassPanel extends StatelessWidget {
  const GlassPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(22),
    this.accent,
    this.radius = 24,
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? accent;
  final double radius;
  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: dark
                ? const Color(0xff0d1322).withValues(alpha: .68)
                : Colors.white.withValues(alpha: .82),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(
              color:
                  accent?.withValues(alpha: dark ? .32 : .22) ??
                  (dark
                      ? Colors.white.withValues(alpha: .10)
                      : const Color(0xff172235).withValues(alpha: .09)),
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

class DashboardBackdrop extends StatelessWidget {
  const DashboardBackdrop({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      IgnorePointer(
        child: RepaintBoundary(
          child: CustomPaint(
            painter: _BackdropPainter(
              Theme.of(context).brightness == Brightness.dark,
              Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
      ),
      child,
    ],
  );
}

class _BackdropPainter extends CustomPainter {
  const _BackdropPainter(this.dark, this.accent);
  final bool dark;
  final Color accent;
  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    canvas.drawRect(
      bounds,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: dark
              ? [
                  const Color(0xff070b16),
                  const Color(0xff10152b),
                  const Color(0xff080e1b),
                ]
              : [
                  const Color(0xffeaf0ff),
                  const Color(0xfff6f1ff),
                  const Color(0xffeef4fc),
                ],
        ).createShader(bounds),
    );
    void glow(Offset center, double radius, Color color, double alpha) {
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..shader = RadialGradient(
            colors: [
              color.withValues(alpha: alpha),
              color.withValues(alpha: 0),
            ],
          ).createShader(Rect.fromCircle(center: center, radius: radius)),
      );
    }

    glow(
      Offset(size.width * .88, size.height * .08),
      size.longestSide * .62,
      accent,
      dark ? .22 : .10,
    );
    glow(
      Offset(size.width * .04, size.height * .58),
      size.longestSide * .50,
      const Color(0xff8b5cf6),
      dark ? .16 : .08,
    );
    glow(
      Offset(size.width * .75, size.height * .95),
      size.longestSide * .40,
      const Color(0xff2563eb),
      dark ? .12 : .06,
    );
  }

  @override
  bool shouldRepaint(covariant _BackdropPainter oldDelegate) =>
      oldDelegate.dark != dark || oldDelegate.accent != accent;
}

class PanelHeading extends StatelessWidget {
  const PanelHeading({
    super.key,
    required this.title,
    required this.icon,
    this.trailing,
  });
  final String title;
  final IconData icon;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: accent, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 16),
          Divider(
            height: 1,
            color: Theme.of(context).colorScheme.outlineVariant
                .withValues(alpha: .3),
          ),
        ],
      ),
    );
  }
}
