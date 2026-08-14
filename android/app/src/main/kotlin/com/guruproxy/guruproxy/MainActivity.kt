package com.guruproxy.guruproxy

import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    companion object {
        private const val CHANNEL = "guruproxy/session_notification"
        private const val NOTIF_CHANNEL_ID = "guruproxy_session"
        private const val NOTIF_ID = 2401
        private const val ACTION_STOP = "com.guruproxy.guruproxy.ACTION_STOP"
        private const val REQ_POST_NOTIF = 2402
    }

    private var methodChannel: MethodChannel? = null
    private var stopReceiver: BroadcastReceiver? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        methodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "init" -> {
                    ensureChannel()
                    registerStopReceiver()
                    maybeRequestNotificationPermission()
                    result.success(null)
                }
                "show" -> {
                    val title = call.argument<String>("title") ?: "GuruProxy"
                    val body = call.argument<String>("body") ?: ""
                    showNotification(title, body)
                    result.success(null)
                }
                "clear" -> {
                    NotificationManagerCompat.from(this).cancel(NOTIF_ID)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun maybeRequestNotificationPermission() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) return
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.POST_NOTIFICATIONS)
            == PackageManager.PERMISSION_GRANTED
        ) {
            return
        }
        requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), REQ_POST_NOTIF)
    }

    private fun ensureChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val mgr = getSystemService(NotificationManager::class.java) ?: return
        val channel = NotificationChannel(
            NOTIF_CHANNEL_ID,
            "GuruProxy session",
            NotificationManager.IMPORTANCE_LOW,
        ).apply {
            description = "Connection status, speeds, and Stop"
        }
        mgr.createNotificationChannel(channel)
    }

    private fun registerStopReceiver() {
        if (stopReceiver != null) return
        stopReceiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context?, intent: Intent?) {
                if (intent?.action == ACTION_STOP) {
                    methodChannel?.invokeMethod("stop", null)
                    NotificationManagerCompat.from(this@MainActivity).cancel(NOTIF_ID)
                }
            }
        }
        val filter = IntentFilter(ACTION_STOP)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(stopReceiver, filter, RECEIVER_NOT_EXPORTED)
        } else {
            @Suppress("UnspecifiedRegisterReceiverFlag")
            registerReceiver(stopReceiver, filter)
        }
    }

    private fun showNotification(title: String, body: String) {
        ensureChannel()
        val launch = packageManager.getLaunchIntentForPackage(packageName)
        val contentPi = PendingIntent.getActivity(
            this,
            0,
            launch,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val stopIntent = Intent(ACTION_STOP).setPackage(packageName)
        val stopPi = PendingIntent.getBroadcast(
            this,
            1,
            stopIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        val notification = NotificationCompat.Builder(this, NOTIF_CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(title)
            .setContentText(body)
            .setContentIntent(contentPi)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .addAction(0, "Stop", stopPi)
            .build()

        NotificationManagerCompat.from(this).notify(NOTIF_ID, notification)
    }

    override fun onDestroy() {
        stopReceiver?.let {
            try {
                unregisterReceiver(it)
            } catch (_: Exception) {
            }
        }
        stopReceiver = null
        super.onDestroy()
    }
}
