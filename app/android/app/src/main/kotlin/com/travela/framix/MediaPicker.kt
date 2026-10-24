package com.travela.framix

import android.app.Activity
import android.content.ContentValues
import android.content.Intent
import android.graphics.BitmapFactory
import android.media.ExifInterface
import android.media.MediaExtractor
import android.media.MediaFormat
import android.media.MediaMetadataRetriever
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.provider.MediaStore
import androidx.core.content.FileProvider
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.concurrent.Executors

/**
 * Method channel `framix/media`: the system document picker plus the metadata the engine needs
 * (P1-011), and saving or sharing an exported video (P1-036). Picked files are not copied: the
 * engine stores the content:// URI and the app keeps a persistable read permission. The engine
 * validates every field.
 */
class MediaPicker(private val activity: Activity) : MethodChannel.MethodCallHandler {
    private var pending: MethodChannel.Result? = null
    private val io = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        // Exports go to the cache, the only folder save and FileProvider share accept (Dart's
        // own temp folder is code_cache, which FileProvider can't serve).
        if (call.method == "exportDir") return result.success(activity.cacheDir.path)
        if (call.method == "saveToGallery" || call.method == "share") {
            // Only files in the cache (the export), never other app-private files.
            val cache = activity.cacheDir.canonicalPath + File.separator
            val file = call.argument<String>("path")?.let { File(it).canonicalFile }
                ?.takeIf { it.isFile && it.path.startsWith(cache) }
                ?: return result.error("no-file", null, null)
            return if (call.method == "share") share(file, result) else save(file, result)
        }
        if (call.method != "pickGallery" && call.method != "pickFiles") {
            return result.notImplemented()
        }
        if (pending != null) return result.error("busy", null, null)
        pending = result
        // One picker covers the gallery, Google Drive and local files on Android.
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = "*/*"
            putExtra(Intent.EXTRA_MIME_TYPES, arrayOf("image/*", "video/*"))
            putExtra(Intent.EXTRA_ALLOW_MULTIPLE, true)
        }
        activity.startActivityForResult(intent, REQUEST)
    }

    /** Handles the picker result; returns false for other requests. */
    fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != REQUEST) return false
        val result = pending ?: return true
        pending = null
        val uris = if (resultCode == Activity.RESULT_OK) picked(data) else emptyList()
        io.execute {
            val items = uris.mapNotNull { probe(it) }
            main.post { result.success(items) }
        }
        return true
    }

    /** Copies the video into Movies/Framix; own inserts need no permission on API 29+. */
    private fun save(file: File, result: MethodChannel.Result) = io.execute {
        val resolver = activity.contentResolver
        val values = ContentValues().apply {
            put(MediaStore.Video.Media.DISPLAY_NAME, "Framix_${System.currentTimeMillis()}.mp4")
            put(MediaStore.Video.Media.MIME_TYPE, "video/mp4")
            put(MediaStore.Video.Media.RELATIVE_PATH, "Movies/Framix")
            // Hidden until complete, so the gallery never shows half a file.
            put(MediaStore.Video.Media.IS_PENDING, 1)
        }
        val collection = MediaStore.Video.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
        val uri = runCatching { resolver.insert(collection, values) }.getOrNull()
        val saved = uri != null && runCatching {
            val out = resolver.openOutputStream(uri) ?: error("no output stream")
            out.use { o -> file.inputStream().use { it.copyTo(o) } }
            val done = ContentValues().apply { put(MediaStore.Video.Media.IS_PENDING, 0) }
            check(resolver.update(uri, done, null, null) == 1) { "still pending" }
        }.isSuccess
        if (!saved && uri != null) runCatching { resolver.delete(uri, null, null) }
        main.post {
            if (saved) result.success("saved") else result.error("save-failed", null, null)
        }
    }

    /** The system share sheet over a FileProvider URI (res/xml/file_paths.xml: the cache). */
    private fun share(file: File, result: MethodChannel.Result) {
        val uri = runCatching {
            FileProvider.getUriForFile(activity, "${activity.packageName}.files", file)
        }.getOrElse { return result.error("no-file", null, null) }
        val send = Intent(Intent.ACTION_SEND).apply {
            type = "video/mp4"
            putExtra(Intent.EXTRA_STREAM, uri)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        activity.startActivity(Intent.createChooser(send, null))
        result.success(null)
    }

    private fun picked(data: Intent?): List<Uri> {
        val clip = data?.clipData ?: return listOfNotNull(data?.data)
        return (0 until clip.itemCount).map { clip.getItemAt(it).uri }
    }

    private fun probe(uri: Uri): Map<String, Any>? {
        val resolver = activity.contentResolver
        // Keep access across restarts; a provider that refuses still works for this session.
        runCatching {
            resolver.takePersistableUriPermission(uri, Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        val type = resolver.getType(uri) ?: return null
        return when {
            type.startsWith("video/") -> probeVideo(uri)
            type.startsWith("image/") -> probeImage(uri)
            else -> null
        }
    }

    private fun probeVideo(uri: Uri): Map<String, Any>? = runCatching {
        MediaMetadataRetriever().use { r ->
            r.setDataSource(activity, uri)
            fun int(key: Int) = r.extractMetadata(key)?.toIntOrNull() ?: 0
            mapOf(
                "uri" to uri.toString(),
                "kind" to "video",
                "durationValue" to (r.extractMetadata(
                    MediaMetadataRetriever.METADATA_KEY_DURATION
                )?.toLongOrNull() ?: 0L),
                "durationTimescale" to 1000,
                "width" to int(MediaMetadataRetriever.METADATA_KEY_VIDEO_WIDTH),
                "height" to int(MediaMetadataRetriever.METADATA_KEY_VIDEO_HEIGHT),
                "rotation" to int(MediaMetadataRetriever.METADATA_KEY_VIDEO_ROTATION),
                "codec" to codecTag(uri),
            )
        }
    }.getOrNull()?.takeIf { readable(it) }

    /**
     * Codec tag: the video track's MIME subtype without `video/` (hevc, avc, x-vnd.on2.vp9),
     * or empty when longer than the engine's 16-character limit. Informational only.
     */
    private fun codecTag(uri: Uri): String =
        videoMime(uri)?.removePrefix("video/")?.takeIf { it.length <= 16 } ?: ""

    private fun videoMime(uri: Uri): String? {
        val extractor = MediaExtractor()
        return try {
            extractor.setDataSource(activity, uri, null)
            (0 until extractor.trackCount)
                .mapNotNull { extractor.getTrackFormat(it).getString(MediaFormat.KEY_MIME) }
                .firstOrNull { it.startsWith("video/") }
        } catch (e: Exception) {
            null
        } finally {
            extractor.release()
        }
    }

    private fun probeImage(uri: Uri): Map<String, Any>? = runCatching {
        val resolver = activity.contentResolver
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        resolver.openInputStream(uri)?.use { BitmapFactory.decodeStream(it, null, bounds) }
        val orientation = resolver.openInputStream(uri)?.use {
            ExifInterface(it).getAttributeInt(
                ExifInterface.TAG_ORIENTATION, ExifInterface.ORIENTATION_NORMAL
            )
        } ?: ExifInterface.ORIENTATION_NORMAL
        mapOf(
            "uri" to uri.toString(),
            "kind" to "image",
            "durationValue" to 0L,
            "durationTimescale" to 0,
            "width" to bounds.outWidth,
            "height" to bounds.outHeight,
            "rotation" to rotationOf(orientation),
            "codec" to "",
        )
    }.getOrNull()?.takeIf { readable(it) }

    /** Drops items the platform could not measure, so one bad file doesn't sink the pick. */
    private fun readable(item: Map<String, Any>): Boolean {
        val sides = listOf(item["width"], item["height"]).all { (it as? Int ?: 0) > 0 }
        val video = item["kind"] == "video"
        return sides && (!video || (item["durationValue"] as? Long ?: 0L) > 0L)
    }

    /** Stops the worker thread; call when the activity is destroyed. */
    fun close() = io.shutdown()

    private fun rotationOf(orientation: Int) = when (orientation) {
        ExifInterface.ORIENTATION_ROTATE_90, ExifInterface.ORIENTATION_TRANSPOSE -> 90
        ExifInterface.ORIENTATION_ROTATE_180, ExifInterface.ORIENTATION_FLIP_VERTICAL -> 180
        ExifInterface.ORIENTATION_ROTATE_270, ExifInterface.ORIENTATION_TRANSVERSE -> 270
        else -> 0
    }

    private companion object {
        const val REQUEST = 0x46_4D // "FM"
    }
}
