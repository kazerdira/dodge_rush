package com.dodgerush.dodge_rush

import android.graphics.PixelFormat
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        // Force RGBA_8888 pixel format — prevents Impeller from probing F16
        // on Adreno GPUs that don't support it, avoiding surface crashes.
        window.setFormat(PixelFormat.RGBA_8888)
        super.onCreate(savedInstanceState)
    }
}
