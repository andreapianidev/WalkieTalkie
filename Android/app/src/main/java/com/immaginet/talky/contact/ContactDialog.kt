// creato da Andrea Piani - 10/11/26 - https://www.andreapiani.com - ContactDialog.kt
package com.immaginet.talky.contact

import android.content.ActivityNotFoundException
import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.widget.Toast
import androidx.annotation.StringRes
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import com.immaginet.talky.BuildConfig
import com.immaginet.talky.R
import java.util.Locale

/**
 * "Scrivimi", come su iPhone: problema, idea o due righe verso la mail di
 * Andrea. Chi scrive invece di lasciare una stella e' un utente che si puo'
 * ancora aiutare. In fondo alla mail ci sono versione, Android e modello,
 * visibili prima dell'invio, cosi' non serve chiederli dopo.
 */
private enum class Topic(@StringRes val title: Int, @StringRes val subject: Int) {
    Bug(R.string.contact_bug, R.string.contact_subject_bug),
    Idea(R.string.contact_idea, R.string.contact_subject_idea),
    Chat(R.string.contact_chat, R.string.contact_subject_chat)
}

private const val ADDRESS = "andreapiani.dev@gmail.com"

private val appVersion get() = "${BuildConfig.VERSION_NAME} (${BuildConfig.VERSION_CODE})"

private fun mailBody(): String =
    "\n\n\n---\nTalky $appVersion · Android ${Build.VERSION.RELEASE} · " +
        "${Build.MANUFACTURER} ${Build.MODEL} · ${Locale.getDefault().toLanguageTag()}"

private fun writeMail(context: Context, topic: Topic) {
    val subject = "Talky $appVersion: ${context.getString(topic.subject)}"
    val uri = Uri.parse("mailto:$ADDRESS?subject=${Uri.encode(subject)}&body=${Uri.encode(mailBody())}")
    try {
        context.startActivity(Intent(Intent.ACTION_SENDTO, uri))
    } catch (e: ActivityNotFoundException) {
        // Nessuna app di posta: l'indirizzo finisce negli appunti.
        val clipboard = context.getSystemService(ClipboardManager::class.java)
        clipboard?.setPrimaryClip(ClipData.newPlainText("Talky", ADDRESS))
        Toast.makeText(context, context.getString(R.string.contact_no_mail_body, ADDRESS), Toast.LENGTH_LONG).show()
    }
}

internal fun openStorePage(context: Context) {
    val id = context.packageName
    try {
        context.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse("market://details?id=$id")))
    } catch (e: ActivityNotFoundException) {
        context.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse("https://play.google.com/store/apps/details?id=$id")))
    }
}

@Composable
fun ContactDialog(onDismiss: () -> Unit) {
    val context = LocalContext.current
    AlertDialog(
        onDismissRequest = onDismiss,
        containerColor = Color(0xFF0D1216),
        titleContentColor = Color(0xFFEAF4D3),
        textContentColor = Color(0xFF8FA889),
        title = { Text(stringResource(R.string.contact_title)) },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                Text(stringResource(R.string.contact_subtitle))
                Topic.entries.forEach { topic ->
                    TextButton(onClick = { writeMail(context, topic) }, modifier = Modifier.fillMaxWidth()) {
                        Text(stringResource(topic.title), color = Color(0xFF6CFF7A))
                    }
                }
                TextButton(onClick = { openStorePage(context) }, modifier = Modifier.fillMaxWidth()) {
                    Text(stringResource(R.string.contact_rate), color = Color(0xFF6CFF7A))
                }
            }
        },
        confirmButton = {
            TextButton(onClick = onDismiss) { Text(stringResource(R.string.contact_close)) }
        }
    )
}
