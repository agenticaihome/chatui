package org.celaut.chatui

import android.app.Activity
import android.content.Intent
import android.os.Bundle

/// Takes a `celaut://` link that another app opens (a phone camera that read a QR code, a
/// browser, a chat) and gives it to [MainActivity] in the task of the app, as
/// [OpenPackageActivity] does for a file: without this step, a second MainActivity, with a
/// second Flutter engine, could start in the task of the other app. The running
/// MainActivity gets the link in `onNewIntent`; if the app does not run, it starts in its
/// own task. Shows nothing. [DeepLinkHandler] gives the link to Flutter, which asks the
/// user before it connects (`docs/celaut/invite.md`, section 6).
class OpenLinkActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val link = intent?.data
        val fresh = intent?.flags?.and(Intent.FLAG_ACTIVITY_LAUNCHED_FROM_HISTORY) == 0
        if (savedInstanceState == null && fresh && link != null &&
            link.scheme.equals("celaut", ignoreCase = true)
        ) {
            startActivity(
                Intent(this, MainActivity::class.java).apply {
                    action = Intent.ACTION_VIEW
                    data = link
                    addFlags(
                        Intent.FLAG_ACTIVITY_NEW_TASK or
                            Intent.FLAG_ACTIVITY_CLEAR_TOP or
                            Intent.FLAG_ACTIVITY_SINGLE_TOP
                    )
                }
            )
        }
        finish()
    }
}
