import 'package:flutter/material.dart';

/// Safe opacity extension — prevents "Invalid argument(s): X.X" crashes
/// that happen when float arithmetic produces values outside [0.0, 1.0].
///
/// Use .o(value) everywhere in painters instead of .withOpacity(value).
extension SafeOpacity on Color {
  Color o(double opacity) => withOpacity(opacity.clamp(0.0, 1.0));
}
