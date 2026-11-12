package org.celaut.chatui

import android.content.Intent
import android.view.WindowManager
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterFragmentActivity() {
    init {
        System.loadLibrary("wallet_ffi")
    }

    /// True when Android creates the activity again with its saved state: its intent was
    /// handled already (a file to import is not imported twice).
    private var restored = false

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        restored = savedInstanceState != null
        super.onCreate(savedInstanceState)
        // Balances, addresses and tx history stay out of recents thumbnails
        // and screen recordings. The mnemonic screens arm the same flag with
        // per-screen control; this keeps it on everywhere else.
        window.setFlags(
            WindowManager.LayoutParams.FLAG_SECURE,
            WindowManager.LayoutParams.FLAG_SECURE
        )
    }

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        SecureStorageHandler.registerWith(flutterEngine, this)
        DeepLinkHandler.registerWith(flutterEngine, intent)
        UpdateHandler.registerWith(flutterEngine, this)
        ConversationHandler.registerWith(flutterEngine, this)
        PackageHandler.registerWith(flutterEngine, this)
        IncomingPackageHandler.registerWith(flutterEngine, this, if (restored) null else intent)
        MotionHandler.registerWith(flutterEngine, this)
        CardsSensorsHandler.registerWith(flutterEngine, this)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        ConversationHandler.onRequestPermissionsResult(requestCode, grantResults)
        MotionHandler.onRequestPermissionsResult(this, requestCode)
    }

    @Deprecated("The picker of PackageHandler uses startActivityForResult")
    @Suppress("DEPRECATION")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        PackageHandler.onActivityResult(this, requestCode, resultCode, data)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        DeepLinkHandler.onNewIntent(intent)
        IncomingPackageHandler.onNewIntent(this, intent)
    }

    override fun onDestroy() {
        if (SecureStorageHandler.host === this) {
            SecureStorageHandler.host = null
        }
        super.onDestroy()
    }
}
