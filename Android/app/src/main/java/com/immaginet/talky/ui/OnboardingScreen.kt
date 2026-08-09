package com.immaginet.talky.ui

import android.content.Context
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.immaginet.talky.R

/**
 * Onboarding di primo avvio, allineato per contenuto a quello iOS e macOS.
 *
 * Due punti sono deliberati e non vanno annacquati riscrivendo i testi:
 * - la pagina 2 dice esplicitamente che serve la STESSA rete Wi-Fi, perche' su
 *   Android il trasporto e' solo TALKY1 su NSD/TCP e senza quello non si vede
 *   nessuno;
 * - la pagina 4 dice che l'abbinamento e' automatico e non c'e' niente da
 *   accettare, perche' su Android non esiste il flusso invito/accetta che c'e'
 *   fra dispositivi Apple.
 */
private const val PREFS_NAME = "talky_prefs"
private const val KEY_SEEN_ONBOARDING = "has_seen_onboarding"

fun hasSeenOnboarding(context: Context): Boolean =
    context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        .getBoolean(KEY_SEEN_ONBOARDING, false)

fun markOnboardingSeen(context: Context) {
    context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        .edit()
        .putBoolean(KEY_SEEN_ONBOARDING, true)
        .apply()
}

private const val PAGE_COUNT = 4

@Composable
fun OnboardingScreen(onFinish: () -> Unit) {
    var page by rememberSaveable { mutableIntStateOf(0) }
    val scrollState = rememberScrollState()

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(
                Brush.verticalGradient(
                    listOf(Color(0xFF0C1117), Color(0xFF070B0F))
                )
            )
    ) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(horizontal = 24.dp, vertical = 20.dp),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.End
            ) {
                if (page < PAGE_COUNT - 1) {
                    TextButton(onClick = onFinish) {
                        Text(
                            text = stringResource(R.string.ob_skip),
                            color = Color(0xFF6F8574)
                        )
                    }
                }
            }

            Column(
                modifier = Modifier
                    .weight(1f)
                    .fillMaxWidth()
                    .verticalScroll(scrollState),
                verticalArrangement = Arrangement.Center,
                horizontalAlignment = Alignment.CenterHorizontally
            ) {
                when (page) {
                    0 -> OnboardingPage(
                        title = stringResource(R.string.ob_p1_title),
                        body = stringResource(R.string.ob_p1_body)
                    )

                    1 -> OnboardingPage(
                        title = stringResource(R.string.ob_p2_title),
                        body = stringResource(R.string.ob_p2_body),
                        highlight = stringResource(R.string.ob_p2_wifi)
                    )

                    2 -> OnboardingPage(
                        title = stringResource(R.string.ob_p3_title),
                        body = stringResource(R.string.ob_p3_body),
                        footnote = stringResource(R.string.ob_p3_rule)
                    )

                    else -> StepsPage()
                }
            }

            Row(
                horizontalArrangement = Arrangement.spacedBy(8.dp),
                modifier = Modifier.padding(vertical = 18.dp)
            ) {
                repeat(PAGE_COUNT) { index ->
                    Box(
                        modifier = Modifier
                            .size(if (index == page) 9.dp else 7.dp)
                            .clip(CircleShape)
                            .background(
                                if (index == page) Color(0xFF6CFF7A) else Color(0xFF2A3A2A)
                            )
                    )
                }
            }

            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                if (page > 0) {
                    Text(
                        text = stringResource(R.string.ob_back),
                        color = Color(0xFF6F8574),
                        style = MaterialTheme.typography.labelLarge,
                        modifier = Modifier
                            .clip(RoundedCornerShape(8.dp))
                            .clickable { page -= 1 }
                            .padding(horizontal = 12.dp, vertical = 10.dp)
                    )
                } else {
                    Spacer(modifier = Modifier.width(1.dp))
                }

                Button(
                    onClick = {
                        if (page == PAGE_COUNT - 1) onFinish() else page += 1
                    },
                    colors = ButtonDefaults.buttonColors(
                        containerColor = Color(0xFF1A2E1A),
                        contentColor = Color(0xFF6CFF7A)
                    ),
                    shape = RoundedCornerShape(10.dp)
                ) {
                    Text(
                        text = stringResource(
                            if (page == PAGE_COUNT - 1) R.string.ob_start else R.string.ob_continue
                        ),
                        fontWeight = FontWeight.Bold
                    )
                }
            }
        }
    }
}

@Composable
private fun OnboardingPage(
    title: String,
    body: String,
    highlight: String? = null,
    footnote: String? = null
) {
    Column(
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(14.dp)
    ) {
        Text(
            text = title,
            color = Color(0xFFEAF4D3),
            fontSize = 26.sp,
            fontWeight = FontWeight.Black,
            textAlign = TextAlign.Center
        )
        Text(
            text = body,
            color = Color(0xFF9CB59A),
            style = MaterialTheme.typography.bodyLarge,
            textAlign = TextAlign.Center
        )
        if (highlight != null) {
            Box(
                modifier = Modifier
                    .clip(RoundedCornerShape(10.dp))
                    .background(Color(0xFF121A16))
                    .padding(14.dp)
            ) {
                Text(
                    text = highlight,
                    color = Color(0xFFFFB347),
                    style = MaterialTheme.typography.bodyMedium,
                    textAlign = TextAlign.Center
                )
            }
        }
        if (footnote != null) {
            Text(
                text = footnote,
                color = Color(0xFF6F8574),
                style = MaterialTheme.typography.bodySmall,
                textAlign = TextAlign.Center
            )
        }
    }
}

@Composable
private fun StepsPage() {
    val steps = remember {
        listOf(R.string.ob_p4_step1, R.string.ob_p4_step2, R.string.ob_p4_step3)
    }

    Column(
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        Text(
            text = stringResource(R.string.ob_p4_title),
            color = Color(0xFFEAF4D3),
            fontSize = 26.sp,
            fontWeight = FontWeight.Black,
            textAlign = TextAlign.Center
        )

        steps.forEachIndexed { index, resource ->
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(12.dp),
                verticalAlignment = Alignment.Top
            ) {
                Box(
                    modifier = Modifier
                        .size(26.dp)
                        .clip(CircleShape)
                        .background(Color(0xFF1A2E1A)),
                    contentAlignment = Alignment.Center
                ) {
                    Text(
                        text = "${index + 1}",
                        color = Color(0xFF6CFF7A),
                        fontSize = 13.sp,
                        fontWeight = FontWeight.Bold
                    )
                }
                Text(
                    text = stringResource(resource),
                    color = Color(0xFFCFE6CA),
                    style = MaterialTheme.typography.bodyMedium
                )
            }
        }

        Text(
            text = stringResource(R.string.ob_p4_channel_note),
            color = Color(0xFF6F8574),
            style = MaterialTheme.typography.bodySmall,
            textAlign = TextAlign.Center
        )
    }
}
