// AD MANAGER - AdMob Integration
// Replace the test IDs below with your real AdMob IDs from admob.google.com
// 
// SETUP STEPS:
// 1. Create account at admob.google.com
// 2. Create an Android app in AdMob
// 3. Replace IDs below with your real IDs
// 4. Add your AdMob App ID in AndroidManifest.xml

import 'dart:io';

class AdManager {
  // ⚠️ REPLACE THESE WITH YOUR REAL ADMOB IDs
  static String get bannerAdUnitId {
    if (Platform.isAndroid) {
      return 'ca-app-pub-3940256099942544/6300978111'; // TEST ID - replace with yours
    }
    return 'ca-app-pub-3940256099942544/2934735716';
  }

  static String get interstitialAdUnitId {
    if (Platform.isAndroid) {
      return 'ca-app-pub-3940256099942544/1033173712'; // TEST ID - replace with yours
    }
    return 'ca-app-pub-3940256099942544/4411468910';
  }

  static String get rewardedAdUnitId {
    if (Platform.isAndroid) {
      return 'ca-app-pub-3940256099942544/5224354917'; // TEST ID - replace with yours
    }
    return 'ca-app-pub-3940256099942544/1712485313';
  }

  // YOUR ADMOB APP ID - Add this to AndroidManifest.xml
  // <meta-data android:name="com.google.android.gms.ads.APPLICATION_ID"
  //            android:value="ca-app-pub-XXXXXXXXXXXXXXXX~XXXXXXXXXX"/>
}
