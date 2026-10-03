package com.tradepulse.stocksimulator

import android.Manifest
import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.SystemClock
import androidx.core.app.ActivityCompat
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.tradepulse.stocksimulator/notifications"
    private val PERMISSION_REQUEST_CODE = 2001
    private var pendingResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Ensure notification channel is created at startup
        HourlyNotificationReceiver.createNotificationChannel(this)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "areNotificationsEnabled" -> {
                    val enabled = NotificationManagerCompat.from(this).areNotificationsEnabled()
                    result.success(enabled)
                }

                "requestNotificationPermission" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                        if (ContextCompat.checkSelfPermission(this, Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED) {
                            result.success(true)
                        } else {
                            pendingResult = result
                            ActivityCompat.requestPermissions(
                                this,
                                arrayOf(Manifest.permission.POST_NOTIFICATIONS),
                                PERMISSION_REQUEST_CODE
                            )
                        }
                    } else {
                        // Permissions implicitly granted below Android 13
                        val enabled = NotificationManagerCompat.from(this).areNotificationsEnabled()
                        result.success(enabled)
                    }
                }

                "showNotification" -> {
                    val id = call.argument<Int>("id") ?: 1001
                    val title = call.argument<String>("title") ?: "Trade X — Hourly Update"
                    val body = call.argument<String>("body") ?: "Portfolio update"
                    val details = call.argument<String>("details")

                    HourlyNotificationReceiver.createNotificationChannel(this)

                    val launchIntent = packageManager.getLaunchIntentForPackage(packageName)?.apply {
                        flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                    }

                    val pendingIntent = PendingIntent.getActivity(
                        this,
                        0,
                        launchIntent,
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT else PendingIntent.FLAG_UPDATE_CURRENT
                    )

                    val builder = NotificationCompat.Builder(this, HourlyNotificationReceiver.CHANNEL_ID)
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
                        val notificationManager = NotificationManagerCompat.from(this)
                        notificationManager.notify(id, builder.build())
                        result.success(true)
                    } catch (e: SecurityException) {
                        result.error("PERMISSION_DENIED", "Notification permission was not granted by the user", null)
                    } catch (e: Exception) {
                        result.error("NOTIFICATION_ERROR", e.message, null)
                    }
                }

                "scheduleHourlyNotification" -> {
                    val title = call.argument<String>("title") ?: "Trade X — Hourly Update"
                    val body = call.argument<String>("body") ?: "Portfolio update"
                    val details = call.argument<String>("details")
                    val intervalMinutes = call.argument<Int>("intervalMinutes") ?: 60

                    // Persist for background broadcast receiver
                    val prefs = getSharedPreferences(HourlyNotificationReceiver.PREFS_NAME, Context.MODE_PRIVATE)
                    prefs.edit()
                        .putBoolean(HourlyNotificationReceiver.KEY_ENABLED, true)
                        .putString(HourlyNotificationReceiver.KEY_LAST_TITLE, title)
                        .putString(HourlyNotificationReceiver.KEY_LAST_BODY, body)
                        .putString(HourlyNotificationReceiver.KEY_LAST_DETAILS, details)
                        .apply()

                    val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
                    val alarmIntent = Intent(this, HourlyNotificationReceiver::class.java).apply {
                        putExtra("title", title)
                        putExtra("body", body)
                        putExtra("details", details)
                    }

                    val pendingIntent = PendingIntent.getBroadcast(
                        this,
                        1001,
                        alarmIntent,
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT else PendingIntent.FLAG_UPDATE_CURRENT
                    )

                    val intervalMillis = intervalMinutes * 60 * 1000L
                    val triggerAtMillis = SystemClock.elapsedRealtime() + intervalMillis

                    try {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                            alarmManager.setAndAllowWhileIdle(AlarmManager.ELAPSED_REALTIME_WAKEUP, triggerAtMillis, pendingIntent)
                        } else {
                            alarmManager.setInexactRepeating(AlarmManager.ELAPSED_REALTIME_WAKEUP, triggerAtMillis, intervalMillis, pendingIntent)
                        }
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("ALARM_ERROR", e.message, null)
                    }
                }

                "cancelNotifications" -> {
                    val prefs = getSharedPreferences(HourlyNotificationReceiver.PREFS_NAME, Context.MODE_PRIVATE)
                    prefs.edit().putBoolean(HourlyNotificationReceiver.KEY_ENABLED, false).apply()

                    val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
                    val alarmIntent = Intent(this, HourlyNotificationReceiver::class.java)
                    val pendingIntent = PendingIntent.getBroadcast(
                        this,
                        1001,
                        alarmIntent,
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_NO_CREATE else PendingIntent.FLAG_NO_CREATE
                    )

                    if (pendingIntent != null) {
                        alarmManager.cancel(pendingIntent)
                        pendingIntent.cancel()
                    }

                    val notificationManager = NotificationManagerCompat.from(this)
                    notificationManager.cancel(HourlyNotificationReceiver.NOTIFICATION_ID)

                    result.success(true)
                }

                "openUrl" -> {
                    val url = call.argument<String>("url")
                    if (!url.isNullOrEmpty()) {
                        try {
                            val intent = Intent(Intent.ACTION_VIEW, android.net.Uri.parse(url)).apply {
                                flags = Intent.FLAG_ACTIVITY_NEW_TASK
                            }
                            startActivity(intent)
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("OPEN_URL_FAILED", e.message, null)
                        }
                    } else {
                        result.error("INVALID_URL", "URL was empty", null)
                    }
                }

                else -> result.notImplemented()
            }
        }
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == PERMISSION_REQUEST_CODE) {
            val granted = grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED
            pendingResult?.success(granted)
            pendingResult = null
        }
    }
}
