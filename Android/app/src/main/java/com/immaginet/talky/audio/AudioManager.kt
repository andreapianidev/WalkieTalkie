package com.immaginet.talky.audio

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioManager
import android.media.AudioRecord
import android.media.AudioTrack
import android.media.MediaRecorder
import android.os.Process
import androidx.core.content.ContextCompat
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.flow
import kotlinx.coroutines.withContext
import java.io.Closeable
import java.util.concurrent.atomic.AtomicBoolean

class AudioManager(context: Context) : Closeable {

    private val appContext = context.applicationContext

    companion object {
        const val SAMPLE_RATE = 48000
        const val CHANNEL_CONFIG = AudioFormat.CHANNEL_IN_MONO
        const val AUDIO_FORMAT = AudioFormat.ENCODING_PCM_16BIT
        const val CHANNELS = 1
        const val BUFFER_SIZE_FRAMES = 2048
    }

    private val isCapturing = AtomicBoolean(false)
    private val isPlaying = AtomicBoolean(false)
    private var audioRecord: AudioRecord? = null
    private var audioTrack: AudioTrack? = null

    val bufferSizeBytes: Int by lazy {
        AudioRecord.getMinBufferSize(SAMPLE_RATE, CHANNEL_CONFIG, AUDIO_FORMAT)
            .coerceAtLeast(BUFFER_SIZE_FRAMES * 2)
    }

    val trackBufferSize: Int by lazy {
        AudioTrack.getMinBufferSize(SAMPLE_RATE, AudioFormat.CHANNEL_OUT_MONO, AUDIO_FORMAT)
            .coerceAtLeast(BUFFER_SIZE_FRAMES * 2)
    }

    fun startCapturing(): Flow<ByteArray> = flow {
        if (isCapturing.getAndSet(true)) return@flow

        var record: AudioRecord? = null
        try {
            if (ContextCompat.checkSelfPermission(
                    appContext,
                    Manifest.permission.RECORD_AUDIO
                ) != PackageManager.PERMISSION_GRANTED
            ) {
                throw SecurityException("Permesso microfono non concesso")
            }

            val bufferSize = bufferSizeBytes
            record = AudioRecord(
                MediaRecorder.AudioSource.MIC,
                SAMPLE_RATE,
                CHANNEL_CONFIG,
                AUDIO_FORMAT,
                bufferSize
            ).also { audioRecord = it }

            if (record.state != AudioRecord.STATE_INITIALIZED) {
                throw IllegalStateException("AudioRecord non inizializzato")
            }

            record.startRecording()
            Process.setThreadPriority(Process.THREAD_PRIORITY_URGENT_AUDIO)

            val buffer = ByteArray(bufferSize)
            while (isCapturing.get() && record.recordingState == AudioRecord.RECORDSTATE_RECORDING) {
                val bytesRead = record.read(buffer, 0, buffer.size)
                if (bytesRead > 0) {
                    emit(buffer.copyOf(bytesRead))
                } else if (bytesRead < 0) {
                    break
                }
            }
        } finally {
            record?.let { recorder ->
                if (recorder.recordingState == AudioRecord.RECORDSTATE_RECORDING) {
                    runCatching { recorder.stop() }
                }
                runCatching { recorder.release() }
            }
            audioRecord = null
            isCapturing.set(false)
        }
    }

    fun stopCapturing() {
        isCapturing.set(false)
    }

    fun prepareTrack(): AudioTrack {
        audioTrack?.let { track ->
            if (track.playState == AudioTrack.PLAYSTATE_PAUSED ||
                track.playState == AudioTrack.PLAYSTATE_STOPPED
            ) {
                track.release()
            } else {
                return track
            }
        }

        val track = AudioTrack.Builder()
            .setAudioAttributes(
                AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_MEDIA)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
                    .build()
            )
            .setAudioFormat(
                AudioFormat.Builder()
                    .setEncoding(AUDIO_FORMAT)
                    .setSampleRate(SAMPLE_RATE)
                    .setChannelMask(AudioFormat.CHANNEL_OUT_MONO)
                    .build()
            )
            .setBufferSizeInBytes(trackBufferSize)
            .setTransferMode(AudioTrack.MODE_STREAM)
            .build()

        track.play()
        audioTrack = track
        isPlaying.set(true)
        return track
    }

    fun writeAudio(data: ByteArray) {
        val track = audioTrack ?: return
        if (track.playState != AudioTrack.PLAYSTATE_PLAYING) return
        track.write(data, 0, data.size, AudioTrack.WRITE_BLOCKING)
    }

    fun stopPlayback() {
        isPlaying.set(false)
        audioTrack?.let { track ->
            track.stop()
            track.release()
        }
        audioTrack = null
    }

    override fun close() {
        stopCapturing()
        stopPlayback()
    }
}
