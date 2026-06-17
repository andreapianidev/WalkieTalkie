package com.immaginet.talky

import android.Manifest
import android.os.Build
import android.os.Bundle
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
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilterChip
import androidx.compose.material3.FilterChipDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.scale
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.immaginet.talky.net.CrossPlatformPeer
import com.immaginet.talky.net.CrossPlatformWalkieManager
import com.google.firebase.FirebaseApp
import com.immaginet.talky.ads.AdBanner
import com.immaginet.talky.ads.AdManager
import com.immaginet.talky.firebase.FirebaseManager
import com.immaginet.talky.radio.RadioManager
import com.immaginet.talky.radio.RadioStation
import com.immaginet.talky.ui.theme.WalkieTalkieAndroidTheme

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        FirebaseManager.init(FirebaseApp.getInstance())
        AdManager.initialize(this)
        AdManager.requestConsent(this)
        enableEdgeToEdge()
        setContent {
            WalkieTalkieAndroidTheme {
                TalkyApp()
            }
        }
    }
}

private enum class AppMode { WALKIE, RADIO }

@Composable
private fun TalkyApp() {
    val context = LocalContext.current
    val walkieManager = remember { CrossPlatformWalkieManager(context.applicationContext) }
    val radioManager = remember { RadioManager() }
    var isTransmitting by remember { mutableStateOf(false) }
    var receivingAudio by remember { mutableStateOf(false) }
    var appMode by remember { mutableStateOf(AppMode.WALKIE) }
    var radioStatus by remember {
        mutableStateOf(RadioManager.RadioStatus(false, "", "", false, null))
    }

    val channels = remember {
        listOf("public", "ch1", "ch2", "ch3", "ch4", "ch5", "ch6", "ch7", "ch8")
    }

    val permissionLauncher = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.RequestMultiplePermissions()
    ) { walkieManager.start() }

    LaunchedEffect(Unit) {
        radioManager.setStatusListener { status -> radioStatus = status }
        val permissions = buildList {
            add(Manifest.permission.RECORD_AUDIO)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                add(Manifest.permission.POST_NOTIFICATIONS)
                add(Manifest.permission.NEARBY_WIFI_DEVICES)
            }
        }.toTypedArray()
        permissionLauncher.launch(permissions)
    }

    LaunchedEffect(walkieManager.remoteAudioActive) {
        receivingAudio = walkieManager.remoteAudioActive
        if (!receivingAudio) {
            walkieManager.audioManager.stopPlayback()
        }
    }

    LaunchedEffect(appMode) {
        if (appMode == AppMode.WALKIE) {
            radioManager.stop()
        } else {
            walkieManager.stopTransmitting()
            isTransmitting = false
        }
    }

    DisposableEffect(Unit) {
        onDispose {
            walkieManager.stopTransmitting()
            walkieManager.close()
            radioManager.close()
        }
    }

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
                channel = walkieManager.currentChannel,
                onModeToggle = {
                    appMode = if (appMode == AppMode.WALKIE) AppMode.RADIO else AppMode.WALKIE
                }
            )

            ModeToggle(appMode = appMode, onToggle = {
                appMode = if (appMode == AppMode.WALKIE) AppMode.RADIO else AppMode.WALKIE
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
                    onChannelChange = { walkieManager.setChannel(it) },
                    onPTTPress = {
                        if (walkieManager.startTransmitting()) {
                            isTransmitting = true
                            FirebaseManager.trackPTTUsed(walkieManager.currentChannel)
                        }
                    },
                    onPTTRelease = {
                        walkieManager.stopTransmitting()
                        isTransmitting = false
                    },
                    onRestart = { walkieManager.restart() }
                )
                AppMode.RADIO -> RadioContent(
                    radioManager = radioManager,
                    status = radioStatus,
                    onStationPlay = { station ->
                        FirebaseManager.trackRadioUsage(station.name, station.country)
                        radioManager.playStation(station)
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
                    text = "WALKIE-TALKIE",
                    isActive = appMode == AppMode.WALKIE,
                    onClick = { if (appMode != AppMode.WALKIE) onToggle() }
                )
            }
            Box(modifier = Modifier.weight(1f)) {
                ModeTab(
                    text = "RADIO FM",
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
                    text = if (radioStatus.isPlaying) radioStatus.stationName else "FM Radio",
                    isActive = radioStatus.isPlaying
                )
            }
        }
        if (appMode == AppMode.WALKIE && channel.isNotBlank()) {
            Text(
                text = "Canale: $channel",
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
private fun ChannelChips(channel: String, channels: List<String>, onChannelChange: (String) -> Unit) {
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
        else -> "462.562"
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
                text = "MHz",
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
    Column(verticalArrangement = Arrangement.spacedBy(14.dp)) {
        FrequencyDisplay(channel = channel, isTransmitting = isTransmitting)

        ChannelChips(
            channel = channel,
            channels = channels,
            onChannelChange = onChannelChange
        )

        SpeakerGrid(modifier = Modifier.height(44.dp))

        PushToTalkPanel(
            isTransmitting = isTransmitting,
            isConnected = isConnected,
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
                text = "RICEZIONE IN CORSO",
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
                            isConnected -> Brush.radialGradient(
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
                            isConnected -> Color(0xFFB9FFC2)
                            else -> Color(0xFF445544)
                        },
                        CircleShape
                    )
                    .pointerInput(Unit) {
                        detectTapGestures(
                            onPress = {
                                if (isConnected) {
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
                        text = if (isTransmitting) "TX" else "PTT",
                        color = Color(0xFF061009),
                        fontSize = 28.sp,
                        fontWeight = FontWeight.Black
                    )
                    Text(
                        text = if (isTransmitting) "IN ONDA" else if (isConnected) "PREMI" else "---",
                        color = Color(0xFF061009).copy(alpha = 0.7f),
                        fontSize = 10.sp,
                        fontWeight = FontWeight.Bold
                    )
                }
            }
            Text(
                text = when {
                    isTransmitting -> "IN TRASMISSIONE... RILASCIA PER FERMARE"
                    isConnected -> "Tieni premuto per parlare"
                    else -> "In attesa connessione..."
                },
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
                    text = "Dispositivi",
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
                    text = "In attesa di iPhone o Android sulla stessa rete locale.",
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
                Text("Log", color = Color(0xFFEAF4D3), style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold)
                Button(
                    onClick = onRestart,
                    colors = ButtonDefaults.buttonColors(containerColor = Color(0xFF1A2E1A)),
                    contentPadding = PaddingValues(horizontal = 12.dp, vertical = 4.dp)
                ) { Text("Riavvia", fontSize = 12.sp) }
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
                    text = if (status.isPlaying) status.stationName else "Seleziona una stazione",
                    color = Color(0xFFEAF4D3),
                    style = MaterialTheme.typography.titleLarge,
                    fontWeight = FontWeight.Bold,
                    textAlign = TextAlign.Center
                )
                if (status.isPlaying) {
                    Text(
                        text = status.stationCountry,
                        color = Color(0xFF8FA889),
                        style = MaterialTheme.typography.bodyMedium
                    )
                }
                if (status.isBuffering) {
                    Text(
                        text = "Buffering...",
                        color = Color(0xFFFFB347),
                        style = MaterialTheme.typography.bodySmall
                    )
                }
                status.error?.let { err ->
                    Text(text = err, color = Color(0xFFFF6666), style = MaterialTheme.typography.bodySmall)
                }
                if (status.isPlaying) {
                    Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                        Button(
                            onClick = {
                                radioManager.getPreviousStation()?.let { radioManager.playStation(it) }
                            },
                            colors = ButtonDefaults.buttonColors(containerColor = Color(0xFF1A2E1A))
                        ) { Text("Prec") }
                        Button(
                            onClick = { radioManager.stop() },
                            colors = ButtonDefaults.buttonColors(containerColor = Color(0xFF3A1A1A))
                        ) { Text("Stop") }
                        Button(
                            onClick = {
                                radioManager.getNextStation()?.let { radioManager.playStation(it) }
                            },
                            colors = ButtonDefaults.buttonColors(containerColor = Color(0xFF1A2E1A))
                        ) { Text("Succ") }
                    }
                }
            }
        }

        Text(
            text = "Stazioni (${RadioManager.stations.size})",
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
