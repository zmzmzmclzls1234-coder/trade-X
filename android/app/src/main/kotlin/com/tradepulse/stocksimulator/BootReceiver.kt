package com.tradepulse.stocksimulator

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.SystemClock

class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        if (intent?.action == Intent.ACTION_BOOT_COMPLETED || intent?.action == Intent.ACTION_MY_PACKAGE_REPLACED) {
            val prefs = context.getSharedPreferences(HourlyNotificationReceiver.PREFS_NAME, Context.MODE_PRIVATE)
            val isEnabled = prefs.getBoolean(HourlyNotificationReceiver.KEY_ENABLED, true)
            if (isEnabled) {
                val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
                val alarmIntent = Intent(context, HourlyNotificationReceiver::class.java)
                val pendingIntent = PendingIntent.getBroadcast(
                    context,
                    1001,
                    alarmIntent,
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT else PendingIntent.FLAG_UPDATE_CURRENT
                )

                val intervalMillis = 60 * 60 * 1000L // 1 hour
                val triggerAtMillis = SystemClock.elapsedRealtime() + intervalMillis

                try {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        alarmManager.setAndAllowWhileIdle(AlarmManager.ELAPSED_REALTIME_WAKEUP, triggerAtMillis, pendingIntent)
                    } else {
                        alarmManager.setInexactRepeating(AlarmManager.ELAPSED_REALTIME_WAKEUP, triggerAtMillis, intervalMillis, pendingIntent)
                    }
                } catch (e: Exception) {
                    // Handled
                }
            }
        }
    }
}
