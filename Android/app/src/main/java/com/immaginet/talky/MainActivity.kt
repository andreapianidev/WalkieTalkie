package com.immaginet.talky

import android.Manifest
import android.app.Activity
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.ServiceConnection
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import android.os.IBinder
import androidx.activity.ComponentActivity
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilterChip
import androidx.compose.material3.FilterChipDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.core.content.ContextCompat
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.scale
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.immaginet.talky.net.CrossPlatformPeer
import com.immaginet.talky.net.TransmissionStartResult
import com.google.firebase.FirebaseApp
import com.immaginet.talky.ads.AdBanner
import com.immaginet.talky.ads.AdManager
import com.immaginet.talky.firebase.FirebaseManager
import com.immaginet.talky.protocol.PrivateChannelId
import com.immaginet.talky.radio.RadioManager
import com.immaginet.talky.radio.RadioStation
import com.immaginet.talky.service.TalkyForegroundService
import com.immaginet.talky.ui.OnboardingScreen
import com.immaginet.talky.ui.hasSeenOnboarding
import com.immaginet.talky.ui.markOnboardingSeen
import com.immaginet.talky.ui.theme.WalkieTalkieAndroidTheme

class MainActivity : ComponentActivity() {
    private var talkyService by mutableStateOf<TalkyForegroundService?>(null)
    private var bindingActive = false

    private val serviceConnection = object : ServiceConnection {
        override fun onServiceConnected(name: ComponentName?, binder: IBinder?) {
            talkyService = (binder as? TalkyForegroundService.LocalBinder)?.service
        }

        override fun onServiceDisconnected(name: ComponentName?) {
            talkyService = null
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        FirebaseManager.init(FirebaseApp.getInstance())
        AdManager.gatherConsentAndInitialize(this)
        ContextCompat.startForegroundService(
            this,
            TalkyForegroundService.intent(applicationContext)
        )
        enableEdgeToEdge()
        setContent {
            WalkieTalkieAndroidTheme {
                TalkyRoot(talkyService)
            }
        }
    }

    override fun onStart() {
        super.onStart()
        if (!bindingActive) {
            bindingActive = bindService(
                TalkyForegroundService.intent(applicationContext),
                serviceConnection,
                Context.BIND_AUTO_CREATE
            )
        }
    }

    override fun onStop() {
        talkyService?.stopTransmitting()
        if (bindingActive) {
            unbindService(serviceConnection)
            bindingActive = false
        }
        talkyService = null
        super.onStop()
    }
}

internal enum class AppMode { WALKIE, RADIO }

internal fun initialAppMode(savedMode: AppMode?, radioIsPlaying: Boolean): AppMode =
    savedMode ?: if (radioIsPlaying) AppMode.RADIO else AppMode.WALKIE

@Composable
private fun TalkyRoot(service: TalkyForegroundService?) {
    val context = LocalContext.current
    var permissionsRequested by rememberSaveable { mutableStateOf(false) }
    var appMode by rememberSaveable { mutableStateOf<AppMode?>(null) }
    // L'onboarding precede i prompt di sistema: spiega a cosa serve il microfono
    // prima che Android lo chieda, ed e' l'unico posto in cui l'utente legge che
    // serve la stessa rete Wi-Fi.
    var onboardingDone by rememberSaveable { mutableStateOf(hasSeenOnboarding(context)) }
    val permissionLauncher = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.RequestMultiplePermissions()
    ) { results ->
        service?.configurePermissions(
            microphoneGranted = results[Manifest.permission.RECORD_AUDIO]
                ?: hasPermission(context, Manifest.permission.RECORD_AUDIO),
            networkGranted = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                results[Manifest.permission.NEARBY_WIFI_DEVICES]
                    ?: hasPermission(context, Manifest.permission.NEARBY_WIFI_DEVICES)
            } else {
                true
            }
        )
    }

    LaunchedEffect(onboardingDone) {
        if (onboardingDone && !permissionsRequested) {
            permissionsRequested = true
            permissionLauncher.launch(requiredPermissions())
        }
    }

    LaunchedEffect(service) {
        service?.configurePermissions(
            microphoneGranted = hasPermission(context, Manifest.permission.RECORD_AUDIO),
            networkGranted = hasNearbyPermission(context)
        )
        if (service != null && appMode == null) {
            appMode = initialAppMode(appMode, service.radioStatus.isPlaying)
        }
    }

    LaunchedEffect(service?.isStopped) {
        if (service?.isStopped == true) {
            (context as? Activity)?.finish()
        }
    }

    if (!onboardingDone) {
        OnboardingScreen(onFinish = {
            markOnboardingSeen(context)
            onboardingDone = true
        })
        return
    }

    val resolvedMode = appMode
    if (service == null || service.isStopped || resolvedMode == null) {
        Box(
            modifier = Modifier
                .fillMaxSize()
                .background(Color(0xFF0C1117)),
            contentAlignment = Alignment.Center
        ) {
            Text(stringResource(R.string.app_starting), color = Color(0xFFEAF4D3))
        }
        return
    }

    TalkyApp(
        service = service,
        appMode = resolvedMode,
        onModeChange = { newMode ->
            if (newMode == AppMode.WALKIE) {
                service.stopRadio()
            } else {
                service.stopTransmitting()
            }
            appMode = newMode
        },
        onRequestMicrophone = {
            permissionLauncher.launch(arrayOf(Manifest.permission.RECORD_AUDIO))
        }
    )
}

private fun requiredPermissions(): Array<String> = buildList {
    add(Manifest.permission.RECORD_AUDIO)
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
        add(Manifest.permission.POST_NOTIFICATIONS)
        add(Manifest.permission.NEARBY_WIFI_DEVICES)
    }
}.toTypedArray()

private fun hasPermission(context: Context, permission: String): Boolean =
    ContextCompat.checkSelfPermission(context, permission) == PackageManager.PERMISSION_GRANTED

private fun hasNearbyPermission(context: Context): Boolean =
    Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU ||
        hasPermission(context, Manifest.permission.NEARBY_WIFI_DEVICES)

@Composable
private fun TalkyApp(
    service: TalkyForegroundService,
    appMode: AppMode,
    onModeChange: (AppMode) -> Unit,
    onRequestMicrophone: () -> Unit
) {
    val walkieManager = service.walkieManager
    val radioManager = service.radioManager
    val isTransmitting = service.isTransmitting
    val receivingAudio = walkieManager.remoteAudioActive
    val radioStatus = service.radioStatus

    val channels = remember {
        listOf("public", "ch1", "ch2", "ch3", "ch4", "ch5", "ch6", "ch7", "ch8")
    }
    val privateChannelLabel = stringResource(R.string.channel_private)

    Scaffold { innerPadding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .background(
                    Brush.verticalGradient(
                        colors = listOf(Color(0xFF0C1117), Color(0xFF17251E), Color(0xFF07090C))
                    )
                )
                .padding(innerPadding)
                .padding(horizontal = 20.dp, vertical = 12.dp),
            verticalArrangement = Arrangement.spacedBy(14.dp)
        ) {
            Header(
                status = walkieManager.status,
                isConnected = walkieManager.isConnected,
                appMode = appMode,
                radioStatus = radioStatus,
                channel = if (walkieManager.currentChannel in channels) {
                    walkieManager.currentChannel
                } else {
                    privateChannelLabel
                },
                onModeToggle = {
                    onModeChange(
                        if (appMode == AppMode.WALKIE) AppMode.RADIO else AppMode.WALKIE
                    )
                }
            )

            ModeToggle(appMode = appMode, onToggle = {
                onModeChange(
                    if (appMode == AppMode.WALKIE) AppMode.RADIO else AppMode.WALKIE
                )
            })

            when (appMode) {
                AppMode.WALKIE -> WalkieContent(
                    channel = walkieManager.currentChannel,
                    channels = channels,
                    isConnected = walkieManager.isConnected,
                    isTransmitting = isTransmitting,
                    receivingAudio = receivingAudio,
                    peers = walkieManager.discoveredPeers,
                    events = walkieManager.events,
                    onChannelChange = service::setChannel,
                    onPTTPress = {
                        when (service.startTransmitting()) {
                            TransmissionStartResult.Started -> {
                                FirebaseManager.trackPTTUsed(walkieManager.currentChannel)
                            }
                            TransmissionStartResult.PermissionDenied -> onRequestMicrophone()
                            else -> Unit
                        }
                    },
                    onPTTRelease = {
                        service.stopTransmitting()
                    },
                    onRestart = service::restartWalkie
                )
                AppMode.RADIO -> RadioContent(
                    radioManager = radioManager,
                    status = radioStatus,
                    onRadioStop = service::stopRadio,
                    onStationPlay = { station ->
                        FirebaseManager.trackRadioUsage(station.name, station.country)
                        service.playStation(station)
                    }
                )
            }
            AdBanner()
        }
    }
}

@Composable
private fun ModeToggle(appMode: AppMode, onToggle: () -> Unit) {
    Card(
        colors = CardDefaults.cardColors(containerColor = Color(0xFF0D1216)),
        shape = RoundedCornerShape(12.dp),
        modifier = Modifier.fillMaxWidth()
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.Center
        ) {
            Box(modifier = Modifier.weight(1f)) {
                ModeTab(
                    text = stringResource(R.string.mode_walkie),
                    isActive = appMode == AppMode.WALKIE,
                    onClick = { if (appMode != AppMode.WALKIE) onToggle() }
                )
            }
            Box(modifier = Modifier.weight(1f)) {
                ModeTab(
                    text = stringResource(R.string.mode_radio),
                    isActive = appMode == AppMode.RADIO,
                    onClick = { if (appMode != AppMode.RADIO) onToggle() }
                )
            }
        }
    }
}

@Composable
private fun ModeTab(text: String, isActive: Boolean, onClick: () -> Unit) {
    Box(
        modifier = Modifier
            .clip(RoundedCornerShape(12.dp))
            .background(if (isActive) Color(0xFF1A2E1A) else Color.Transparent)
            .clickable(onClick = onClick)
            .padding(vertical = 12.dp),
        contentAlignment = Alignment.Center
    ) {
        Text(
            text = text,
            color = if (isActive) Color(0xFF6CFF7A) else Color(0xFF556655),
            style = MaterialTheme.typography.labelLarge,
            fontWeight = if (isActive) FontWeight.Bold else FontWeight.Normal
        )
    }
}

@Composable
private fun Header(
    status: String,
    isConnected: Boolean,
    appMode: AppMode,
    radioStatus: RadioManager.RadioStatus,
    channel: String,
    onModeToggle: () -> Unit
) {
    Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text(
                text = "Talky",
                color = Color(0xFFEAF4D3),
                style = MaterialTheme.typography.headlineLarge,
                fontWeight = FontWeight.Black
            )
            if (appMode == AppMode.WALKIE) {
                StatusPill(text = status, isActive = isConnected)
            } else {
                StatusPill(
                    text = if (radioStatus.isPlaying) {
                        radioStatus.stationName
                    } else {
                        stringResource(R.string.header_radio_idle)
                    },
                    isActive = radioStatus.isPlaying
                )
            }
        }
        if (appMode == AppMode.WALKIE && channel.isNotBlank()) {
            Text(
                text = stringResource(R.string.header_channel, channel),
                color = Color(0xFF8FA889),
                style = MaterialTheme.typography.bodySmall
            )
        }
    }
}

@Composable
private fun StatusPill(text: String, isActive: Boolean) {
    val color = if (isActive) Color(0xFF38F778) else Color(0xFF8FA889)
    Row(
        modifier = Modifier
            .clip(RoundedCornerShape(999.dp))
            .background(color.copy(alpha = 0.12f))
            .border(1.dp, color.copy(alpha = 0.4f), RoundedCornerShape(999.dp))
            .padding(horizontal = 10.dp, vertical = 6.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Box(
            modifier = Modifier
                .size(8.dp)
                .clip(CircleShape)
                .background(color)
        )
        Spacer(modifier = Modifier.width(6.dp))
        Text(
            text = text,
            color = Color(0xFFDDF5D2),
            style = MaterialTheme.typography.labelSmall,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
            modifier = Modifier.weight(1f, fill = false)
        )
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun ChannelChips(
    channel: String,
    channels: List<String>,
    onChannelChange: (String) -> Unit,
    onPrivateChannelClick: () -> Unit
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .horizontalScroll(rememberScrollState()),
        horizontalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        channels.forEach { ch ->
            FilterChip(
                selected = ch == channel,
                onClick = { onChannelChange(ch) },
                label = {
                    Text(
                        ch,
                        style = MaterialTheme.typography.labelSmall
                    )
                },
                colors = FilterChipDefaults.filterChipColors(
                    containerColor = Color(0xFF121A16),
                    selectedContainerColor = Color(0xFF1A3A1A),
                    labelColor = Color(0xFF9CB59A),
                    selectedLabelColor = Color(0xFF6CFF7A)
                ),
                border = FilterChipDefaults.filterChipBorder(
                    borderColor = Color(0xFF2A3A2A),
                    selectedBorderColor = Color(0xFF3A7A3A),
                    enabled = true,
                    selected = ch == channel
                )
            )
        }
        FilterChip(
            selected = channel !in channels,
            onClick = onPrivateChannelClick,
            label = {
                Text(
                    stringResource(R.string.channel_private),
                    style = MaterialTheme.typography.labelSmall
                )
            },
            colors = FilterChipDefaults.filterChipColors(
                containerColor = Color(0xFF121A16),
                selectedContainerColor = Color(0xFF1A3A1A),
                labelColor = Color(0xFF9CB59A),
                selectedLabelColor = Color(0xFF6CFF7A)
            ),
            border = FilterChipDefaults.filterChipBorder(
                borderColor = Color(0xFF2A3A2A),
                selectedBorderColor = Color(0xFF3A7A3A),
                enabled = true,
                selected = channel !in channels
            )
        )
    }
}

@Composable
private fun FrequencyDisplay(channel: String, isTransmitting: Boolean) {
    val freq = when (channel) {
        "public" -> "462.562"
        "ch1" -> "462.587"
        "ch2" -> "462.612"
        "ch3" -> "462.637"
        "ch4" -> "462.662"
        "ch5" -> "462.687"
        "ch6" -> "462.712"
        "ch7" -> "467.562"
        "ch8" -> "467.587"
        else -> stringResource(R.string.channel_private_caps)
    }
    val displayColor = when {
        isTransmitting -> Color(0xFFFF4444)
        else -> Color(0xFFFFB347)
    }
    Card(
        colors = CardDefaults.cardColors(containerColor = Color(0xFF050A08)),
        shape = RoundedCornerShape(6.dp),
        modifier = Modifier.fillMaxWidth()
    ) {
        Row(
            modifier = Modifier
                .padding(horizontal = 16.dp, vertical = 10.dp)
                .fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text(
                text = freq,
                color = displayColor,
                fontSize = 28.sp,
                fontWeight = FontWeight.Black
            )
            Text(
                text = if (channel in listOf(
                        "public", "ch1", "ch2", "ch3", "ch4", "ch5", "ch6", "ch7", "ch8"
                    )
                ) {
                    stringResource(R.string.freq_unit_mhz)
                } else {
                    stringResource(R.string.freq_unit_channel)
                },
                color = displayColor.copy(alpha = 0.5f),
                fontSize = 12.sp,
                fontWeight = FontWeight.Bold
            )
        }
    }
}

@Composable
private fun SpeakerGrid(modifier: Modifier = Modifier) {
    Card(
        colors = CardDefaults.cardColors(containerColor = Color(0xFF050A08)),
        shape = RoundedCornerShape(6.dp),
        modifier = modifier.fillMaxWidth()
    ) {
        LazyVerticalGrid(
            columns = GridCells.Fixed(15),
            modifier = Modifier.padding(12.dp),
            verticalArrangement = Arrangement.spacedBy(4.dp),
            horizontalArrangement = Arrangement.spacedBy(4.dp),
            userScrollEnabled = false
        ) {
            items(90) {
                Box(
                    modifier = Modifier
                        .clip(CircleShape)
                        .background(Color(0xFF8FA889).copy(alpha = 0.3f))
                        .aspectRatio(1f)
                )
            }
        }
    }
}

@Composable
private fun WalkieContent(
    channel: String,
    channels: List<String>,
    isConnected: Boolean,
    isTransmitting: Boolean,
    receivingAudio: Boolean,
    peers: List<CrossPlatformPeer>,
    events: List<String>,
    onChannelChange: (String) -> Unit,
    onPTTPress: () -> Unit,
    onPTTRelease: () -> Unit,
    onRestart: () -> Unit
) {
    var showPrivateChannelDialog by rememberSaveable { mutableStateOf(false) }

    Column(verticalArrangement = Arrangement.spacedBy(14.dp)) {
        FrequencyDisplay(channel = channel, isTransmitting = isTransmitting)

        ChannelChips(
            channel = channel,
            channels = channels,
            onChannelChange = onChannelChange,
            onPrivateChannelClick = { showPrivateChannelDialog = true }
        )

        SpeakerGrid(modifier = Modifier.height(44.dp))

        PushToTalkPanel(
            isTransmitting = isTransmitting,
            isConnected = isConnected,
            receivingAudio = receivingAudio,
            onPress = onPTTPress,
            onRelease = onPTTRelease
        )

        AnimatedVisibility(
            visible = receivingAudio,
            enter = fadeIn(),
            exit = fadeOut()
        ) {
            ReceivingIndicator()
        }

        PeerList(peers = peers)

        EventLog(events = events, onRestart = onRestart)
    }

    if (showPrivateChannelDialog) {
        PrivateChannelDialog(
            onDismiss = { showPrivateChannelDialog = false },
            onConfirm = { privateChannel ->
                showPrivateChannelDialog = false
                onChannelChange(privateChannel)
            }
        )
    }
}

@Composable
private fun PrivateChannelDialog(
    onDismiss: () -> Unit,
    onConfirm: (String) -> Unit
) {
    var password by remember { mutableStateOf("") }
    val passwordIsValid = password.length >= PrivateChannelId.MIN_PASSWORD_LENGTH

    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text(stringResource(R.string.private_dialog_title)) },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                Text(
                    stringResource(R.string.private_dialog_body)
                )
                OutlinedTextField(
                    value = password,
                    onValueChange = { password = it },
                    label = { Text(stringResource(R.string.private_dialog_password)) },
                    supportingText = {
                        Text(
                            stringResource(
                                R.string.private_dialog_password_hint,
                                PrivateChannelId.MIN_PASSWORD_LENGTH
                            )
                        )
                    },
                    singleLine = true,
                    visualTransformation = PasswordVisualTransformation(),
                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Password)
                )
                Text(
                    stringResource(R.string.private_dialog_warning),
                    style = MaterialTheme.typography.bodySmall,
                    color = Color(0xFF8FA889)
                )
            }
        },
        confirmButton = {
            TextButton(
                enabled = passwordIsValid,
                onClick = { onConfirm(PrivateChannelId.fromPassword(password)) }
            ) {
                Text(stringResource(R.string.private_dialog_join))
            }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) {
                Text(stringResource(R.string.private_dialog_cancel))
            }
        }
    )
}

@Composable
private fun ReceivingIndicator() {
    val infiniteTransition = rememberInfiniteTransition(label = "rx")
    val alpha by infiniteTransition.animateFloat(
        initialValue = 0.4f,
        targetValue = 1f,
        animationSpec = infiniteRepeatable(
            animation = tween(500, easing = LinearEasing),
            repeatMode = RepeatMode.Reverse
        ),
        label = "rxAlpha"
    )
    Card(
        colors = CardDefaults.cardColors(containerColor = Color(0xFF1A0A0A)),
        shape = RoundedCornerShape(8.dp),
        modifier = Modifier.fillMaxWidth()
    ) {
        Row(
            modifier = Modifier
                .padding(10.dp)
                .fillMaxWidth(),
            horizontalArrangement = Arrangement.Center,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Box(
                modifier = Modifier
                    .size(8.dp)
                    .clip(CircleShape)
                    .background(Color(0xFFFF3333).copy(alpha = alpha))
            )
            Spacer(modifier = Modifier.width(8.dp))
            Text(
                text = stringResource(R.string.rx_in_progress),
                color = Color(0xFFFF6666).copy(alpha = alpha),
                style = MaterialTheme.typography.labelLarge,
                fontWeight = FontWeight.Bold
            )
        }
    }
}

@Composable
private fun PushToTalkPanel(
    isTransmitting: Boolean,
    isConnected: Boolean,
    receivingAudio: Boolean,
    onPress: () -> Unit,
    onRelease: () -> Unit
) {
    val scale = if (isTransmitting) 0.92f else 1f
    Card(
        colors = CardDefaults.cardColors(containerColor = Color(0xFF121A16)),
        shape = RoundedCornerShape(8.dp),
        modifier = Modifier.fillMaxWidth()
    ) {
        Column(
            modifier = Modifier.padding(16.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(10.dp)
        ) {
            Box(
                modifier = Modifier
                    .size(130.dp)
                    .scale(scale)
                    .clip(CircleShape)
                    .background(
                        when {
                            isTransmitting -> Brush.radialGradient(
                                colors = listOf(Color(0xFFFF4444), Color(0xFFCC2222), Color(0xFF330808))
                            )
                            isConnected && !receivingAudio -> Brush.radialGradient(
                                colors = listOf(Color(0xFF6CFF7A), Color(0xFF1E7C3B), Color(0xFF0C1711))
                            )
                            else -> Brush.radialGradient(
                                colors = listOf(Color(0xFF445544), Color(0xFF223322), Color(0xFF0A110C))
                            )
                        }
                    )
                    .border(
                        2.dp,
                        when {
                            isTransmitting -> Color(0xFFFF6666)
                            isConnected && !receivingAudio -> Color(0xFFB9FFC2)
                            else -> Color(0xFF445544)
                        },
                        CircleShape
                    )
                    .pointerInput(isConnected, receivingAudio) {
                        detectTapGestures(
                            onPress = {
                                if (isConnected && !receivingAudio) {
                                    onPress()
                                    tryAwaitRelease()
                                    onRelease()
                                }
                            }
                        )
                    },
                contentAlignment = Alignment.Center
            ) {
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    Text(
                        text = stringResource(
                            if (isTransmitting) R.string.ptt_tx else R.string.ptt_idle
                        ),
                        color = Color(0xFF061009),
                        fontSize = 28.sp,
                        fontWeight = FontWeight.Black
                    )
                    Text(
                        text = stringResource(
                            when {
                                isTransmitting -> R.string.ptt_badge_on_air
                                receivingAudio -> R.string.ptt_badge_rx
                                isConnected -> R.string.ptt_badge_press
                                else -> R.string.ptt_badge_none
                            }
                        ),
                        color = Color(0xFF061009).copy(alpha = 0.7f),
                        fontSize = 10.sp,
                        fontWeight = FontWeight.Bold
                    )
                }
            }
            Text(
                text = stringResource(
                    when {
                        isTransmitting -> R.string.ptt_hint_transmitting
                        receivingAudio -> R.string.ptt_hint_receiving
                        isConnected -> R.string.ptt_hint_ready
                        else -> R.string.ptt_hint_waiting
                    }
                ),
                color = if (isTransmitting) Color(0xFFFFAAAA) else Color(0xFF9CB59A),
                style = MaterialTheme.typography.bodySmall,
                textAlign = TextAlign.Center
            )
        }
    }
}

@Composable
private fun PeerList(peers: List<CrossPlatformPeer>) {
    Card(
        colors = CardDefaults.cardColors(containerColor = Color(0xFF10161C)),
        shape = RoundedCornerShape(8.dp),
        modifier = Modifier.fillMaxWidth()
    ) {
        Column(modifier = Modifier.padding(14.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                Text(
                    text = stringResource(R.string.peers_title),
                    color = Color(0xFFEAF4D3),
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.Bold
                )
                if (peers.isNotEmpty()) {
                    Text("(${peers.size})", color = Color(0xFF6CFF7A), style = MaterialTheme.typography.labelSmall)
                }
            }
            if (peers.isEmpty()) {
                Text(
                    text = stringResource(R.string.peers_empty),
                    color = Color(0xFF87968B),
                    style = MaterialTheme.typography.bodyMedium
                )
            } else {
                peers.forEach { peer ->
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(8.dp)
                    ) {
                        Box(
                            modifier = Modifier
                                .size(8.dp)
                                .clip(CircleShape)
                                .background(Color(0xFF38F778))
                        )
                        Column {
                            Text(peer.name, color = Color(0xFFCFE6CA), style = MaterialTheme.typography.bodyMedium, maxLines = 1, overflow = TextOverflow.Ellipsis)
                            Text("${peer.host}:${peer.port} - ${peer.channel}", color = Color(0xFF8FA889), style = MaterialTheme.typography.bodySmall)
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun EventLog(events: List<String>, onRestart: () -> Unit) {
    Card(
        colors = CardDefaults.cardColors(containerColor = Color(0xFF0D1216)),
        shape = RoundedCornerShape(8.dp),
        modifier = Modifier.fillMaxWidth()
    ) {
        Column(modifier = Modifier.padding(14.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(stringResource(R.string.log_title), color = Color(0xFFEAF4D3), style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold)
                Button(
                    onClick = onRestart,
                    colors = ButtonDefaults.buttonColors(containerColor = Color(0xFF1A2E1A)),
                    contentPadding = PaddingValues(horizontal = 12.dp, vertical = 4.dp)
                ) { Text(stringResource(R.string.log_restart), fontSize = 12.sp) }
            }
            LazyColumn(modifier = Modifier.height(100.dp), reverseLayout = true) {
                items(events.reversed()) { event ->
                    Text(event, color = Color(0xFF9CB59A), style = MaterialTheme.typography.bodySmall)
                }
            }
        }
    }
}

@Composable
private fun RadioContent(
    radioManager: RadioManager,
    status: RadioManager.RadioStatus,
    onRadioStop: () -> Unit,
    onStationPlay: (RadioStation) -> Unit
) {
    Column(verticalArrangement = Arrangement.spacedBy(14.dp)) {
        Card(
            colors = CardDefaults.cardColors(containerColor = Color(0xFF121A16)),
            shape = RoundedCornerShape(8.dp),
            modifier = Modifier.fillMaxWidth()
        ) {
            Column(
                modifier = Modifier.padding(16.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                Text(
                    text = if (status.isPlaying || status.isBuffering) {
                        status.stationName
                    } else {
                        stringResource(R.string.radio_select_station)
                    },
                    color = Color(0xFFEAF4D3),
                    style = MaterialTheme.typography.titleLarge,
                    fontWeight = FontWeight.Bold,
                    textAlign = TextAlign.Center
                )
                if (status.isPlaying || status.isBuffering) {
                    Text(
                        text = status.stationCountry,
                        color = Color(0xFF8FA889),
                        style = MaterialTheme.typography.bodyMedium
                    )
                }
                if (status.isBuffering) {
                    Text(
                        text = stringResource(R.string.radio_buffering),
                        color = Color(0xFFFFB347),
                        style = MaterialTheme.typography.bodySmall
                    )
                }
                status.error?.let { err ->
                    Text(text = err, color = Color(0xFFFF6666), style = MaterialTheme.typography.bodySmall)
                }
                if (status.isPlaying || status.isBuffering) {
                    Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                        Button(
                            onClick = {
                                radioManager.getPreviousStation()?.let(onStationPlay)
                            },
                            colors = ButtonDefaults.buttonColors(containerColor = Color(0xFF1A2E1A))
                        ) { Text(stringResource(R.string.radio_prev)) }
                        Button(
                            onClick = onRadioStop,
                            colors = ButtonDefaults.buttonColors(containerColor = Color(0xFF3A1A1A))
                        ) { Text(stringResource(R.string.radio_stop)) }
                        Button(
                            onClick = {
                                radioManager.getNextStation()?.let(onStationPlay)
                            },
                            colors = ButtonDefaults.buttonColors(containerColor = Color(0xFF1A2E1A))
                        ) { Text(stringResource(R.string.radio_next)) }
                    }
                }
            }
        }

        Text(
            text = stringResource(R.string.radio_stations_count, RadioManager.stations.size),
            color = Color(0xFFEAF4D3),
            style = MaterialTheme.typography.titleMedium,
            fontWeight = FontWeight.Bold
        )

        LazyColumn(
            modifier = Modifier.weight(1f),
            verticalArrangement = Arrangement.spacedBy(6.dp)
        ) {
            items(RadioManager.stations) { station ->
                val isCurrent = radioManager.getCurrentStationId() == station.id
                Card(
                    colors = CardDefaults.cardColors(
                        containerColor = if (isCurrent) Color(0xFF1A2E1A) else Color(0xFF0D1216)
                    ),
                    shape = RoundedCornerShape(6.dp),
                    modifier = Modifier
                        .fillMaxWidth()
                        .clickable { onStationPlay(station) }
                ) {
                    Row(
                        modifier = Modifier
                            .padding(12.dp)
                            .fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Column {
                            Text(
                                station.name,
                                color = if (isCurrent) Color(0xFF6CFF7A) else Color(0xFFCFE6CA),
                                style = MaterialTheme.typography.bodyMedium,
                                fontWeight = if (isCurrent) FontWeight.Bold else FontWeight.Normal
                            )
                            Text(
                                station.country,
                                color = Color(0xFF8FA889),
                                style = MaterialTheme.typography.bodySmall
                            )
                        }
                        if (isCurrent && status.isPlaying) {
                            Box(
                                modifier = Modifier
                                    .size(8.dp)
                                    .clip(CircleShape)
                                    .background(Color(0xFF6CFF7A))
                            )
                        }
                    }
                }
            }
        }
    }
}
