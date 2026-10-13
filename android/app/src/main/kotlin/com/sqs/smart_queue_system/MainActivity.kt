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
        return mapOf("destination" to (intent.getStringExtra("destination") ?: "Alerts"), "user_id" to (intent.getStringExtra("user_id") ?: ""))
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
                "clear" -> { manager.cancelAll(); result.success(null) }
                "show" -> {
                    val id = call.argument<String>("notification_id")?.toIntOrNull() ?: 1
                    val target = Intent(this, MainActivity::class.java).apply {
                        flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
                        putExtra("sqs_local", "true")
                        putExtra("destination", call.argument<String>("destination"))
                        putExtra("user_id", call.argument<String>("user_id"))
                    }
                    val pending = PendingIntent.getActivity(this, id, target, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
                    val builder = if (Build.VERSION.SDK_INT >= 26) android.app.Notification.Builder(this, channelId) else android.app.Notification.Builder(this)
                    val body = call.argument<String>("body") ?: ""
                    builder.setSmallIcon(R.drawable.ic_stat_sqs).setContentTitle(call.argument<String>("title"))
                        .setContentText(body).setStyle(android.app.Notification.BigTextStyle().bigText(body))
                        .setAutoCancel(true).setContentIntent(pending).setVisibility(android.app.Notification.VISIBILITY_PRIVATE)
                    try { manager.notify(id, builder.build()); result.success(null) }
                    catch (_: SecurityException) { result.success(null) }
                }
                else -> result.notImplemented()
            }
        }
    }
}
