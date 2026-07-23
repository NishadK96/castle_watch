package com.example.castle_watch

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray
import org.json.JSONObject

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "castle_watch/play_overlay"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "canDraw" -> result.success(
                    Build.VERSION.SDK_INT < Build.VERSION_CODES.M ||
                        Settings.canDrawOverlays(this)
                )
                "requestPermission" -> {
                    startActivity(
                        Intent(
                            Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                            Uri.parse("package:$packageName")
                        )
                    )
                    result.success(null)
                }
                "start" -> {
                    val accounts = JSONArray()
                    (call.argument<List<Map<String, String>>>("accounts") ?: emptyList())
                        .forEach { accounts.put(JSONObject(it)) }
                    val intent = Intent(this, PlayOverlayService::class.java).apply {
                        putExtra("sessionId", call.argument<String>("sessionId"))
                        putExtra("secret", call.argument<String>("secret"))
                        putExtra("supabaseUrl", call.argument<String>("supabaseUrl"))
                        putExtra("anonKey", call.argument<String>("anonKey"))
                        putExtra("accounts", accounts.toString())
                    }
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        startForegroundService(intent)
                    } else {
                        startService(intent)
                    }
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }
}
