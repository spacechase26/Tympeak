import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme.dart';

class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final double radius;
  final Color? color;
  final Gradient? gradient;
  final bool hasBorder;

  const GlassCard({
    super.key,
    required this.child,
    this.padding,
    this.radius = 20,
    this.color,
    this.gradient,
    this.hasBorder = true,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: padding ?? const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: gradient ??
                LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    color ?? Colors.white.withAlpha(22),
                    color?.withAlpha(8) ?? Colors.white.withAlpha(8),
                  ],
                ),
            borderRadius: BorderRadius.circular(radius),
            border: hasBorder
                ? Border.all(color: kGlassBorder, width: 1)
                : null,
          ),
          child: child,
        ),
      ),
    );
  }
}

class GlassBadge extends StatelessWidget {
  final String label;
  final Color color;

  const GlassBadge(this.label, {super.key, this.color = kPurple});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(40),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withAlpha(80)),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }
}
