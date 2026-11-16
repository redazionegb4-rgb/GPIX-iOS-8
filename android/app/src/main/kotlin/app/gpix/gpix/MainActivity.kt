package app.gpix.gpix

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.view.WindowManager
import android.app.Notification
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.app.PendingIntent
import android.app.NotificationChannel
import android.app.NotificationManager
import android.media.AudioAttributes
import android.media.RingtoneManager
import android.net.Uri
import android.os.Build

class MainActivity : FlutterActivity() {
    private var transcription: VoiceTranscription? = null
    private var reelEditing: ReelEditingBridge? = null
    private var gallery: GalleryBridge? = null
    private val directMessageChannel = "gpix_direct_messages_v2"
    private val badgeChannel = "gpix_unread_badge_v1"
    private val badgeNotificationId = 51793
    private val activityChannel = "gpix_activity_badge_v1"
    private fun directMessageSound(): Uri {
        val soundName = resources.getResourceEntryName(R.raw.gpix_dm)
        return Uri.parse("android.resource://$packageName/raw/$soundName")
    }
    private val notificationAudio = AudioAttributes.Builder()
        .setUsage(AudioAttributes.USAGE_NOTIFICATION)
        .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
        .build()

    private fun configureDirectMessages(engine: FlutterEngine) {
        val manager = getSystemService(NotificationManager::class.java) ?: return
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                directMessageChannel, "Messaggi privati", NotificationManager.IMPORTANCE_DEFAULT
            )
            channel.description = "Notifiche delle conversazioni uno a uno su GPIX"
            channel.setSound(directMessageSound(), notificationAudio)
            channel.setShowBadge(true)
            manager.createNotificationChannel(channel)
            val activity = NotificationChannel(
                activityChannel, "Attività GPIX", NotificationManager.IMPORTANCE_DEFAULT
            )
            activity.setShowBadge(true)
            manager.createNotificationChannel(activity)
            val badge = NotificationChannel(
                badgeChannel, "Contatore non letti", NotificationManager.IMPORTANCE_LOW
            )
            badge.setShowBadge(true)
            manager.createNotificationChannel(badge)
        }
        MethodChannel(engine.dartExecutor.binaryMessenger, "GPIX/notificationAudio")
            .setMethodCallHandler { call, result ->
                if (call.method == "badgeChannels") {
                    result.success(Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
                    return@setMethodCallHandler
                }
                if (call.method == "syncBadge") {
                    val count = (call.arguments as? Int ?: 0).coerceAtLeast(0)
                    MainActivityHuaweiBadge.update(this, count)
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        val active = manager.activeNotifications
                        if (count == 0) {
                            manager.cancel(badgeNotificationId)
                            for (entry in active) {
                                val channel = entry.notification.channelId
                                if (channel == directMessageChannel || channel == activityChannel) {
                                    manager.cancel(entry.tag, entry.id)
                                }
                            }
                        } else if (manager.areNotificationsEnabled()) {
                            val hasBadgeNotification = active.any { entry ->
                                entry.id != badgeNotificationId &&
                                    manager.getNotificationChannel(entry.notification.channelId)?.canShowBadge() == true
                            }
                            if (hasBadgeNotification) {
                                manager.cancel(badgeNotificationId)
                            } else {
                                val launch = packageManager.getLaunchIntentForPackage(packageName)
                                val notification = Notification.Builder(this, badgeChannel)
                                    .setSmallIcon(applicationInfo.icon)
                                    .setContentTitle("GPIX")
                                    .setContentText(if (count == 1) "1 elemento non letto" else "$count elementi non letti")
                                    .setNumber(count)
                                    .setOnlyAlertOnce(true)
                                    .setShowWhen(false)
                                if (launch != null) {
                                    notification.setContentIntent(PendingIntent.getActivity(
                                        this, 0, launch, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                                    ))
                                }
                                manager.notify(badgeNotificationId, notification.build())
                            }
                        }
                    }
                    result.success(null)
                    return@setMethodCallHandler
                }
                if (call.method != "playDirectMessage") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                if (manager.areNotificationsEnabled()) {
                    val sound = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        val channel = manager.getNotificationChannel(directMessageChannel)
                        if (channel != null && channel.importance >= NotificationManager.IMPORTANCE_DEFAULT) {
                            channel.sound
                        } else null
                    } else directMessageSound()
                    if (sound != null) {
                        RingtoneManager.getRingtone(this, sound)?.let {
                            it.audioAttributes = notificationAudio
                            it.play()
                        }
                    }
                }
                result.success(null)
            }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        configureDirectMessages(flutterEngine)
        gallery = GalleryBridge(this)
        reelEditing = ReelEditingBridge(this, flutterEngine.dartExecutor.binaryMessenger)
        transcription = VoiceTranscription(this, flutterEngine.dartExecutor.binaryMessenger)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "GPIX/gallery").setMethodCallHandler(gallery)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "GPIX/privacy").setMethodCallHandler { call, result ->
            if (call.method == "secure") {
                if (call.arguments == true) window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
                else window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                result.success(null)
            } else result.notImplemented()
        }
    }
    override fun onRequestPermissionsResult(requestCode:Int, permissions:Array<out String>, grantResults:IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        gallery?.permissionResult(requestCode)
    }
    override fun onDestroy() { gallery?.close(); reelEditing?.close(); transcription?.close(); super.onDestroy() }
}



class MainActivityBadgeReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != "com.google.android.c2dm.intent.RECEIVE") return
        val count = intent.getStringExtra("badgeCount")?.toIntOrNull() ?: return
        MainActivityHuaweiBadge.update(context, count, goAsync())
    }
}

private object MainActivityHuaweiBadge {
    private val authority = Uri.parse("content://com.huawei.android.launcher.settings/badge/")
    private val worker = java.util.concurrent.Executors.newSingleThreadExecutor()

    fun update(context: Context, count: Int, pending: BroadcastReceiver.PendingResult? = null) {
        if (!Build.MANUFACTURER.equals("Huawei", ignoreCase = true)) { pending?.finish(); return }
        val app = context.applicationContext
        worker.execute { try { apply(app, count) } finally { pending?.finish() } }
    }

    private fun apply(context: Context, count: Int) {
        val component = context.packageManager.getLaunchIntentForPackage(context.packageName)?.component ?: return
        try {
            context.contentResolver.call(authority, "change_badge", null, Bundle().apply {
                putString("package", component.packageName)
                putString("class", component.className)
                putInt("badgenumber", count.coerceAtLeast(0))
            })
        } catch (_: RuntimeException) {
            // EMUI firmware may restrict access to its launcher provider.
        }
    }
}
