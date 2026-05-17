package com.spacechase.tympeak

import android.content.Intent
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "com.spacechase.tympeak/keepalive"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "start" -> { startKeepAlive(); result.success(null) }
                    "stop"  -> { stopKeepAlive();  result.success(null) }
                    else    -> result.notImplemented()
                }
            }
    }

    private fun startKeepAlive() {
        val intent = Intent(this, TimerKeepAliveService::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(intent)
        } else {
            startService(intent)
        }
    }

    private fun stopKeepAlive() {
        stopService(Intent(this, TimerKeepAliveService::class.java))
    }
}
