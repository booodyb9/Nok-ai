package app.nok.nok_ai
import android.content.Intent
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(engine: FlutterEngine) {
        super.configureFlutterEngine(engine)
        MethodChannel(engine.dartExecutor.binaryMessenger, "app.nok/screen_guide").setMethodCallHandler { call, result ->
            when (call.method) {
                "isEnabled" -> result.success(NokAccessibilityService.instance != null)
                "openSettings", "showGuide", "syncPreferences" -> {
                    getSharedPreferences("nok_native", MODE_PRIVATE).edit().putString("language", call.argument<String>("language") ?: "ar")
                        .putFloat("rate", (call.argument<Double>("rate") ?: 0.48).toFloat().coerceIn(0.25f, 0.7f))
                        .putFloat("volume", (call.argument<Double>("volume") ?: 0.85).toFloat().coerceIn(0f, 1f)).apply()
                    if (call.method == "openSettings") startActivity(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS))
                    else if (call.method == "showGuide") {
                        val service = NokAccessibilityService.instance
                        if (service == null) { result.error("disabled", "Enable accessibility first", null); return@setMethodCallHandler }
                        service.showGuide()
                    }
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }
}
