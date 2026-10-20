package com.sqs.smart_queue_system

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import io.flutter.plugins.firebase.messaging.FlutterFirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage

object SqsNotifications {
    fun show(context: Context, data: Map<String, String>) {
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= 26) manager.createNotificationChannel(NotificationChannel("sqs_updates", "Clinic and queue updates", NotificationManager.IMPORTANCE_HIGH))
        val id = data["notification_id"]?.toIntOrNull() ?: return
        fun intent(read: Boolean): PendingIntent {
            val target = Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
                action = if (read) "sqs.read.$id" else "sqs.open.$id"
                putExtra("sqs_local", "true")
                data.forEach { (key, value) -> putExtra(key, value) }
                putExtra("mark_read", if (read) "true" else "false")
            }
            return PendingIntent.getActivity(context, id, target, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        }
        val builder = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(context, "sqs_updates") else Notification.Builder(context)
        builder.setSmallIcon(R.drawable.ic_stat_sqs).setContentTitle(data["title"] ?: "SQS update")
            .setContentText(data["body"]).setStyle(Notification.BigTextStyle().bigText(data["body"]))
            .setAutoCancel(true).setOnlyAlertOnce(true).setContentIntent(intent(false))
            .setVisibility(Notification.VISIBILITY_PRIVATE)
            .addAction(Notification.Action.Builder(null, "Mark as read", intent(true)).build())
        try { manager.notify(id, builder.build()) } catch (_: SecurityException) { }
    }
}
class SqsMessagingService : FlutterFirebaseMessagingService() {
    override fun onMessageReceived(message: RemoteMessage) { SqsNotifications.show(this, message.data) }
}
