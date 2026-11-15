package app.gpix.gpix

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.RectF
import android.media.MediaMetadataRetriever
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import androidx.annotation.OptIn
import androidx.media3.common.C
import androidx.media3.common.MediaItem
import androidx.media3.common.MimeTypes
import androidx.media3.common.audio.ChannelMixingAudioProcessor
import androidx.media3.common.audio.ChannelMixingMatrix
import androidx.media3.common.util.UnstableApi
import androidx.media3.effect.BitmapOverlay
import androidx.media3.effect.OverlayEffect
import androidx.media3.effect.Presentation
import androidx.media3.transformer.Composition
import androidx.media3.transformer.DefaultEncoderFactory
import androidx.media3.transformer.EditedMediaItem
import androidx.media3.transformer.EditedMediaItemSequence
import androidx.media3.transformer.Effects
import androidx.media3.transformer.ExportException
import androidx.media3.transformer.ExportResult
import androidx.media3.transformer.ProgressHolder
import androidx.media3.transformer.Transformer
import androidx.media3.transformer.VideoEncoderSettings
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.io.File
import java.util.concurrent.Executors
import kotlin.math.max
import kotlin.math.min
import kotlin.math.roundToInt

@OptIn(UnstableApi::class)
class ReelEditingBridge(private val context: Context, messenger: BinaryMessenger) :
    MethodChannel.MethodCallHandler {
    private val channel = MethodChannel(messenger, "GPIX/reelEditing")
    private val main = Handler(Looper.getMainLooper())
    private val worker = Executors.newSingleThreadExecutor()
    private var transformer: Transformer? = null
    private var exportResult: MethodChannel.Result? = null

    init { channel.setMethodCallHandler(this) }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "inspect" -> background(result) { inspect(input(call)) }
            "frames" -> background(result) {
                val file = input(call)
                val positions = call.argument<List<Number>>("positions") ?: emptyList()
                val size = (call.argument<Number>("size")?.toInt() ?: 175).coerceIn(80, 320)
                if (isPhoto(file)) {
                    val thumb = jpeg(photo(file, size), 78)
                    positions.take(12).map { thumb }
                } else {
                    video(file) { reader ->
                        positions.take(12).map { time -> jpeg(frame(reader, time.toLong(), size), 78) }
                    }
                }
            }
            "cover" -> background(result) {
                val file = input(call)
                val title = if (isPhoto(file)) photo(file, 1100) else video(file) { reader ->
                    frame(reader, call.argument<Number>("positionMs")?.toLong() ?: 0, 1080)
                }
                val portrait = portrait(title)
                val output = File(call.argument<String>("output") ?: error("Percorso mancante"))
                output.writeBytes(jpeg(portrait, 92))
                title.recycle()
                output.absolutePath
            }
            "export" -> try {
                export(call, result)
            } catch (e: Exception) {
                transformer = null
                exportResult = null
                result.error("REEL_EXPORT", e.message, null)
            }
            "progress" -> {
                val holder = ProgressHolder()
                val state = transformer?.getProgress(holder)
                result.success(if (state == Transformer.PROGRESS_STATE_AVAILABLE) holder.progress else null)
            }
            else -> result.notImplemented()
        }
    }

    private fun background(result: MethodChannel.Result, work: () -> Any) {
        worker.execute {
            try {
                val value = work()
                main.post { result.success(value) }
            } catch (e: Exception) {
                main.post { result.error("REEL_MEDIA", e.message, null) }
            }
        }
    }

    private fun input(call: MethodCall): File = File(call.argument<String>("path") ?: error("File mancante"))
        .also { require(it.isFile && it.length() > 0) { "Contenuto non disponibile" } }

    private fun isPhoto(file: File): Boolean {
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeFile(file.absolutePath, bounds)
        return bounds.outWidth > 0 && bounds.outHeight > 0
    }

    private inline fun <T> video(file: File, block: (MediaMetadataRetriever) -> T): T {
        val reader = MediaMetadataRetriever()
        try {
            reader.setDataSource(file.absolutePath)
            return block(reader)
        } finally {
            reader.release()
        }
    }

    private fun inspect(file: File): Map<String, Any> {
        if (isPhoto(file)) return mapOf("photo" to true, "thumbnail" to jpeg(photo(file, 240), 80))
        return video(file) { reader ->
            require(reader.extractMetadata(MediaMetadataRetriever.METADATA_KEY_HAS_VIDEO) == "yes") {
                "Scegli una foto o un video"
            }
            val length = reader.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION)?.toLongOrNull() ?: 0
            require(length > 0) { "Video non riproducibile" }
            val preview = frame(reader, min(length / 5, 700), 240)
            mapOf("photo" to false, "durationMs" to length, "thumbnail" to jpeg(preview, 80))
        }
    }

    private fun frame(reader: MediaMetadataRetriever, ms: Long, size: Int): Bitmap {
        val width = reader.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_WIDTH)?.toIntOrNull() ?: size
        val height = reader.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_HEIGHT)?.toIntOrNull() ?: size
        val rotation = reader.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_ROTATION)?.toIntOrNull() ?: 0
        val extent = max(width, height).coerceAtLeast(1)
        val outWidth = (width.toDouble() * size / extent).roundToInt().coerceAtLeast(1)
        val outHeight = (height.toDouble() * size / extent).roundToInt().coerceAtLeast(1)
        val timeUs = ms.coerceAtLeast(0) * 1000
        val rotated = rotation == 90 || rotation == 270
        val frame = if (Build.VERSION.SDK_INT >= 27) {
            reader.getScaledFrameAtTime(timeUs, MediaMetadataRetriever.OPTION_CLOSEST,
                if (rotated) outHeight else outWidth, if (rotated) outWidth else outHeight)
        } else {
            reader.getFrameAtTime(timeUs, MediaMetadataRetriever.OPTION_CLOSEST)
        } ?: reader.getFrameAtTime(0, MediaMetadataRetriever.OPTION_CLOSEST_SYNC)
          ?: error("Fotogramma non disponibile")
        return scale(frame, size)
    }

    private fun photo(file: File, size: Int): Bitmap {
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeFile(file.absolutePath, bounds)
        require(bounds.outWidth > 0 && bounds.outHeight > 0) { "Foto non leggibile" }
        var sample = 1
        while (max(bounds.outWidth, bounds.outHeight) / sample > size * 2) sample *= 2
        val bitmap = BitmapFactory.decodeFile(file.absolutePath, BitmapFactory.Options().apply { inSampleSize = sample })
            ?: error("Foto non disponibile")
        return scale(bitmap, size)
    }

    private fun scale(bitmap: Bitmap, size: Int): Bitmap {
        val extent = max(bitmap.width, bitmap.height)
        if (extent <= size) return bitmap
        val width = (bitmap.width.toDouble() * size / extent).roundToInt().coerceAtLeast(1)
        val height = (bitmap.height.toDouble() * size / extent).roundToInt().coerceAtLeast(1)
        return Bitmap.createScaledBitmap(bitmap, width, height, true).also {
            if (it != bitmap) bitmap.recycle()
        }
    }

    private fun jpeg(bitmap: Bitmap, quality: Int): ByteArray {
        val bytes = ByteArrayOutputStream()
        bitmap.compress(Bitmap.CompressFormat.JPEG, quality, bytes)
        bitmap.recycle()
        return bytes.toByteArray()
    }

    private fun portrait(bitmap: Bitmap): Bitmap {
        val output = Bitmap.createBitmap(WIDTH, HEIGHT, Bitmap.Config.ARGB_8888)
        val zoom = max(WIDTH.toFloat() / bitmap.width, HEIGHT.toFloat() / bitmap.height)
        val width = bitmap.width * zoom
        val height = bitmap.height * zoom
        val left = (WIDTH - width) / 2f
        val top = (HEIGHT - height) / 2f
        Canvas(output).drawBitmap(bitmap, null, RectF(left, top, left + width, top + height),
            Paint(Paint.FILTER_BITMAP_FLAG))
        return output
    }

    private fun mixer(volume: Float): ChannelMixingAudioProcessor =
        ChannelMixingAudioProcessor().apply {
            putChannelMixingMatrix(ChannelMixingMatrix.create(1, 2).scaleBy(volume))
            putChannelMixingMatrix(ChannelMixingMatrix.create(2, 2).scaleBy(volume))
        }

    private fun export(call: MethodCall, result: MethodChannel.Result) {
        if (transformer != null) {
            result.error("REEL_BUSY", "Un reel è già in esportazione", null)
            return
        }
        val clips = call.argument<List<Map<String, Any?>>>("clips") ?: emptyList()
        require(clips.isNotEmpty() && clips.size <= 16) { "Aggiungi almeno una clip" }
        val originalAudio = call.argument<Boolean>("originalAudio") ?: true
        val music = call.argument<String>("music")?.takeIf { it.isNotEmpty() }?.let(::File)
        require(music == null || music.isFile) { "Brano non disponibile" }
        val presentation = Presentation.createForWidthAndHeight(WIDTH, HEIGHT, Presentation.LAYOUT_SCALE_TO_FIT_WITH_CROP)
        var totalMs = 0L
        val items = clips.map { clip ->
            val file = File(clip["path"] as? String ?: error("Clip mancante"))
            require(file.isFile) { "Una clip non è più disponibile" }
            val start = (clip["startMs"] as? Number)?.toLong() ?: 0
            val end = (clip["endMs"] as? Number)?.toLong() ?: 0
            require(start >= 0 && end > start) { "Taglio non valido" }
            totalMs += end - start
            val photo = clip["photo"] == true
            val media = MediaItem.Builder().setUri(Uri.fromFile(file))
            if (photo) {
                media.setImageDurationMs(end - start)
            } else {
                media.setClippingConfiguration(MediaItem.ClippingConfiguration.Builder()
                    .setStartPositionMs(start).setEndPositionMs(end).build())
            }
            EditedMediaItem.Builder(media.build())
                .setFrameRate(30)
                .setRemoveAudio(!originalAudio)
                .setEffects(Effects(
                    if (originalAudio) listOf(mixer(if (music == null) 1f else .7f)) else emptyList(),
                    listOf(presentation)
                )).build()
        }
        require(totalMs <= 90_000) { "Il reel supera 90 secondi" }
        val sequences = mutableListOf(
            if (originalAudio) EditedMediaItemSequence.withAudioAndVideoFrom(items)
            else EditedMediaItemSequence.withVideoFrom(items)
        )
        if (music != null) {
            val start = call.argument<Number>("musicStartMs")?.toLong() ?: 0
            val length = call.argument<Number>("musicLengthMs")?.toLong() ?: 15_000
            val track = MediaItem.Builder().setUri(Uri.fromFile(music))
                .setClippingConfiguration(MediaItem.ClippingConfiguration.Builder()
                    .setStartPositionMs(start).setEndPositionMs(start + length).build())
                .build()
            val edit = EditedMediaItem.Builder(track).setRemoveVideo(true)
                .setEffects(Effects(listOf(mixer(if (originalAudio) .65f else 1f)), emptyList())).build()
            sequences.add(EditedMediaItemSequence.Builder(setOf(C.TRACK_TYPE_AUDIO)).addItem(edit).setIsLooping(true).build())
        }
        val file = File(call.argument<String>("output") ?: error("Percorso mancante"))
        if (file.exists()) file.delete()
        val overlayPath = call.argument<String>("overlay")
        val overlay = if (overlayPath == null) null else BitmapFactory.decodeFile(overlayPath)
            ?: error("Testo non disponibile")
        val composition = Composition.Builder(sequences)
            .setHdrMode(Composition.HDR_MODE_TONE_MAP_HDR_TO_SDR_USING_OPEN_GL)
        if (overlay != null) {
            composition.setEffects(Effects(emptyList(),
                listOf(OverlayEffect(listOf(BitmapOverlay.createStaticBitmapOverlay(overlay))))))
        }
        val encoder = DefaultEncoderFactory.Builder(context)
            .setRequestedVideoEncoderSettings(VideoEncoderSettings.Builder().setBitrate(1_720_000).build())
            .setEnableFallback(true).build()
        val next = Transformer.Builder(context)
            .setVideoMimeType(MimeTypes.VIDEO_H264)
            .setAudioMimeType(MimeTypes.AUDIO_AAC)
            .setEncoderFactory(encoder)
            .addListener(object : Transformer.Listener {
                override fun onCompleted(composition: Composition, output: ExportResult) {
                    transformer = null
                    exportResult = null
                    overlay?.recycle()
                    if (file.isFile && file.length() in 1..25L * 1024 * 1024) {
                        result.success(file.absolutePath)
                    } else {
                        file.delete()
                        result.error("REEL_SIZE", "Il video supera il limite di caricamento. Accorcia il reel e riprova.", null)
                    }
                }

                override fun onError(composition: Composition, output: ExportResult, cause: ExportException) {
                    transformer = null
                    exportResult = null
                    overlay?.recycle()
                    file.delete()
                    result.error("REEL_EXPORT", "Impossibile esportare questa clip. Sostituiscila e riprova.", cause.errorCode)
                }
            }).build()
        transformer = next
        exportResult = result
        next.start(composition.build(), file.absolutePath)
    }

    fun close() {
        channel.setMethodCallHandler(null)
        transformer?.cancel()
        transformer = null
        exportResult?.error("CLOSED", "Editor chiuso", null)
        exportResult = null
        worker.shutdown()
    }

    private companion object {
        const val WIDTH = 540
        const val HEIGHT = 960
    }
}
