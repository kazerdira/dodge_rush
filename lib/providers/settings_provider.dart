import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/game_models.dart';

class SettingsProvider extends ChangeNotifier {
  int _bestScore = 0;
  int _totalCoins = 0;
  int _gamesPlayed = 0;
  bool _soundEnabled = true;
  bool _vibrationEnabled = true;
  bool _adsRemoved = false;
  int _selectedSkinIndex = 0;
  List<int> _unlockedSkins = [0];

  int get bestScore => _bestScore;
  int get totalCoins => _totalCoins;
  int get gamesPlayed => _gamesPlayed;
  bool get soundEnabled => _soundEnabled;
  bool get vibrationEnabled => _vibrationEnabled;
  bool get adsRemoved => _adsRemoved;
  int get selectedSkinIndex => _selectedSkinIndex;
  SkinType get selectedSkin => SkinType.values[_selectedSkinIndex % SkinType.values.length];
  List<int> get unlockedSkins => _unlockedSkins;

  SettingsProvider() { _load(); }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    _bestScore = prefs.getInt('bestScore') ?? 0;
    _totalCoins = prefs.getInt('totalCoins') ?? 0;
    _gamesPlayed = prefs.getInt('gamesPlayed') ?? 0;
    _soundEnabled = prefs.getBool('soundEnabled') ?? true;
    _vibrationEnabled = prefs.getBool('vibrationEnabled') ?? true;
    _adsRemoved = prefs.getBool('adsRemoved') ?? false;
    _selectedSkinIndex = prefs.getInt('selectedSkin') ?? 0;
    _unlockedSkins = (prefs.getString('unlockedSkins') ?? '0').split(',').map(int.parse).toList();
    notifyListeners();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('bestScore', _bestScore);
    await prefs.setInt('totalCoins', _totalCoins);
    await prefs.setInt('gamesPlayed', _gamesPlayed);
    await prefs.setBool('soundEnabled', _soundEnabled);
    await prefs.setBool('vibrationEnabled', _vibrationEnabled);
    await prefs.setBool('adsRemoved', _adsRemoved);
    await prefs.setInt('selectedSkin', _selectedSkinIndex);
    await prefs.setString('unlockedSkins', _unlockedSkins.join(','));
  }

  void updateBestScore(int score) {
    if (score > _bestScore) { _bestScore = score; _save(); notifyListeners(); }
  }

  void addCoins(int amount) { _totalCoins += amount; _save(); notifyListeners(); }

  bool spendCoins(int amount) {
    if (_totalCoins >= amount) { _totalCoins -= amount; _save(); notifyListeners(); return true; }
    return false;
  }

  void incrementGamesPlayed() { _gamesPlayed++; _save(); }

  void unlockSkin(int index) {
    if (!_unlockedSkins.contains(index)) { _unlockedSkins.add(index); _save(); notifyListeners(); }
  }

  void selectSkin(int index) { _selectedSkinIndex = index; _save(); notifyListeners(); }
  void toggleSound() { _soundEnabled = !_soundEnabled; _save(); notifyListeners(); }
  void toggleVibration() { _vibrationEnabled = !_vibrationEnabled; _save(); notifyListeners(); }
  void removeAds() { _adsRemoved = true; _save(); notifyListeners(); }
}
