import 'package:flutter/material.dart';
import '../models/game_models.dart';

// ─────────────────────────────────────────────────────────────────────────────
// PAINTER REGISTRY — Open/Closed dispatch for entity rendering
//
// Instead of a growing if-is chain in game_painter.dart, each entity type
// registers its painter once. Adding a new entity = register a painter.
// No modification to game_painter.dart needed.
// ─────────────────────────────────────────────────────────────────────────────

/// Signature for an entity painter function.
/// Receives the entity (cast to the specific subtype inside), canvas, size,
/// and the current animation tick.
typedef EntityPainterFn = void Function(
    Canvas canvas, Size size, GameEntity entity, double animTick);

class PainterRegistry {
  PainterRegistry._();
  static final PainterRegistry instance = PainterRegistry._();

  final Map<String, EntityPainterFn> _painters = {};

  /// Register a painter for a given renderType key.
  void register(String renderType, EntityPainterFn painter) {
    _painters[renderType] = painter;
  }

  /// Paint an entity using its registered painter.
  /// Returns false if no painter is registered for this entity's renderType.
  bool paint(Canvas canvas, Size size, GameEntity entity, double animTick) {
    final fn = _painters[entity.renderType];
    if (fn == null) return false;
    fn(canvas, size, entity, animTick);
    return true;
  }

  /// Whether a painter is registered for the given type key.
  bool has(String renderType) => _painters.containsKey(renderType);
}
