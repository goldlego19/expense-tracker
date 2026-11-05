import 'package:flutter/material.dart';

import '../models/ledger.dart';

Duration motionDuration(BuildContext context, [int milliseconds = 320]) =>
    (MediaQuery.maybeOf(context)?.disableAnimations ?? false)
    ? Duration.zero
    : Duration(milliseconds: milliseconds);

class Reveal extends StatelessWidget {
  const Reveal({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: 1),
    duration: motionDuration(context, 420),
    curve: Curves.easeOutCubic,
    child: child,
    builder: (_, value, child) => Opacity(
      opacity: value,
      child: Transform.translate(
        offset: Offset(0, (1 - value) * 16),
        child: child,
      ),
    ),
  );
}

class AnimatedMoney extends StatelessWidget {
  const AnimatedMoney({super.key, required this.cents, this.style});
  final int cents;
  final TextStyle? style;
  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: cents.toDouble(), end: cents.toDouble()),
    duration: motionDuration(context, 450),
    curve: Curves.easeOutCubic,
    builder: (_, value, _) => Text(money(value.round()), style: style),
  );
}

Future<void> showLedgerEditor(BuildContext context, Widget child) =>
    showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close editor',
      barrierColor: Colors.black54,
      transitionDuration: motionDuration(context, 240),
      pageBuilder: (_, _, _) => child,
      transitionBuilder: (_, animation, _, child) => FadeTransition(
        opacity: animation,
        child: ScaleTransition(
          scale: Tween(begin: .96, end: 1.0).animate(
            CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
          ),
          child: child,
        ),
      ),
    );
