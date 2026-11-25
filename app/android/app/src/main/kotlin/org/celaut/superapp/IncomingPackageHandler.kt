package org.celaut.superapp

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
/// A link to a service (issue #135) comes the same way, as `{link: url}`: the `url` of a
/// `celaut://import?url=…` link ([OpenLinkActivity]), or an http(s) link to a `.celaut.bee`
/// file ([OpenPackageActivity]). Both put it in [EXTRA_LINK].
object IncomingPackageHandler {
    private const val CHANNEL = "org.celaut.superapp/incoming"

    /// The link to a service that [OpenLinkActivity] or [OpenPackageActivity] gives to
    /// MainActivity.
    const val EXTRA_LINK = "org.celaut.superapp.LINK"

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

    /// The http(s) link to a `.celaut.bee` file of a VIEW intent. Flutter checks it again
    /// before the download.
    fun linkOf(intent: Intent?): String? {
        if (intent == null || intent.action != Intent.ACTION_VIEW) return null
        if (intent.flags and Intent.FLAG_ACTIVITY_LAUNCHED_FROM_HISTORY != 0) return null
        val data = intent.data ?: return null
        return when (data.scheme?.lowercase()) {
            "http", "https" -> httpOrNull(data.toString())
            else -> null
        }
    }

    /// The link to a service in `celaut://import?url=<the link, encoded>` (issue #135): its
    /// `url`, if it is an http(s) link. Null for another `celaut://` link.
    fun importLinkOf(link: Uri): String? {
        if (!link.scheme.equals("celaut", ignoreCase = true)) return null
        if (!link.host.equals("import", ignoreCase = true)) return null
        return httpOrNull(link.getQueryParameter("url"))
    }

    private fun httpOrNull(link: String?): String? =
        link?.trim()?.takeIf { it.startsWith("http://", true) || it.startsWith("https://", true) }

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
