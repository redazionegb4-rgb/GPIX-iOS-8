package app.gpix.gpix
import android.Manifest
import android.app.Activity
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Matrix
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.MediaStore
import android.util.Size
import androidx.exifinterface.media.ExifInterface
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.io.File
import java.util.UUID
import java.util.concurrent.Executors

class GalleryBridge(private val activity:Activity):MethodChannel.MethodCallHandler {
 private val executor=Executors.newSingleThreadExecutor()
 private val main=Handler(Looper.getMainLooper())
 private var pending:MethodChannel.Result?=null
 override fun onMethodCall(call:MethodCall,result:MethodChannel.Result) {
  when(call.method) {
   "recent" -> {
    val permission=if(Build.VERSION.SDK_INT>=33) Manifest.permission.READ_MEDIA_IMAGES else Manifest.permission.READ_EXTERNAL_STORAGE
    val limited=Build.VERSION.SDK_INT>=34 && activity.checkSelfPermission("android.permission.READ_MEDIA_VISUAL_USER_SELECTED")==PackageManager.PERMISSION_GRANTED
    if(activity.checkSelfPermission(permission)==PackageManager.PERMISSION_GRANTED || limited) list(result)
    else if(pending!=null) result.error("BUSY","Richiesta foto già aperta",null)
    else {pending=result; val permissions=if(Build.VERSION.SDK_INT>=34) arrayOf(permission,"android.permission.READ_MEDIA_VISUAL_USER_SELECTED") else arrayOf(permission);activity.requestPermissions(permissions,6406)}
   }
   "copy" -> background(result) {
    val id=call.argument<String>("id")?:error("Foto mancante")
    require(id.matches(Regex("[0-9]+")))
    val uri=Uri.withAppendedPath(MediaStore.Images.Media.EXTERNAL_CONTENT_URI,id)
    val resolver=activity.contentResolver
    val options=BitmapFactory.Options().apply { inJustDecodeBounds=true }
    resolver.openInputStream(uri).use { BitmapFactory.decodeStream(it,null,options) }
    require(options.outWidth>0 && options.outHeight>0) {"Foto non decodificabile"}
    var sample=1;while(maxOf(options.outWidth,options.outHeight)/sample>3000) sample*=2
    val decoded=resolver.openInputStream(uri).use {BitmapFactory.decodeStream(it,null,BitmapFactory.Options().apply{inSampleSize=sample})}?:error("Foto non disponibile")
    val exif=resolver.openInputStream(uri).use {ExifInterface(it!!)}
    val matrix=Matrix();if(exif.isFlipped) matrix.postScale(-1f,1f);matrix.postRotate(exif.rotationDegrees.toFloat())
    val normalized=Bitmap.createBitmap(decoded,0,0,decoded.width,decoded.height,matrix,true)
    val file=File(activity.cacheDir,"gpix-photo-${UUID.randomUUID()}.jpg")
    file.outputStream().use {normalized.compress(Bitmap.CompressFormat.JPEG,95,it)}
    if(normalized!==decoded) normalized.recycle();decoded.recycle();file.absolutePath
   }
   else -> result.notImplemented()
  }
 }
 fun permissionResult(code:Int):Boolean {if(code!=6406)return false;val result=pending;pending=null;if(result!=null) list(result);return true}
 private fun list(result:MethodChannel.Result)=background(result) {
  val values=mutableListOf<Map<String,Any>>()
  activity.contentResolver.query(MediaStore.Images.Media.EXTERNAL_CONTENT_URI,arrayOf(MediaStore.Images.Media._ID),null,null,"${MediaStore.Images.Media.DATE_ADDED} DESC")?.use {cursor ->
   while(cursor.moveToNext() && values.size<100) {
    val id=cursor.getLong(0);val uri=Uri.withAppendedPath(MediaStore.Images.Media.EXTERNAL_CONTENT_URI,"$id")
    try {
     val bitmap=if(Build.VERSION.SDK_INT>=29) activity.contentResolver.loadThumbnail(uri,Size(180,180),null) else MediaStore.Images.Thumbnails.getThumbnail(activity.contentResolver,id,MediaStore.Images.Thumbnails.MINI_KIND,null)
     if(bitmap!=null) {val bytes=ByteArrayOutputStream();bitmap.compress(Bitmap.CompressFormat.JPEG,75,bytes);bitmap.recycle();values.add(mapOf("id" to "$id","thumbnail" to bytes.toByteArray()))}
    } catch(_:Exception) {}
   }
  };values
 }
 private fun background(result:MethodChannel.Result,work:()->Any) {executor.execute {try {val value=work();main.post{result.success(value)}}catch(e:Exception){main.post{result.error("GALLERY",e.message,null)}}}}
 fun close(){pending?.error("CLOSED","Schermata chiusa",null);pending=null;executor.shutdown()}
}
