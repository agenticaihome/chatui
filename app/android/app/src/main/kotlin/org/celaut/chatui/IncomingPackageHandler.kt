package org.celaut.chatui

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/// A `.celaut.bee` file that the user opens in a file manager (VIEW) or shares with the app
/// (SEND) goes to Flutter, which starts its import (`docs/celaut/package.md`).
/// [OpenPackageActivity] takes the intent and gives the file to MainActivity as a VIEW. The file
/// that launched the activity is answered by `takeIncoming`; a file that comes while the
/// app runs, in front or in the background, is pushed through `incoming`. Flutter copies
/// it with `copyPackage` of [PackageHandler], as a file of the picker.
object IncomingPackageHandler {
    private const val CHANNEL = "org.celaut.chatui/incoming"

    private var channel: MethodChannel? = null
    private var pending: Map<String, Any>? = null
    private val main = Handler(Looper.getMainLooper())

    fun registerWith(engine: FlutterEngine, context: Context, launchIntent: Intent?) {
        channel = MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL).also {
            it.setMethodCallHandler { call, result ->
                when (call.method) {
                    "takeIncoming" -> {
                        result.success(pending)
                        pending = null
                    }
                    else -> result.notImplemented()
                }
            }
        }
        receive(context, launchIntent)
    }

    fun onNewIntent(context: Context, intent: Intent?) = receive(context, intent)

    private fun receive(context: Context, intent: Intent?) {
        val uri = fileOf(intent) ?: return
        // The provider of the file gives its name and size: not on the main thread.
        Thread {
            val file = PackageHandler.describe(context, uri)
            main.post {
                // The file waits here until Flutter has it: `incoming` gives it at once if
                // Flutter listens, and `takeIncoming` gives it after a cold start.
                pending = file
                channel?.invokeMethod("incoming", file, object : MethodChannel.Result {
                    override fun success(result: Any?) {
                        if (pending === file) pending = null
                    }

                    override fun error(code: String, message: String?, details: Any?) {}

                    override fun notImplemented() {}
                })
            }
        }.start()
    }

    /// The file of a VIEW or SEND intent, if it has one. An intent that Android gives again
    /// when the user opens the app from the recent apps is not a new file.
    fun fileOf(intent: Intent?): Uri? {
        if (intent == null) return null
        if (intent.flags and Intent.FLAG_ACTIVITY_LAUNCHED_FROM_HISTORY != 0) return null
        val uri = when (intent.action) {
            Intent.ACTION_VIEW -> intent.data
            Intent.ACTION_SEND -> streamOf(intent)
            else -> null
        } ?: return null
        return if (uri.scheme == "content") uri else null
    }

    private fun streamOf(intent: Intent): Uri? =
        if (Build.VERSION.SDK_INT >= 33) {
            intent.getParcelableExtra(Intent.EXTRA_STREAM, Uri::class.java)
        } else {
            @Suppress("DEPRECATION")
            intent.getParcelableExtra(Intent.EXTRA_STREAM)
        }
}
