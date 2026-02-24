import 'package:flutter/material.dart';

/// Safe opacity extension — prevents "Invalid argument(s): X.X" crashes.
/// Uses direct Color.fromARGB instead of withOpacity() to avoid Flutter
/// internal alpha multiplication bugs on certain versions.
extension SafeOpacity on Color {
  Color o(double opacity) {
    final a = (opacity.clamp(0.0, 1.0) * 255).round().clamp(0, 255);
    return Color.fromARGB(a, red, green, blue);
  }
}
