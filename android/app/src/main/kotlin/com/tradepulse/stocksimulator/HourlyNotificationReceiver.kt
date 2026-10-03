package com.tradepulse.stocksimulator

import android.app.AlarmManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.SystemClock
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat

class HourlyNotificationReceiver : BroadcastReceiver() {
    companion object {
        const val CHANNEL_ID = "tradex_hourly_portfolio"
        const val CHANNEL_NAME = "Trade X Hourly Updates"
        const val NOTIFICATION_ID = 1001
        const val PREFS_NAME = "tradex_notifications"
        const val KEY_ENABLED = "hourly_enabled"
        const val KEY_LAST_TITLE = "last_title"
        const val KEY_LAST_BODY = "last_body"
        const val KEY_LAST_DETAILS = "last_details"

        fun createNotificationChannel(context: Context) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val channel = NotificationChannel(
                    CHANNEL_ID,
                    CHANNEL_NAME,
                    NotificationManager.IMPORTANCE_HIGH
                ).apply {
                    description = "Hourly summaries of your portfolio value and stock movements"
                    enableVibration(true)
                    setShowBadge(true)
                }
                val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                notificationManager.createNotificationChannel(channel)
            }
        }

        fun scheduleNextAlarm(
            context: Context,
            title: String,
            body: String,
            details: String?,
            intervalMinutes: Int = 60
        ) {
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager ?: return
            val alarmIntent = Intent(context, HourlyNotificationReceiver::class.java).apply {
                putExtra("title", title)
                putExtra("body", body)
                putExtra("details", details)
            }

            val pendingIntent = PendingIntent.getBroadcast(
                context,
                NOTIFICATION_ID,
                alarmIntent,
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT else PendingIntent.FLAG_UPDATE_CURRENT
            )

            val intervalMillis = intervalMinutes * 60 * 1000L
            val triggerAtMillis = SystemClock.elapsedRealtime() + intervalMillis

            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    alarmManager.setAndAllowWhileIdle(
                        AlarmManager.ELAPSED_REALTIME_WAKEUP,
                        triggerAtMillis,
                        pendingIntent
                    )
                } else {
                    alarmManager.setInexactRepeating(
                        AlarmManager.ELAPSED_REALTIME_WAKEUP,
                        triggerAtMillis,
                        intervalMillis,
                        pendingIntent
                    )
                }
            } catch (e: Exception) {
                // Handled gracefully
            }
        }
    }

    override fun onReceive(context: Context, intent: Intent?) {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val isEnabled = prefs.getBoolean(KEY_ENABLED, true)
        if (!isEnabled) return

        createNotificationChannel(context)

        // Read real portfolio update stored from previous hour
        val title = intent?.getStringExtra("title")
            ?: prefs.getString(KEY_LAST_TITLE, "Trade X — Hourly Update")
            ?: "Trade X — Hourly Update"

        val body = intent?.getStringExtra("body")
            ?: prefs.getString(KEY_LAST_BODY, "Your portfolio summary has been updated.")
            ?: "Your portfolio summary has been updated."

        val details = intent?.getStringExtra("details")
            ?: prefs.getString(KEY_LAST_DETAILS, null)

        val launchIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)?.apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }

        val pendingIntent = PendingIntent.getActivity(
            context,
            0,
            launchIntent,
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT else PendingIntent.FLAG_UPDATE_CURRENT
        )

        val builder = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.stat_notify_more)
            .setContentTitle(title)
            .setContentText(body)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_EVENT)
            .setAutoCancel(true)
            .setContentIntent(pendingIntent)

        if (!details.isNullOrEmpty()) {
            builder.setStyle(
                NotificationCompat.BigTextStyle()
                    .bigText("$body\n\n$details")
                    .setBigContentTitle(title)
            )
        }

        try {
            val notificationManager = NotificationManagerCompat.from(context)
            notificationManager.notify(NOTIFICATION_ID, builder.build())
        } catch (e: SecurityException) {
            // Permission denied on Android 13+
        } catch (e: Exception) {
            // Exception logged
        }

        // Reschedule next hourly notification cycle in background
        scheduleNextAlarm(context, title, body, details, 60)
    }
}
