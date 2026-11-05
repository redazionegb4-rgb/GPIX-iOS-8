package app.gpix.gpix

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.view.WindowManager

class MainActivity : FlutterActivity() {
    private var gallery: GalleryBridge? = null
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        gallery = GalleryBridge(this)
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
    override fun onDestroy() { gallery?.close(); super.onDestroy() }
}

