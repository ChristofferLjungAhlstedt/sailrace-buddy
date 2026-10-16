import 'package:flutter/material.dart';
import '../data/boat_classes.dart';

class ClassLogo extends StatelessWidget {
  const ClassLogo({
    super.key,
    required this.className,
    this.size = 32,
    this.showFallback = true,
  });

  final String className;
  final double size;

  /// Show the generic sailboat icon when the class has no logo.
  final bool showFallback;

  @override
  Widget build(BuildContext context) {
    final Widget fallback = showFallback
        ? Icon(Icons.sailing, size: size)
        : const SizedBox.shrink();

    final asset = findBoatClass(className)?.logoAsset;
    if (asset == null) return fallback;

    return Image.asset(
      asset,
      width: size,
      height: size,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) => fallback,
    );
  }
}