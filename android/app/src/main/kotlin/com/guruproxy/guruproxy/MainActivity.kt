package com.guruproxy.guruproxy

import android.Manifest
import android.app.Activity
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.net.VpnService
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import ca.psiphon.PsiphonTunnel
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject
import java.io.File
import java.util.concurrent.atomic.AtomicInteger

class MainActivity : FlutterActivity(), PsiphonTunnel.HostService {
    companion object {
        private const val NOTIF_CHANNEL = "guruproxy/session_notification"
        private const val TUNNEL_CHANNEL = "guruproxy/android_tunnel"
        private const val TUNNEL_EVENTS = "guruproxy/android_tunnel_events"
        private const val APPS_CHANNEL = "guruproxy/installed_apps"
        private const val NOTIF_CHANNEL_ID = "guruproxy_session"
        private const val NOTIF_ID = 2401
        private const val ACTION_STOP = "com.guruproxy.guruproxy.ACTION_STOP"
        private const val REQ_POST_NOTIF = 2402
        private const val REQ_VPN = 2602
        private const val TAG = "GuruProxy"
    }

    private var notifChannel: MethodChannel? = null
    private var tunnelChannel: MethodChannel? = null
    private var eventSink: EventChannel.EventSink? = null
    private var stopReceiver: BroadcastReceiver? = null
    private var psiphonTunnel: PsiphonTunnel? = null
    private var configJson: String = "{}"
    private var embeddedServerEntries: String = ""
    private val httpPort = AtomicInteger(0)
    private val socksPort = AtomicInteger(0)
    private val mainHandler = Handler(Looper.getMainLooper())
    private var pendingVpnResult: MethodChannel.Result? = null
    private var sessionWakeLock: PowerManager.WakeLock? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        psiphonTunnel = PsiphonTunnel.newPsiphonTunnel(this)

        notifChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, NOTIF_CHANNEL)
        notifChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "init" -> {
                    ensureNotifChannel()
                    registerStopReceiver()
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

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, APPS_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "listLaunchable" -> {
                        Thread {
                            try {
                                val list = listLaunchableApps()
                                mainHandler.post { result.success(list) }
                            } catch (e: Exception) {
                                mainHandler.post {
                                    result.error("apps_failed", e.message, null)
                                }
                            }
                        }.start()
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
                    val path = call.argument<String>("serverEntriesPath")
                    embeddedServerEntries = loadServerEntries(path)
                    Thread {
                        try {
                            acquireSessionWakeLock()
                            psiphonTunnel?.stop()
                            // Keep Psiphon in proxy mode; whole-device routing is TUN→SOCKS via GuruProxyVpnService.
                            psiphonTunnel?.setVpnMode(false)
                            psiphonTunnel?.startTunneling(embeddedServerEntries)
                            mainHandler.post { result.success(null) }
                        } catch (e: Exception) {
                            Log.e(TAG, "startTunneling failed: ${e.message}", e)
                            mainHandler.post {
                                result.error("start_failed", e.message, null)
                            }
                        }
                    }.start()
                }
                "stop" -> {
                    Thread {
                        try {
                            stopVpnService()
                            psiphonTunnel?.stop()
                            releaseSessionWakeLock()
                            mainHandler.post { result.success(null) }
                        } catch (e: Exception) {
                            mainHandler.post {
                                result.error("stop_failed", e.message, null)
                            }
                        }
                    }.start()
                }
                "prepareVpn" -> {
                    val prep = VpnService.prepare(this)
                    if (prep != null) {
                        pendingVpnResult = result
                        startActivityForResult(prep, REQ_VPN)
                    } else {
                        result.success(true)
                    }
                }
                "startVpnRouting" -> {
                    val socks = call.argument<Int>("socks") ?: socksPort.get()
                    val mode = call.argument<String>("mode") ?: "all"
                    val apps = call.argument<String>("apps") ?: ""
                    val i = Intent(this, GuruProxyVpnService::class.java).apply {
                        action = GuruProxyVpnService.ACTION_START
                        putExtra(GuruProxyVpnService.EXTRA_SOCKS, socks)
                        putExtra(GuruProxyVpnService.EXTRA_MODE, mode)
                        putExtra(GuruProxyVpnService.EXTRA_APPS, apps)
                    }
                    ContextCompat.startForegroundService(this, i)
                    result.success(null)
                }
                "stopVpnRouting" -> {
                    stopVpnService()
                    result.success(null)
                }
                "vpnRunning" -> result.success(GuruProxyVpnService.running)
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

    private fun loadServerEntries(path: String?): String {
        return try {
            if (!path.isNullOrBlank()) {
                val f = File(path)
                if (f.isFile) {
                    Log.i(TAG, "Loading server entries from ${f.length()} bytes")
                    f.readText()
                } else {
                    Log.w(TAG, "serverEntriesPath missing: $path")
                    ""
                }
            } else {
                Log.w(TAG, "No serverEntriesPath — relying on remote list only")
                ""
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed reading server entries: ${e.message}")
            ""
        }
    }

    private fun stopVpnService() {
        val i = Intent(this, GuruProxyVpnService::class.java).setAction(GuruProxyVpnService.ACTION_STOP)
        try {
            startService(i)
        } catch (_: Exception) {
        }
    }

    private fun listLaunchableApps(): List<Map<String, Any?>> {
        val pm = packageManager
        val main = Intent(Intent.ACTION_MAIN, null).addCategory(Intent.CATEGORY_LAUNCHER)
        val resolved = pm.queryIntentActivities(main, 0)
        val out = ArrayList<Map<String, Any?>>()
        val seen = HashSet<String>()
        for (ri in resolved) {
            val pkg = ri.activityInfo.packageName
            if (!seen.add(pkg) || pkg == packageName) continue
            val label = try {
                ri.loadLabel(pm)?.toString() ?: pkg
            } catch (_: Exception) {
                pkg
            }
            val system = try {
                val ai = pm.getApplicationInfo(pkg, 0)
                (ai.flags and ApplicationInfo.FLAG_SYSTEM) != 0
            } catch (_: Exception) {
                false
            }
            out.add(
                mapOf(
                    "package" to pkg,
                    "label" to label,
                    "system" to system,
                ),
            )
        }
        out.sortBy { (it["label"] as? String)?.lowercase() ?: "" }
        return out
    }

    @Deprecated("Deprecated in Android")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == REQ_VPN) {
            val ok = resultCode == Activity.RESULT_OK
            pendingVpnResult?.success(ok)
            pendingVpnResult = null
        }
    }

    private fun emit(map: Map<String, Any?>) {
        mainHandler.post { eventSink?.success(map) }
    }

    override fun getContext(): Context = applicationContext

    override fun getPsiphonConfig(): String {
        return try {
            val obj = JSONObject(configJson)
            if (obj.has("DataRootDirectory")) {
                java.io.File(obj.getString("DataRootDirectory")).mkdirs()
            }
            obj.toString()
        } catch (_: Exception) {
            configJson
        }
    }

    override fun bindToDevice(fileDescriptor: Long) {
        // When system VPN is active, protect Psiphon sockets from the TUN loop.
        val vpn = GuruProxyVpnService.instance ?: return
        if (!vpn.protect(fileDescriptor.toInt())) {
            throw IllegalStateException("VpnService.protect failed")
        }
    }

    override fun onDiagnosticMessage(message: String?) {
        if (message != null) {
            Log.i(TAG, message)
            emit(mapOf("type" to "diagnostic", "message" to message))
        }
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
        Log.i(TAG, "CONNECTED socks=${socksPort.get()} http=${httpPort.get()}")
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

    private fun acquireSessionWakeLock() {
        if (sessionWakeLock?.isHeld == true) return
        val pm = getSystemService(POWER_SERVICE) as PowerManager
        sessionWakeLock = pm.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "GuruProxy:Session").apply {
            setReferenceCounted(false)
            acquire(4 * 60 * 60 * 1000L)
        }
    }

    private fun releaseSessionWakeLock() {
        try {
            if (sessionWakeLock?.isHeld == true) sessionWakeLock?.release()
        } catch (_: Exception) {
        }
        sessionWakeLock = null
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
                    Thread {
                        stopVpnService()
                        psiphonTunnel?.stop()
                        releaseSessionWakeLock()
                    }.start()
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
        maybeRequestNotificationPermission()
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
            stopVpnService()
            psiphonTunnel?.stop()
            releaseSessionWakeLock()
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
