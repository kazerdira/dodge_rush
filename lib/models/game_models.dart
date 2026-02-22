import 'package:flutter/material.dart';

enum SkinType { neon, inferno, phantom, verdant, gold }
enum ObstacleType { wall, spike }
enum PowerUpType { shield, slowTime, extraLife }

Color skinColor(SkinType skin) {
  switch (skin) {
    case SkinType.neon: return const Color(0xFF00F5FF);
    case SkinType.inferno: return const Color(0xFFFF4500);
    case SkinType.phantom: return const Color(0xFFBF00FF);
    case SkinType.verdant: return const Color(0xFF39FF14);
    case SkinType.gold: return const Color(0xFFFFD700);
  }
}

class Player {
  double x;
  double y;
  SkinType skin;
  double size;
  Color get color => skinColor(skin);

  Player({this.x = 0.5, this.y = 0.82, this.skin = SkinType.neon, this.size = 16});
}

class Obstacle {
  double x, y, width, height, speed;
  ObstacleType type;
  Color color;

  Obstacle({
    required this.x, required this.y,
    required this.width, required this.height,
    required this.speed, required this.type,
    required this.color,
  });
}

class Coin {
  double x, y, speed;
  bool collected;
  Coin({required this.x, required this.y, required this.speed, this.collected = false});
}

class PowerUp {
  double x, y, speed;
  PowerUpType type;
  bool collected;
  PowerUp({required this.x, required this.y, required this.speed, required this.type, this.collected = false});
}

class RunState {
  bool isPlaying;
  bool isPaused;
  bool isGameOver;
  int score;
  int coins;
  int lives;
  int combo;
  int maxCombo;
  double difficulty;
  double speed;
  bool isShieldActive;
  double shieldTimer;
  bool isSlowActive;
  double slowTimer;

  RunState({
    this.isPlaying = false, this.isPaused = false, this.isGameOver = false,
    this.score = 0, this.coins = 0, this.lives = 3,
    this.combo = 0, this.maxCombo = 0, this.difficulty = 0, this.speed = 1.0,
    this.isShieldActive = false, this.shieldTimer = 0,
    this.isSlowActive = false, this.slowTimer = 0,
  });
}
