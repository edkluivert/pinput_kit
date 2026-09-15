package com.kluivert.pinputkit

import android.util.Log
import io.flutter.embedding.engine.plugins.FlutterPlugin

/**
 * Plugin entry point, registered automatically through the pubspec
 * `pluginClass`. Its only job is to load libpinput_kit.so, the one call site
 * that fires JNI_OnLoad.
 */
class PinputKitPlugin : FlutterPlugin {
    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        try {
            System.loadLibrary("pinput_kit")
        } catch (e: UnsatisfiedLinkError) {
            Log.e("PinputKit", "Failed to load libpinput_kit.so: ${e.message}")
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {}
}
