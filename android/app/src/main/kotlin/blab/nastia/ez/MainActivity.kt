package blab.nastia.ez

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var shareChannel: MethodChannel? = null
    private var pendingSharedImage: Map<String, Any?>? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        createMessagesNotificationChannel()
        pendingSharedImage = sharedImageFromIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        val sharedImage = sharedImageFromIntent(intent) ?: return
        pendingSharedImage = sharedImage
        shareChannel?.invokeMethod("sharedImage", sharedImage)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, NOTIFICATIONS_CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method == "openNotificationSettings") {
                    openNotificationSettings()
                    result.success(null)
                } else {
                    result.notImplemented()
                }
            }
        shareChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SHARE_INTENT_CHANNEL)
        shareChannel?.setMethodCallHandler { call, result ->
            if (call.method == "getInitialSharedImage") {
                result.success(pendingSharedImage)
                pendingSharedImage = null
            } else {
                result.notImplemented()
            }
        }
    }

    private fun createMessagesNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val channel = NotificationChannel(
            MESSAGES_CHANNEL_ID,
            getString(R.string.messages_notification_channel_name),
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = getString(R.string.messages_notification_channel_description)
        }
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        manager.createNotificationChannel(channel)
    }

    private fun openNotificationSettings() {
        startActivity(
            Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).apply {
                putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
            },
        )
    }

    private fun sharedImageFromIntent(intent: Intent?): Map<String, Any?>? {
        if (intent?.action != Intent.ACTION_SEND) return null
        val stream = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            intent.getParcelableExtra(Intent.EXTRA_STREAM, Uri::class.java)
        } else {
            @Suppress("DEPRECATION")
            intent.getParcelableExtra(Intent.EXTRA_STREAM) as? Uri
        } ?: return null
        val mimeType = intent.type?.takeIf { it.startsWith("image/") }
            ?: contentResolver.getType(stream)?.takeIf { it.startsWith("image/") }
            ?: return null
        val bytes = try {
            contentResolver.openInputStream(stream)?.use { it.readBytes() }
                ?: return null
        } catch (_: Exception) {
            return null
        }
        if (bytes.isEmpty()) return null
        return mapOf(
            "uri" to stream.toString(),
            "mimeType" to mimeType,
            "name" to (stream.lastPathSegment ?: "shared-image"),
            "bytes" to bytes,
        )
    }

    private companion object {
        const val NOTIFICATIONS_CHANNEL = "blab/notifications"
        const val SHARE_INTENT_CHANNEL = "blab/share_intent"
        const val MESSAGES_CHANNEL_ID = "messages"
    }
}
