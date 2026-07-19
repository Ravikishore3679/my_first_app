import 'package:flutter/material.dart';

class FadeSlideIn extends StatelessWidget {
  const FadeSlideIn({super.key, required this.child, this.delay = Duration.zero});

  final Widget child;
  final Duration delay;

  @override
  Widget build(BuildContext context) {
    const baseMs = 420;
    final totalMs = baseMs + delay.inMilliseconds;
    final delayedStart = totalMs == 0 ? 0.0 : delay.inMilliseconds / totalMs;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: totalMs),
      child: child,
      builder: (context, rawValue, builtChild) {
        final curvedValue = rawValue <= delayedStart
            ? 0.0
            : Curves.easeOutCubic.transform(
                (rawValue - delayedStart) / (1 - delayedStart),
              );
        final shifted = 20 * (1 - curvedValue);
        return Opacity(
          opacity: curvedValue,
          child: Transform.translate(
            offset: Offset(0, shifted),
            child: builtChild,
          ),
        );
      },
    );
  }
}
