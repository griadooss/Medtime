package com.zimpics.medtime

import android.os.Bundle
import androidx.core.view.WindowCompat
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        // Enable edge-to-edge display for Android 15+ compatibility
        // This ensures backward compatibility and proper inset handling
        // Required for apps targeting SDK 35+ to avoid Play Console warnings
        // Note: FlutterActivity doesn't extend ComponentActivity, so we use
        // WindowCompat.setDecorFitsSystemWindows() instead of enableEdgeToEdge()
        WindowCompat.setDecorFitsSystemWindows(window, false)
        super.onCreate(savedInstanceState)
    }
}
