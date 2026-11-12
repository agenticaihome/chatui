package org.celaut.chatui

import android.app.Activity
import android.content.Context
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
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
object CardsSensorsHandler {
    private const val DEVICE = "argus/cards_device"
    private const val GYRO = "argus/cards_gyro"

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
