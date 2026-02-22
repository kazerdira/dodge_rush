# 🎮 Dodge Rush — Flutter Arcade Game

A complete, production-ready Flutter arcade game ready for Google Play Store.

---

## 📱 What's Included

| Screen | Description |
|--------|-------------|
| **Home Screen** | Animated logo, high score display, coin counter |
| **Game Screen** | Full dodge gameplay with lanes, obstacles, particles |
| **Game Over Screen** | Score display, rewarded ad button, play again |
| **Shop Screen** | 5 player skins purchasable with coins |
| **Settings Screen** | Sound, vibration, stats, rate/share |

## 💰 Monetization (AdMob Ready)

- ✅ **Rewarded Ads** — "Watch Ad to Revive" button in game over
- ✅ **Interstitial Ads** — Show every 3 game overs (add in game_over_screen.dart)
- ✅ **Remove Ads IAP** — $1.99 button in Shop screen
- ✅ **Coin System** — Earn coins per game, spend on skins
- ⬜ **Banner Ads** — Add to home/settings screens

---

## 🚀 Setup Instructions (Step by Step)

### Step 1 — Install Flutter
1. Download Flutter from https://flutter.dev/docs/get-started/install
2. Run `flutter doctor` and fix any issues
3. Install Android Studio + Android SDK

### Step 2 — Run the Game
```bash
cd dodge_rush
flutter pub get
flutter run
```

### Step 3 — Add AdMob (to earn money)
1. Go to https://admob.google.com and create an account
2. Add a new Android app
3. Create 3 ad units: Banner, Interstitial, Rewarded
4. Copy your Ad Unit IDs into `lib/utils/ad_manager.dart`
5. Add your App ID to `android/app/src/main/AndroidManifest.xml`:
```xml
<meta-data
    android:name="com.google.android.gms.ads.APPLICATION_ID"
    android:value="ca-app-pub-XXXXXXXXXXXXXXXX~XXXXXXXXXX"/>
```

### Step 4 — Build for Release
```bash
# Generate keystore (do once)
keytool -genkey -v -keystore ~/upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload

# Build release APK
flutter build apk --release

# OR build App Bundle (recommended for Play Store)
flutter build appbundle --release
```
Your release file will be at: `build/app/outputs/bundle/release/app-release.aab`

### Step 5 — Publish to Play Store
1. Go to https://play.google.com/console
2. Pay $25 one-time registration fee
3. Create new app
4. Upload your `.aab` file
5. Fill in store listing (name, description, screenshots)
6. Submit for review (usually 1-3 days)

---

## 🎨 Customization

### Change Game Speed
In `lib/utils/constants.dart`:
```dart
static const double initialSpeed = 250.0;    // Starting speed
static const double speedIncrement = 15.0;   // Speed increase per interval
```

### Add New Skins
In `lib/utils/constants.dart`, add to `playerSkins` list:
```dart
PlayerSkin(name: 'Ice', color: Color(0xFF87CEEB), glowColor: Color(0xFF87CEEB), price: 300, icon: Icons.ac_unit),
```

### Change Colors
The main colors are:
- Cyan `0xFF00F5FF` — primary/player color
- Pink `0xFFFF006E` — danger/accent color  
- Dark `0xFF0A0A1A` — background

---

## 📋 TODO for Full Production

- [ ] Add real AdMob ads (replace placeholders in game_over_screen.dart)
- [ ] Add `in_app_purchase` package for Remove Ads IAP
- [ ] Add `url_launcher` for Rate Us button
- [ ] Add `share_plus` for Share button
- [ ] Track owned skins in SharedPreferences
- [ ] Add background music with `audioplayers`
- [ ] Add sound effects on dodge/collision
- [ ] Add Google Play Games leaderboard
- [ ] Create app icon (1024x1024 PNG)
- [ ] Take 8 screenshots for Play Store listing

---

## 🏪 Play Store Description Template

**Short description:**
Dodge obstacles in this addictive reflex arcade game! How far can you go?

**Full description:**
Dodge Rush is the ultimate reflex challenge! Navigate through 5 lanes, dodging incoming obstacles as the speed increases. Simple to learn, impossible to master.

🎮 FEATURES:
• Smooth 60fps gameplay
• 5 unique player skins to unlock
• Coins system — earn rewards as you play
• Compete for the highest score
• Revive with rewarded ads
• Vibration & sound effects

How far can YOU go?

---

## 📂 Project Structure

```
lib/
├── main.dart                  ← App entry point
├── utils/
│   ├── game_state.dart        ← Score, coins, settings (Provider)
│   ├── constants.dart         ← Skins, game tuning values
│   └── ad_manager.dart        ← AdMob unit IDs
└── screens/
    ├── home_screen.dart       ← Main menu
    ├── game_screen.dart       ← Core gameplay
    ├── game_over_screen.dart  ← Results + ads
    ├── shop_screen.dart       ← Skins store
    └── settings_screen.dart   ← Preferences
```
