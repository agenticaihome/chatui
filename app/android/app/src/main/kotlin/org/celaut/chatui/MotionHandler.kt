package org.celaut.chatui

import android.Manifest
import android.annotation.SuppressLint
import android.app.Activity
import android.content.Context
import android.content.pm.PackageManager
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.location.Location
import android.location.LocationListener
import android.location.LocationManager
import android.os.Build
import android.os.Bundle
import android.os.Looper
import android.view.Surface
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

/// The motion of the phone for the vehicle motion cues (lib/services/motion_cues.dart).
///
/// `argus/motion`: while Dart listens, each sample is `[ax, ay, az, gx, gy, gz, t]`:
/// the acceleration without gravity, then gravity, in m/s² on the axes of the screen
/// as it is shown (x right, y up, z out of the glass) whatever the rotation of the
/// phone, then the time of the sample in seconds. With the fused sensors (linear
/// acceleration and gravity) the phone can turn in the hand without false cues;
/// without them gravity is a low-pass of the accelerometer. No permission: the rate
/// stays under 200 Hz.
///
/// `argus/speed`: while Dart listens, the speed over the ground in m/s from the GPS
/// of the phone (LocationManager, no Google services), once a second at most. It
/// needs the precise location, which `argus/motion_permission` asks for. Dart reads
/// it next to `argus/motion`, and dates it with the time of the last sample there:
/// some phones keep the clock of the sensors apart from that of the fixes.
object MotionHandler {
    private const val MOTION = "argus/motion"
    private const val SPEED = "argus/speed"
    private const val PERMISSION = "argus/motion_permission"
    private const val REQUEST_LOCATION = 7303

    private var pending: MethodChannel.Result? = null

    fun registerWith(engine: FlutterEngine, activity: Activity) {
        val messenger = engine.dartExecutor.binaryMessenger
        EventChannel(messenger, MOTION).setStreamHandler(Motion(activity))
        EventChannel(messenger, SPEED).setStreamHandler(Speed(activity))
        MethodChannel(messenger, PERMISSION).setMethodCallHandler { call, result ->
            when (call.method) {
                "hasLocation" -> result.success(hasLocation(activity))
                "requestLocation" -> requestLocation(activity, result)
                else -> result.notImplemented()
            }
        }
    }

    private fun hasLocation(context: Context): Boolean =
        ContextCompat.checkSelfPermission(context, Manifest.permission.ACCESS_FINE_LOCATION) ==
            PackageManager.PERMISSION_GRANTED

    private fun requestLocation(activity: Activity, result: MethodChannel.Result) {
        if (hasLocation(activity)) {
            result.success(true)
            return
        }
        // One question at a time: an older one that is still open is answered "no".
        pending?.success(false)
        pending = result
        // Android 12 wants the approximate location asked with the precise one; only
        // the precise one gives the GPS.
        ActivityCompat.requestPermissions(
            activity,
            arrayOf(Manifest.permission.ACCESS_FINE_LOCATION, Manifest.permission.ACCESS_COARSE_LOCATION),
            REQUEST_LOCATION
        )
    }

    /// Called by `MainActivity.onRequestPermissionsResult`.
    fun onRequestPermissionsResult(activity: Activity, requestCode: Int) {
        if (requestCode != REQUEST_LOCATION) return
        pending?.success(hasLocation(activity))
        pending = null
    }

    private class Motion(private val activity: Activity) : EventChannel.StreamHandler, SensorEventListener {
        private val sensors = activity.getSystemService(Context.SENSOR_SERVICE) as SensorManager
        private var sink: EventChannel.EventSink? = null
        private val gravity = FloatArray(3)
        private var gravityKnown = false

        override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
            sink = events
            gravityKnown = false
            val linear = sensors.getDefaultSensor(Sensor.TYPE_LINEAR_ACCELERATION)
            val grav = sensors.getDefaultSensor(Sensor.TYPE_GRAVITY)
            if (linear != null && grav != null) {
                sensors.registerListener(this, grav, SensorManager.SENSOR_DELAY_GAME)
                sensors.registerListener(this, linear, SensorManager.SENSOR_DELAY_GAME)
                return
            }
            val raw = sensors.getDefaultSensor(Sensor.TYPE_ACCELEROMETER)
            if (raw == null) {
                events.error("no_sensor", "This phone has no accelerometer", null)
                return
            }
            sensors.registerListener(this, raw, SensorManager.SENSOR_DELAY_GAME)
        }

        override fun onCancel(arguments: Any?) {
            sensors.unregisterListener(this)
            sink = null
        }

        override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {}

        override fun onSensorChanged(event: SensorEvent) {
            val out = sink ?: return
            val v = event.values
            val t = event.timestamp / 1e9
            when (event.sensor.type) {
                Sensor.TYPE_GRAVITY -> {
                    v.copyInto(gravity, endIndex = 3)
                    gravityKnown = true
                }
                Sensor.TYPE_LINEAR_ACCELERATION -> {
                    if (gravityKnown) out.success(onScreen(v[0], v[1], v[2], t))
                }
                Sensor.TYPE_ACCELEROMETER -> {
                    if (!gravityKnown) {
                        v.copyInto(gravity, endIndex = 3)
                        gravityKnown = true
                    }
                    // About one second at the rate of SENSOR_DELAY_GAME (~50 Hz).
                    for (i in 0..2) gravity[i] += (v[i] - gravity[i]) * 0.02f
                    out.success(onScreen(v[0] - gravity[0], v[1] - gravity[1], v[2] - gravity[2], t))
                }
            }
        }

        /// The sample on the axes of the screen: the sensors give those of the phone
        /// held in its natural orientation.
        private fun onScreen(ax: Float, ay: Float, az: Float, t: Double): DoubleArray {
            val g = gravity
            val axes = when (rotation()) {
                Surface.ROTATION_90 -> floatArrayOf(-ay, ax, az, -g[1], g[0], g[2])
                Surface.ROTATION_180 -> floatArrayOf(-ax, -ay, az, -g[0], -g[1], g[2])
                Surface.ROTATION_270 -> floatArrayOf(ay, -ax, az, g[1], -g[0], g[2])
                else -> floatArrayOf(ax, ay, az, g[0], g[1], g[2])
            }
            return DoubleArray(7) { if (it < 6) axes[it].toDouble() else t }
        }

        @Suppress("DEPRECATION")
        private fun rotation(): Int =
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                activity.display?.rotation ?: Surface.ROTATION_0
            } else {
                activity.windowManager.defaultDisplay.rotation
            }
    }

    private class Speed(private val activity: Activity) : EventChannel.StreamHandler, LocationListener {
        private val locations = activity.getSystemService(Context.LOCATION_SERVICE) as LocationManager
        private var sink: EventChannel.EventSink? = null

        // hasLocation checks the permission; lint does not see through it.
        @SuppressLint("MissingPermission")
        override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
            if (!hasLocation(activity)) {
                events.error("no_permission", "The precise location is not allowed", null)
                return
            }
            if (!locations.allProviders.contains(LocationManager.GPS_PROVIDER)) {
                events.error("no_gps", "This phone has no GPS", null)
                return
            }
            sink = events
            try {
                locations.requestLocationUpdates(LocationManager.GPS_PROVIDER, 1000L, 0f, this, Looper.getMainLooper())
            } catch (e: SecurityException) {
                sink = null
                events.error("no_permission", e.message, null)
            }
        }

        override fun onCancel(arguments: Any?) {
            locations.removeUpdates(this)
            sink = null
        }

        override fun onLocationChanged(location: Location) {
            if (location.hasSpeed()) sink?.success(location.speed.toDouble())
        }

        // Before Android 11 these have no default body: a call to a missing one crashes.
        override fun onProviderEnabled(provider: String) {}

        override fun onProviderDisabled(provider: String) {}

        @Deprecated("Called only before Android 10")
        override fun onStatusChanged(provider: String?, status: Int, extras: Bundle?) {}
    }
}
