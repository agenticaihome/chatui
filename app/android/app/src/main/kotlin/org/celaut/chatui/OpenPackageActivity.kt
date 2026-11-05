package org.celaut.chatui

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.os.Bundle

/// Takes a `.celaut.bee` file that a file manager opens (VIEW) or shares (SEND), and gives it
/// to [MainActivity] in the task of the app, with the permission to read it. A file manager
/// starts the activity of its intent in its own task: without this step, a second
/// MainActivity, with a second Flutter engine, would start there while the app runs. The
/// task of the app comes to the front, and the running MainActivity gets the file in
/// `onNewIntent`; if the app does not run, it starts in its own task. Shows nothing.
class OpenPackageActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val uri = if (savedInstanceState == null) IncomingPackageHandler.fileOf(intent) else null
        if (uri != null) {
            try {
                startActivity(forward(uri, Intent.FLAG_GRANT_READ_URI_PERMISSION))
            } catch (e: SecurityException) {
                // No permission to read the file, so none to give: the app gets the file all
                // the same, and says that it cannot read it.
                startActivity(forward(uri, 0))
            }
        }
        finish()
    }

    private fun forward(uri: Uri, grant: Int) =
        Intent(this, MainActivity::class.java).apply {
            action = Intent.ACTION_VIEW
            setDataAndType(uri, intent.type)
            addFlags(
                Intent.FLAG_ACTIVITY_NEW_TASK or
                    Intent.FLAG_ACTIVITY_CLEAR_TOP or
                    Intent.FLAG_ACTIVITY_SINGLE_TOP or
                    grant
            )
        }
}
