# 🎮 Dodge Rush — Complete Setup Guide

## What You Have

A **production-ready Flutter arcade game** with:
- ✅ Full gameplay (dodge obstacles, collect coins, power-ups)
- ✅ Lives system (3 hearts)
- ✅ Increasing difficulty over time
- ✅ 5 unlockable skins (Neon, Fire, Ice, Gold, Rainbow)
- ✅ Coins system + local storage
- ✅ Best score tracking
- ✅ Game Over screen with "Watch Ad to Continue" button
- ✅ Shop screen (skin purchases)
- ✅ Settings screen (sound, vibration)
- ✅ AdMob integration points (ready to plug in)
- ✅ IAP integration points (ready to plug in)

---

## Step 1: Install Flutter

1. Go to https://flutter.dev/docs/get-started/install
2. Download Flutter for Windows/Mac
3. Run the installer and follow instructions
4. Run `flutter doctor` in terminal — fix any issues shown

---

## Step 2: Set Up the Project

```bash
# 1. Create a new Flutter project
flutter create dodge_rush
cd dodge_rush

# 2. Replace the lib/ folder with the provided files
# 3. Replace pubspec.yaml with the provided one

# 4. Install dependencies
flutter pub get

# 5. Run on your phone (enable USB debugging on Android)
flutter run
```

---

## Step 3: Add AdMob (Real Ads)

### 3a. Create AdMob Account
1. Go to https://admob.google.com
2. Create account → Add app → Android
3. Note your **App ID** and **Ad Unit IDs**

### 3b. Configure Android
Edit `android/app/src/main/AndroidManifest.xml`:
```xml
<manifest>
  <application>
    <!-- Add this inside <application> tag -->
    <meta-data
      android:name="com.google.android.gms.ads.APPLICATION_ID"
      android:value="ca-app-pub-XXXXXXXXXXXXXXXX~XXXXXXXXXX"/>
  </application>
</manifest>
```

### 3c. Create ads_service.dart
Create `lib/services/ads_service.dart`:
```dart
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdsService {
  static const String _interstitialId = 'ca-app-pub-YOUR_ID/YOUR_UNIT_ID';
  static const String _rewardedId = 'ca-app-pub-YOUR_ID/YOUR_UNIT_ID';
  static const String _bannerId = 'ca-app-pub-YOUR_ID/YOUR_UNIT_ID';

  InterstitialAd? _interstitialAd;
  RewardedAd? _rewardedAd;

  static void initialize() => MobileAds.instance.initialize();

  void loadInterstitial() {
    InterstitialAd.load(
      adUnitId: _interstitialId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) => _interstitialAd = ad,
        onAdFailedToLoad: (error) => print('Interstitial failed: $error'),
      ),
    );
  }

  void showInterstitial() {
    _interstitialAd?.show();
    _interstitialAd = null;
    loadInterstitial(); // preload next
  }

  void loadRewarded() {
    RewardedAd.load(
      adUnitId: _rewardedId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) => _rewardedAd = ad,
        onAdFailedToLoad: (error) => print('Rewarded failed: $error'),
      ),
    );
  }

  void showRewarded({required VoidCallback onRewarded}) {
    _rewardedAd?.show(
      onUserEarnedReward: (ad, reward) => onRewarded(),
    );
    _rewardedAd = null;
    loadRewarded();
  }
}
```

### 3d. Where to call ads:
- **After every 2-3 game overs** → `adsService.showInterstitial()` in game_over_screen.dart
- **"Watch Ad to Continue" button** → `adsService.showRewarded(onRewarded: () { /* give extra life */ })`
- **Banner on home screen** → `BannerAd` widget in home_screen.dart

---

## Step 4: Add In-App Purchases

### Add dependency in pubspec.yaml:
```yaml
in_app_purchase: ^3.1.13
```

### Products to create in Play Console:
| Product ID | Type | Price | Description |
|---|---|---|---|
| `remove_ads` | Non-consumable | $1.99 | Remove all ads |
| `coins_100` | Consumable | $0.99 | 100 coins |
| `coins_500` | Consumable | $3.99 | 500 coins |

---

## Step 5: Publish to Play Store

### 5a. Build Release APK
```bash
# Generate keystore (one time)
keytool -genkey -v -keystore ~/key.jks -keyalg RSA -keysize 2048 -validity 10000 -alias key

# Build release bundle
flutter build appbundle --release
```

### 5b. Play Console Setup
1. Go to https://play.google.com/console
2. Create new app → Fill in details
3. Upload `build/app/outputs/bundle/release/app-release.aab`
4. Set content rating, pricing, etc.
5. Submit for review (usually 1-3 days)

---

## Monetization Revenue Estimate

| Source | How | Monthly Estimate |
|---|---|---|
| Interstitial ads | Every 2-3 game overs | $30-150 |
| Rewarded ads | Continue button | $20-100 |
| Banner ads | Home/game over screen | $5-30 |
| Remove Ads IAP | One-time $1.99 | $10-50 |
| Coin IAP bundles | $0.99-$3.99 | $5-30 |
| **Total** | | **$70-360/month** |

*With 1,000+ daily active users, this can scale to $500-2,000/month*

---

## File Structure

```
lib/
├── main.dart                    # App entry point
├── theme/
│   └── app_theme.dart          # Colors, fonts, theme
├── models/
│   └── game_models.dart        # Player, Obstacle, Coin, GameState
├── providers/
│   ├── game_provider.dart      # Game loop, physics, collision
│   └── settings_provider.dart  # User prefs, coins, skins
├── screens/
│   ├── home_screen.dart        # Main menu
│   ├── game_screen.dart        # Gameplay
│   ├── game_over_screen.dart   # Results + ad button
│   ├── shop_screen.dart        # Skins + remove ads
│   └── settings_screen.dart    # Sound, vibration
└── services/
    └── ads_service.dart        # (YOU CREATE THIS - see Step 3c)
```

---

## Quick Customization Tips

- **Change game speed**: Edit `_tickRate` and base speed in `game_provider.dart`
- **Add new obstacle type**: Add to `ObstacleType` enum and `Obstacle.generate()`
- **Add new skin**: Add to `SkinType` enum, set color in `Player.color`, add cost in `SettingsProvider.skinCosts`
- **Change colors**: Edit `app_theme.dart`
- **Add background music**: Use `audioplayers` package, call `AudioPlayer().play()` in `startGame()`

---

## Need Help?

Common issues:
- `flutter pub get` fails → Check internet, run `flutter clean` first
- App crashes on start → Run `flutter run --verbose` to see error
- AdMob not working → Use test ad IDs first: `ca-app-pub-3940256099942544/1033173712`
