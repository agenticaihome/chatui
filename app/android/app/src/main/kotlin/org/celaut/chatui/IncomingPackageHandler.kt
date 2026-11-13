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
///
/// A link to a service (issue #135) comes the same way, as `{link: url}`: a
/// `chatui://import?url=…` link, an http(s) link to a `.celaut.bee` file, or a text that
/// another app shares with a link in it. [OpenPackageActivity] puts it in [EXTRA_LINK].
object IncomingPackageHandler {
    private const val CHANNEL = "org.celaut.chatui/incoming"

    /// The link to a service that [OpenPackageActivity] gives to MainActivity.
    const val EXTRA_LINK = "org.celaut.chatui.LINK"

    private val HTTP_LINK = Regex("https?://\\S+", RegexOption.IGNORE_CASE)

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
        val link = forwardedLinkOf(intent)
        if (link != null) {
            give(mapOf("link" to link))
            return
        }
        val uri = fileOf(intent) ?: return
        // The provider of the file gives its name and size: not on the main thread.
        Thread {
            val file = PackageHandler.describe(context, uri)
            main.post { give(file) }
        }.start()
    }

    /// The file or the link waits here until Flutter has it: `incoming` gives it at once if
    /// Flutter listens, and `takeIncoming` gives it after a cold start.
    private fun give(item: Map<String, Any>) {
        pending = item
        channel?.invokeMethod("incoming", item, object : MethodChannel.Result {
            override fun success(result: Any?) {
                if (pending === item) pending = null
            }

            override fun error(code: String, message: String?, details: Any?) {}

            override fun notImplemented() {}
        })
    }

    /// The link that [OpenPackageActivity] put in the intent, if any.
    private fun forwardedLinkOf(intent: Intent?): String? {
        if (intent == null) return null
        if (intent.flags and Intent.FLAG_ACTIVITY_LAUNCHED_FROM_HISTORY != 0) return null
        return intent.getStringExtra(EXTRA_LINK)?.takeIf { it.isNotBlank() }
    }

    /// The link to a service in a VIEW or SEND intent: the `url` of a
    /// `chatui://import?url=…` link, an http(s) link, or the first http(s) link of a shared
    /// text. Flutter checks it again before the download.
    fun linkOf(intent: Intent?): String? {
        if (intent == null) return null
        if (intent.flags and Intent.FLAG_ACTIVITY_LAUNCHED_FROM_HISTORY != 0) return null
        return when (intent.action) {
            Intent.ACTION_VIEW -> {
                val data = intent.data ?: return null
                when (data.scheme?.lowercase()) {
                    "chatui" -> if (data.host == "import") data.getQueryParameter("url") else null
                    "http", "https" -> data.toString()
                    else -> null
                }
            }
            Intent.ACTION_SEND -> {
                if (streamOf(intent) != null) return null
                val text = intent.getStringExtra(Intent.EXTRA_TEXT) ?: return null
                HTTP_LINK.find(text)?.value
            }
            else -> null
        }?.trim()?.takeIf { it.startsWith("http://", true) || it.startsWith("https://", true) }
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
