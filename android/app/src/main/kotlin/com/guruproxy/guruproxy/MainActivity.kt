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
import android.os.Handler
import android.os.Looper
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import ca.psiphon.PsiphonTunnel
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject
import java.util.concurrent.atomic.AtomicInteger

class MainActivity : FlutterActivity(), PsiphonTunnel.HostService {
    companion object {
        private const val NOTIF_CHANNEL = "guruproxy/session_notification"
        private const val TUNNEL_CHANNEL = "guruproxy/android_tunnel"
        private const val TUNNEL_EVENTS = "guruproxy/android_tunnel_events"
        private const val NOTIF_CHANNEL_ID = "guruproxy_session"
        private const val NOTIF_ID = 2401
        private const val ACTION_STOP = "com.guruproxy.guruproxy.ACTION_STOP"
        private const val REQ_POST_NOTIF = 2402
    }

    private var notifChannel: MethodChannel? = null
    private var tunnelChannel: MethodChannel? = null
    private var eventSink: EventChannel.EventSink? = null
    private var stopReceiver: BroadcastReceiver? = null
    private var psiphonTunnel: PsiphonTunnel? = null
    private var configJson: String = "{}"
    private val httpPort = AtomicInteger(0)
    private val socksPort = AtomicInteger(0)
    private val mainHandler = Handler(Looper.getMainLooper())

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        psiphonTunnel = PsiphonTunnel.newPsiphonTunnel(this)

        notifChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, NOTIF_CHANNEL)
        notifChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "init" -> {
                    ensureNotifChannel()
                    registerStopReceiver()
                    maybeRequestNotificationPermission()
                    result.success(null)
                }
                "show" -> {
                    showNotification(
                        call.argument<String>("title") ?: "GuruProxy",
                        call.argument<String>("body") ?: "",
                    )
                    result.success(null)
                }
                "clear" -> {
                    NotificationManagerCompat.from(this).cancel(NOTIF_ID)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        tunnelChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, TUNNEL_CHANNEL)
        tunnelChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "start" -> {
                    val cfg = call.argument<String>("config") ?: ""
                    if (cfg.isBlank()) {
                        result.error("no_config", "Empty Psiphon config", null)
                        return@setMethodCallHandler
                    }
                    configJson = cfg
                    Thread {
                        try {
                            psiphonTunnel?.stop()
                            psiphonTunnel?.startTunneling("")
                            mainHandler.post { result.success(null) }
                        } catch (e: Exception) {
                            mainHandler.post {
                                result.error("start_failed", e.message, null)
                            }
                        }
                    }.start()
                }
                "stop" -> {
                    Thread {
                        try {
                            psiphonTunnel?.stop()
                            mainHandler.post { result.success(null) }
                        } catch (e: Exception) {
                            mainHandler.post {
                                result.error("stop_failed", e.message, null)
                            }
                        }
                    }.start()
                }
                else -> result.notImplemented()
            }
        }

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, TUNNEL_EVENTS)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    eventSink = events
                }

                override fun onCancel(arguments: Any?) {
                    eventSink = null
                }
            })
    }

    private fun emit(map: Map<String, Any?>) {
        mainHandler.post {
            eventSink?.success(map)
        }
    }

    // ---- PsiphonTunnel.HostService ----

    override fun getContext(): Context = applicationContext

    override fun getPsiphonConfig(): String {
        return try {
            // Ensure DataRootDirectory exists if present in JSON.
            val obj = JSONObject(configJson)
            if (obj.has("DataRootDirectory")) {
                val root = obj.getString("DataRootDirectory")
                java.io.File(root).mkdirs()
            }
            obj.toString()
        } catch (_: Exception) {
            configJson
        }
    }

    override fun onDiagnosticMessage(message: String?) {
        if (message != null) emit(mapOf("type" to "diagnostic", "message" to message))
    }

    override fun onAvailableEgressRegions(regions: MutableList<String>?) {
        emit(mapOf("type" to "regions", "regions" to (regions ?: emptyList<String>())))
    }

    override fun onSocksProxyPortInUse(port: Int) {
        emit(mapOf("type" to "socks_in_use", "port" to port))
    }

    override fun onHttpProxyPortInUse(port: Int) {
        emit(mapOf("type" to "http_in_use", "port" to port))
    }

    override fun onListeningSocksProxyPort(port: Int) {
        socksPort.set(port)
        emit(mapOf("type" to "socks", "port" to port))
    }

    override fun onListeningHttpProxyPort(port: Int) {
        httpPort.set(port)
        emit(mapOf("type" to "http", "port" to port))
    }

    override fun onUpstreamProxyError(message: String?) {
        emit(mapOf("type" to "upstream_error", "message" to (message ?: "")))
    }

    override fun onConnecting() {
        emit(mapOf("type" to "connecting"))
    }

    override fun onConnected() {
        emit(
            mapOf(
                "type" to "connected",
                "socks" to socksPort.get(),
                "http" to httpPort.get(),
            ),
        )
    }

    override fun onConnectedServerRegion(region: String?) {
        emit(mapOf("type" to "region", "region" to (region ?: "")))
    }

    override fun onHomepage(url: String?) {}

    override fun onClientUpgradeDownloaded(filename: String?) {}

    override fun onClientIsLatestVersion() {}

    override fun onUntunneledAddress(address: String?) {}

    override fun onBytesTransferred(sent: Long, received: Long) {
        emit(mapOf("type" to "bytes", "sent" to sent, "received" to received))
    }

    override fun onStartedWaitingForNetworkConnectivity() {
        emit(mapOf("type" to "waiting_network"))
    }

    override fun onStoppedWaitingForNetworkConnectivity() {}

    override fun onActiveAuthorizationIDs(authorizations: MutableList<String>?) {}

    override fun onExiting() {
        emit(mapOf("type" to "exiting"))
    }

    override fun onClientRegion(region: String?) {}

    override fun onClientAddress(address: String?) {}

    // ---- notifications ----

    private fun maybeRequestNotificationPermission() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) return
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.POST_NOTIFICATIONS)
            == PackageManager.PERMISSION_GRANTED
        ) {
            return
        }
        requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), REQ_POST_NOTIF)
    }

    private fun ensureNotifChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val mgr = getSystemService(NotificationManager::class.java) ?: return
        mgr.createNotificationChannel(
            NotificationChannel(
                NOTIF_CHANNEL_ID,
                "GuruProxy session",
                NotificationManager.IMPORTANCE_LOW,
            ).apply { description = "Connection status, speeds, and Stop" },
        )
    }

    private fun registerStopReceiver() {
        if (stopReceiver != null) return
        stopReceiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context?, intent: Intent?) {
                if (intent?.action == ACTION_STOP) {
                    notifChannel?.invokeMethod("stop", null)
                    NotificationManagerCompat.from(this@MainActivity).cancel(NOTIF_ID)
                    Thread { psiphonTunnel?.stop() }.start()
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
        ensureNotifChannel()
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
        try {
            psiphonTunnel?.stop()
        } catch (_: Exception) {
        }
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
