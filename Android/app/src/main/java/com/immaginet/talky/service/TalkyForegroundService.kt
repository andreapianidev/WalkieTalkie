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

        fun intent(applicationContext: android.content.Context): Intent =
            Intent(applicationContext, TalkyForegroundService::class.java)
    }

    inner class LocalBinder : Binder() {
        val service: TalkyForegroundService
            get() = this@TalkyForegroundService
    }

    private val binder = LocalBinder()
    private var walkieStarted = false
    private var resourcesClosed = false

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
        walkieManager = CrossPlatformWalkieManager(applicationContext)
        radioManager = RadioManager().also { manager ->
            manager.setStatusListener { status ->
                radioStatus = status
                updateForegroundNotification(isTransmitting = walkieManager.isTransmitting())
            }
        }
        updateForegroundNotification(isTransmitting = false)
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
        updateForegroundNotification(isTransmitting = walkieManager.isTransmitting())
        return START_STICKY
    }

    fun configurePermissions(microphoneGranted: Boolean, networkGranted: Boolean) {
        permissionPolicy = WalkiePermissionPolicy(
            microphoneGranted = microphoneGranted,
            networkGranted = networkGranted
        )
        if (permissionPolicy.canReceive && !walkieStarted) {
            runCatching { walkieManager.start() }
                .onSuccess { walkieStarted = true }
        }
        updateForegroundNotification(isTransmitting = walkieManager.isTransmitting())
    }

    fun setChannel(channel: String) {
        if (!permissionPolicy.canReceive) return
        walkieManager.setChannel(channel)
        walkieStarted = true
        updateForegroundNotification(isTransmitting = false)
    }

    fun restartWalkie() {
        if (!permissionPolicy.canReceive) return
        walkieManager.restart()
        walkieStarted = true
        updateForegroundNotification(isTransmitting = false)
    }

    fun startTransmitting(): TransmissionStartResult {
        if (!permissionPolicy.canTransmit) return TransmissionStartResult.PermissionDenied
        val result = walkieManager.startTransmitting()
        if (result == TransmissionStartResult.Started) {
            updateForegroundNotification(isTransmitting = true)
        }
        return result
    }

    fun stopTransmitting() {
        walkieManager.stopTransmitting()
        updateForegroundNotification(isTransmitting = false)
    }

    fun playStation(station: RadioStation) {
        stopTransmitting()
        radioManager.playStation(station)
        updateForegroundNotification(isTransmitting = false)
    }

    fun stopRadio() {
        radioManager.stop()
        updateForegroundNotification(isTransmitting = false)
    }

    fun stopAll() {
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
        runCatching { walkieManager.stopTransmitting() }
        runCatching { radioManager.close() }
        runCatching { walkieManager.close() }
        walkieStarted = false
    }

    private fun updateForegroundNotification(isTransmitting: Boolean) {
        val canUseMicrophoneType = isTransmitting && permissionPolicy.microphoneGranted
        ServiceCompat.startForeground(
            this,
            NOTIFICATION_ID,
            buildNotification(isTransmitting),
            TalkyForegroundTypePolicy.types(canUseMicrophoneType)
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
            permissionPolicy.canReceive -> getString(
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
}
