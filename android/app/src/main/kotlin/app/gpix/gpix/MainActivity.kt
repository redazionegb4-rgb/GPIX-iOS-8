package app.gpix.gpix

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.view.WindowManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.media.AudioAttributes
import android.media.RingtoneManager
import android.net.Uri
import android.os.Build

class MainActivity : FlutterActivity() {
    private var transcription: VoiceTranscription? = null
    private var gallery: GalleryBridge? = null
    private val directMessageChannel = "gpix_direct_messages_v1"
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
            manager.createNotificationChannel(channel)
        }
        MethodChannel(engine.dartExecutor.binaryMessenger, "GPIX/notificationAudio")
            .setMethodCallHandler { call, result ->
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
    override fun onDestroy() { gallery?.close(); transcription?.close(); super.onDestroy() }
}

