package com.citycare.citycare

import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "citycare/device")
            .setMethodCallHandler { call, result ->
                if (call.method == "isEmulator") {
                    result.success(isEmulator())
                } else {
                    result.notImplemented()
                }
            }
    }

    /// Empreinte / produit / hardware typiques d'un AVD (pas un Samsung reel).
    private fun isEmulator(): Boolean {
        val fingerprint = Build.FINGERPRINT.lowercase()
        val product = Build.PRODUCT.lowercase()
        val hardware = Build.HARDWARE.lowercase()
        val model = Build.MODEL.lowercase()
        val manufacturer = Build.MANUFACTURER.lowercase()
        val brand = Build.BRAND.lowercase()
        return fingerprint.contains("generic") ||
            fingerprint.contains("emulator") ||
            fingerprint.contains("unknown") ||
            product.contains("sdk") ||
            product.contains("emulator") ||
            product.contains("vbox") ||
            hardware.contains("goldfish") ||
            hardware.contains("ranchu") ||
            hardware.contains("vbox") ||
            model.contains("sdk") ||
            model.contains("emulator") ||
            model.contains("android sdk") ||
            manufacturer.contains("genymotion") ||
            (brand.contains("generic") && model.contains("google_sdk"))
    }
}