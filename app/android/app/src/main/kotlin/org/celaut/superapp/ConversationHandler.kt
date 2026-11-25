package org.celaut.superapp

import android.Manifest
import android.app.Activity
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/// Starts and stops [ConversationService], and asks for the notification permission
/// (Android 13+) when Dart asks. Nothing here needs the permission: without it the
/// service runs with no notification.
object ConversationHandler {
    private const val CHANNEL = "org.celaut.superapp/conversation"
    private const val REQUEST_NOTIFICATIONS = 7302

    private var pending: MethodChannel.Result? = null

    fun registerWith(engine: FlutterEngine, activity: Activity) {
        MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "start" -> result.success(
                    ConversationService.start(activity, call.argument<List<String>>("reasons"))
                )
                "stop" -> {
                    ConversationService.stop(activity)
                    result.success(null)
                }
                "requestNotificationPermission" -> requestNotificationPermission(activity, result)
                else -> result.notImplemented()
            }
        }
    }

    private fun requestNotificationPermission(activity: Activity, result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU ||
            ContextCompat.checkSelfPermission(activity, Manifest.permission.POST_NOTIFICATIONS) ==
            PackageManager.PERMISSION_GRANTED
        ) {
            result.success(true)
            return
        }
        // One question at a time: an older one that is still open is answered "no".
        pending?.success(false)
        pending = result
        ActivityCompat.requestPermissions(
            activity, arrayOf(Manifest.permission.POST_NOTIFICATIONS), REQUEST_NOTIFICATIONS
        )
    }

    /// Called by `MainActivity.onRequestPermissionsResult`.
    fun onRequestPermissionsResult(requestCode: Int, grantResults: IntArray) {
        if (requestCode != REQUEST_NOTIFICATIONS) return
        val granted = grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED
        pending?.success(granted)
        pending = null
    }
}
