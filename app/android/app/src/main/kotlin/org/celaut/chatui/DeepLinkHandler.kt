package org.celaut.chatui

import android.content.Intent
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/// Hands `ergopay:` and `celaut:` VIEW intents to Flutter. The link that launched the
/// activity is answered from `getInitialLink`; links arriving while the
/// app is open are pushed through `onLink`.
///
/// A `celaut:` link (a node invitation, `docs/celaut/invite.md`) comes through
/// [OpenLinkActivity]. Flutter refuses a link longer than 2048 characters before it reads
/// it; only the start of a longer one crosses the channel, enough for Flutter to see that it
/// is too long.
object DeepLinkHandler {
    private const val CHANNEL = "argus/deeplink"
    private const val MAX_CELAUT_LINK = 4096
    private var channel: MethodChannel? = null
    private var initialLink: String? = null

    fun registerWith(engine: FlutterEngine, launchIntent: Intent?) {
        initialLink = linkFrom(launchIntent)
        channel = MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL).also {
            it.setMethodCallHandler { call, result ->
                when (call.method) {
                    "getInitialLink" -> {
                        result.success(initialLink)
                        initialLink = null
                    }
                    else -> result.notImplemented()
                }
            }
        }
    }

    fun onNewIntent(intent: Intent?) {
        val link = linkFrom(intent) ?: return
        val ch = channel
        if (ch != null) ch.invokeMethod("onLink", link) else initialLink = link
    }

    private fun linkFrom(intent: Intent?): String? {
        if (intent?.action != Intent.ACTION_VIEW) return null
        val data = intent.dataString ?: return null
        if (data.startsWith("ergopay:", ignoreCase = true)) return data
        if (!data.startsWith("celaut:", ignoreCase = true)) return null
        // An intent that Android gives again when the user opens the app from the recent
        // apps is not a new link.
        if (intent.flags and Intent.FLAG_ACTIVITY_LAUNCHED_FROM_HISTORY != 0) return null
        return if (data.length > MAX_CELAUT_LINK) data.substring(0, MAX_CELAUT_LINK + 1) else data
    }
}
