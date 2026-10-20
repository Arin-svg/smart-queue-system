package com.sqs.smart_queue_system

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Intent
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var channel: MethodChannel? = null
    private val channelId = "sqs_updates"
    private fun payload(intent: Intent?): Map<String, String>? {
        if (intent?.getStringExtra("sqs_local") != "true") return null
        return mapOf("notification_id" to (intent.getStringExtra("notification_id") ?: ""), "mark_read" to (intent.getStringExtra("mark_read") ?: "false"), "destination" to (intent.getStringExtra("destination") ?: "Alerts"), "user_id" to (intent.getStringExtra("user_id") ?: ""))
    }
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        payload(intent)?.let { channel?.invokeMethod("open", it) }
    }
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val manager = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "sqs/notifications")
        channel!!.setMethodCallHandler { call, result ->
            when (call.method) {
                "initialize" -> {
                    if (Build.VERSION.SDK_INT >= 26) manager.createNotificationChannel(NotificationChannel(channelId, "Clinic and queue updates", NotificationManager.IMPORTANCE_HIGH))
                    result.success(null)
                }
                "initial" -> { result.success(payload(intent)); intent?.removeExtra("sqs_local") }
                "cancel" -> { manager.cancel(call.argument<String>("notification_id")?.toIntOrNull() ?: 0); result.success(null) }
                "clear" -> { manager.cancelAll(); result.success(null) }
                "show" -> {
                    SqsNotifications.show(this, call.arguments as Map<String, String>)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }
}
