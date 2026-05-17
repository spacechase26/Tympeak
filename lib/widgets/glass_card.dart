import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme.dart';

class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final double radius;
  final Color? color;

  const GlassCard({
    super.key,
    required this.child,
    this.padding,
    this.radius = 20,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: padding ?? const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: color ?? kGlassColor,
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: kGlassBorder, width: 1),
          ),
          child: child,
        ),
      ),
    );
  }
}
