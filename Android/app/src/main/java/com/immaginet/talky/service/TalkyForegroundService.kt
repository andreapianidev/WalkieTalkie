package com.immaginet.talky.service

import android.Manifest
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Binder
import android.os.Build
import android.os.IBinder
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.core.app.NotificationCompat
import androidx.core.app.ServiceCompat
import androidx.core.content.ContextCompat
import com.immaginet.talky.MainActivity
import com.immaginet.talky.R
import com.immaginet.talky.net.CrossPlatformWalkieManager
import com.immaginet.talky.net.TransmissionStartResult
import com.immaginet.talky.permissions.WalkiePermissionPolicy
import com.immaginet.talky.radio.RadioManager
import com.immaginet.talky.radio.RadioStation

class TalkyForegroundService : Service() {
    companion object {
        private const val NOTIFICATION_CHANNEL_ID = "talky_background"
        private const val NOTIFICATION_ID = 1001
        private const val ACTION_STOP = "com.immaginet.talky.action.STOP_BACKGROUND"
        private const val WAKE_LOCK_TIMEOUT_MS = 10 * 60 * 1000L
        private const val WAKE_LOCK_REFRESH_MS = 9 * 60 * 1000L

        fun intent(applicationContext: android.content.Context): Intent =
            Intent(applicationContext, TalkyForegroundService::class.java)
    }

    inner class LocalBinder : Binder() {
        val service: TalkyForegroundService
            get() = this@TalkyForegroundService
    }

    private val binder = LocalBinder()
    private val mainHandler = Handler(Looper.getMainLooper())
    private val wakeLockRefresh = Runnable {
        if (::wakeLock.isInitialized && wakeLock.isHeld) {
            wakeLock.release()
        }
        updateWakeLock()
    }
    private var walkieStarted = false
    private var resourcesClosed = false
    private lateinit var wakeLock: PowerManager.WakeLock

    var isStopped by mutableStateOf(false)
        private set

    var isTransmitting by mutableStateOf(false)
        private set

    lateinit var walkieManager: CrossPlatformWalkieManager
        private set

    lateinit var radioManager: RadioManager
        private set

    var permissionPolicy by mutableStateOf(
        WalkiePermissionPolicy(microphoneGranted = false, networkGranted = false)
    )
        private set

    var radioStatus by mutableStateOf(
        RadioManager.RadioStatus(false, "", "", false, null)
    )
        private set

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        updateForegroundNotification(isTransmitting = false)
        wakeLock = getSystemService(PowerManager::class.java)
            .newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "$packageName:talky_background")
            .apply {
                setReferenceCounted(false)
            }
        walkieManager = CrossPlatformWalkieManager(applicationContext)
        walkieManager.setTransmissionStateListener(::onTransmissionStateChanged)
        radioManager = RadioManager(applicationContext).also { manager ->
            manager.setStatusListener { status ->
                runOnMainThread {
                    if (resourcesClosed || isStopped) return@runOnMainThread
                    radioStatus = status
                    updateWakeLock()
                    updateForegroundNotification(isTransmitting)
                }
            }
        }
        configurePermissions(
            microphoneGranted = hasPermission(Manifest.permission.RECORD_AUDIO),
            networkGranted = hasNearbyPermission()
        )
    }

    override fun onBind(intent: Intent?): IBinder = binder

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) {
            stopAll()
            return START_NOT_STICKY
        }
        updateForegroundNotification(isTransmitting)
        return START_STICKY
    }

    fun configurePermissions(microphoneGranted: Boolean, networkGranted: Boolean) {
        if (resourcesClosed || isStopped) return
        permissionPolicy = WalkiePermissionPolicy(
            microphoneGranted = microphoneGranted,
            networkGranted = networkGranted
        )
        if (permissionPolicy.canReceive && !walkieStarted) {
            runCatching { walkieManager.start() }
                .onSuccess { walkieStarted = true }
        } else if (!permissionPolicy.canReceive && walkieStarted) {
            walkieManager.suspendNetwork()
            walkieStarted = false
        }
        updateWakeLock()
        updateForegroundNotification(isTransmitting)
    }

    fun setChannel(channel: String) {
        if (resourcesClosed || isStopped || !permissionPolicy.canReceive) return
        walkieManager.setChannel(channel)
        walkieStarted = true
        updateForegroundNotification(isTransmitting = false)
    }

    fun restartWalkie() {
        if (resourcesClosed || isStopped || !permissionPolicy.canReceive) return
        walkieManager.restart()
        walkieStarted = true
        updateForegroundNotification(isTransmitting = false)
    }

    fun startTransmitting(): TransmissionStartResult {
        if (resourcesClosed || isStopped || !permissionPolicy.canTransmit) {
            return TransmissionStartResult.PermissionDenied
        }
        return walkieManager.startTransmitting()
    }

    fun stopTransmitting() {
        if (resourcesClosed || isStopped) return
        walkieManager.stopTransmitting()
    }

    fun playStation(station: RadioStation) {
        if (resourcesClosed || isStopped) return
        stopTransmitting()
        radioManager.playStation(station)
        updateForegroundNotification(isTransmitting = false)
    }

    fun stopRadio() {
        if (resourcesClosed || isStopped) return
        radioManager.stop()
        updateForegroundNotification(isTransmitting = false)
    }

    fun stopAll() {
        if (isStopped) return
        isStopped = true
        closeResources()
        ServiceCompat.stopForeground(this, ServiceCompat.STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    override fun onDestroy() {
        closeResources()
        super.onDestroy()
    }

    private fun closeResources() {
        if (resourcesClosed) return
        resourcesClosed = true
        isTransmitting = false
        walkieManager.setTransmissionStateListener(null)
        runCatching { walkieManager.stopTransmitting() }
        runCatching { radioManager.close() }
        runCatching { walkieManager.close() }
        mainHandler.removeCallbacks(wakeLockRefresh)
        if (::wakeLock.isInitialized && wakeLock.isHeld) {
            runCatching { wakeLock.release() }
        }
        walkieStarted = false
    }

    private fun updateForegroundNotification(isTransmitting: Boolean) {
        val canUseMicrophoneType = isTransmitting && permissionPolicy.microphoneGranted
        ServiceCompat.startForeground(
            this,
            NOTIFICATION_ID,
            buildNotification(isTransmitting),
            TalkyForegroundTypePolicy.types(
                isTransmitting = canUseMicrophoneType,
                isRadioActive = radioStatus.isPlaying || radioStatus.isBuffering
            )
        )
    }

    private fun buildNotification(isTransmitting: Boolean): Notification {
        val openAppIntent = PendingIntent.getActivity(
            this,
            0,
            Intent(this, MainActivity::class.java),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val stopIntent = PendingIntent.getService(
            this,
            1,
            intent(applicationContext).setAction(ACTION_STOP),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val content = when {
            isTransmitting -> getString(R.string.notification_transmitting)
            radioStatus.isPlaying -> getString(
                R.string.notification_radio_playing,
                radioStatus.stationName
            )
            permissionPolicy.canReceive && ::walkieManager.isInitialized -> getString(
                R.string.notification_walkie_ready,
                walkieManager.currentChannel
            )
            else -> getString(R.string.notification_radio_ready)
        }

        return NotificationCompat.Builder(this, NOTIFICATION_CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_launcher_foreground)
            .setContentTitle(getString(R.string.notification_title))
            .setContentText(content)
            .setContentIntent(openAppIntent)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .addAction(
                android.R.drawable.ic_menu_close_clear_cancel,
                getString(R.string.notification_stop),
                stopIntent
            )
            .build()
    }

    private fun createNotificationChannel() {
        val channel = NotificationChannel(
            NOTIFICATION_CHANNEL_ID,
            getString(R.string.notification_channel_name),
            NotificationManager.IMPORTANCE_LOW
        ).apply {
            description = getString(R.string.notification_channel_description)
            setShowBadge(false)
        }
        getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
    }

    private fun hasPermission(permission: String): Boolean =
        ContextCompat.checkSelfPermission(this, permission) == PackageManager.PERMISSION_GRANTED

    private fun hasNearbyPermission(): Boolean =
        Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU ||
            hasPermission(Manifest.permission.NEARBY_WIFI_DEVICES)

    private fun onTransmissionStateChanged(active: Boolean) {
        runOnMainThread {
            if (resourcesClosed || isStopped) return@runOnMainThread
            isTransmitting = active
            updateWakeLock()
            updateForegroundNotification(active)
        }
    }

    private fun updateWakeLock() {
        if (!::wakeLock.isInitialized) return
        mainHandler.removeCallbacks(wakeLockRefresh)
        val shouldHold = !resourcesClosed &&
            !isStopped &&
            TalkyWakeLockPolicy.shouldHold(isTransmitting = isTransmitting)
        if (shouldHold && !wakeLock.isHeld) {
            wakeLock.acquire(WAKE_LOCK_TIMEOUT_MS)
        } else if (!shouldHold && wakeLock.isHeld) {
            wakeLock.release()
        }
        if (shouldHold) {
            mainHandler.postDelayed(wakeLockRefresh, WAKE_LOCK_REFRESH_MS)
        }
    }

    private inline fun runOnMainThread(crossinline action: () -> Unit) {
        if (Looper.myLooper() == Looper.getMainLooper()) {
            action()
        } else {
            mainHandler.post { action() }
        }
    }
}
