package blab.nastia.ez

import android.app.PendingIntent
import android.content.ClipboardManager
import android.os.Handler
import android.os.Looper
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import com.android.installreferrer.api.InstallReferrerClient
import com.android.installreferrer.api.InstallReferrerStateListener
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var pendingInviteShare: MethodChannel.Result? = null
    private var inviteRequest = 9104
    private var clipboardChanged = false
    private var clipboardTimestamp = 0L
    private var clipboardListener: ClipboardManager.OnPrimaryClipChangedListener? = null
    private val referrerClosers = mutableListOf<() -> Unit>()
    private var pendingInviteText: String? = null
    private val inviteHandler = Handler(Looper.getMainLooper())
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
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "blab/invite")
            .setMethodCallHandler { call, result ->
                if (call.method == "shareInvite") {
                    shareInvite(call.argument<String>("text") ?: "", result)
                } else if (call.method == "getInstallReferrer") {
                    readInstallReferrer(result)
                } else {
                    result.notImplemented()
                }
            }
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

    private fun readInstallReferrer(result: MethodChannel.Result) {
        val client = InstallReferrerClient.newBuilder(this).build()
        var finished = false
        fun finish(value: String?, retry: Boolean = false) {
            if (finished) return
            finished = true
            client.endConnection()
            if (retry) result.error("referrer_unavailable", "Try on next launch", null)
            else result.success(value)
        }
        val close = { finish(null, retry = true) }
        referrerClosers.add(close)
        val timeout = Runnable { finish(null, retry = true) }
        inviteHandler.postDelayed(timeout, 3500)
        try {
            client.startConnection(object : InstallReferrerStateListener {
                override fun onInstallReferrerSetupFinished(responseCode: Int) {
                    inviteHandler.removeCallbacks(timeout)
                    if (finished) return
                    when (responseCode) {
                        InstallReferrerClient.InstallReferrerResponse.OK -> {
                            try { finish(client.installReferrer.installReferrer) }
                            catch (_: Exception) { finish(null, retry = true) }
                        }
                        InstallReferrerClient.InstallReferrerResponse.FEATURE_NOT_SUPPORTED -> finish(null)
                        else -> finish(null, retry = true)
                    }
                }
                override fun onInstallReferrerServiceDisconnected() {
                    inviteHandler.removeCallbacks(timeout)
                    finish(null, retry = true)
                }
            })
        } catch (_: Exception) {
            inviteHandler.removeCallbacks(timeout)
            finish(null, retry = true)
        }
    }

    private fun shareInvite(text: String, result: MethodChannel.Result) {
        if (pendingInviteShare != null || text.isBlank()) {
            result.error("share_unavailable", "Cannot open sharing", null)
            return
        }
        pendingInviteShare = result
        pendingInviteText = text
        val request = ++inviteRequest
        if (Build.VERSION.SDK_INT < 35) {
            val clipboard = getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
            clipboardChanged = false
            clipboardTimestamp = if (Build.VERSION.SDK_INT >= 26) clipboard.primaryClipDescription?.timestamp ?: 0 else 0
            clipboardListener = ClipboardManager.OnPrimaryClipChangedListener { clipboardChanged = true }
            clipboard.addPrimaryClipChangedListener(clipboardListener!!)
        }
        InviteShareReceiver.onChosen = { callbackRequest, exposed ->
            if (callbackRequest == request && request == inviteRequest) finishInviteShare(exposed)
        }
        val callback = PendingIntent.getBroadcast(
            this, request,
            Intent(this, InviteShareReceiver::class.java).putExtra("request", request),
            PendingIntent.FLAG_UPDATE_CURRENT or
                (if (Build.VERSION.SDK_INT >= 31) PendingIntent.FLAG_MUTABLE else 0),
        )
        val send = Intent(Intent.ACTION_SEND).apply {
            type = "text/plain"
            putExtra(Intent.EXTRA_TEXT, text)
        }
        try {
            @Suppress("DEPRECATION")
            startActivityForResult(Intent.createChooser(send, null, callback.intentSender), request)
        } catch (error: Exception) {
            pendingInviteShare = null
            pendingInviteText = null
            InviteShareReceiver.onChosen = null
            result.error("share_unavailable", "Cannot open sharing", null)
        }
    }

    @Deprecated("Activity result bridge used by FlutterActivity")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != inviteRequest) return
        val pending = pendingInviteShare
        inviteHandler.postDelayed({
            if (pendingInviteShare != null && pendingInviteShare === pending && requestCode == inviteRequest) {
                // FR-4: older Sharesheets report Copy without a chosen component.
                val copied = if (Build.VERSION.SDK_INT < 35) {
                    val clipboard = getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
                    val changed = clipboardChanged || (Build.VERSION.SDK_INT >= 26 &&
                        (clipboard.primaryClipDescription?.timestamp ?: 0) > clipboardTimestamp)
                    changed && clipboard.primaryClip?.getItemAt(0)?.text?.toString() == pendingInviteText
                } else false
                finishInviteShare(copied)
            }
        }, 300)
    }

    private fun finishInviteShare(exposed: Boolean) {
        val result = pendingInviteShare ?: return
        clipboardListener?.let {
            (getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager).removePrimaryClipChangedListener(it)
        }
        clipboardListener = null
        pendingInviteShare = null
        pendingInviteText = null
        InviteShareReceiver.onChosen = null
        result.success(exposed)
    }

    override fun onDestroy() {
        referrerClosers.toList().forEach { it() }
        referrerClosers.clear()
        inviteHandler.removeCallbacksAndMessages(null)
        finishInviteShare(false)
        super.onDestroy()
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
