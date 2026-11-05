package org.celaut.chatui

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.net.ConnectivityManager
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.provider.OpenableColumns
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.concurrent.atomic.AtomicBoolean

/// The package of a service, for a node that does not have it (`docs/celaut/package.md`):
/// the user picks a `.celaut.bee` file, and the app copies it into its cache with a
/// stream (a service can be large, so never into memory). Also says if the network is
/// metered, so that the app can warn before a large transfer on mobile data.
///
/// The pick and the copy are two calls. The pick answers as soon as the user chose the
/// file, with its name and size, so that the app shows its progress card before the copy
/// starts. While the copy runs, it tells its bytes to Flutter (`copied`), and `cancelCopy`
/// stops it.
object PackageHandler {
    private const val CHANNEL = "org.celaut.chatui/package"
    private const val REQUEST_PICK = 7303

    /// The time between two counts of the copy that go to Flutter.
    private const val REPORT_MS = 100L

    private var pending: MethodChannel.Result? = null
    private var channel: MethodChannel? = null
    private val main = Handler(Looper.getMainLooper())

    /// The copy that runs now stops when this is set. One copy at a time.
    private val cancelled = AtomicBoolean(false)

    fun registerWith(engine: FlutterEngine, activity: Activity) {
        channel = MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL).also {
            it.setMethodCallHandler { call, result ->
                when (call.method) {
                    "pickPackage" -> pick(activity, result)
                    "copyPackage" -> copyInBackground(activity, call.argument<String>("uri"), result)
                    "cancelCopy" -> {
                        cancelled.set(true)
                        result.success(null)
                    }
                    "isMetered" -> result.success(isMetered(activity))
                    else -> result.notImplemented()
                }
            }
        }
    }

    private fun isMetered(context: Context): Boolean {
        val manager = context.getSystemService(Context.CONNECTIVITY_SERVICE) as? ConnectivityManager
        return manager?.isActiveNetworkMetered ?: false
    }

    private fun pick(activity: Activity, result: MethodChannel.Result) {
        // One question at a time: an older one that is still open gets no file.
        pending?.success(null)
        pending = result
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            // Any type: a .celaut.bee file has no MIME type of its own.
            type = "*/*"
        }
        try {
            @Suppress("DEPRECATION")
            activity.startActivityForResult(intent, REQUEST_PICK)
        } catch (e: Exception) {
            pending = null
            result.error("no_picker", e.message, null)
        }
    }

    /// Called by `MainActivity.onActivityResult`. Answers with the file that the user
    /// chose, not with a copy: the copy is `copyPackage`.
    fun onActivityResult(context: Context, requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode != REQUEST_PICK) return
        val result = pending ?: return
        pending = null
        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null) {
            result.success(null)
            return
        }
        // The provider of the file gives its name and size: not on the main thread.
        Thread {
            val chosen = describe(context, uri)
            main.post { result.success(chosen) }
        }.start()
    }

    /// The uri, the name and the size of a file (-1 if the provider does not say it).
    private fun describe(context: Context, uri: Uri): Map<String, Any> {
        var name: String? = null
        var size = -1L
        try {
            context.contentResolver.query(
                uri,
                arrayOf(OpenableColumns.DISPLAY_NAME, OpenableColumns.SIZE),
                null,
                null,
                null,
            )?.use {
                if (it.moveToFirst()) {
                    name = it.getString(0)
                    if (!it.isNull(1)) size = it.getLong(1)
                }
            }
        } catch (e: Exception) {
            // A provider that does not answer: the copy says if the file can be read.
        }
        return mapOf(
            "uri" to uri.toString(),
            "name" to (name ?: uri.lastPathSegment ?: "package"),
            "bytes" to size,
        )
    }

    private fun copyInBackground(context: Context, uri: String?, result: MethodChannel.Result) {
        if (uri == null) {
            result.error("copy_failed", "the call has no uri", null)
            return
        }
        cancelled.set(false)
        // The copy reads and writes the disk: not on the main thread.
        Thread {
            try {
                val copied = copy(context, Uri.parse(uri))
                main.post { result.success(copied) }
            } catch (e: CopyCancelled) {
                main.post { result.error("cancelled", "the copy was cancelled", null) }
            } catch (e: Exception) {
                main.post { result.error("copy_failed", e.message, null) }
            }
        }.start()
    }

    private class CopyCancelled : Exception()

    private fun copy(context: Context, uri: Uri): Map<String, Any> {
        val folder = File(context.cacheDir, "packages")
        folder.mkdirs()
        val target = File(folder, "picked-${System.currentTimeMillis()}.bee")
        val input = context.contentResolver.openInputStream(uri)
            ?: throw IllegalStateException("the file cannot be opened")
        try {
            input.use { source ->
                target.outputStream().use { sink ->
                    val buffer = ByteArray(1 shl 16)
                    var total = 0L
                    var reported = 0L
                    while (true) {
                        if (cancelled.get()) throw CopyCancelled()
                        val n = source.read(buffer)
                        if (n < 0) break
                        sink.write(buffer, 0, n)
                        total += n
                        val now = SystemClock.uptimeMillis()
                        if (now - reported >= REPORT_MS) {
                            reported = now
                            report(total)
                        }
                    }
                    report(total)
                }
            }
        } catch (e: Exception) {
            target.delete()
            throw e
        }
        return mapOf(
            "path" to target.absolutePath,
            "bytes" to target.length(),
        )
    }

    /// Tell Flutter the bytes that the copy wrote so far.
    private fun report(bytes: Long) {
        main.post { channel?.invokeMethod("copied", bytes) }
    }
}
