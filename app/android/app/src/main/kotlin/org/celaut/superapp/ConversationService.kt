package org.celaut.superapp

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import android.os.PowerManager

/// Keeps the process, and so the tunnel sockets, alive while a conversation with a
/// service is open and the app is in the background (`docs/celaut-plan.md`, section 3).
/// The instance itself runs on the node and is not affected.
///
/// The launch of a service, the transfer of a service file to a node and the import of a
/// file use it too (Josemi, 2026-10-23): Dart sends the reasons that hold it
/// (`ForegroundHolds`), and the notification names the most urgent one. While one of
/// those holds it, the service keeps the CPU awake with a partial wake lock, so
/// that the work goes on with the screen off. The watcher of answers (`ChatDoneWatcher`,
/// reason "answer") is a fourth one: it reads a chat that the user left, until the answer is
/// done, and then releases the service. A conversation alone holds no wake lock.
///
/// The foreground service type is `specialUse`. `dataSync` is for transfers that end,
/// and on Android 15 (targetSdk 35 and later) the system stops it after 6 hours in 24;
/// a conversation can be longer. `specialUse` has no such limit. It needs a subtype
/// property in the manifest, and a store review if the app is on Google Play; this app
/// is not.
///
/// If the user refuses the notification permission (Android 13+), the service still
/// runs: the system shows it in the list of running apps, but there is no notification
/// in the shade.
class ConversationService : Service() {
    companion object {
        private const val CHANNEL_ID = "conversation"
        private const val NOTIFICATION_ID = 7301
        private const val EXTRA_REASONS = "reasons"

        /// The work that keeps the CPU awake. A conversation is not in it. An answer that is
        /// pending after the user left the chat is: the reads go on with the screen off.
        private val WORK = setOf("launch", "transfer", "import", "answer")

        /// The longest a wake lock is held, in case Dart never releases it.
        private const val WAKE_LOCK_MS = 30L * 60L * 1000L

        /// The running service, in this process. A change of the reasons goes to it
        /// directly: a new start of a foreground service is not allowed while the app is in
        /// the background (Android 12+), and the work often ends there.
        private var running: ConversationService? = null

        fun start(context: Context, reasons: List<String>? = null): Boolean {
            val now = reasons ?: listOf("conversation")
            running?.let {
                it.update(now)
                return true
            }
            return try {
                context.applicationContext.let {
                    val intent = Intent(it, ConversationService::class.java)
                    intent.putStringArrayListExtra(EXTRA_REASONS, ArrayList(now))
                    androidx.core.content.ContextCompat.startForegroundService(it, intent)
                }
                true
            } catch (e: Exception) {
                // For example ForegroundServiceStartNotAllowedException (Android 12+) when
                // the app is not in the foreground. The conversation works without it.
                false
            }
        }

        fun stop(context: Context) {
            val app = context.applicationContext
            app.stopService(Intent(app, ConversationService::class.java))
        }
    }

    private var wakeLock: PowerManager.WakeLock? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        running = this
    }

    /// New reasons for a service that runs: its notification and its wake lock follow.
    private fun update(reasons: List<String>) {
        try {
            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.notify(NOTIFICATION_ID, buildNotification(reasons))
        } catch (e: Exception) {
            // No permission for notifications: the service runs without one.
        }
        holdCpu(reasons.any { it in WORK })
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val reasons = intent?.getStringArrayListExtra(EXTRA_REASONS) ?: arrayListOf("conversation")
        try {
            val notification = buildNotification(reasons)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                startForeground(
                    NOTIFICATION_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE
                )
            } else {
                startForeground(NOTIFICATION_ID, notification)
            }
        } catch (e: Exception) {
            stopSelf()
            return START_NOT_STICKY
        }
        holdCpu(reasons.any { it in WORK })
        // The service holds nothing but the process: if the system kills it, the
        // tunnel is gone and there is nothing to restart.
        return START_NOT_STICKY
    }

    override fun onDestroy() {
        holdCpu(false)
        if (running === this) running = null
        super.onDestroy()
    }

    /// Hold the CPU awake ([on]), or let it sleep.
    private fun holdCpu(on: Boolean) {
        if (on) {
            if (wakeLock?.isHeld == true) return
            val power = getSystemService(Context.POWER_SERVICE) as PowerManager
            wakeLock = power.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "superapp:work").apply {
                setReferenceCounted(false)
                acquire(WAKE_LOCK_MS)
            }
        } else {
            wakeLock?.let { if (it.isHeld) it.release() }
            wakeLock = null
        }
    }

    /// The title and the text of the notification for the most urgent reason.
    private fun texts(reasons: List<String>): Pair<Int, Int> = when {
        "launch" in reasons -> R.string.launch_notification_title to R.string.launch_notification_text
        "transfer" in reasons -> R.string.transfer_notification_title to R.string.transfer_notification_text
        "import" in reasons -> R.string.import_notification_title to R.string.import_notification_text
        "answer" in reasons -> R.string.answer_notification_title to R.string.answer_notification_text
        else -> R.string.conversation_notification_title to R.string.conversation_notification_text
    }

    private fun buildNotification(reasons: List<String>): Notification {
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            manager.createNotificationChannel(
                NotificationChannel(
                    CHANNEL_ID,
                    getString(R.string.conversation_channel_name),
                    NotificationManager.IMPORTANCE_LOW
                )
            )
            Notification.Builder(this, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }
        val open = packageManager.getLaunchIntentForPackage(packageName)?.let {
            PendingIntent.getActivity(
                this, 0, it, PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
            )
        }
        return builder
            .setSmallIcon(R.drawable.ic_conversation)
            .setContentTitle(getString(texts(reasons).first))
            .setContentText(getString(texts(reasons).second))
            .setOngoing(true)
            .setContentIntent(open)
            .build()
    }
}
