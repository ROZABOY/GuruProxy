package com.guruproxy.guruproxy

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Intent
import android.content.pm.PackageManager
import android.content.pm.ServiceInfo
import android.net.VpnService
import android.os.Build
import android.os.ParcelFileDescriptor
import android.os.PowerManager
import android.util.Log
import androidx.core.app.NotificationCompat
import java.io.File
import java.io.FileOutputStream

/**
 * Whole-device VPN: Android TUN → hev-socks5-tunnel → local Psiphon SOCKS.
 * Supports all / exclude-list / include-list app routing.
 */
class GuruProxyVpnService : VpnService() {
    companion object {
        private const val TAG = "GuruProxyVpn"
        private const val CH_ID = "guruproxy_vpn"
        private const val NOTIF_ID = 2601
        const val ACTION_START = "com.guruproxy.guruproxy.VPN_START"
        const val ACTION_STOP = "com.guruproxy.guruproxy.VPN_STOP"
        const val EXTRA_SOCKS = "socks"
        const val EXTRA_MODE = "mode" // all | exclude | include
        const val EXTRA_APPS = "apps" // comma-separated package names

        @Volatile
        var running: Boolean = false
            private set

        @Volatile
        var instance: GuruProxyVpnService? = null
            private set
    }

    private var tun: ParcelFileDescriptor? = null
    private var hev: Process? = null
    private var wakeLock: PowerManager.WakeLock? = null

    override fun onCreate() {
        super.onCreate()
        instance = this
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_STOP -> {
                stopAll()
                stopSelf()
                return START_NOT_STICKY
            }
            ACTION_START, null -> {
                val socks = intent?.getIntExtra(EXTRA_SOCKS, 17888) ?: 17888
                val mode = intent?.getStringExtra(EXTRA_MODE) ?: "all"
                val apps = (intent?.getStringExtra(EXTRA_APPS) ?: "")
                    .split(',')
                    .map { it.trim() }
                    .filter { it.isNotEmpty() }
                try {
                    startVpn(socks, mode, apps)
                } catch (e: Exception) {
                    Log.e(TAG, "VPN start failed: ${e.message}", e)
                    stopAll()
                    stopSelf()
                }
            }
        }
        return START_STICKY
    }

    private fun startVpn(socksPort: Int, mode: String, apps: List<String>) {
        ensureChannel()
        acquireWakeLock()
        val notif = buildNotification("GuruProxy VPN", "Routing device traffic…")
        if (Build.VERSION.SDK_INT >= 34) {
            startForeground(NOTIF_ID, notif, ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE)
        } else {
            startForeground(NOTIF_ID, notif)
        }

        val builder = Builder()
            .setSession("GuruProxy")
            .setMtu(8500)
            .addAddress("10.8.0.2", 32)
            .addRoute("0.0.0.0", 0)
            .addDnsServer("1.1.1.1")
            .addDnsServer("8.8.8.8")
            .setBlocking(true)

        try {
            builder.addDisallowedApplication(packageName)
        } catch (_: PackageManager.NameNotFoundException) {
        }

        when (mode) {
            "exclude" -> {
                for (pkg in apps) {
                    try {
                        builder.addDisallowedApplication(pkg)
                    } catch (_: PackageManager.NameNotFoundException) {
                        Log.w(TAG, "exclude skip missing pkg $pkg")
                    }
                }
            }
            "include" -> {
                var added = 0
                for (pkg in apps) {
                    try {
                        builder.addAllowedApplication(pkg)
                        added++
                    } catch (_: PackageManager.NameNotFoundException) {
                        Log.w(TAG, "include skip missing pkg $pkg")
                    }
                }
                if (added == 0) {
                    throw IllegalStateException("Include list empty — pick at least one app")
                }
            }
        }

        tun?.close()
        tun = builder.establish()
        if (tun == null) {
            throw IllegalStateException("VPN not prepared or revoked")
        }

        val fd = tun!!.fd
        val hevBin = extractHevBinary()
        val conf = writeHevConfig(socksPort)
        hev?.destroy()
        val pb = ProcessBuilder(hevBin.absolutePath, conf.absolutePath, fd.toString())
        pb.redirectErrorStream(true)
        pb.directory(filesDir)
        hev = pb.start()
        Thread {
            try {
                hev?.inputStream?.bufferedReader()?.forEachLine { Log.i(TAG, "hev: $it") }
            } catch (_: Exception) {
            }
        }.start()

        running = true
        Log.i(TAG, "VPN up socks=$socksPort mode=$mode apps=${apps.size}")
        updateNotification("GuruProxy VPN · On", "SOCKS 127.0.0.1:$socksPort · $mode")
    }

    private fun extractHevBinary(): File {
        val abi = Build.SUPPORTED_ABIS.firstOrNull() ?: "arm64-v8a"
        val assetName = when {
            abi.startsWith("arm64") -> "hev/hev-socks5-tunnel-android-arm64-v8a"
            abi.startsWith("armeabi") -> "hev/hev-socks5-tunnel-android-armeabi-v7a"
            abi.startsWith("x86_64") -> "hev/hev-socks5-tunnel-android-x86_64"
            abi.startsWith("x86") -> "hev/hev-socks5-tunnel-android-x86"
            else -> "hev/hev-socks5-tunnel-android-arm64-v8a"
        }
        val out = File(filesDir, "hev-socks5-tunnel")
        assets.open(assetName).use { input ->
            FileOutputStream(out).use { output -> input.copyTo(output) }
        }
        out.setExecutable(true, false)
        return out
    }

    private fun writeHevConfig(socksPort: Int): File {
        val conf = File(filesDir, "hev-socks5-tunnel.yml")
        conf.writeText(
            """
            |tunnel:
            |  mtu: 8500
            |socks5:
            |  port: $socksPort
            |  address: 127.0.0.1
            |  udp: 'udp'
            |misc:
            |  task-stack-size: 20480
            |  log-level: warn
            """.trimMargin(),
        )
        return conf
    }

    private fun stopAll() {
        running = false
        try {
            hev?.destroy()
        } catch (_: Exception) {
        }
        hev = null
        try {
            tun?.close()
        } catch (_: Exception) {
        }
        tun = null
        releaseWakeLock()
        stopForeground(STOP_FOREGROUND_REMOVE)
        Log.i(TAG, "VPN stopped")
    }

    override fun onDestroy() {
        instance = null
        stopAll()
        super.onDestroy()
    }

    override fun onRevoke() {
        stopAll()
        stopSelf()
        super.onRevoke()
    }

    private fun acquireWakeLock() {
        if (wakeLock?.isHeld == true) return
        val pm = getSystemService(POWER_SERVICE) as PowerManager
        wakeLock = pm.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "GuruProxy:VpnWake").apply {
            setReferenceCounted(false)
            acquire(6 * 60 * 60 * 1000L)
        }
    }

    private fun releaseWakeLock() {
        try {
            if (wakeLock?.isHeld == true) wakeLock?.release()
        } catch (_: Exception) {
        }
        wakeLock = null
    }

    private fun ensureChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val mgr = getSystemService(NotificationManager::class.java) ?: return
        mgr.createNotificationChannel(
            NotificationChannel(CH_ID, "GuruProxy VPN", NotificationManager.IMPORTANCE_LOW),
        )
    }

    private fun buildNotification(title: String, body: String): Notification {
        ensureChannel()
        val launch = packageManager.getLaunchIntentForPackage(packageName)
        val pi = PendingIntent.getActivity(
            this,
            0,
            launch,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val stop = PendingIntent.getService(
            this,
            1,
            Intent(this, GuruProxyVpnService::class.java).setAction(ACTION_STOP),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        return NotificationCompat.Builder(this, CH_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(title)
            .setContentText(body)
            .setContentIntent(pi)
            .setOngoing(true)
            .addAction(0, "Stop", stop)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .build()
    }

    private fun updateNotification(title: String, body: String) {
        val mgr = getSystemService(NotificationManager::class.java) ?: return
        mgr.notify(NOTIF_ID, buildNotification(title, body))
    }
}
