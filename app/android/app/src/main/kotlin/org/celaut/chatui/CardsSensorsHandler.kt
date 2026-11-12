package org.celaut.chatui

import android.app.Activity
import android.content.Context
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioTrack
import android.os.Build
import android.os.Vibrator
import android.os.VibratorManager
import android.view.Surface
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

/// The sensors of the cards deck (`docs/celaut/cards.md`, section 13).
///
/// `argus/cards_device` says what the phone has (`caps`: a gyroscope, a vibration motor), so
/// that the app hides the settings that cannot work. `argus/cards_gyro` gives the turn rate
/// of the phone in rad/s on the axes of the screen (x to the right, y up, z out of the
/// screen), then the time of the sample in seconds. The stream runs only while the deck (or
/// the test of the settings) listens; nothing is kept here. Android needs no permission for
/// the gyroscope at this rate (SENSOR_DELAY_GAME, ~50 Hz), and none for the haptics of the
/// views that the app uses.
///
/// `argus/cards_sound` plays one short synthetic sound (`play`: 16-bit mono PCM, the rate and
/// a gain) on the stream of the system sounds. It needs no permission.
object CardsSensorsHandler {
    private const val DEVICE = "argus/cards_device"
    private const val GYRO = "argus/cards_gyro"
    private const val SOUND = "argus/cards_sound"

    fun registerWith(engine: FlutterEngine, activity: Activity) {
        val messenger = engine.dartExecutor.binaryMessenger
        MethodChannel(messenger, DEVICE).setMethodCallHandler { call, result ->
            when (call.method) {
                "caps" -> result.success(
                    mapOf("gyroscope" to hasGyroscope(activity), "vibrator" to hasVibrator(activity)),
                )
                else -> result.notImplemented()
            }
        }
        EventChannel(messenger, GYRO).setStreamHandler(Gyro(activity))
        MethodChannel(messenger, SOUND).setMethodCallHandler { call, result ->
            when (call.method) {
                "play" -> {
                    val pcm = call.argument<ByteArray>("pcm")
                    val rate = call.argument<Int>("rate")
                    val gain = call.argument<Double>("gain") ?: 1.0
                    if (pcm == null || rate == null) result.error("bad_args", "pcm and rate are needed", null)
                    else result.success(play(pcm, rate, gain.toFloat()))
                }
                else -> result.notImplemented()
            }
        }
    }

    /// Plays a short sound (16-bit mono PCM) on the stream of the system sounds: it follows
    /// the volume and the silent mode of the phone. It needs no permission. The track is
    /// released when it ends. Returns false when the phone cannot play it.
    private fun play(pcm: ByteArray, rate: Int, gain: Float): Boolean {
        if (pcm.isEmpty() || pcm.size > 64 * 1024) return false
        return try {
            val track = AudioTrack.Builder()
                .setAudioAttributes(
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_ASSISTANCE_SONIFICATION)
                        .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                        .build(),
                )
                .setAudioFormat(
                    AudioFormat.Builder()
                        .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
                        .setSampleRate(rate)
                        .setChannelMask(AudioFormat.CHANNEL_OUT_MONO)
                        .build(),
                )
                .setBufferSizeInBytes(pcm.size)
                .setTransferMode(AudioTrack.MODE_STATIC)
                .build()
            track.write(pcm, 0, pcm.size)
            track.setVolume(gain.coerceIn(0f, 1f))
            track.setNotificationMarkerPosition(pcm.size / 2)
            track.setPlaybackPositionUpdateListener(object : AudioTrack.OnPlaybackPositionUpdateListener {
                override fun onMarkerReached(t: AudioTrack) = t.release()
                override fun onPeriodicNotification(t: AudioTrack) {}
            })
            track.play()
            true
        } catch (e: Exception) {
            false
        }
    }

    private fun hasGyroscope(context: Context): Boolean {
        val sensors = context.getSystemService(Context.SENSOR_SERVICE) as SensorManager
        return sensors.getDefaultSensor(Sensor.TYPE_GYROSCOPE) != null
    }

    @Suppress("DEPRECATION")
    private fun hasVibrator(context: Context): Boolean {
        val vibrator = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            (context.getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as? VibratorManager)?.defaultVibrator
        } else {
            context.getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator
        }
        return vibrator?.hasVibrator() == true
    }

    private class Gyro(private val activity: Activity) : EventChannel.StreamHandler, SensorEventListener {
        private val sensors = activity.getSystemService(Context.SENSOR_SERVICE) as SensorManager
        private var sink: EventChannel.EventSink? = null

        override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
            val gyro = sensors.getDefaultSensor(Sensor.TYPE_GYROSCOPE)
            if (gyro == null) {
                events.error("no_sensor", "This phone has no gyroscope", null)
                return
            }
            sink = events
            sensors.registerListener(this, gyro, SensorManager.SENSOR_DELAY_GAME)
        }

        override fun onCancel(arguments: Any?) {
            sensors.unregisterListener(this)
            sink = null
        }

        override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {}

        override fun onSensorChanged(event: SensorEvent) {
            val out = sink ?: return
            val v = event.values
            // The axes of the phone in its natural orientation → the axes of the screen.
            val axes = when (rotation()) {
                Surface.ROTATION_90 -> floatArrayOf(-v[1], v[0], v[2])
                Surface.ROTATION_180 -> floatArrayOf(-v[0], -v[1], v[2])
                Surface.ROTATION_270 -> floatArrayOf(v[1], -v[0], v[2])
                else -> floatArrayOf(v[0], v[1], v[2])
            }
            out.success(doubleArrayOf(axes[0].toDouble(), axes[1].toDouble(), axes[2].toDouble(), event.timestamp / 1e9))
        }

        @Suppress("DEPRECATION")
        private fun rotation(): Int =
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                activity.display?.rotation ?: Surface.ROTATION_0
            } else {
                activity.windowManager.defaultDisplay.rotation
            }
    }
}
